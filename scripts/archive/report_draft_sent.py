from pathlib import Path
import requests

env_file = Path("/home/administrator/.hermes/.env")
BOT_TOKEN = None
for line in env_file.read_text().splitlines():
    if line.startswith("DISCORD_BOT_TOKEN="):
        val = line.split("=", 1)[1]
        if val != "***":
            BOT_TOKEN = val
            break

# Fallback: read raw via subprocess (handles masked display)
if not BOT_TOKEN or BOT_TOKEN.count('.') < 2:
    import subprocess
    result = subprocess.run(
        ['bash', '-c', 'source /home/administrator/.hermes/.env 2>/dev/null && printf "%s" "$DISCORD_BOT_TOKEN"'],
        capture_output=True, text=True, timeout=5
    )
    BOT_TOKEN = result.stdout.strip()

CHANNEL_ID = '1477414648348147765'
url = f'https://discord.com/api/v10/channels/{CHANNEL_ID}/messages'
headers = {'Authorization': f'Bot {BOT_TOKEN}', 'Content-Type': 'application/json'}

content = """✅ **Draft Sent via Approval Watcher**

**Draft ID:** `em_64b9p56a1e9xx8jj51dfjmqatp`
**Sent at:** 2026-04-19T18:41:02Z
**Status:** sent"""

post = requests.post(url, headers=headers, json={'content': content})
print(post.status_code, post.text)
