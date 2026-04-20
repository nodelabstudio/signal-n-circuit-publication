#!/usr/bin/env python3
"""
Send a Buttondown draft email to subscribers.

Usage:
  python3 send_buttondown_draft.py DRAFT_ID

Requires BUTTONDOWN_API_KEY in environment or ~/.hermes/.env
"""

import json
import os
import sys
from pathlib import Path
from urllib import error, request

API_URL = "https://api.buttondown.email/v1/emails"


def read_key() -> str:
    """Read Buttondown API key from .env file or environment."""
    env_file = Path("/home/administrator/.hermes/.env")
    if env_file.exists():
        for line in env_file.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith("BUTTONDOWN_API_KEY="):
                value = line.split("=", 1)[1].strip().strip('"').strip("'")
                if value:
                    return value

    env_key = os.environ.get("BUTTONDOWN_API_KEY", "").strip()
    if env_key:
        return env_key

    return ""


def send_draft(api_key: str, draft_id: str) -> dict:
    """Send a Buttondown draft."""
    url = f"{API_URL}/{draft_id}"
    
    # Set publish date to now
    from datetime import datetime, timezone
    publish_date = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    
    payload = {
        "status": "sent",
        "publish_date": publish_date
    }
    
    req = request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        method="PATCH",
        headers={
            "Authorization": f"Token {api_key}",
            "Content-Type": "application/json",
        },
    )
    
    with request.urlopen(req, timeout=30) as resp:
        raw = resp.read().decode("utf-8", errors="replace")
        return json.loads(raw)


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} DRAFT_ID")
        return 1
    
    draft_id = sys.argv[1].strip()
    if not draft_id:
        print("ERROR: Draft ID is empty")
        return 1
    
    api_key = read_key()
    if not api_key:
        print("ERROR: BUTTONDOWN_API_KEY missing")
        return 1
    
    try:
        result = send_draft(api_key, draft_id)
        print(f"✅ Draft {draft_id} sent successfully")
        print(f"Sent at: {result.get('sent_at', '(unknown)')}")
        print(f"Recipients: {result.get('recipient_count', '(unknown)')}")
        return 0
    except error.HTTPError as e:
        detail = e.read().decode("utf-8", errors="replace")
        print(f"ERROR: Buttondown API HTTP {e.code}: {detail}")
        return 1
    except Exception as e:
        print(f"ERROR: failed to send draft: {e}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())