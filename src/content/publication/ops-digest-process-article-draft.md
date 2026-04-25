---
title: 'From Black Box to Living Log: How I Built an Ops Digest for My AI Agent Stack'
date: 2026-04-08
category: 'operator-stack'
tags:
  - 'hermes'
  - 'openclaw'
  - 'agent-ops'
  - 'obsidian'
  - 'automation'
excerpt: 'The infrastructure for a living ops digest — how one developer turned a black-box AI agent stack into a morning-scanned logbook with Git-synced Obsidian vaults.'
author: 'jsnode'
authorImage: ''
authorBio: ''
image: '/images/articles/chatgpt-image-2-ops-digest-process-article-draft.png'
sources:
  - 'https://github.com/nodelabstudio/hermes-digests'
  - 'https://github.com/nodelabstudio/hermes-ops-digest'
type: 'article'
---

# From Black Box to Living Log: How I Built an Ops Digest for My AI Agent Stack

**Signal & Circuit | X Node Dev | Draft v1**

---

## The Problem Nobody Talks About

You automate your AI agent to handle research, content pipelines, and cron jobs. Great. But now you have an agent running 20 tasks, 5 cron jobs, and a content pipeline with items in 7 stages. You open the dashboard and see numbers. You have no idea what's actually happening.

That's where I was. A running AI agent system that felt like a black box I was peeking into through a keyhole.

I needed one document that answered: what's this thing doing right now, what's coming next, and what broke recently.

---

## The Setup

My agent (named Knight, running on a WSL2 Ubuntu box - I run a Windows machine with a modest RTX 3060 12GB VRAM that runs local models) manages:

- 54 tasks across a Kanban board (TASKS.json)
- A content pipeline with items from ideas → published (CONTENT.json)
- 3 active cron jobs for research, publishing, and system health
- Daily X research that generates ecosystem digests + Reddit scans

All of that lives in `/home/administrator/.hermes/`. The agent updates the board constantly. But, I only see the board when I go looking for it. When I used Openclaw, I had a nice mission control dashboard running, but it was too busy. I also have the Hermes Agent Workspace for Hermes, but it just doesn't feel quite complete and it's not fun to navigate.


---

## The Solution: Ops Digest

Every morning at 7 AM ET, the agent generates an ops-digest.md from live data:

- Task counts by column (in-progress, review, todo, blocked, done)
- Active cron jobs with next run times and last status
- Content pipeline stage breakdown
- Blocked tasks and what the blocker is
- Recent completions so nothing falls off the radar
- System health (disk, memory, cron job status)

Then it syncs that digest to an Obsidian vault that's cloned to my Windows Desktop via GitHub.

I open Obsidian. I see today's digest. I know what's happening.

---

## How the Vault Sync Works

The agent has two repos it manages:

**hermes-digests** — Contains the daily research digests
```
openclaw-digest.md  (ecosystem research from X + GitHub)
x-digest.md        (X/Twitter sweep results)
reddit-digest.md   (Reddit community scan for Signal & Circuit topics)
```

**hermes-ops-digest** — Contains the ops digest
```
ops-digest.md  (task board + cron health + system status)
```

Both repos are cloned locally. The agent commits and pushes after each pipeline run. Obsidian points at the folder on my Windows Desktop, so the digests appear instantly after each sync.

```
Hermes Agent (WSL2)
  └─ cron job fires at 7 AM ET
       ├─ Generate ops-digest.md from live data
       ├─ Generate research digests (ecosystem + X + Reddit)
       ├─ Commit + push to hermes-digests (GitHub)
       └─ Commit + push to hermes-ops-digest (GitHub)

Obsidian (Windows Desktop)
  └─ Vault pointing at C:\Users\Administrator\Desktop\hermes-ops-digest\
       └─ ops-digest.md auto-updates when Git pulls
```

---

## The GitHub Connection

The vault syncs only require Git push/pull. No special Obsidian sync plugins, no third-party services. The repos are public and living at:

- `https://github.com/********/hermes-digests`
- `https://github.com/********/hermes-ops-digest`

When the agent pushes, Obsidian pulls on next refresh. The whole thing works because both sides are just Git underneath.

---

## What the Ops Digest Looks Like

The digest is structured for scanning, not reading:

**At a Glance** — one line table: total tasks, in-progress, review waiting me, todo, recurring, blocked, done, content items, active cron jobs.

**Cron Jobs** — table with job name, schedule in ET, next run, last status, delivery target. I can see at a glance if something failed.

**Review** — tasks waiting on me to make a call. Owner, agent, what it needs. I go here first every morning.

**Todo** — what's queued but not started.

**Blocked** — what's stuck and why. Usually a decision I need to make or a dependency.

**Recurring** — automation tasks with last run and health status.

**Content Pipeline** — how many items in each stage (ideas → scripting → editing → scheduled → post → published).

**What Happened Recently** — timestamped log of task completions so nothing silently disappears.

**System Health** — disk, memory, whether the agent is still reachable.

---

## Why This Is Different From Just Checking the Dashboard

The dashboard shows the board. The digest shows the situation.

The board tells you what state things are in. The digest tells you what matters right now — what's about to run, what needs your input, what's blocked and sitting there.

With the digest I spend 2 minutes orienting and 30 seconds deciding what to tackle first. Without it I was opening the dashboard, scanning columns, cross-referencing notes, and missing things anyway.

---

## The Research Pipeline Layer

The ops digest is one layer. Below it is the research pipeline that feeds the digests:

**Ecosystem digest** — scans X profiles, GitHub repos (OpenClaw, Hermes Agent, Nous Research), and ClawHub for new findings. Runs daily at 7 AM ET.

**X digest** — sweeps X/Twitter for topics relevant to Signal & Circuit (AI agents, local-first AI, operator tooling, Claude Code patterns).

**Reddit digest** — scans subreddits for community questions, complaints, and interests relevant to the publication's beat.

All three feed into the hermes-digests vault. The ops digest feeds into hermes-ops-digest. Different repos, different purposes, same sync mechanism.

---

## What's Next

The digest is working. Next step is expanding what the research pipeline finds — more sources, more signal, less noise. The vault structure already supports it: new digest files get added to the repo and sync automatically.

The constraint right now is not the infrastructure. It's how fast I can review what the agent produces before it goes out. That's the bottleneck the digest is designed to remove — I spend less time finding problems and more time deciding what to do about them.

---

