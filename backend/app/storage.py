"""Private object storage. The bucket is private; access is only through backend-signed URLs."""

from typing import Protocol


class Storage(Protocol):
    def upload(self, path: str, data: bytes, content_type: str) -> None: ...
    def download(self, path: str) -> bytes: ...
    def signed_url(self, path: str, ttl_seconds: int) -> str: ...
    def remove(self, paths: list[str]) -> None: ...


class SupabaseStorage:
    def __init__(self, client, bucket: str):
        self.bucket = client.storage.from_(bucket)

    def upload(self, path, data, content_type):
        self.bucket.upload(path, data, {"content-type": content_type, "upsert": "false"})

    def download(self, path):
        return self.bucket.download(path)

    def signed_url(self, path, ttl_seconds):
        res = self.bucket.create_signed_url(path, ttl_seconds)
        url = res.get("signedURL") or res.get("signedUrl") or res.get("signed_url")
        if not url:
            raise RuntimeError("Storage did not return a signed URL")
        return url

    def remove(self, paths):
        if paths:
            self.bucket.remove(paths)
