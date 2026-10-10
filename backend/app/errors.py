"""Consistent application errors. Every error response has the shape:
{"error": {"code": str, "message": str, "details": any|null, "request_id": str|null}}
"""


class AppError(Exception):
    def __init__(self, status_code: int, code: str, message: str, details=None, headers=None):
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message
        self.details = details
        self.headers = headers or {}


def not_found(what: str = "Resource") -> AppError:
    # Ownership failures also use 404 so other users' resource ids are never confirmed.
    return AppError(404, "not_found", f"{what} not found.")


def conflict(code: str, message: str) -> AppError:
    return AppError(409, code, message)


class UniqueViolation(Exception):
    """Raised by repositories when a unique constraint rejects an insert."""
