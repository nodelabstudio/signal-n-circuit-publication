---
title: 'Repo search is becoming agent spend control'
date: 2026-05-18
category: 'analysis'
tags:
  - 'ai-agents'
  - 'developer-tools'
  - 'mcp'
  - 'code-search'
  - 'context-engineering'
excerpt: 'Semble shows why code search now belongs in the agent runtime budget, not the developer convenience drawer.'
author: 'X Node Dev'
authorImage: ''
authorBio: ''
image: '/images/articles/tech-marketing-3d-semble-agent-code-search.png'
sources:
  - 'https://github.com/MinishLab/semble'
  - 'https://news.ycombinator.com/item?id=48169874'
  - 'https://huggingface.co/minishlab/potion-code-16M'
  - 'https://github.com/MinishLab/semble/tree/main/benchmarks'
type: 'article'
draft: false
---

Coding agents waste real money when they search a repo the wrong way.

A common loop looks harmless. The agent runs `grep`, opens whole files, reads too much context, misses the right call site, and tries again. That pattern burns tokens, hides relevant code, and makes the model look weaker than the workflow around it.

Semble, a new open-source project from MinishLab, turns that pain into a cleaner product claim. Its README says the tool gives agents code search with about 98 percent fewer tokens than `grep` plus full file reads. The stronger point is bigger than one library: repo search has become part of agent spend control.

## The search tool moved into the runtime

MinishLab describes Semble as a code search library and Model Context Protocol server for Claude Code, OpenAI Codex, OpenCode, Cursor, and sub-agents. Model Context Protocol, or MCP, gives agents a common way to call tools. In this case, the tool searches local paths or git URLs and returns relevant code chunks instead of whole files.

That matters because the agent's search path shapes the rest of the run. A blunt search returns noisy lines. The agent then reads files to recover context. Each read adds tokens. Each extra token competes with the task, the plan, the tool list, and the user's instructions.

Semble's README makes the economics plain. The project claims 98 percent fewer tokens on average versus `grep` plus read. It also says `grep` plus read needs a full 100,000-token context window for 85 percent recall, while Semble reaches 94 percent recall at a 2,000-token budget.

Those numbers need normal buyer caution. Benchmarks can favor the tool that designed them. The Hacker News thread around Semble also pressed on methodology. One discussion point asked whether the benchmark measures end-to-end agent success or retrieval quality. That is the right question.

Even with that caveat, the direction is hard to ignore. Code search now affects cost, latency, and answer quality before the agent writes a patch.

## Semble combines old search with small embeddings

The interesting part of Semble is how ordinary the architecture looks. MinishLab says the tool chunks files with Chonkie, uses Model2Vec static embeddings through `potion-code-16M`, combines that with BM25 lexical search, fuses results with Reciprocal Rank Fusion, and reranks with code-aware signals.

The code-aware signals include method calls, private identifiers, camelCase and PascalCase names, function definitions, snake_case identifiers, path patterns, and file extensions. That list sounds boring because code search should care about boring code facts. A tool that understands identifiers and paths can give an agent better snippets than a raw string match.

Semble also avoids a transformer forward pass at query time. MinishLab says queries run in about 1.5 milliseconds on a central processing unit, or CPU. The README reports 263 milliseconds for indexing in its benchmark table, compared with 57 seconds for CodeRankEmbed Hybrid. It also reports 0.854 NDCG@10 for Semble versus 0.862 for CodeRankEmbed Hybrid.

NDCG@10 is a ranking metric. It scores whether useful results appear near the top of the first ten results. For builders, the plain reading is simple: Semble claims near-transformer retrieval quality with much faster local indexing and queries.

That trade matters for agent loops. A tool that needs a large hosted service or a slow index job may help big teams. A tool that runs locally with no application programming interface keys can fit personal agents, small teams, and cron-based workflows.

## The MCP shape matters

The MCP server form may matter as much as the search algorithm. MinishLab shows setup examples for Claude Code, Codex, OpenCode, and Cursor. It also shows an `AGENTS.md` or `CLAUDE.md` helper function for shell-based search.

That means Semble can sit beside the agent as a normal tool. The agent asks a natural-language or code query. The tool returns targeted chunks. The model keeps the rest of the context window for reasoning, tests, and the actual edit.

This fits the wider Signal & Circuit pattern from recent scans. MCP tool lists have context costs. Local memory systems need review gates. Background coding agents need launch settings and permission boundaries. Semble adds another runtime surface: code search has to become intentional, measured, and scoped.

A team that adds Semble still needs rules. Which repos can it index? When should the agent trust a snippet? When should it open the full file? How should the run record which search query led to which change? Those questions turn search into audit data and raise it above convenience.

## The Hacker News pushback helps the story

The Hacker News thread made the claim sharper. One commenter asked how `grep` can use tokens, since `grep` itself does not call a model. The answer from the Semble side was practical: the token cost arrives when the agent reads the files behind the matches.

That distinction matters. Developers often think in commands. Agents think in context. `grep` may be cheap in the shell. A bad search result can become expensive once the model has to read around it, retry, and reason over noise.

Another thread point noted that models may distrust unfamiliar tool outputs because they learned to lean on `grep`. That is a real adoption problem. Better tools still need clear descriptions, predictable output, and training through repeated use. If an agent keeps rereading files after every search result, the token savings shrink.

This is why tool shape matters. A search tool for agents has to return enough context to be useful and enough source location data to be checkable. It also has to avoid acting like a magic answer machine. The agent should still verify key code paths before editing.

## Builders should measure search like infrastructure

Semble points at a simple operating rule: measure repo search as part of agent infrastructure.

Count search calls. Count full-file reads after search. Track token savings. Track wrong-result retries. Record which snippets led to edits. Compare the same task with raw `grep`, semantic search, and a hybrid tool. The best answer may differ by repo size, language mix, naming quality, and test coverage.

Small teams can start with a narrow rule. Use targeted search first. Open full files only when the snippet points at the right area. Keep the search query and result path in the session log. If the agent changes code, require a test or a reviewer to tie the change back to the found source.

That workflow keeps the model out of the swamp. It also makes debugging easier. When a patch fails, the team can inspect whether the agent searched the wrong concept, trusted the wrong snippet, or skipped verification.

Semble earns coverage because it makes a hidden cost visible. Coding agents spend tokens while they write and while they look around. Search quality decides how much of the context window survives long enough for the work that matters.

The next useful agent stack will treat repository search like logging, tests, and permissions. It belongs in the runtime budget. It belongs in review. It belongs in the audit trail.