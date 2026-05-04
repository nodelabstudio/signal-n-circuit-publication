# Signal & Circuit voice bank

This folder gives the writing engine taste memory.

The goal is not to make drafts pass a generic grammar checklist. The goal is to make every future draft learn from Angel's approvals, rejections, and rewrites.

How the loop works:

1. Pull voice context before drafting:
   `python3 scripts/voice_engine.py context --surface x-research --topic "api access"`
2. Draft from the retrieved examples and scars.
3. Lint the draft before it reaches Discord:
   `python3 scripts/voice_engine.py lint --surface x-research --file /tmp/draft.txt --require-source`
4. Capture Angel feedback after approval, rejection, or rewrite:
   `python3 scripts/voice_engine.py capture-feedback --surface x-research --draft-id RSP-YYYYMMDD-01 --status rejected --draft-file /tmp/draft.txt --feedback "too generic"`

The engine should learn from three things:

- Approved patterns: what Angel actually likes.
- Rejected patterns: what made a draft smell like AI.
- Correction records: exact scar tissue from past feedback.

Files:

- `approved-examples.md`: approved cadence and why it worked.
- `rejected-examples.md`: rejected drafts and why they failed.
- `angel-corrections.json`: structured feedback records the script can read.
- `banned-structures.json`: sentence shapes and phrases that trip AI voice alarms.
- `surface-rules.json`: surface-specific settings for X research, HOT takes, article promos, article body, and homepage copy.
