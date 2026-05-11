---
title: 'MCP has a context budget'
date: 2026-05-11
category: 'analysis'
tags:
  - 'ai-agents'
  - 'mcp'
  - 'developer-tools'
  - 'rag'
  - 'context-engineering'
excerpt: 'Agent teams keep adding tools and retrieval, but every tool definition and every source path competes for the same scarce context window.'
author: 'X Node Dev'
authorImage: ''
authorBio: ''
image: '/images/articles/tech-marketing-3d-mcp-context-budget.png'
sources:
  - 'https://dev.to/kenimo49/your-mcp-server-eats-55000-tokens-before-your-agent-says-a-word-i-measured-the-real-cost-19l8'
  - 'https://blog.google/innovation-and-ai/technology/developers-tools/expanded-gemini-api-file-search-multimodal-rag/'
  - 'https://unix.foo/posts/local-ai-needs-to-be-norm/'
  - 'https://www.jamesshore.com/v2/blog/2026/you-need-ai-that-reduces-your-maintenance-costs'
  - 'https://news.ycombinator.com/item?id=48085821'
  - 'https://news.ycombinator.com/item?id=48089289'
type: 'article'
draft: false
---

Agent tools can burn the budget before the agent starts the task.

That is the useful warning from this week's community scan. Builders keep wiring more Model Context Protocol servers, retrieval stores, local files, and helper tools into agents. Each addition looks small on its own. Together, they compete for the same context window that the agent needs for the actual job.

The clearest number came from Ken Huang's DEV.to article on MCP token cost. Huang measured a full GitHub MCP server with 93 tools at about 55,000 tokens of tool definitions before the agent says a word. That turns tool inventory into an architecture cost, not a setup detail.

## Tool count is now a bill of materials

The Model Context Protocol, or MCP, gives agents a standard way to discover and call tools. That standard matters because every team wants agents to reach files, tickets, databases, browsers, calendars, and internal APIs without custom glue for each one.

Huang's DEV.to article shows the other side of that convenience. His table estimates a one-tool PostgreSQL server at about 35 tokens, a seven-tool Google Maps server at about 704 tokens, a 26-tool GitHub server at about 4,242 tokens, and a full 93-tool GitHub setup at about 55,000 tokens.

That spread matters more than the exact token count. A small, focused server has a different operating profile than a broad capability bundle. Both may use MCP. One acts like a cheap adapter. The other acts like a large dependency that loads into the agent's working memory.

Huang also gives a scale example that should make operators wince. Three heavy services can consume about 143,000 tokens, or roughly 71 percent of a 200,000-token context window, before the task context arrives. At that point, the agent doesn't have a tool problem. It has a memory allocation problem.

## More tools can make the agent worse

Token cost is only one part of the hit. Huang reports that output quality visibly degrades after 50 or more tool definitions. The agent starts chasing tangents, recommending the wrong tools, and losing focus on the user's question.

That tracks with how agent systems fail in practice. A tool list works as behavior-shaping input. It shapes what the model thinks it can do. A bloated tool surface can make a simple task feel like a maze.

The fix starts with boring hygiene. Huang recommends `allowedTools`, shorter descriptions, and connecting servers only when a task needs them. Those steps cut noise before the model sees it. They also force a useful design question: which tools belong in the default workbench, and which tools should load only on demand?

That question belongs in architecture review. Teams already review database indexes, cloud permissions, and package dependencies. MCP tool inventory deserves the same treatment because it affects cost, latency, and behavior on every run.

## Retrieval is solving the same pressure from another side

Google's May 2026 Gemini API File Search update points at a related pattern. Google says File Search now supports multimodal retrieval, custom metadata filters, and page-level citations. The Google post also quotes Code Fundi saying agents reclaim more than 50 percent of their context window for reasoning when they use retrieval over broad context stuffing.

That claim lands because the core pressure is the same. Agents need less bulk context and more precise context. A retrieval layer with page citations can carry less text while improving verification. A metadata filter can keep irrelevant files out of the answer path. Multimodal retrieval can pull diagrams and images when the task needs them instead of making the agent carry a whole archive.

This is where MCP and retrieval meet. MCP gives agents access to tools. Retrieval gives agents access to source material. Both systems can help. Both systems can also flood the context window if teams treat connection as the same thing as design.

## Local-first AI adds another reason to care

The community scan also found strong Hacker News attention around the essay "Local AI Needs to be the Norm." That post argues that cloud AI features make small products inherit vendor uptime, rate limits, billing paths, retention questions, and consent burdens. The author frames local AI as a reliability and privacy choice for mainstream product work.

Local-first agents make context budgets even more visible. A small machine has real memory limits. Local models may have smaller context windows. A local workflow also tends to involve personal files, app data, notes, and project state. The team has to decide what crosses the agent boundary.

A local agent that loads every tool and every file is still a fragile system. Local execution removes some cloud risk. Context cost remains. The architecture still needs scoped tools, filtered retrieval, and clear rules for what the model sees.

## Maintenance cost includes context design

James Shore's May 2026 essay on AI maintenance costs gives this trend a useful management frame. Shore argues that AI code generation must reduce maintenance cost in proportion to its speed gains. If agents help teams create more software but increase future maintenance, the early speed boost becomes a long-term penalty.

Context design belongs in that maintenance ledger. A messy tool surface makes every future agent run harder to reason about. A retrieval layer without metadata makes answers harder to verify. A default MCP bundle with dozens of unused tools makes each task more expensive and less predictable.

Teams often treat agent setup as personal preference. One developer connects a GitHub server. Another connects email. Someone adds browser access. Someone else adds a document store. Soon the agent has a tool closet that no one audits.

That drift creates future work. Debugging an agent means asking which tools loaded, which descriptions influenced the model, which retrieval filters ran, and which source citations back the answer. If the team cannot answer those questions, the agent stack has become another unowned dependency.

## The practical rule: load less by default

The best near-term agent architecture will feel less exciting than the demo. It will load fewer tools. It will name tool scopes clearly. It will keep broad servers out of default sessions. It will measure token overhead before and after each integration. It will require citations for retrieval-backed answers.

A useful team checklist is short:

1. Count default MCP tools before each agent run.
2. Set `allowedTools` for routine workflows.
3. Trim long tool descriptions.
4. Disconnect servers that do not match the task.
5. Use metadata filters and page citations for retrieval.
6. Log which tools and sources shaped high-risk outputs.

That checklist has none of the glamour of a new model launch. It will save money and reduce weird agent behavior.

The agent stack is becoming normal software infrastructure. Normal infrastructure needs budgets. MCP has one. Retrieval has one. Local-first systems have one. The teams that respect those budgets will give their agents less to carry and more room to think.
