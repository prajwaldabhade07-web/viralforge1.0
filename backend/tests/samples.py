"""Builders for minimal, structurally valid MP4 and WebM byte strings (header data only)."""
import struct


def mp4_bytes(seconds=10.0, timescale=1000, brand=b"isom", pad=2048, version=0, moov_first=True) -> bytes:
    ftyp_body = brand + b"\x00\x00\x02\x00" + b"isomiso2"
    ftyp = struct.pack(">I", 8 + len(ftyp_body)) + b"ftyp" + ftyp_body
    dur = int(seconds * timescale)
    if version == 1:
        body = b"\x01\x00\x00\x00" + struct.pack(">QQIQ", 0, 0, timescale, dur) + b"\x00" * 80
    else:
        body = b"\x00\x00\x00\x00" + struct.pack(">IIII", 0, 0, timescale, dur) + b"\x00" * 80
    mvhd = struct.pack(">I", 8 + len(body)) + b"mvhd" + body
    moov = struct.pack(">I", 8 + len(mvhd)) + b"moov" + mvhd
    mdat = struct.pack(">I", 8 + pad) + b"mdat" + b"\x00" * pad
    return ftyp + (moov + mdat if moov_first else mdat + moov)


def _size(n: int) -> bytes:
    return bytes([0x80 | n]) if n < 127 else bytes([0x40 | (n >> 8), n & 0xFF])


def _el(ident: bytes, payload: bytes) -> bytes:
    return ident + _size(len(payload)) + payload


def webm_bytes(seconds=10.0, pad=2048, doctype=b"webm") -> bytes:
    header = _el(b"\x1a\x45\xdf\xa3", _el(b"\x42\x82", doctype))
    info = _el(
        b"\x15\x49\xa9\x66",
        _el(b"\x2a\xd7\xb1", (1_000_000).to_bytes(3, "big")) + _el(b"\x44\x89", struct.pack(">d", seconds * 1000.0)),
    )
    cluster = _el(b"\x1f\x43\xb6\x75", b"\x00" * pad)
    segment = b"\x18\x53\x80\x67" + b"\x01\xff\xff\xff\xff\xff\xff\xff" + info + cluster
    return header + segment
