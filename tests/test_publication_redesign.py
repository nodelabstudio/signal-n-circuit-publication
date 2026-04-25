from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def test_article_page_uses_article_excerpt_instead_of_generic_standfirst():
    article_page = read("src/pages/articles/[slug].astro")

    assert "The commercial shape of AI agents is getting clearer" not in article_page
    assert "post.excerpt" in article_page
    assert "article-hero" in article_page


def test_homepage_has_front_page_editorial_sections():
    homepage = read("src/pages/index.astro")

    assert "front-page" in homepage
    assert "lead-feature" in homepage
    assert "story-pair" in homepage
    assert "beat-rail" in homepage
    assert "Operator brief" in homepage
    assert "lead-img-link" in homepage
    assert "react.lazy" not in homepage


def test_lead_story_is_separate_from_secondary_stories():
    homepage = read("src/pages/index.astro")
    css = homepage.split("<style>")[1] if "<style>" in homepage else ""

    # lead-feature is a standalone full-width card, not sharing a row with story-pair
    assert "lead-feature" in css
    assert "story-pair" in css

    # lead-feature and story-pair should be separate sections, not siblings in same grid row
    assert "story-pair" not in css.split("lead-feature")[0] if "lead-feature" in css else True


def test_empty_category_has_visual_article_card_aesthetic():
    category_page = read("src/pages/category/[category]/index.astro")
    css = category_page.split("<style>")[1] if "<style>" in category_page else ""

    # The empty state should feel like a story card, not a bare panel
    assert "empty" in category_page
    assert "article-card" not in category_page or "hover" in css


def test_article_card_has_min_height_for_layout_consistency():
    article_card = read("src/components/ArticleCard.astro")
    css = article_card.split("<style>")[1] if "<style>" in article_card else ""

    assert ".article-card" in css
    assert "height: 100%" in css or "min-height" in css


def test_header_and_footer_carry_publication_identity():
    header = read("src/components/Header.astro")
    footer = read("src/components/Footer.astro")

    assert "Field notes for AI operators" in header
    assert "Original docs, repos, release notes, and field testing" in footer
    assert "Agent Ops" in footer


def test_article_title_visually_dominates_section_headings():
    article_page = read("src/pages/articles/[slug].astro")
    css = article_page.split("<style>")[1] if "<style>" in article_page else ""

    assert "font-size: clamp(3rem, 6.4vw, 6.4rem);" in css
    assert "max-width: 22ch;" in css
    assert ":global(.body-card h2)" in css
    assert ".body-card .standfirst" in css
    assert "font-size: clamp(2.15rem, 4.2vw, 3.35rem);" in css
    assert "font-size: clamp(1.22rem, 1.55vw, 1.5rem) !important;" in css
    assert "font-size: clamp(1.8rem, 3vw, 2.45rem);" not in css


def test_article_body_paragraphs_have_global_spacing():
    article_page = read("src/pages/articles/[slug].astro")
    css = article_page.split("<style>")[1] if "<style>" in article_page else ""

    assert ":global(.body-card p)" in css
    assert ":global(.body-card p + p)" in css
    assert "margin-top: 1.55rem !important;" in css
