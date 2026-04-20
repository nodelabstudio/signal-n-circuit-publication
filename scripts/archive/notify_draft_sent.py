#!/usr/bin/env python3
"""Send a Discord notification about a draft that was just sent."""
import json
import urllib.request
from pathlib import Path

env_file = Path("/home/administrator/.hermes/.env")
discord_token = None
for line in env_file.read_text(encoding="utf-8", errors="replace").splitlines():
    stripped = line.strip()
    if stripped.startswith("DISCORD_BOT_TOKEN=") and len(stripped) > len("DISCORD_BOT_TOKEN="):
        value = line.split("=", 1)[1].strip().strip('"').strip("'")
        if value:
            discord_token = value
            break

CHANNEL_ID = "1477414648348147765"
url = f"https://discord.com/api/v10/channels/{CHANNEL_ID}/messages"
req = urllib.request.Request(
    url,
    data=json.dumps({
        "content": "📤 **Draft Sent via Approval Watcher**\n**Draft ID:** `em_64b9p56a1e9xx8jj51dfjmqatp`\n**Sent at:** 2026-04-19T19:11:34Z\n**Status:** sent"
    }).encode("utf-8"),
    headers={
        "Authorization": f"Bot {discord_token}",
        "Content-Type": "application/json",
        "User-Agent": "SignalCircuitBot/1.0"
    },
    method="POST"
)
with urllib.request.urlopen(req, timeout=30) as resp:
    result = json.loads(resp.read().decode("utf-8", errors="replace"))
    print("Message sent:", result.get("id"))
