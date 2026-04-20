import discord
import asyncio
import os

TOKEN = os.environ.get('DISCORD_BOT_TOKEN')
CHANNEL_ID = 1477414648348147765

async def main():
    intents = discord.Intents.default()
    client = discord.Client(intents=intents)
    
    @client.event
    async def on_ready():
        channel = client.get_channel(CHANNEL_ID)
        await channel.send(
            '📤 **Approval Watcher Report**\n'
            '✅ **1 draft sent**\n'
            '**Draft ID:** `em_64b9p56a1e9xx8jj51dfjmqatp`\n'
            '**Sent at:** 2026-04-19T20:36:32Z\n'
            '**Total drafts checked:** 15'
        )
        await client.close()
    
    async with client:
        await client.start(TOKEN)

asyncio.run(main())
