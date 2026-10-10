"""Gemini access behind a small interface so the pipeline can be tested with a fake.

Uses the official `google-genai` SDK. Model availability is verified through the API
(`models.get`); there is no silent fallback to another model.
"""
import logging
import re
import time
from typing import Protocol, TypeVar

from pydantic import BaseModel, ValidationError

log = logging.getLogger("viralforge.gemini")
T = TypeVar("T", bound=BaseModel)


class ModelUnavailable(Exception):
    """The configured model (or API key) cannot be used. Needs a configuration fix."""


class ProviderError(Exception):
    def __init__(self, message: str, transient: bool):
        super().__init__(message)
        self.transient = transient


class MalformedResponse(Exception):
    pass


class FileProcessingError(Exception):
    pass


class GeminiGateway(Protocol):
    def check_model(self) -> None: ...
    def upload_video(self, path: str, mime_type: str): ...
    def delete_file(self, handle) -> None: ...
    def generate_json(self, *, system: str, prompt: str, schema: type[T], file=None, temperature: float = 0.3) -> T: ...


class GoogleGenaiGateway:
    def __init__(self, api_key: str, model: str, timeout_s: int = 180, file_ready_timeout_s: int = 300,
                 max_attempts: int = 3, sleep=time.sleep):
        from google import genai
        from google.genai import types

        self._genai, self._types = genai, types
        self.model = model
        self.file_ready_timeout_s = file_ready_timeout_s
        self.max_attempts = max_attempts
        self._sleep = sleep
        self.client = genai.Client(api_key=api_key, http_options=types.HttpOptions(timeout=timeout_s * 1000))

    # ---- availability -------------------------------------------------------------------
    def check_model(self) -> None:
        try:
            self.client.models.get(model=self.model)
        except Exception as e:  # noqa: BLE001
            code = getattr(e, "code", None)
            if code in (400, 401, 403):
                raise ModelUnavailable("The Gemini API key was rejected. Check GEMINI_API_KEY in .env.") from e
            if code == 404:
                raise ModelUnavailable(
                    f"Model '{self.model}' is not available for this API key. Set GEMINI_MODEL in .env to a "
                    "model your key can use (list them at https://ai.google.dev/gemini-api/docs/models)."
                ) from e
            raise ModelUnavailable(f"Could not verify the Gemini model right now: {type(e).__name__}.") from e

    # ---- files --------------------------------------------------------------------------
    def upload_video(self, path: str, mime_type: str):
        try:
            f = self.client.files.upload(file=path, config=self._types.UploadFileConfig(mime_type=mime_type))
            deadline = time.monotonic() + self.file_ready_timeout_s
            while True:
                state = getattr(getattr(f, "state", None), "name", str(getattr(f, "state", "")))
                if state == "ACTIVE" or state == "None":
                    return f
                if state == "FAILED":
                    raise FileProcessingError("Gemini could not process this video. Try re-exporting it as MP4 (H.264).")
                if time.monotonic() > deadline:
                    raise ProviderError("Timed out waiting for Gemini to process the video.", transient=True)
                self._sleep(2)
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

    # ---- generation ---------------------------------------------------------------------
    def generate_json(self, *, system, prompt, schema, file=None, temperature=0.3):
        contents = [file, prompt] if file is not None else [prompt]
        config = self._types.GenerateContentConfig(
            system_instruction=system, temperature=temperature,
            response_mime_type="application/json", response_schema=schema,
        )
        repair_note = ""
        last_error = "unknown"
        for attempt in range(1, self.max_attempts + 1):
            try:
                resp = self.client.models.generate_content(
                    model=self.model, contents=contents + ([repair_note] if repair_note else []), config=config)
                text = (getattr(resp, "text", None) or "").strip()
                if not text:
                    raise MalformedResponse("empty response (possibly blocked by the provider)")
                text = re.sub(r"^```(?:json)?|```$", "", text, flags=re.MULTILINE).strip()
                return schema.model_validate_json(text)
            except (ValidationError, MalformedResponse, ValueError) as e:
                last_error = str(e)[:300]
                log.warning("Malformed Gemini output on attempt %d: %s", attempt, type(e).__name__)
                repair_note = ("Your previous reply was invalid (" + last_error.replace("\n", " ")[:200]
                               + "). Reply again with valid JSON that matches the schema exactly.")
            except Exception as e:  # noqa: BLE001
                err = self._classify(e)
                if isinstance(err, ProviderError) and err.transient and attempt < self.max_attempts:
                    self._sleep(min(2 ** attempt * 2, 20))
                    continue
                raise err from e
        raise MalformedResponse(f"The AI returned an invalid response after {self.max_attempts} attempts: {last_error}")

    def _classify(self, e: Exception) -> Exception:
        code = getattr(e, "code", None)
        if code in (401, 403):
            return ModelUnavailable("The Gemini API key was rejected. Check GEMINI_API_KEY in .env.")
        if code == 404:
            return ModelUnavailable(f"Model '{self.model}' is not available for this API key.")
        if code == 429 or (isinstance(code, int) and code >= 500) or "timeout" in type(e).__name__.lower() \
                or "connect" in type(e).__name__.lower():
            return ProviderError("The AI service is busy or unreachable.", transient=True)
        return ProviderError(f"The AI service rejected the request ({type(e).__name__}).", transient=False)
