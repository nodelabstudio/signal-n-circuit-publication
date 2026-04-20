#!/usr/bin/env python3
import os
token = os.environ.get("DISCORD_BOT_TOKEN", "")
print("DISCORD_BOT_TOKEN set:", bool(token))
print("Token prefix:", token[:10] if token else "(empty)")
