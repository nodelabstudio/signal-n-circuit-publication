# Signal & Circuit -- Project Context

## What This Is

Signal & Circuit is an AI/tech research publication built on Astro.
Hermes agent researches topics (AI agents, local-first AI, operator tooling,
open-source ML, infrastructure) and drafts longform editorial articles.
The publication pipeline: research -> draft -> review -> publish -> promote.

## Byline

All articles use the byline "X Node Dev". No fake author personas.
No deceptive AI attribution. If an article is AI-assisted, the byline
stays X Node Dev. Do not invent contributor names.

## Voice and Style

The voice is the same DNA as X posts but longer and more editorial.
A builder writing for builders. Informed, opinionated, grounded in specifics.

Reading level: 6th grade. Short sentences. Plain words.
If jargon is necessary, explain it immediately after using it.

First person or direct address. Active voice only.

Problem first, then solution. Every article opens with a concrete problem,
gap, or finding. Never open with a tool name or a generic opinion.

Every claim references a named source: company, research org, author, repo, or dataset.
Prefer original sources (official docs, company blogs, published research, GitHub repos)
over aggregators and listicles.

### Banned patterns

No em dashes. Use colons, periods, or restructure.

No juxtaposition pivots. No "It's not X. It's Y." No "The real thing isn't A. It's B."
State the claim directly without the contrast setup.

No banned words: "delve," "leverage," "unlock," "groundbreaking," "game-changer,"
"revolutionize," "in conclusion," "it is important to note," "empowering," "comprehensive."

It's okay to use contractions at times for a more conversational tone, but avoid overusing them in a way that feels informal or chatty. The voice should be approachable but still maintain a level of professionalism and authority.

No emojis. No hashtags in body copy.

No "nobody tells you," "what nobody talks about," or secret-knowledge openers.

No generic openers like "AI agents are quietly..." Start with the problem or the number.

For articles, use contracted voice ("don't," "it's") at times for a more conversational tone, but avoid overusing contractions in a way that feels informal or chatty. The voice should be approachable but still maintain a level of professionalism and authority.

### Longform additions (beyond X post rules)

Articles can use section headers (### level) to break up longer pieces.
Each section should be self-contained enough that a reader skimming headers
gets the shape of the argument.

Paragraphs are allowed (unlike X posts which use one-sentence-per-line).
Keep paragraphs to 3-4 sentences max. White space matters.

Code blocks and terminal output are encouraged when showing real tooling.
Always specify the language for syntax highlighting.

Pull quotes or callout blocks can highlight key findings or numbers.

## Content Structure

Articles live in: src/content/publication
Frontmatter follows Astro content collection schema defined in src/content.config.ts.

## Deploy Workflow

To publish an article:
bash scripts/deploy-article.sh <slug>
This syncs markdown to the site repo, pushes to GitHub, and polls the live site.

Manual git workflow:
cd /home/administrator/site && git add -A && git commit -m "<message>" && git push origin main

## Article Images

Read the `Image Generation` skill in the SKILL.md located at `home/administrator/.hermes/skills/publication/signal-circuit-publication-pipeline/SKILL.md` for image generation rules and API details. Always generate a hero image for each article before deploying.

## X Promotion

X posting happens via post-bridge.
Posts for X can be scheduled automatically.
Do NOT use Postiz or any third-party scheduler only post-bridge.
If an article needs X promotion, draft the post and send to Discord channel 1477414797757907075 for Angel's approval.

## Topics

Cover whatever emerges from research. Core areas include but are not limited to:

AI agents and agent frameworks (OpenClaw, Hermes Agent, LangGraph, CrewAI,
AutoGen, and the growing ecosystem of open-source agent tooling).

Local-first AI and on-device inference (Ollama, llama.cpp, MLX, ONNX Runtime,
quantization techniques, running models on consumer hardware).

Operator tooling and workflow automation (cron orchestration, approval flows,
human-in-the-loop patterns, pipeline reliability, agent ops).

Open-source ML infrastructure (training frameworks, serving stacks, vector
databases, fine-tuning pipelines, model registries).

Developer experience and devtools (IDE integrations, code agents, MCP servers,
context management, prompt engineering tooling).

LLM evaluation and observability (DeepEval, Langfuse, Braintrust, tracing,
cost tracking, quality gates for production LLM apps).

Vertical AI applications (healthcare scheduling, legal document processing,
real estate, logistics -- where AI meets domain-specific pain points).

AI content and research pipelines (transcription tooling, YouTube-to-research
workflows, Fabric patterns, RSS aggregation, automated source discovery).

AI business models and go-to-market (managed AI services vs SaaS, pricing
models, operator vs agency positioning, capacity constraints as strategy).

Model releases and changelog analysis (what actually changed in the release,
not the marketing -- pricing moves, context window changes, deprecations,
migration requirements).

The editorial filter: would a working developer, infrastructure engineer,
or small operator find this useful in the next 30 days? If not, skip it.
YouTube videos from monitored channels are valid source material when
transcribed and cited.

## Editorial System (from legacy pipeline, still valid)

### Article Types

- analysis: Deep dives on trends, tools, or shifts in the ecosystem. These are
  the backbone of the publication. 800-2000 words. Requires at least 2 named
  sources (repos, docs, company blogs, research papers). Examples: "Local-first
  agent systems stop being toys when they can survive handoffs."

- niche-teardown: Dissects a specific industry or vertical pain point where AI
  automation has a concrete, measurable impact. Opens with the operational problem,
  names real vendors or operators, and includes concrete KPIs or cost figures.
  Examples: "Home healthcare scheduling is the kind of AI pain point that
  punishes bad ops fast."

- profile: Builder spotlight. How a specific person, team, or small operator
  runs their stack. Grounded in specifics: what tools, what workflow, what broke,
  what worked. Not puff pieces. The reader should walk away with something they
  can steal for their own setup.

- breaking: Release Watch. Short-format recurring column covering what actually
  shipped in a release. Not the marketing pitch, not the launch event hype.
  Focus on changelog lines that alter pricing, limits, reliability, migration
  requirements, or workflow friction for builders. 400-800 words. Can cover
  multiple releases in one column.

- service-model: Business model analysis for AI services. How operators price,
  package, and deliver AI-powered workflows. Covers managed AI vs SaaS, operator
  vs agency positioning, retention mechanics, and where the real margin lives.

- comparison: Side-by-side evaluation of competing tools or approaches. Must
  include hands-on testing or verifiable benchmarks, not just feature matrix
  marketing. State what was tested, on what hardware, and with what workload.

- how-to: Step-by-step walkthrough of a specific workflow or integration.
  Targeted at intermediate developers. Includes working code or commands.
  Must be reproducible on a standard dev machine. These are rare and only
  published when the workflow is non-obvious and poorly documented elsewhere.

### QA Grading

Articles get a letter grade before publishing. The grade reflects sourcing
quality, voice compliance, structural clarity, and factual accuracy.

- A: Publication-ready. Strong sourcing, clean voice, no revision needed.
- A-: Publication-ready with minor polish. May need one sentence tightened
  or one source strengthened. No structural issues.
- B+: Needs one revision pass. Common issues: generic language where specifics
  are needed, missing a named vendor or concrete metric, one section that
  repeats the point without adding evidence. Fixable in one pass.
- B or below: Not publishable. Either the sourcing is too weak (aggregator-only,
  no original sources), the voice drifts into AI-sounding patterns, or the
  structure doesn't follow problem-first format. Requires a rewrite, not a polish.

Grade A or A- required for publication. B+ gets one revision pass and is
re-graded. If it doesn't reach A- after revision, it goes back to draft
or gets killed. Do not publish B-grade work.

### X Post Format (per article)

Each published article gets a single combined X post with three components
woven together:

- hook: Problem-first opener. No tool name, no link. Ground it in a specific
  pain point, number, or finding that makes the reader stop scrolling. Must
  follow `x-writing-rules` as the single writing authority. No juxtaposition.
  No em dashes. No banned words.

- takeaway: What it means for builders. One to two sentences connecting the
  problem to the insight. Includes the full article URL from signalcircuit.cloud.

- question: Engagement prompt that invites the reader to weigh in with their
  own experience. Phrased as a genuine question, not a rhetorical setup.
  Includes the article URL again.

Each sentence stands on its own line with a blank line between sentences.
The post reads vertically, not horizontally.

The combined post goes to Discord channel 1477414797757907075 as a single
message for Angel's review. Angel approves or requests changes. Only after
approval does Angel manually post via post-bridge. Hermes never posts to X
directly. Hermes never schedules X posts. Hermes never uses Postiz.

### Production URL
https://signalcircuit.cloud

### Published Articles (live on site)
- managed-ai-services-are-the-real-agent-business
- small-operators-are-building-ai-systems-that-feel-more-like-services-than-software
- the-best-vertical-ai-products-start-with-a-complaint-not-a-demo
- release-notes-are-starting-to-matter-more-than-launch-events
- the-next-wave-of-ai-service-businesses-will-look-more-like-operators-than-agencies
- the-best-ai-builder-tools-are-starting-to-look-like-control-panels-not-chatbots
- local-first-agent-systems-stop-being-toys-when-they-can-survive-handoffs
- openclaw-2026-4-2-is-where-local-agent-ops-start-acting-like-production-software
- home-healthcare-scheduling-is-the-kind-of-ai-pain-point-that-punishes-bad-ops-fast

### Unpublished Drafts (idea/ready stage, not yet on site)
- C001: Why I build iOS apps with AI (x-thread, ready)
- C002: The glue developer (x-post, ready)
- C003: 5 things before publishing first iOS app (x-thread, ready)
- C005: How I use local-only AI automation (x-thread, ready)
- C006: App Store screenshot teardown (x-thread, ready)
- C011: Localization is distribution (x-thread, ready)
- C012: Capacity constraints as product strategy (x-thread, ready)
- C013: Voice in/out is table stakes (x-post, ready)
- C014-C016: idea stage, not drafted

### What NOT to do
Do NOT create or reference CONTENT.json. That was an OpenClaw artifact.
Article state lives in the Astro content collection and git history.
Pipeline tracking happens through AGENTS.md and Discord, not JSON state files.
Do NOT reference any path under .openclaw or .openclaw.pre-migration. Those are deleted.