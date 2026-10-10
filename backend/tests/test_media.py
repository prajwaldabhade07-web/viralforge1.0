import pytest

from app.services.media import MediaError, validate_upload
from tests.samples import mp4_bytes, webm_bytes

KW = dict(allowed_extensions=["mp4", "webm", "mov"], max_bytes=50 * 1024 * 1024, min_seconds=1, max_seconds=90)


def check(name, data, mime="video/mp4", **over):
    return validate_upload(filename=name, declared_mime=mime, data=data, **{**KW, **over})


def code_of(fn):
    with pytest.raises(MediaError) as e:
        fn()
    return e.value.code


def test_valid_mp4():
    info = check("clip.mp4", mp4_bytes(12.5))
    assert (info.container, info.mime_type, info.duration_seconds) == ("mp4", "video/mp4", 12.5)


def test_valid_mp4_with_moov_at_end_and_64bit_mvhd():
    assert check("c.mp4", mp4_bytes(30, moov_first=False)).duration_seconds == 30
    assert check("c.mp4", mp4_bytes(45, version=1, timescale=90000)).duration_seconds == 45


def test_valid_webm():
    info = check("clip.webm", webm_bytes(20), mime="video/webm")
    assert (info.container, info.duration_seconds) == ("webm", 20.0)


def test_valid_mov():
    info = check("clip.mov", mp4_bytes(8, brand=b"qt  "), mime="video/quicktime")
    assert info.container == "mov"


def test_generic_mime_allowed_because_contents_are_sniffed():
    assert check("clip.mp4", mp4_bytes(), mime="application/octet-stream").container == "mp4"


def test_wrong_extension_rejected():
    assert code_of(lambda: check("clip.exe", mp4_bytes())) == "unsupported_extension"
    assert code_of(lambda: check("clip", mp4_bytes())) == "unsupported_extension"


def test_renamed_non_video_rejected():
    assert code_of(lambda: check("evil.mp4", b"MZ\x90\x00" + b"\x00" * 4000)) == "unsupported_media"
    assert code_of(lambda: check("evil.mp4", b"<html>" + b"a" * 4000)) == "unsupported_media"


def test_extension_must_match_contents():
    assert code_of(lambda: check("clip.webm", mp4_bytes(), mime="video/webm")) == "extension_mismatch"


def test_declared_mime_must_match_contents():
    assert code_of(lambda: check("clip.mp4", mp4_bytes(), mime="video/webm")) == "mime_mismatch"
    assert code_of(lambda: check("clip.mp4", mp4_bytes(), mime="image/png")) == "mime_mismatch"


def test_audio_and_image_brands_rejected():
    assert code_of(lambda: check("a.mp4", mp4_bytes(brand=b"M4A "))) == "unsupported_media"
    assert code_of(lambda: check("a.mp4", mp4_bytes(brand=b"heic"))) == "unsupported_media"


def test_matroska_rejected():
    assert code_of(lambda: check("a.webm", webm_bytes(doctype=b"matroska"), mime="video/webm")) == "unsupported_media"


def test_size_limits():
    assert code_of(lambda: check("a.mp4", b"")) == "empty_or_tiny_file"
    assert code_of(lambda: check("a.mp4", mp4_bytes(pad=5000), max_bytes=4000)) == "file_too_large"


def test_duration_limits():
    assert code_of(lambda: check("a.mp4", mp4_bytes(0.4))) == "video_too_short"
    assert code_of(lambda: check("a.mp4", mp4_bytes(300))) == "video_too_long"
    assert check("a.mp4", mp4_bytes(90)).duration_seconds == 90  # boundary allowed


def test_truncated_or_corrupt_container():
    data = mp4_bytes()
    ftyp_only = data[:data.index(b"moov") - 4] + b"\x00" * 2000
    assert code_of(lambda: check("a.mp4", ftyp_only)) == "duration_unreadable"
    assert code_of(lambda: check("a.webm", webm_bytes()[:30] + b"\x00" * 2000, mime="video/webm")) == "duration_unreadable"
