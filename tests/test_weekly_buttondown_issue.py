import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import weekly_buttondown_issue as weekly


def test_parse_article_reads_image_from_frontmatter(tmp_path):
    article = tmp_path / "human-newsletter.md"
    article.write_text(
        """---
title: 'Human Newsletter Test'
date: 2026-04-24
excerpt: 'A short useful summary.'
image: '/images/articles/human-newsletter.png'
---

Body.
""",
        encoding="utf-8",
    )

    parsed = weekly.parse_article(article)

    assert parsed is not None
    assert parsed.image == "/images/articles/human-newsletter.png"


def test_build_body_uses_human_note_and_article_images():
    article = weekly.Article(
        slug="human-newsletter-test",
        title="Human Newsletter Test",
        excerpt="A short useful summary.",
        published=date(2026, 4, 24),
        image="/images/articles/human-newsletter.png",
    )

    body = weekly.build_body([article])

    assert "I pulled together the pieces worth your time this week" in body
    assert "My read" in body
    assert "<img" in body
    assert "https://signalcircuit.cloud/images/articles/human-newsletter.png" in body
    assert "alt=\"Hero image for Human Newsletter Test\"" in body
    assert "Read the piece" in body
