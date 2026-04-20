import os
token = os.environ.get('DISCORD_BOT_TOKEN', '')
webhook = os.environ.get('DISCORD_WEBHOOK_APPROVAL', '')
print('DISCORD_BOT_TOKEN:', 'set' if token else 'NOT SET', '| prefix:', token[:20] if token else '')
print('DISCORD_WEBHOOK_APPROVAL:', 'set' if webhook else 'NOT SET')
