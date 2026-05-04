#!/usr/bin/env python3
"""Signal & Circuit voice engine.

This is the first local layer of taste memory for Signal & Circuit writing.
It reads the voice bank, lints drafts for AI-smelling structures, prints
retrieval context before drafting, and captures Angel feedback after review.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from voice_feedback import VAULT_VOICE_DIR, mirror_voice_bank

ROOT = Path(__file__).resolve().parents[1]
VOICE_DIR = ROOT / "writing" / "voice-bank"
BANNED_FILE = VOICE_DIR / "banned-structures.json"
SURFACE_FILE = VOICE_DIR / "surface-rules.json"
CORRECTIONS_FILE = VOICE_DIR / "angel-corrections.json"
APPROVED_FILE = VOICE_DIR / "approved-examples.md"
REJECTED_FILE = VOICE_DIR / "rejected-examples.md"


@dataclass
class Finding:
    severity: str
    code: str
    message: str
    snippet: str = ""


def load_json(path: Path, fallback: Any) -> Any:
    if not path.exists():
        return fallback
    return json.loads(path.read_text(encoding="utf-8"))


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def read_text_arg(args: argparse.Namespace) -> str:
    if args.text:
        return args.text
    if args.file:
        return Path(args.file).read_text(encoding="utf-8", errors="replace")
    if not sys.stdin.isatty():
        return sys.stdin.read()
    raise SystemExit("Provide --text, --file, or stdin")


def first_nonempty_line(text: str) -> str:
    for line in text.splitlines():
        stripped = line.strip()
        if stripped:
            return stripped
    return ""


def sentences(text: str) -> list[str]:
    cleaned = re.sub(r"https?://\S+", " URL ", text)
    cleaned = re.sub(r"v?\d+\.\d+(?:\.\d+)?", " VERSION ", cleaned)
    parts = re.split(r"(?<=[.!?])\s+", cleaned.strip())
    return [p.strip() for p in parts if p.strip()]


def count_concrete_hits(text: str, examples: list[str]) -> int:
    lowered = text.lower()
    return sum(1 for item in examples if item.lower() in lowered)


def extract_relevant_records(surface: str, topic: str, limit: int = 5) -> list[dict[str, Any]]:
    raw = load_json(CORRECTIONS_FILE, {"records": []})
    topic_terms = {t for t in re.split(r"[^a-zA-Z0-9_@+-]+", topic.lower()) if t}
    scored: list[tuple[int, dict[str, Any]]] = []
    for record in raw.get("records", []):
        score = 0
        if surface and record.get("surface") == surface:
            score += 3
        tags = {str(t).lower() for t in record.get("topic_tags", [])}
        score += len(topic_terms & tags) * 2
        haystack = " ".join(str(record.get(k, "")) for k in ("draft_before", "angel_feedback", "lesson", "replacement_pattern")).lower()
        score += sum(1 for term in topic_terms if term and term in haystack)
        if record.get("status_active", True):
            score += 1
        scored.append((score, record))
    scored.sort(key=lambda item: item[0], reverse=True)
    return [record for score, record in scored[:limit] if score > 0] or [record for _, record in scored[:limit]]


def lint_text(text: str, surface: str = "x-research", require_source: bool | None = None) -> list[Finding]:
    banned = load_json(BANNED_FILE, {})
    surfaces = load_json(SURFACE_FILE, {"surfaces": {}}).get("surfaces", {})
    surface_rules = surfaces.get(surface, {})
    if require_source is None:
        require_source = bool(surface_rules.get("require_source", False))

    findings: list[Finding] = []
    lowered = text.lower()

    max_chars = surface_rules.get("max_chars")
    if max_chars and len(text.strip()) > int(max_chars):
        findings.append(Finding("error", "too_long", f"Draft is {len(text.strip())} chars, over {max_chars}."))

    if require_source and not re.search(r"https?://\S+", text):
        findings.append(Finding("error", "missing_source", "Factual X draft is missing a source URL."))

    if "—" in text:
        findings.append(Finding("error", "em_dash", "Em dash detected. Use a colon, period, comma, or rewrite."))

    if surface.startswith("x") or surface in {"hot-take", "article-promo"}:
        if "#" in text:
            findings.append(Finding("error", "hashtag", "Hashtag detected."))

    for item in banned.get("banned_words", []):
        if item.lower() in lowered:
            findings.append(Finding("error", "banned_word", f"Banned word or phrase: {item}", item))

    for item in banned.get("ai_connective_phrases", []):
        if item.lower() in lowered:
            findings.append(Finding("error", "ai_connective", f"AI connective phrase: {item}", item))

    for item in banned.get("recycled_framing", []):
        pattern = r"\b" + re.escape(item.lower()) + r"\b"
        if re.search(pattern, lowered):
            findings.append(Finding("warn", "recycled_framing", f"Recycled framing needs a concrete reason to stay: {item}", item))

    for entry in banned.get("banned_regex", []):
        pattern = entry.get("pattern", "")
        if pattern and re.search(pattern, text, flags=re.IGNORECASE | re.DOTALL):
            findings.append(Finding("error", f"structure_{entry.get('name', 'regex')}", f"Banned structure: {entry.get('name', pattern)}"))

    first = first_nonempty_line(text)
    if first:
        thesis_patterns = [
            r"^[A-Z][A-Za-z0-9 +/&-]+\s+(is|are|marks|represents|shows|reveals|highlights|underscores)\b",
            r"^[A-Z][A-Za-z0-9 +/&-]+\s+(gets|becomes|turns into|breaks)\s+(messy|risky|painful|important)\b",
            r"^(The future of|The rise of|The evolution of|A new era of)\b",
        ]
        if any(re.search(p, first, flags=re.IGNORECASE) for p in thesis_patterns):
            findings.append(Finding("warn", "thesis_opener", "Opening line looks like a thesis statement. Start with the interesting detail or reaction.", first))

    abstract_hits = []
    for item in banned.get("abstract_nouns", []):
        pattern = r"\b" + re.escape(item.lower()) + r"\b"
        if re.search(pattern, lowered):
            abstract_hits.append(item)
    if len(abstract_hits) >= 3:
        findings.append(Finding("warn", "abstract_density", f"High abstract noun density: {', '.join(abstract_hits[:8])}"))

    concrete_hits = count_concrete_hits(text, banned.get("concrete_noun_examples", []))
    if surface in {"x-research", "hot-take", "article-promo"} and concrete_hits == 0:
        findings.append(Finding("warn", "low_concrete_nouns", "No known concrete nouns detected. Add the actual tool, file, endpoint, repo, limit, or artifact."))

    sent = sentences(text)
    if len(sent) >= 3:
        lengths = [len(s.split()) for s in sent[:4]]
        if max(lengths) - min(lengths) <= 4:
            findings.append(Finding("warn", "flat_rhythm", "Sentence lengths are too even. Vary the rhythm so it does not read assembled."))

    if text.strip().endswith(("matters.", "important.", "key.", "critical.", "essential.")):
        findings.append(Finding("warn", "summary_closer", "Closer sounds like a summary tag. End with a take, detail, or concrete consequence."))

    return findings


def finding_dict(finding: Finding) -> dict[str, str]:
    return {
        "severity": finding.severity,
        "code": finding.code,
        "message": finding.message,
        "snippet": finding.snippet,
    }


def cmd_lint(args: argparse.Namespace) -> int:
    text = read_text_arg(args)
    findings = lint_text(text, surface=args.surface, require_source=args.require_source)
    errors = [f for f in findings if f.severity == "error"]
    if args.json:
        print(json.dumps({"ok": not errors, "findings": [finding_dict(f) for f in findings]}, indent=2))
    else:
        if not findings:
            print("Voice lint passed.")
        else:
            for finding in findings:
                snippet = f" [{finding.snippet}]" if finding.snippet else ""
                print(f"{finding.severity.upper()}: {finding.code}: {finding.message}{snippet}")
    return 1 if errors else 0


def cmd_context(args: argparse.Namespace) -> int:
    records = extract_relevant_records(args.surface, args.topic, args.limit)
    surfaces = load_json(SURFACE_FILE, {"surfaces": {}}).get("surfaces", {})
    surface_rules = surfaces.get(args.surface, {})
    print(f"Signal & Circuit voice context")
    print(f"Surface: {args.surface}")
    print(f"Topic: {args.topic or '(none)'}")
    if surface_rules:
        print("\nSurface rules:")
        for key, value in surface_rules.items():
            print(f"- {key}: {value}")
    print("\nRelevant voice scars:")
    for idx, record in enumerate(records, 1):
        print(f"\n{idx}. {record.get('draft_id', 'record')}: {record.get('status', '')}")
        print(f"Angel feedback: {record.get('angel_feedback', '')}")
        print(f"Lesson: {record.get('lesson', '')}")
        if record.get("replacement_pattern"):
            print(f"Use instead: {record['replacement_pattern']}")
    print("\nDrafting order:")
    print("1. Source fact")
    print("2. Concrete weird detail")
    print("3. Human reaction")
    print("4. Angle")
    print("5. Draft")
    print("\nSelf-critique before delivery:")
    print("What makes this sound like an AI trying not to sound like AI?")
    print("Name the exact smell, then rewrite before Angel sees it.")
    return 0


def cmd_capture_feedback(args: argparse.Namespace) -> int:
    raw = load_json(CORRECTIONS_FILE, {"version": 1, "records": []})
    draft = ""
    if args.draft_file:
        draft = Path(args.draft_file).read_text(encoding="utf-8", errors="replace").strip()
    elif args.draft:
        draft = args.draft.strip()
    rewrite = ""
    if args.rewrite_file:
        rewrite = Path(args.rewrite_file).read_text(encoding="utf-8", errors="replace").strip()
    elif args.rewrite:
        rewrite = args.rewrite.strip()
    record = {
        "date": datetime.now().strftime("%Y-%m-%d"),
        "captured_at": utc_now(),
        "surface": args.surface,
        "draft_id": args.draft_id,
        "status": args.status,
        "topic_tags": [tag.strip().lower() for tag in args.tag if tag.strip()],
        "draft_before": draft,
        "angel_feedback": args.feedback.strip(),
        "lesson": args.lesson.strip() if args.lesson else args.feedback.strip(),
        "replacement_pattern": rewrite,
        "status_active": True,
    }
    raw.setdefault("records", []).append(record)
    CORRECTIONS_FILE.write_text(json.dumps(raw, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    mirror_voice_bank()
    print(f"Captured feedback for {args.draft_id} in {CORRECTIONS_FILE}")
    print(f"Mirrored voice bank to {VAULT_VOICE_DIR}")
    return 0


def cmd_mirror(args: argparse.Namespace) -> int:
    mirror_voice_bank()
    print(f"Mirrored voice bank to {VAULT_VOICE_DIR}")
    return 0


def cmd_score(args: argparse.Namespace) -> int:
    text = read_text_arg(args)
    findings = lint_text(text, surface=args.surface, require_source=args.require_source)
    penalty = 0
    for finding in findings:
        penalty += 15 if finding.severity == "error" else 6
    score = max(0, 100 - penalty)
    print(json.dumps({"score": score, "ok": score >= args.min_score and not any(f.severity == "error" for f in findings), "findings": [finding_dict(f) for f in findings]}, indent=2))
    return 0 if score >= args.min_score and not any(f.severity == "error" for f in findings) else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    lint = sub.add_parser("lint", help="Lint draft text for AI voice smells")
    lint.add_argument("--surface", default="x-research")
    lint.add_argument("--text", default="")
    lint.add_argument("--file", default="")
    lint.add_argument("--require-source", action="store_true", default=None)
    lint.add_argument("--json", action="store_true")
    lint.set_defaults(func=cmd_lint)

    score = sub.add_parser("score", help="Return numeric voice score")
    score.add_argument("--surface", default="x-research")
    score.add_argument("--text", default="")
    score.add_argument("--file", default="")
    score.add_argument("--require-source", action="store_true", default=None)
    score.add_argument("--min-score", type=int, default=80)
    score.set_defaults(func=cmd_score)

    context = sub.add_parser("context", help="Print voice-bank context before drafting")
    context.add_argument("--surface", default="x-research")
    context.add_argument("--topic", default="")
    context.add_argument("--limit", type=int, default=5)
    context.set_defaults(func=cmd_context)

    capture = sub.add_parser("capture-feedback", help="Append Angel feedback to the voice bank")
    capture.add_argument("--surface", required=True)
    capture.add_argument("--draft-id", required=True)
    capture.add_argument("--status", choices=["approved", "rejected", "revision", "approved-pattern"], required=True)
    capture.add_argument("--draft", default="")
    capture.add_argument("--draft-file", default="")
    capture.add_argument("--feedback", required=True)
    capture.add_argument("--lesson", default="")
    capture.add_argument("--rewrite", default="")
    capture.add_argument("--rewrite-file", default="")
    capture.add_argument("--tag", action="append", default=[])
    capture.set_defaults(func=cmd_capture_feedback)

    mirror = sub.add_parser("mirror", help="Mirror voice bank into the Obsidian vault")
    mirror.set_defaults(func=cmd_mirror)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
