#!/usr/bin/env python3
import os, requests, json

BOT_TOKEN = os.environ.get('DISCORD_BOT_TOKEN')
CHANNEL_ID = '1477414648348147765'

headers = {'Authorization': f'Bot {BOT_TOKEN}', 'Content-Type': 'application/json'}
payload = {
    'content': '📤 **Draft Sent via Approval Watcher**\n**Draft ID:** `em_64b9p56a1e9xx8jj51dfjmqatp`\n**Sent at:** 2026-04-19T23:03:14Z\n**Status:** sent'
}
r = requests.post(f'https://discord.com/api/v10/channels/{CHANNEL_ID}/messages', headers=headers, json=payload)
print(r.status_code, r.text[:300])
