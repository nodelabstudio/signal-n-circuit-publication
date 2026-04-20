import json, os, urllib.request
from pathlib import Path

# Read tokens directly from .env file
env_file = Path("/home/administrator/.hermes/.env")
tokens = {}
for line in env_file.read_text(encoding="utf-8", errors="replace").splitlines():
    if '=' in line:
        key, _, val = line.partition('=')
        tokens[key.strip()] = val.strip().strip('"').strip("'")

bot_token = tokens.get('DISCORD_BOT_TOKEN', '')
CHANNEL_ID = '1477414648348147765'

msg = {
    'content': '📤 **Draft Sent via Approval Watcher**\n'
               '**Draft ID:** `em_64b9p56a1e9xx8jj51dfjmqatp`\n'
               '**Sent at:** 2026-04-19T23:12:02Z\n'
               '**Status:** ✅ sent'
}

req = urllib.request.Request(
    f'https://discord.com/api/v10/channels/{CHANNEL_ID}/messages',
    data=json.dumps(msg).encode(),
    headers={
        'Content-Type': 'application/json',
        'Authorization': f'Bot {bot_token}',
        'User-Agent': 'SignalCircuitBot/1.0'
    },
    method='POST'
)
try:
    with urllib.request.urlopen(req, timeout=10) as r:
        print('Posted:', r.status)
except Exception as e:
    print('Error:', e)
