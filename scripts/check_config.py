"""Offline validation of the root .env file. Never prints secret values.
Usage: python scripts/check_config.py   (exit code 0 = OK, 1 = problems found)"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = ["SUPABASE_URL", "SUPABASE_ANON_KEY", "SUPABASE_SERVICE_ROLE_KEY", "GEMINI_API_KEY", "GEMINI_MODEL"]


def load(path: Path) -> dict:
    values = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        values[k.strip()] = v.strip().strip('"').strip("'")
    return values


def main() -> int:
    env_path = ROOT / ".env"
    if not env_path.exists():
        print("[FAIL] .env not found. Copy .env.example to .env and fill it in.")
        return 1
    env = load(env_path)
    problems = []
    for key in REQUIRED:
        v = env.get(key, "")
        if not v or "YOUR_" in v or v.startswith("your-"):
            problems.append(f"{key} is missing or still a placeholder.")
    url = env.get("SUPABASE_URL", "")
    if url and "YOUR_" not in url and not re.match(r"^https://[a-z0-9-]+\.supabase\.(co|com)/?$", url):
        problems.append("SUPABASE_URL should look like https://<project-ref>.supabase.co")
    anon, service = env.get("SUPABASE_ANON_KEY", ""), env.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if anon and service and anon == service:
        problems.append("SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are identical. Use the public key for the first "
                        "and the secret key for the second.")
    if env.get("GEMINI_API_KEY") and env.get("GEMINI_API_KEY") == service:
        problems.append("GEMINI_API_KEY equals the Supabase service key; check your values.")
    try:
        if int(env.get("MAX_UPLOAD_MB", "50")) > 50:
            print("[WARN] MAX_UPLOAD_MB is above 50. Supabase's free plan rejects files over 50 MB.")
    except ValueError:
        problems.append("MAX_UPLOAD_MB must be a whole number.")
    cors = env.get("CORS_ORIGINS", "http://localhost:5173")
    port = env.get("FRONTEND_PORT", "5173")
    if f"localhost:{port}" not in cors and f"127.0.0.1:{port}" not in cors:
        print(f"[WARN] CORS_ORIGINS does not include the frontend origin (http://localhost:{port}).")
    if problems:
        for p in problems:
            print("[FAIL]", p)
        return 1
    print("[ OK ] .env looks complete (values were not printed). Online checks: open /api/v1/health/ready after starting the backend.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
