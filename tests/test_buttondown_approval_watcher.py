import json
import sys
from pathlib import Path
from urllib.error import HTTPError

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import buttondown_approval_watcher as watcher


class FakeResponse:
    def __init__(self, payload, status=200):
        self.payload = payload
        self.status = status

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def read(self):
        return json.dumps(self.payload).encode("utf-8")


def http_error(status, payload):
    class Body:
        def read(self):
            return json.dumps(payload).encode("utf-8")

        def close(self):
            pass

    return HTTPError("https://api.buttondown.email/v1/emails/example", status, "error", {}, Body())


def test_send_buttondown_draft_treats_already_sent_status_as_success_after_patch_failure(monkeypatch):
    calls = []

    def fake_urlopen(req, timeout=30):
        calls.append(req)
        if len(calls) == 1:
            raise http_error(401, {"detail": "transient auth failure", "code": "missing_authentication_header"})
        return FakeResponse({"results": [{"id": "em_example", "status": "sent"}]})

    monkeypatch.setattr(watcher.urllib.request, "urlopen", fake_urlopen)

    assert watcher.send_buttondown_draft("em_example", "test-api-key") is True
    assert len(calls) == 2
