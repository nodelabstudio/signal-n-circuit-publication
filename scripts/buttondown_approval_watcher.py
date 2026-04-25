#!/usr/bin/env python3
"""
Buttondown Draft Reaction Watcher

Polls Discord channel 1477414648348147765 for draft notifications with 👍 reactions.
When a draft notification has a 👍 reaction, sends the draft via Buttondown API.

Run this as a cron job every 5-10 minutes.
"""

import json
import os
import re
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional
import urllib.parse
import urllib.request

# Discord configuration
DISCORD_CHANNEL_ID = "1477414648348147765"
DISCORD_API_BASE = "https://discord.com/api/v10"
MESSAGE_LIMIT = 25  # How many recent messages to check
POLL_INTERVAL_MINUTES = 5  # For continuous polling mode

# Buttondown draft pattern in Discord messages
DRAFT_PATTERN = r"\*\*Draft ID:\*\* `([a-z0-9_]+)`"


def read_discord_token() -> Optional[str]:
    """Read Discord bot token from .env."""
    env_file = Path("/home/administrator/.hermes/.env")
    if not env_file.exists():
        return None
    
    for line in env_file.read_text(encoding="utf-8", errors="replace").splitlines():
        stripped = line.strip()
        if stripped.startswith("DISCORD_BOT_TOKEN=") and len(stripped) > len("DISCORD_BOT_TOKEN="):
            value = line.split("=", 1)[1].strip().strip('"').strip("'")
            if value:
                return value
    return None


def read_buttondown_key() -> Optional[str]:
    """Read Buttondown API key from .env."""
    env_file = Path("/home/administrator/.hermes/.env")
    if not env_file.exists():
        return None
    
    for line in env_file.read_text(encoding="utf-8", errors="replace").splitlines():
        stripped = line.strip()
        if stripped.startswith("BUTTONDOWN_API_KEY=") and len(stripped) > len("BUTTONDOWN_API_KEY="):
            value = line.split("=", 1)[1].strip().strip('"').strip("'")
            if value:
                return value
    return None


def discord_api_request(method: str, endpoint: str, token: str, data: Optional[dict] = None) -> dict:
    """Make a Discord API request."""
    url = f"{DISCORD_API_BASE}/{endpoint}"
    headers = {
        "Authorization": f"Bot {token}",
        "Content-Type": "application/json",
        "User-Agent": "SignalCircuitBot/1.0"
    }
    
    req_data = None
    if data is not None:
        req_data = json.dumps(data).encode("utf-8")
    
    req = urllib.request.Request(
        url,
        data=req_data,
        headers=headers,
        method=method
    )
    
    with urllib.request.urlopen(req, timeout=30) as resp:
        raw = resp.read().decode("utf-8", errors="replace")
        return json.loads(raw) if raw else {}


def fetch_channel_messages(token: str, limit: int = MESSAGE_LIMIT) -> List[dict]:
    """Fetch recent messages from the Discord channel."""
    try:
        endpoint = f"channels/{DISCORD_CHANNEL_ID}/messages?limit={limit}"
        return discord_api_request("GET", endpoint, token)
    except Exception as e:
        print(f"WARNING: Failed to fetch Discord messages: {e}")
        return []


def extract_draft_id(message: dict) -> Optional[str]:
    """Extract Buttondown draft ID from a Discord message."""
    content = message.get("content", "")
    match = re.search(DRAFT_PATTERN, content)
    if match:
        return match.group(1)
    return None


def has_thumbs_up_reaction(message: dict) -> bool:
    """Check if a message has at least one 👍 reaction."""
    reactions = message.get("reactions", [])
    for reaction in reactions:
        emoji = reaction.get("emoji", {})
        if emoji.get("name") == "👍" and reaction.get("count", 0) > 0:
            return True
    return False


def get_buttondown_draft_status(draft_id: str, api_key: str) -> Optional[str]:
    """Return a Buttondown draft's current status, or None if lookup fails."""
    try:
        url = "https://api.buttondown.email/v1/emails"
        req = urllib.request.Request(
            url,
            headers={
                "Authorization": f"Token {api_key}",
                "Content-Type": "application/json",
                "User-Agent": "SignalCircuitBot/1.0",
            }
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            result = json.loads(resp.read().decode("utf-8", errors="replace"))
        for email in result.get("results", []):
            if email.get("id") == draft_id:
                return email.get("status")
    except Exception as e:
        print(f"WARNING: Failed to check Buttondown status for {draft_id}: {e}")
    return None


def send_buttondown_draft(draft_id: str, api_key: str) -> bool:
    """Queue a Buttondown draft for delivery.

    Buttondown status machine: draft -> about_to_send -> in_flight -> sent.
    PATCHing to "sent" directly just marks the record as sent-in-history
    without dispatching to subscribers, so the only status that triggers
    real delivery is "about_to_send".
    """
    current_status = get_buttondown_draft_status(draft_id, api_key)
    if current_status in {"about_to_send", "in_flight", "sent"}:
        print(f"✅ Draft {draft_id} is already {current_status}; no action needed")
        return True

    try:
        url = f"https://api.buttondown.email/v1/emails/{draft_id}"
        payload = {"status": "about_to_send"}

        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            method="PATCH",
            headers={
                "Authorization": f"Token {api_key}",
                "Content-Type": "application/json",
                "User-Agent": "SignalCircuitBot/1.0",
            }
        )

        with urllib.request.urlopen(req, timeout=30) as resp:
            result = json.loads(resp.read().decode("utf-8", errors="replace"))
            print(f"✅ Draft {draft_id} queued for delivery")
            print(f"   Status: {result.get('status', '(unknown)')}")
            return True
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace") if e.fp else "No body"
        try:
            error_detail = json.loads(body)
            # If draft is already sent, that's fine — don't treat as failure
            if error_detail.get("code") == "status_invalid" and "sent" in error_detail.get("detail", ""):
                print(f"✅ Draft {draft_id} was already sent (auto-sent by Buttondown)")
                return True
        except Exception:
            pass
        current_status = get_buttondown_draft_status(draft_id, api_key)
        if current_status in {"about_to_send", "in_flight", "sent"}:
            print(f"✅ Draft {draft_id} is already {current_status}; no action needed")
            return True
        print(f"❌ Failed to queue draft {draft_id}: HTTP {e.code}: {body}")
        return False
    except Exception as e:
        current_status = get_buttondown_draft_status(draft_id, api_key)
        if current_status in {"about_to_send", "in_flight", "sent"}:
            print(f"✅ Draft {draft_id} is already {current_status}; no action needed")
            return True
        print(f"❌ Failed to queue draft {draft_id}: {e}")
        return False


def check_and_process_drafts() -> int:
    """Main function: check Discord for draft notifications with 👍 reactions."""
    discord_token = read_discord_token()
    if not discord_token:
        print("ERROR: DISCORD_BOT_TOKEN not found in .env")
        return 1
    
    buttondown_key = read_buttondown_key()
    if not buttondown_key:
        print("ERROR: BUTTONDOWN_API_KEY not found in .env")
        return 1
    
    print(f"Checking Discord channel {DISCORD_CHANNEL_ID} for draft approvals...")
    messages = fetch_channel_messages(discord_token)
    
    if not messages:
        print("No messages found in channel")
        return 0
    
    processed = 0
    found_drafts = 0
    for msg in messages:
        # Only look at messages from our bot (optional but good practice)
        # if msg.get("author", {}).get("bot") != True:
        #     continue
        
        draft_id = extract_draft_id(msg)
        if not draft_id:
            continue

        # Only process actual draft creation notifications, not sent/report messages
        content = msg.get("content", "")
        if not content.startswith("📬 **New Buttondown Weekly Draft Created**"):
            continue

        found_drafts += 1
        message_id = msg.get("id")
        content_preview = msg.get("content", "")[:100].replace("\n", " ")
        
        print(f"Found draft notification: {draft_id} (msg {message_id})")
        print(f"  Preview: {content_preview}...")
        
        if has_thumbs_up_reaction(msg):
            print(f"  👍 Reaction detected! Sending draft {draft_id}...")
            if send_buttondown_draft(draft_id, buttondown_key):
                processed += 1
                # Optional: Add a reaction or reply to indicate sent
                try:
                    endpoint = f"channels/{DISCORD_CHANNEL_ID}/messages/{message_id}/reactions/✅/@me"
                    discord_api_request("PUT", endpoint, discord_token)
                except:
                    pass  # Ignore reaction errors
            else:
                print(f"  Failed to send draft {draft_id}")
        else:
            print(f"  No 👍 reaction yet")
    
    if found_drafts == 0:
        print("No draft notifications found in channel.")
    elif processed == 0:
        print(f"Found {found_drafts} draft(s) but no 👍 reactions yet.")
    else:
        print(f"Processed {processed} draft(s).")
    
    return 0


def continuous_poll():
    """Run in continuous polling mode (for testing)."""
    print(f"Starting continuous poll every {POLL_INTERVAL_MINUTES} minutes...")
    while True:
        print(f"\n--- Polling at {datetime.now().strftime('%H:%M:%S')} ---")
        check_and_process_drafts()
        time.sleep(POLL_INTERVAL_MINUTES * 60)


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "--continuous":
        continuous_poll()
        return 0
    else:
        return check_and_process_drafts()


if __name__ == "__main__":
    raise SystemExit(main())
