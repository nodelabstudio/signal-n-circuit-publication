import subprocess, json, urllib.request

env_path = '/home/administrator/.hermes/.env'
var_name = 'DISCORD_BOT_TOKEN'
result = subprocess.run(
    ['bash', '-c', f'source {env_path} 2>/dev/null && printf "%s" "${{{var_name}}}"'],
    capture_output=True, text=True, timeout=5
)
DISCORD_BOT_TOKEN = result.stdout.strip()

CHANNEL_ID = '1477414648348147765'
DISCORD_API_BASE = 'https://discord.com/api/v10'

url = f'{DISCORD_API_BASE}/channels/{CHANNEL_ID}/messages'
headers = {
    'Authorization': f'Bot {DISCORD_BOT_TOKEN}',
    'Content-Type': 'application/json',
    'User-Agent': 'SignalCircuitBot/1.0'
}
payload = {
    'content': '✅ **Approval Watcher Report — April 19, 2026**\n\n**1 draft sent**\n\n**Draft ID:** `em_64b9p56a1e9xx8jj51dfjmqatp`\n**Status:** sent\n**Sent at:** 2026-04-19T22:41:40Z'
}

req = urllib.request.Request(
    url,
    data=json.dumps(payload).encode('utf-8'),
    headers=headers,
    method='POST'
)
try:
    with urllib.request.urlopen(req, timeout=30) as resp:
        body = resp.read().decode('utf-8')
        print(f'Status: {resp.status}')
        print(f'Response: {body[:300]}')
except Exception as e:
    print(f'Error: {e}')
