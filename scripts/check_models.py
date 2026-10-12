from pathlib import Path
env = {}
for line in Path(".env").read_text(encoding="utf-8").splitlines():
    if "=" in line and not line.strip().startswith("#"):
        k, v = line.split("=", 1); env[k.strip()] = v.strip().strip('"')
from google import genai
c = genai.Client(api_key=env["GEMINI_API_KEY"])
for m in ["gemini-2.5-flash", "gemini-3.5-flash", "gemini-3.7-flash", "gemini-3-flash-preview"]:
    try:
        r = c.models.generate_content(model=m, contents="Reply with the word OK.")
        print("WORKS ", m)
    except Exception as e:
        print("FAILED", m, getattr(e, "code", ""), str(e)[:90].replace("\n", " "))
