#!/usr/bin/env python3
import requests, subprocess, os

CHANNEL_ID = "1477414797757907075"
BOT_TOKEN = "MTQ3Nz...bcVg"
DISCORD_API = "https://discord.com/api/v10"
HEADER = {"Authorization": f"Bot {BOT_TOKEN}"}
APPROVE_SCRIPT = "/home/administrator/site/scripts/approve-research-post.sh"

r = requests.get(f"{DISCORD_API}/channels/{CHANNEL_ID}/messages", headers=HEADER)
msgs = r.json() if r.status_code == 200 else []

approved = []
for msg in msgs:
    content = msg.get("content", "")
    if "📋 RESEARCH POST DRAFT" not in content:
        continue
    msg_id = msg["id"]
    # Check reactions
    reactions = msg.get("reactions", [])
    has_approve = any(r.get("emoji", {}).get("name") == "✅" for r in reactions)
    if has_approve:
        approved.append(msg_id)

if approved:
    print(f"Found {len(approved)} message(s) with ✅: {', '.join(approved)}")
    result = subprocess.run(["bash", APPROVE_SCRIPT, "all"], capture_output=True, text=True)
    print(result.stdout)
    if result.stderr:
        print(result.stderr)
    # Send confirmation
    confirm_msg = f"✅ Approve-all triggered by reactions on {len(approved)} message(s). Running approval..."
    requests.post(f"{DISCORD_API}/channels/{CHANNEL_ID}/messages", headers=HEADER, json={"content": confirm_msg})
else:
    print("No ✅ reactions found on research post drafts.")