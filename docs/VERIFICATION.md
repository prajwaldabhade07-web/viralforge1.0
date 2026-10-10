# Verification status (honest ledger)

The project was built in an **offline Linux sandbox**: no internet, no Flutter/Dart SDK, and no FastAPI, Pydantic,
pytest, Supabase or Gemini packages installed. Nothing here has run against live Supabase or Gemini.

## Executed and passing in the sandbox (83 tests plus manual checks)
Run with a minimal pytest stand-in and, for the pipeline tests, a throwaway Pydantic stand-in (neither ships in this project):

| Area | Tests | Result |
|---|---|---|
| Scoring (formulas, half-up rounding, bounds, bands) | 23 | pass |
| Media validation (magic bytes, MP4/MOV/WebM duration parsing, spoofing, limits) | 14 | pass |
| Safety (sanitising, injection heuristics, delimiters, log redaction) | 14 | pass |
| Report assembly and personas | 4 | pass |
| Pipeline and worker with in-memory fakes (fail-closed moderation, blocking and deletion, transient requeue/backoff, partial/failed personas, lease loss, stale-job recovery, script input, duplicate guard, injection) | 17 | pass |
| Gemini gateway retry/error mapping, auth verifier and cache, rate limiter | 11 | pass |
| `scripts/check_config.py` against placeholder / valid / duplicate-key `.env` files | manual | pass |
| `python -m compileall` on all backend code and tests | n/a | pass |

The Pydantic stand-in does not run validators, so the *real* model validators were not exercised.

## Written but NOT executed (needs your machine)
- **Backend API tests** (`test_api_*.py`, `test_ai_schemas.py`: 37 tests) need FastAPI/Pydantic/httpx. They cover
  auth, ownership isolation, uploads, job lifecycle, retries, rate limits, OpenAPI, CORS and schema validators.
- **Flutter tests** (41 tests in `frontend/test`) and **`flutter analyze`**: no Flutter SDK was available. The Dart code
  got only a crude bracket/import check; expect to possibly fix a few compile or analyzer errors on first run.
- **`ruff`** lint/format, startup of the FastAPI app, `uvicorn`, Swagger generation.
- **All live integration**: Supabase auth/DB/storage calls (supabase-py API shapes were written from knowledge, not
  tested), SQL migrations on a real Postgres, Gemini Files API upload, `models.get`, structured output with
  `response_schema`, real video processing, the browser drag-and-drop component (`flutter_dropzone`), and Google Fonts loading.
- **Model availability:** whether `gemini-3.8-flash` exists for your key is unknown; the backend checks at startup.

## Suggested first run
1. `.\scripts\test.ps1` and report the first error, if any.
2. Start the backend and open `/api/v1/health/ready`.
3. Register, create a project, upload a short MP4, watch the analysis, open the report.
4. Register a second account and confirm it sees none of the first account's data.
