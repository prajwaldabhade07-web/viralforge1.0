"""Upload validation that does not trust filename or client MIME type.

Container type is sniffed from magic bytes; duration is read from the container header
(MP4/MOV `mvhd`, WebM EBML Info) in pure Python, so no ffprobe is required.
"""

import os
import struct
from dataclasses import dataclass

CANONICAL_MIME = {"mp4": "video/mp4", "mov": "video/quicktime", "webm": "video/webm"}
_ACCEPTED_DECLARED = {
    "mp4": {"video/mp4", "video/x-m4v", "application/mp4"},
    "mov": {"video/quicktime", "video/mov"},
    "webm": {"video/webm"},
}
_GENERIC_MIME = {"", "application/octet-stream", "binary/octet-stream"}
_NON_VIDEO_BRANDS = {
    b"M4A ",
    b"M4B ",
    b"M4P ",
    b"heic",
    b"heix",
    b"hevc",
    b"mif1",
    b"msf1",
    b"avif",
    b"avis",
    b"crx ",
}
_MIN_BYTES = 1024


class MediaError(Exception):
    def __init__(self, code: str, message: str, status: int = 422):
        super().__init__(message)
        self.code = code
        self.message = message
        self.status = status


@dataclass(frozen=True)
class VideoInfo:
    container: str  # mp4 | mov | webm
    extension: str
    mime_type: str
    duration_seconds: float


def sniff_container(head: bytes) -> str | None:
    if len(head) >= 12 and head[4:8] == b"ftyp":
        brand = head[8:12]
        if brand in _NON_VIDEO_BRANDS:
            return None
        return "mov" if brand == b"qt  " else "mp4"
    if head[:4] == b"\x1a\x45\xdf\xa3":
        return "webm" if b"webm" in head[:64] else None  # Matroska (.mkv) is not supported
    return None


def _mp4_duration(data: bytes) -> float | None:
    n, pos = len(data), 0
    while pos + 8 <= n:
        size = struct.unpack(">I", data[pos : pos + 4])[0]
        typ, header = data[pos + 4 : pos + 8], 8
        if size == 1:
            if pos + 16 > n:
                return None
            size, header = struct.unpack(">Q", data[pos + 8 : pos + 16])[0], 16
        elif size == 0:
            size = n - pos
        if size < header:
            return None
        if typ == b"moov":
            return _mvhd_duration(data, pos + header, min(pos + size, n))
        pos += size
    return None


def _mvhd_duration(data: bytes, start: int, end: int) -> float | None:
    pos = start
    while pos + 8 <= end:
        size = struct.unpack(">I", data[pos : pos + 4])[0]
        typ = data[pos + 4 : pos + 8]
        if size < 8:
            return None
        if typ == b"mvhd":
            body = pos + 8
            if body + 4 > end:
                return None
            version = data[body]
            try:
                if version == 1:
                    timescale = struct.unpack(">I", data[body + 20 : body + 24])[0]
                    duration = struct.unpack(">Q", data[body + 24 : body + 32])[0]
                else:
                    timescale = struct.unpack(">I", data[body + 12 : body + 16])[0]
                    duration = struct.unpack(">I", data[body + 16 : body + 20])[0]
            except struct.error:
                return None
            return duration / timescale if timescale else None
        pos += size
    return None


def _vint(data: bytes, pos: int, keep_marker: bool) -> tuple[int, int, bool] | None:
    """Read an EBML variable-length integer. Returns (value, length, unknown_size)."""
    if pos >= len(data):
        return None
    first = data[pos]
    length = 1
    mask = 0x80
    while length <= 8 and not first & mask:
        length += 1
        mask >>= 1
    if length > 8 or pos + length > len(data):
        return None
    value = first if keep_marker else first & (mask - 1)
    for b in data[pos + 1 : pos + length]:
        value = (value << 8) | b
    unknown = (not keep_marker) and value == (1 << (7 * length)) - 1
    return value, length, unknown


def _webm_duration(data: bytes) -> float | None:
    segment, info = 0x18538067, 0x1549A966
    pos, n = 0, len(data)
    seg_end = n
    in_segment = False
    timescale = 1_000_000
    duration = None
    steps = 0
    while pos < n and steps < 500:
        steps += 1
        ident = _vint(data, pos, True)
        if ident is None:
            break
        eid, ilen, _ = ident
        size = _vint(data, pos + ilen, False)
        if size is None:
            break
        esize, slen, unknown = size
        body = pos + ilen + slen
        if eid == segment:
            in_segment, seg_end = True, (n if unknown else min(n, body + esize))
            pos = body
            continue
        if eid == info and in_segment:
            end, p = min(seg_end, body + esize), body
            while p < end:
                i2 = _vint(data, p, True)
                if i2 is None:
                    break
                s2 = _vint(data, p + i2[1], False)
                if s2 is None:
                    break
                b2 = p + i2[1] + s2[1]
                payload = data[b2 : b2 + s2[0]]
                if i2[0] == 0x2AD7B1:
                    timescale = int.from_bytes(payload, "big") or timescale
                elif i2[0] == 0x4489:
                    if len(payload) == 4:
                        duration = struct.unpack(">f", payload)[0]
                    elif len(payload) == 8:
                        duration = struct.unpack(">d", payload)[0]
                p = b2 + s2[0]
            return duration * timescale / 1e9 if duration else None
        pos = body + esize
    return None


def read_duration(container: str, data: bytes) -> float | None:
    try:
        return _webm_duration(data) if container == "webm" else _mp4_duration(data)
    except (struct.error, IndexError, OverflowError):
        return None


def validate_upload(
    *,
    filename: str,
    declared_mime: str | None,
    data: bytes,
    allowed_extensions: list[str],
    max_bytes: int,
    min_seconds: float,
    max_seconds: float,
) -> VideoInfo:
    ext = os.path.splitext(filename or "")[1].lower().lstrip(".")
    if not ext or ext not in allowed_extensions:
        raise MediaError(
            "unsupported_extension",
            f"Unsupported file type. Use one of: {', '.join(allowed_extensions)}.",
        )
    if len(data) < _MIN_BYTES:
        raise MediaError("empty_or_tiny_file", "That file is empty or too small to be a video.")
    if len(data) > max_bytes:
        raise MediaError(
            "file_too_large", f"The video is larger than {max_bytes // (1024 * 1024)} MB.", 413
        )

    container = sniff_container(data[:64])
    if container is None:
        raise MediaError(
            "unsupported_media", "The file contents are not a supported MP4, MOV or WebM video."
        )
    if container not in allowed_extensions or ext != container:
        raise MediaError(
            "extension_mismatch",
            f"The file extension .{ext} does not match its contents ({container}).",
        )
    declared = (declared_mime or "").split(";")[0].strip().lower()
    if declared not in _GENERIC_MIME and declared not in _ACCEPTED_DECLARED[container]:
        raise MediaError(
            "mime_mismatch", "The declared file type does not match the file contents."
        )

    duration = read_duration(container, data)
    if duration is None or duration <= 0:
        raise MediaError(
            "duration_unreadable",
            "Could not read the video's duration. The file may be corrupted or fragmented; re-export it as a standard MP4.",
        )
    if duration < min_seconds:
        raise MediaError(
            "video_too_short", f"The video must be at least {min_seconds:g} seconds long."
        )
    if duration > max_seconds:
        raise MediaError(
            "video_too_long",
            f"The video must be {max_seconds:g} seconds or shorter (yours is {duration:.0f}s).",
        )
    return VideoInfo(container, container, CANONICAL_MIME[container], round(duration, 2))
