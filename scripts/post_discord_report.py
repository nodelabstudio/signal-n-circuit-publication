#!/usr/bin/env python3
"""Post approval watcher report to Discord."""
import json, os, urllib.request
from datetime import datetime, timezone
from pathlib import Path

CHANNEL_ID = "1477414648348147765"
DISCORD_API_BASE = "https://discord.com/api/v10"

def read_token(prefix: str) -> str:
    env_file = Path("/home/administrator/.hermes/.env")
    for line in env_file.read_text(encoding="utf-8", errors="replace").splitlines():
        stripped = line.strip()
        if stripped.startswith(f"{prefix}=") and len(stripped) > len(f"{prefix}=") + 2:
            return line.split("=", 1)[1].strip().strip('"').strip("'")
    raise ValueError(f"{prefix} not found")

def post_message(token: str, content: str) -> dict:
    url = f"{DISCORD_API_BASE}/channels/{CHANNEL_ID}/messages"
    data = json.dumps({"content": content}).encode("utf-8")
    req = urllib.request.Request(
        url, data=data, method="POST",
        headers={
            "Authorization": f"Bot {token}",
            "Content-Type": "application/json",
            "User-Agent": "SignalCircuitBot/1.0",
        }
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))

if __name__ == "__main__":
    token = read_token("DISCORD_BOT_TOKEN")
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    content = (
        f"📤 **Approval Watcher Report — {now}**\n"
        f"**1 draft sent**\n"
        f"**Draft ID:** `em_64b9p56a1e9xx8jj51dfjmqatp`\n"
        f"**Status:** ✅ Sent"
    )
    result = post_message(token, content)
    print(f"Posted message {result['id']} to Discord channel {CHANNEL_ID}")
