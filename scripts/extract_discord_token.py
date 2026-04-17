#!/usr/bin/env python3
with open('/home/administrator/.hermes/.env', 'rb') as f:
    content = f.read()
pos = content.find(b'DISCORD_BOT_TOKEN=')
print('Position:', pos)
if pos >= 0:
    snippet = content[pos+18:pos+18+80]
    print('Raw bytes:', repr(snippet))