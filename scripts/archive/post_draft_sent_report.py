#!/usr/bin/env python3
import os, urllib.request, json
from pathlib import Path

DISCORD_CHANNEL_ID = "1477414648348147765"
DISCORD_BOT_TOKEN = None

env_file = Path("/home/administrator/.hermes/.env")
if env_file.exists():
    for line in env_file.read_text(encoding="utf-8", errors="replace").splitlines():
        stripped = line.strip()
        if stripped.startswith("DISCORD_BOT_TOKEN=") and len(stripped) > len("DISCORD_BOT_TOKEN="):
            DISCORD_BOT_TOKEN = stripped.split("=", 1)[1].strip().strip('"').strip("'")
            break

if not DISCORD_BOT_TOKEN:
    print("ERROR: DISCORD_BOT_TOKEN not found in /home/administrator/.hermes/.env")
    exit(1)

url = f"https://discord.com/api/v10/channels/{DISCORD_CHANNEL_ID}/messages"
message = (
    "✅ **Approval Watcher Report — April 19, 2026**\n\n"
    "**1 draft sent**\n"
    "**Draft ID:** `em_64b9p56a1e9xx8jj51dfjmqatp`\n"
    "**Sent at:** 2026-04-19T20:36:32Z\n"
    "**Total drafts checked:** 15\n"
    "No errors encountered."
)
payload = json.dumps({"content": message}).encode()

req = urllib.request.Request(url, data=payload, method="POST")
req.add_header("Authorization", f"Bot {DISCORD_BOT_TOKEN}")
req.add_header("User-Agent", "SignalCircuitBot/1.0")
req.add_header("Content-Type", "application/json")

try:
    with urllib.request.urlopen(req) as resp:
        print(f"Discord delivery OK: {resp.status}")
except Exception as e:
    print(f"Discord delivery failed: {e}")
