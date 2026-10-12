import sys
from pathlib import Path
env = {}
for line in Path(".env").read_text(encoding="utf-8").splitlines():
    if "=" in line and not line.strip().startswith("#"):
        k, v = line.split("=", 1); env[k.strip()] = v.strip().strip('"')
from google import genai
c = genai.Client(api_key=env["GEMINI_API_KEY"])
m = env.get("GEMINI_MODEL", "gemini-3.8-flash")
print("Testing model:", m)
try:
    r = c.models.generate_content(model=m, contents="Reply with the word OK.")
    print("RESULT: works ->", r.text.strip()[:50])
except Exception as e:
    print("RESULT: failed ->", type(e).__name__, getattr(e, "code", ""), str(e)[:700])
print("\nModels your key lists (flash family):")
try:
    for x in c.models.list():
        if "flash" in x.name: print(" ", x.name.replace("models/", ""))
except Exception as e:
    print("could not list models:", str(e)[:200])
