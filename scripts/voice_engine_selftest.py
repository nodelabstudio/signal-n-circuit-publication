#!/usr/bin/env python3
"""Self tests for scripts/voice_engine.py."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE_PATH = ROOT / "scripts" / "voice_engine.py"

spec = importlib.util.spec_from_file_location("voice_engine", ENGINE_PATH)
assert spec and spec.loader
voice_engine = importlib.util.module_from_spec(spec)
sys.modules["voice_engine"] = voice_engine
spec.loader.exec_module(voice_engine)


def codes(text: str, surface: str = "x-research", require_source: bool | None = None) -> set[str]:
    return {finding.code for finding in voice_engine.lint_text(text, surface=surface, require_source=require_source)}


def test_rejects_known_ai_connective() -> None:
    found = codes("That gets messy when data is fragmented across platforms. https://example.com")
    assert "ai_connective" in found
    assert "low_concrete_nouns" in found


def test_rejects_tidy_antithesis() -> None:
    found = codes("The real operator tooling market isn't dashboards. It's the invisible stuff. https://example.com")
    assert "structure_real_x_isnt_y" in found


def test_rejects_missing_source_for_x() -> None:
    found = codes("Slack permissions broke the agent again.", surface="x-research")
    assert "missing_source" in found


def test_accepts_spoken_cadence_pattern() -> None:
    found = codes("Things like WhatsApp history, tweet archives, or bookmarks you might need years from now, that's where it gets messy.\n\nhttps://example.com")
    assert "ai_connective" not in found
    assert "structure_not_x_its_y" not in found
    assert "missing_source" not in found


def test_article_promo_allows_no_reaction_but_requires_url() -> None:
    found = codes("If an agent wrote half the repo, somebody still has to explain the commit six months later.\n\nhttps://signalcircuit.cloud/articles/example/", surface="article-promo")
    assert "missing_source" not in found
    assert "low_concrete_nouns" not in found


def main() -> int:
    tests = [
        test_rejects_known_ai_connective,
        test_rejects_tidy_antithesis,
        test_rejects_missing_source_for_x,
        test_accepts_spoken_cadence_pattern,
        test_article_promo_allows_no_reaction_but_requires_url,
    ]
    for test in tests:
        test()
        print(f"PASS {test.__name__}")
    print(f"{len(tests)} voice engine tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
