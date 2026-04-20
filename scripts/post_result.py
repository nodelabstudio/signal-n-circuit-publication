import os
import requests
from pathlib import Path

env_file = Path("/home/administrator/.hermes/.env")
if env_file.exists():
    for line in env_file.read_text(encoding="utf-8", errors="replace").splitlines():
        stripped = line.strip()
        if stripped.startswith("DISCORD_BOT_TOKEN="):
            value = line.split("=", 1)[1].strip().strip('"').strip("'")
            if value:
                os.environ["DISCORD_BOT_TOKEN"] = value

BOT_TOKEN = os.environ['DISCORD_BOT_TOKEN']
CHANNEL_ID = '1477414648348147765'
url = f'https://discord.com/api/v10/channels/{CHANNEL_ID}/messages'
headers = {'Authorization': f'Bot {BOT_TOKEN}', 'Content-Type': 'application/json'}
payload = {
    'content': '✅ **Newsletter Sent!**\n**Draft ID:** `em_64b9p56a1e9xx8jj51dfjmqatp`\n**Subject:** Signal & Circuit Weekly: April 18, 2026\n**Status:** Successfully sent via Buttondown API at 2026-04-19T17:47:07Z'
}
r = requests.post(url, json=payload, headers=headers)
print(r.status_code, r.text[:200])
