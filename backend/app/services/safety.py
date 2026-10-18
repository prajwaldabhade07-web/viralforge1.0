"""Handling of untrusted text: sanitising, prompt-injection heuristics, log redaction."""

import logging
import re
import secrets
import unicodedata

_CONTROL = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f\u200b-\u200f\u202a-\u202e\u2066-\u2069]")
_MANY_NEWLINES = re.compile(r"\n{4,}")

_INJECTION_PATTERNS = [
    r"ignore\s+(all\s+|any\s+|the\s+)?(previous|prior|above|earlier)\s+(instructions|prompts?|rules)",
    r"disregard\s+(all\s+|any\s+|the\s+)?(previous|prior|above|system)",
    r"(reveal|print|show|repeat)\s+(your\s+|the\s+)?(system|hidden|initial)\s+(prompt|instructions)",
    r"you\s+are\s+now\s+(a|an|in)\b",
    r"\bnew\s+instructions?\s*:",
    r"</?\s*(system|assistant|developer)\s*>",
    r"\bjailbreak\b",
    r"override\s+(the\s+)?(scoring|scores?|rules|policy|moderation)",
    r"(give|assign|rate)\s+(this\s+|it\s+)?(a\s+)?(perfect|10/10|100)\b",
]
_INJECTION_RE = re.compile("|".join(_INJECTION_PATTERNS), re.IGNORECASE)


def sanitize_text(value: str | None, max_len: int) -> str:
    """Normalise untrusted text: strip control/bidi characters, collapse blank runs, truncate."""
    if not value:
        return ""
    text = unicodedata.normalize("NFC", str(value))
    text = _CONTROL.sub("", text).replace("\r\n", "\n").replace("\r", "\n")
    text = _MANY_NEWLINES.sub("\n\n\n", text).strip()
    return text[:max_len]


def detect_injection(text: str) -> bool:
    return bool(text and _INJECTION_RE.search(text))


def new_boundary() -> str:
    return secrets.token_hex(8)


def wrap_untrusted(label: str, text: str, boundary: str) -> str:
    """Wrap untrusted text in a per-request random boundary the user cannot predict or close."""
    safe = text.replace(boundary, "")
    return (
        f"<<<UNTRUSTED_{label.upper()}_{boundary}\n{safe}\nUNTRUSTED_{label.upper()}_{boundary}>>>"
    )


_SECRET_RE = re.compile(
    r"(eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{5,})"  # JWTs
    r"|(AIza[0-9A-Za-z_\-]{20,})"  # Google API keys
    r"|(sb_secret_[A-Za-z0-9_\-]+)|(sb_publishable_[A-Za-z0-9_\-]+)"
)


def redact(text: str) -> str:
    return _SECRET_RE.sub("[REDACTED]", text)


class RedactingFilter(logging.Filter):
    """Masks tokens and API keys that might leak into log messages."""

    def filter(self, record: logging.LogRecord) -> bool:
        try:
            record.msg = redact(record.getMessage())
            record.args = ()
        except Exception:  # never let logging break the app
            pass
        return True
