# ViralForge Experimental

AI-powered, **video-first** analysis of short-form content. Upload a clip, say where you will post it
(Instagram Reels, TikTok or YouTube Shorts), and get a Viral Readiness Report based on what is actually in the
video: five scores, strengths, weaknesses, prioritised fixes, craft notes and ten AI-simulated viewer reactions.

This is a standalone project. It shares nothing with any other ViralForge repository.

| Part | Technology |
|---|---|
| Frontend | Flutter Web (Dart), Riverpod, go_router, Dio |
| Backend | Python 3.11+, FastAPI, Pydantic v2 |
| Auth / database / storage | Supabase (email+password auth, PostgreSQL with row level security, private bucket) |
| AI | Google Gemini through the official `google-genai` SDK (model set in `.env`) |

> **Read [docs/VERIFICATION.md](docs/VERIFICATION.md) first.** The code was written in an offline sandbox. It lists
> exactly what was executed, what was not, and what you should expect to check on your machine.

---

## 1. Prerequisites (Windows)

1. **Python 3.11 or newer**: https://www.python.org/downloads/ (tick *Add python.exe to PATH*).
2. **Flutter SDK 3.24 or newer** (stable, with web support): https://docs.flutter.dev/get-started/install/windows/web
3. **Google Chrome**.
4. A **Supabase** account (free plan is fine) and a **Gemini API key**.

## 2. Unzip

Unzip so the folder is `C:\Users\Admin\Desktop\viralforge-experiment` (any location works).

## 3. One-time cloud setup (click by click)

**Supabase**

1. Open https://supabase.com/dashboard → **New project**. Choose a name, a database password and a region. Wait until it finishes provisioning.
2. **Project Settings** (gear icon, bottom left) → **API** (or **API Keys**). Keep this page open; you need three values:
   - **Project URL**
   - the public key (**anon** or **publishable**)
   - the secret key (**service_role** or **secret**)
3. **SQL Editor** (left menu) → **New query**. Open `supabase\setup.sql` from this project in Notepad, copy everything, paste it into the editor and press **Run**. You should see *Success. No rows returned*. (It is safe to run again.)
4. **Authentication** → **Sign In / Providers** → **Email**. For quick local testing you may switch **Confirm email** off; otherwise new accounts must click the emailed link before signing in.
5. **Authentication** → **URL Configuration** → set **Site URL** to `http://localhost:5173`.
6. **Storage**: confirm a bucket named **videos** exists and is **Private**.

**Gemini**

1. Open https://aistudio.google.com/apikey → **Create API key**. Copy it.

## 4. Configure and install

Open PowerShell in the project folder:

```powershell
cd C:\Users\Admin\Desktop\viralforge-experiment
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1
```

The first run creates `.env` and tells you to fill it in. Then:

```powershell
notepad .env
```

Replace every `YOUR_...` placeholder with your values (the file explains each one). Never paste them into chat.
Run the setup script again; it installs everything and ends with `Setup complete`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1
```

## 5. Run (two terminals)

**Terminal 1: backend**
```powershell
.\scripts\run-backend.ps1
```
**Terminal 2: frontend** (opens Chrome at http://localhost:5173)
```powershell
.\scripts\run-frontend.ps1
```

| URL | What it is |
|---|---|
| http://localhost:8000/api/v1/health | Liveness |
| http://localhost:8000/api/v1/health/ready | **Readiness: checks config, database tables and that your Gemini key can use `GEMINI_MODEL`** |
| http://localhost:8000/docs | Interactive API documentation (Swagger) |
| http://localhost:5173 | The app |

**Open `/health/ready` before testing the app.** If it says `degraded`, its `checks` section tells you what to fix.
In particular, `gemini_model.ok = false` means `gemini-3.8-flash` is not available to your key: set `GEMINI_MODEL`
in `.env` to a model your key can use and restart the backend. The app never silently switches models.

## 6. Use it

Register → create a project → **New analysis** → drop or choose a video (MP4, WebM or MOV, up to 90 s and 50 MB by
default) → pick the platform, niche and audience → **Upload and analyse**. The status page updates live and you can
leave it; finished reports live under the project and in **History**.

## 7. Tests

```powershell
.\scripts\test.ps1     # ruff, pytest, flutter analyze, flutter test (Gemini is mocked: no API credits used)
```
Run one part: `cd backend; .\.venv\Scripts\python -m pytest -q` or `cd frontend; flutter test`.

## 8. Troubleshooting

| Symptom | Fix |
|---|---|
| `Missing configuration: ...` when starting the backend | `.env` still has placeholders. Edit it and restart. |
| Sign-in screen says it cannot reach the service | Check `SUPABASE_URL`/`SUPABASE_ANON_KEY`, then re-run `run-frontend.ps1` (it regenerates `frontend\config.json`). |
| App shows "Cannot reach the ViralForge server" | Backend is not running, or `API_BASE_URL` / `CORS_ORIGINS` in `.env` do not match the ports in use. |
| `/health/ready`: `database.ok = false` | `supabase\setup.sql` was not run (step 3.3), or `SUPABASE_URL` / service key are wrong. |
| `/health/ready`: model not available | Change `GEMINI_MODEL` (see section 5). |
| Upload says "Could not read the video's duration" | The file is fragmented or damaged. Re-export as a standard MP4 (H.264). |
| Upload fails above 50 MB | Supabase's free plan caps single files at 50 MB. |
| Registered but cannot sign in | Email confirmation is on: click the link in the email, or turn **Confirm email** off (step 3.4). |
| PowerShell blocks scripts | Use the `powershell -ExecutionPolicy Bypass -File ...` form shown above. |

## 9. How it works

1. **Upload** (`POST /projects/{id}/videos`): the backend streams the file with a size cap, sniffs the real container
   from its bytes (not the filename or MIME header), reads the duration, and stores it in a private bucket at
   `{user}/{project}/{video}.ext`. Videos are only reachable through short-lived signed URLs after an ownership check.
2. **Analysis** (`POST /projects/{id}/analyses`) returns `202` at once and creates a persistent `queued` job. A database
   unique index allows only one active job per video.
3. **Worker** (in-process thread, claims jobs with `FOR UPDATE SKIP LOCKED`): safety check → upload to Gemini Files
   API → analysis → persona simulation → deterministic scoring → report saved. Transient provider errors are
   re-queued with backoff; crashed jobs are recovered after a lease timeout; every state change is guarded so a
   stale worker cannot overwrite a newer result.
4. **Frontend** polls `GET /analyses/{id}` and renders the report when `status = completed`.

Details: [docs/API.md](docs/API.md) (contract) and [docs/SCORING.md](docs/SCORING.md) (rubric, moderation, safety).

## 10. Security notes

- The Supabase **service-role key** and the **Gemini key** exist only in the backend process. `frontend\config.json`
  is generated with the public URL, public anon key and API URL only, and is git-ignored.
- Every backend query is filtered by the authenticated user's id; other users' resources return `404`. Row level
  security on all tables is a second layer; clients can only read their own rows and cannot write videos, jobs or reports.
- Captions, scripts, niche text and anything inside the video are treated as untrusted data: sanitised, wrapped in
  per-request random delimiters, and the model is told never to follow instructions found there. Scores are
  computed by backend code, so a prompt injection cannot set them.
- Moderation runs before analysis and **fails closed**: if the check cannot complete, nothing is analysed. Blocked
  submissions are deleted (video, caption, script) and only the error code is kept.
- Per-user rate limits apply (defaults: 120 requests/min, 20 uploads/hour, 20 analyses/hour).

## 11. Known limits

- Single-process, in-memory rate limiter and worker: right for local use, not for multiple server instances.
- Uploads pass through the backend and are held in memory (≤ `MAX_UPLOAD_MB`).
- The server rejects over-length videos; the browser only pre-checks type and size.
- Scores and personas are AI opinions, not predictions or audience research (the report says so).
