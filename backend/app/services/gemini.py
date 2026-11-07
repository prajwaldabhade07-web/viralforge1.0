"""Gemini access behind a small interface so the pipeline can be tested with a fake.

Uses the official `google-genai` SDK. Model availability is verified through the API
(`models.get`); there is no silent fallback to another model.
"""

import logging
import random
import re
import time
from typing import Protocol, TypeVar

from pydantic import BaseModel, ValidationError

log = logging.getLogger("viralforge.gemini")
T = TypeVar("T", bound=BaseModel)


class ModelUnavailable(Exception):
    """The configured model (or API key) cannot be used. Needs a configuration fix."""


class ProviderError(Exception):
    def __init__(
        self,
        message: str,
        transient: bool,
        kind: str | None = None,
        retry_after: float | None = None,
    ):
        super().__init__(message)
        self.transient = transient
        self.kind = kind  # "quota" when the API key's quota for the model is exhausted
        self.retry_after = retry_after  # seconds Google asked us to wait, when known


_RETRY_RE = re.compile(r"retry in (?:(\d+)h)?(?:(\d+)m)?(?:([\d.]+)s)?", re.IGNORECASE)


def retry_seconds(message: str) -> float | None:
    """Parse Google's 'Please retry in 6h45m54.04s' hint; None when absent."""
    m = _RETRY_RE.search(message or "")
    if not m or not any(m.groups()):
        return None
    h, mn, sec = m.groups()
    return int(h or 0) * 3600 + int(mn or 0) * 60 + float(sec or 0)


class MalformedResponse(Exception):
    pass


class FileProcessingError(Exception):
    pass


class GeminiGateway(Protocol):
    def check_model(self) -> None: ...
    def upload_video(self, path: str, mime_type: str): ...
    def delete_file(self, handle) -> None: ...
    def generate_json(
        self, *, system: str, prompt: str, schema: type[T], file=None, temperature: float = 0.3
    ) -> T: ...


class GoogleGenaiGateway:
    def __init__(
        self,
        api_key: str,
        model: str,
        timeout_s: int = 120,
        file_ready_timeout_s: int = 300,
        max_attempts: int = 5,
        sleep=time.sleep,
        thinking_level: str = "",
        media_resolution: str = "",
    ):
        from google import genai
        from google.genai import types

        self._genai, self._types = genai, types
        self.model = model
        # Google recommends leaving temperature at its default for Gemini 3 models (low values can
        # make them loop or return empty/invalid output), so it is only sent for other models.
        self._default_temp = "gemini-3" in model.lower()
        self.file_ready_timeout_s = file_ready_timeout_s
        self.max_attempts = max_attempts
        self._sleep = sleep
        self.thinking_level = (thinking_level or "").strip()
        self.media_resolution = (media_resolution or "").strip()
        self._extras_ok = True  # flips to False if the API rejects the speed settings
        self.client = genai.Client(
            api_key=api_key, http_options=types.HttpOptions(timeout=timeout_s * 1000)
        )

    # ---- availability -------------------------------------------------------------------
    def check_model(self) -> None:
        try:
            self.client.models.get(model=self.model)
        except Exception as e:  # noqa: BLE001
            code = getattr(e, "code", None)
            if code in (400, 401, 403):
                raise ModelUnavailable(
                    "The Gemini API key was rejected. Check GEMINI_API_KEY in .env."
                ) from e
            if code == 404:
                raise ModelUnavailable(
                    f"Model '{self.model}' is not available for this API key. Set GEMINI_MODEL in .env to a "
                    "model your key can use (list them at https://ai.google.dev/gemini-api/docs/models)."
                ) from e
            raise ModelUnavailable(
                f"Could not verify the Gemini model right now: {type(e).__name__}."
            ) from e

    # ---- files --------------------------------------------------------------------------
    def upload_video(self, path: str, mime_type: str):
        try:
            f = self.client.files.upload(
                file=path, config=self._types.UploadFileConfig(mime_type=mime_type)
            )
            deadline = time.monotonic() + self.file_ready_timeout_s
            while True:
                state = getattr(getattr(f, "state", None), "name", str(getattr(f, "state", "")))
                if state == "ACTIVE" or state == "None":
                    return f
                if state == "FAILED":
                    raise FileProcessingError(
                        "Gemini could not process this video. Try re-exporting it as MP4 (H.264)."
                    )
                if time.monotonic() > deadline:
                    raise ProviderError(
                        "Timed out waiting for Gemini to process the video.", transient=True
                    )
                self._sleep(1)
                f = self.client.files.get(name=f.name)
        except (FileProcessingError, ProviderError):
            raise
        except Exception as e:  # noqa: BLE001
            raise self._classify(e) from e

    def delete_file(self, handle) -> None:
        try:
            self.client.files.delete(name=handle.name)
        except Exception:  # noqa: BLE001 - best effort; files auto-expire after 48h
            log.warning("Could not delete temporary Gemini file")

    # ---- speed settings -----------------------------------------------------------------
    def _extras(self, has_file: bool) -> dict:
        """Optional speed settings (low thinking, low video resolution). Built defensively:
        anything the installed SDK or the model does not support is skipped."""
        if not getattr(self, "_extras_ok", False):
            return {}
        out: dict = {}
        level = getattr(self, "thinking_level", "")
        if level:
            try:
                out["thinking_config"] = self._types.ThinkingConfig(thinking_level=level)
            except Exception:  # noqa: BLE001
                pass
        res = getattr(self, "media_resolution", "")
        if has_file and res:
            try:
                out["media_resolution"] = getattr(
                    self._types.MediaResolution, f"MEDIA_RESOLUTION_{res.upper()}"
                )
            except Exception:  # noqa: BLE001
                pass
        return out

    def _make_config(self, system, temperature, schema, has_file, use_extras=True):
        base = dict(
            system_instruction=system,
            response_mime_type="application/json",
            response_schema=schema,
        )
        if not getattr(self, "_default_temp", False):
            base["temperature"] = temperature
        extras = self._extras(has_file) if use_extras else {}
        try:
            return self._types.GenerateContentConfig(**base, **extras)
        except Exception:  # noqa: BLE001
            if not extras:
                raise
            log.warning("Speed settings are not supported by this SDK; continuing without them")
            self._extras_ok = False
            return self._types.GenerateContentConfig(**base)

    # ---- generation ---------------------------------------------------------------------
    def generate_json(self, *, system, prompt, schema, file=None, temperature=0.3):
        contents = [file, prompt] if file is not None else [prompt]
        repair_note = ""
        last_error = "unknown"
        # Speed settings are dropped for the rest of this call if the API keeps failing.
        use_extras = True
        for attempt in range(1, self.max_attempts + 1):
            config = self._make_config(system, temperature, schema, file is not None, use_extras)
            try:
                resp = self.client.models.generate_content(
                    model=self.model,
                    contents=contents + ([repair_note] if repair_note else []),
                    config=config,
                )
                text = (getattr(resp, "text", None) or "").strip()
                if not text:
                    declined = self._declined_reason(resp)
                    if declined:
                        raise ProviderError(
                            "The AI provider's own safety filter declined to process this "
                            f"content ({declined}), so nothing was analysed. Try a different video.",
                            transient=False,
                            kind="declined",
                        )
                    raise MalformedResponse("empty response from the AI")
                text = re.sub(r"^```(?:json)?|```$", "", text, flags=re.MULTILINE).strip()
                return schema.model_validate_json(text)
            except (ValidationError, MalformedResponse, ValueError) as e:
                last_error = str(e)[:300]
                log.warning("Malformed Gemini output on attempt %d: %s", attempt, type(e).__name__)
                repair_note = (
                    "Your previous reply was invalid ("
                    + last_error.replace("\n", " ")[:200]
                    + "). Reply again with valid JSON that matches the schema exactly."
                )
            except ProviderError:
                raise
            except Exception as e:  # noqa: BLE001
                if (
                    getattr(e, "code", None) == 400
                    and use_extras
                    and self._extras(file is not None)
                ):
                    log.warning("Gemini rejected the speed settings; retrying without them")
                    self._extras_ok = False
                    continue
                err = self._classify(e)
                # Log the real cause (provider text only, never user content).
                log.warning(
                    "Gemini call failed (attempt %d/%d): %s | %s",
                    attempt,
                    self.max_attempts,
                    self._describe(e),
                    str(e).replace("\n", " ")[:200],
                )
                if isinstance(err, ProviderError) and err.transient and attempt < self.max_attempts:
                    if use_extras and attempt >= 2 and self._extras(file is not None):
                        # Two server-side failures in a row: try again with plain settings.
                        use_extras = False
                        log.warning("Retrying Gemini without the speed settings")
                    wait = err.retry_after or self._backoff(attempt)
                    self._sleep(min(wait, 60))
                    continue
                raise err from e
        raise MalformedResponse(
            f"The AI returned an invalid response after {self.max_attempts} attempts: {last_error}"
        )

    @staticmethod
    def _declined_reason(resp) -> str | None:
        """Name of the provider-side safety block (prompt or candidate), or None when the reply is
        simply empty or cut off and is worth retrying."""
        fb = getattr(resp, "prompt_feedback", None)
        br = getattr(fb, "block_reason", None)
        name = getattr(br, "name", None) or (str(br) if br else "")
        if name and name != "BLOCK_REASON_UNSPECIFIED":
            return name
        for cand in getattr(resp, "candidates", None) or []:
            fr = getattr(cand, "finish_reason", None)
            fname = getattr(fr, "name", None) or (str(fr) if fr else "")
            if fname in ("SAFETY", "PROHIBITED_CONTENT", "BLOCKLIST", "SPII"):
                return fname
        return None

    @staticmethod
    def _backoff(attempt: int) -> float:
        """Patient, jittered waits (about 5, 15, 30, 45 s): overloaded models need time."""
        return [5, 15, 30, 45][min(attempt - 1, 3)] + random.uniform(0, 2)

    @staticmethod
    def _describe(e: Exception) -> str:
        parts = [type(e).__name__]
        code = getattr(e, "code", None)
        if code:
            parts.append(str(code))
        status = getattr(e, "status", None)
        if isinstance(status, str) and status:
            parts.append(status)
        return " ".join(parts)

    def _classify(self, e: Exception) -> Exception:
        code = getattr(e, "code", None)
        if code in (401, 403):
            return ModelUnavailable(
                "The Gemini API key was rejected. Check GEMINI_API_KEY in .env."
            )
        if code == 404:
            return ModelUnavailable(f"Model '{self.model}' is not available for this API key.")
        if code == 429:
            msg = str(e)
            secs = retry_seconds(msg)
            if (secs is not None and secs > 90) or "perday" in msg.lower().replace(" ", "").replace(
                "_", ""
            ):
                when = (
                    f" It resets in about {int(secs // 3600)}h {int(secs % 3600 // 60)}m."
                    if secs
                    else ""
                )
                return ProviderError(
                    f"The Gemini API quota for model '{self.model}' is used up.{when} Set GEMINI_MODEL in .env to "
                    "another model, wait for the reset, or enable billing on the key's Google project.",
                    transient=False,
                    kind="quota",
                )
            return ProviderError(
                "The AI service is rate limiting requests. Retrying shortly.",
                transient=True,
                retry_after=(secs + 1) if secs else None,
            )
        if (
            (isinstance(code, int) and code >= 500)
            or "timeout" in type(e).__name__.lower()
            or "connect" in type(e).__name__.lower()
        ):
            return ProviderError(
                f"The AI service is busy or unreachable ({self._describe(e)}).", transient=True
            )
        return ProviderError(
            f"The AI service rejected the request ({self._describe(e)}).", transient=False
        )
