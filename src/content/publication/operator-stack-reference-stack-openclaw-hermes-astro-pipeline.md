---
title: 'The Operator Stack: OpenClaw, Hermes, and the Astro Pipeline Running This Publication'
date: 2026-04-04
category: 'operator-stack'
tags:
  - 'operator-stack'
  - 'openclaw'
  - 'hermes'
  - 'astro'
  - 'pipeline'
excerpt: 'A look at the actual automation stack behind Signal & Circuit. What holds together, what breaks, and what another operator can replicate without buying anything new.'
author: 'X Node Dev'
authorImage: ''
authorBio: ''
image: '/images/articles/regenerated-operator-stack-reference-stack-openclaw-hermes-astro-pipeline.jpg'
sources: []
type: 'operator-stack'
draft: false
---

## Who this operator is

This publication runs on a two-person mental model: a human editor with a full-time job, and an agent pipeline that handles the mechanical work of research, drafting, image generation, scheduling, and distribution.

The stack grew organically. Not from a master plan but from replacing things that broke with things that held.

---

## The core stack

**OpenClaw** as the agent runtime. Every skill that handles research, content generation, image prompting, and social distribution runs here. The pipeline runs on cron jobs staggered five minutes apart to avoid TASKS.json race conditions.

**Hermes Agent** as the orchestration layer on top. The mc agent handles board hygiene, task state management, content pipeline progression, and daily digest generation. It is the operations conscience that keeps the pipeline honest.

**Astro** as the publication renderer. Markdown files with frontmatter, rendered to static HTML, deployed as a Node server.

**Postiz** as the social scheduler. All distribution is drafted by OpenClaw agents and queued in Postiz for timed publishing.

**Buttondown** for newsletter distribution. A simple email newsletter with Buttondown's API driving subscriptions and sends.

---

## What broke and what replaced it

**Manual image generation was the first thing to fail.** Generating article images by hand took 20 minutes per article. At 2-3 articles per week, that was an hour of tedium per week that had no editorial value.

Replaced with: a Gemini image generation script run as part of the article pipeline. The mc agent calls `imagen-4.0-generate-001` with editorial-style prompts, saves to the right path, and updates the content frontmatter automatically. The agent decides what visual concept matches the article's argument.

**Social posting at random times was the second failure.** Early posts went out whenever the agent finished, which meant 2 AM publishes visible to nobody. Distribution timing matters.

Replaced with: a manifest-driven posting schedule. All posts are queued at 9 AM ET before they go anywhere near Postiz. The validation script checks times before anything is created in the API.

** TASKS.json race conditions.** When multiple cron jobs fire at the same time, simultaneous writes to the task board corrupt the JSON. Every agent needs the board but only one should write at a time.

Replaced with: staggered execution. Cron jobs have 5+ minute offsets from each other. No two jobs write to TASKS.json simultaneously.

---

## What another operator can replicate

The whole pipeline runs on open-source tools and consumer-grade APIs. Nothing requires an enterprise contract or a team of engineers to maintain.

The specific stack is less important than the discipline: every workflow that requires a human to remember something is a candidate for automation, and every automated workflow that produces bad output is a candidate for a review gate before it touches the outside world.

The pipeline is not autonomous. It is assisted. The human editor still reviews everything before it goes live.

---

## What to watch in the next 90 days

The weakest part of the current stack is the image generation pipeline. Gemini produces good output but the prompts are hand-tuned. The next improvement is a prompt library per article type that the agent can reference before generating, reducing the per-article tuning overhead.

The second weak point is social copy. Post captions still require a human eye before they post. Better prompt templates in the OpenClaw social skills could close that gap.

---

*This is the first Operator Stack profile. If you are running an AI operations stack and want to be profiled, message the publication with your setup.*
