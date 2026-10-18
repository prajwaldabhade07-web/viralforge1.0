"""Thin data-access layer. One generic interface, a Supabase implementation here and an
in-memory one in tests/fakes.py. Ownership (user_id) is always part of the `where` filters
built by the services/routers; the Supabase service-role key bypasses RLS, so this code
is the enforcement point for backend access (RLS protects any direct client access)."""

from typing import Any, Protocol

from app.errors import UniqueViolation

Where = dict[str, Any]  # {"col": value} for equality, {"col": ("in", [..])} for membership


class Repo(Protocol):
    def insert(self, table: str, row: dict) -> dict: ...
    def select(
        self,
        table: str,
        where: Where | None = None,
        order: str | None = None,
        desc: bool = True,
        limit: int | None = None,
        offset: int = 0,
    ) -> list[dict]: ...
    def count(self, table: str, where: Where | None = None) -> int: ...
    def update(self, table: str, where: Where, patch: dict) -> list[dict]: ...
    def delete(self, table: str, where: Where) -> int: ...
    def claim_next_job(self, lease_seconds: int) -> dict | None: ...


def _apply(q, where: Where | None):
    for col, val in (where or {}).items():
        if isinstance(val, tuple) and val and val[0] == "in":
            q = q.in_(col, list(val[1]))
        elif val is None:
            q = q.is_(col, "null")
        else:
            q = q.eq(col, val)
    return q


class SupabaseRepo:
    def __init__(self, url: str, service_key: str):
        from supabase import create_client

        self.client = create_client(url, service_key)

    def insert(self, table, row):
        try:
            res = self.client.table(table).insert(row).execute()
        except Exception as e:  # noqa: BLE001
            if (
                getattr(e, "code", None) == "23505"
                or "23505" in str(e)
                or "duplicate key" in str(e)
            ):
                raise UniqueViolation(str(table)) from e
            raise
        return res.data[0]

    def select(self, table, where=None, order=None, desc=True, limit=None, offset=0):
        q = _apply(self.client.table(table).select("*"), where)
        if order:
            q = q.order(order, desc=desc)
        if limit is not None:
            q = q.range(offset, offset + limit - 1)
        return q.execute().data or []

    def count(self, table, where=None):
        q = _apply(self.client.table(table).select("id", count="exact"), where).limit(1)
        return q.execute().count or 0

    def update(self, table, where, patch):
        try:
            return _apply(self.client.table(table).update(patch), where).execute().data or []
        except Exception as e:  # noqa: BLE001
            if (
                getattr(e, "code", None) == "23505"
                or "23505" in str(e)
                or "duplicate key" in str(e)
            ):
                raise UniqueViolation(str(table)) from e
            raise

    def delete(self, table, where):
        return len(_apply(self.client.table(table).delete(), where).execute().data or [])

    def claim_next_job(self, lease_seconds):
        rows = self.client.rpc("claim_next_job", {"lease_seconds": lease_seconds}).execute().data
        if isinstance(rows, dict):
            rows = [rows]
        rows = [r for r in (rows or []) if r and r.get("id")]
        return rows[0] if rows else None
