---
title: 'AI-written code needs a paper trail before teams can own it'
date: 2026-04-29
category: 'ai-policy'
tags:
  - 'ai-coding'
  - 'copyright'
  - 'code-review'
  - 'developer-tools'
  - 'operations'
excerpt: 'AI coding tools raise a practical ownership problem: teams need evidence of human decisions before generated code becomes code they can safely ship, defend, and maintain.'
author: 'jsnode'
authorImage: ''
authorBio: ''
image: '/images/articles/regenerated-v5-ai-coding-agent-adoption-reaches-90-but-comprehension-debt-emerges-as-hidden-cost.jpg'
sources:
  - 'https://legallayer.substack.com/p/who-owns-the-claude-code-wrote'
  - 'https://news.ycombinator.com/item?id=47932937'
  - 'https://lobste.rs/s/pv23xq/who_owns_code_claude_wrote'
  - 'https://github.com/anthropics/claude-code/issues/49363'
  - 'https://dev.to/googleai/how-i-used-gemini-cli-to-orchestrate-a-complex-rag-migration-43ga'
type: 'article'
draft: false
---

A team can merge AI-written code faster than it can prove who owns the work.

That sounds like a lawyer problem until it lands inside a normal pull request. A developer asks Claude Code, Cursor, or Codex for a feature. The tool writes most of it. The tests pass. The diff looks fine. Then the team has to answer harder questions: who made the creative choices, who reviewed the output, who checked license risk, and who can explain the code six months later?

Sena Evren's Legal Layer post, "Who Owns the Code Claude Wrote?", put that question in plain terms. Evren wrote that agentic coding tools can produce code that may be uncopyrightable, assigned to an employer by contract, or exposed to open-source license risk. Hacker News pushed the post to 459 points and 428 comments. Lobsters also discussed it under `law` and `vibecoding`.

The numbers matter because this moved beyond policy circles. Developers are arguing about it in the same places they argue about build tools, code review, and production bugs.

## The legal risk turns into an ops risk

Legal Layer's central warning is simple: copyright law cares about human authorship. Evren cites the US Copyright Office position and the Thaler case to say work made without meaningful human authorship may not qualify for copyright protection. The post also notes a limit: Thaler dealt with visual art and no human creative input, not a disputed software pull request with mixed human and AI work.

That limit is the whole problem for software teams.

A real AI-assisted pull request rarely comes with a clean line between human work and model output. The human may write the prompt, accept some code, reject other code, change the architecture, add tests, and edit the final diff. Or the human may accept a large patch with only light cleanup. Those two cases can look the same in Git if the team doesn't keep records.

So the operational question is not only "is this code copyrightable?" The better question is "can we show the human decisions that made this code ours?"

## The paper trail should start in the pull request

Legal Layer says developers should document the decisions behind AI-assisted work: architecture choices, rejected outputs, human edits, review notes, and dependency or license checks. That advice maps cleanly onto normal engineering process.

Teams don't need a new ceremony for every AI commit. They need a better pull request template.

A practical AI-assisted PR should answer five questions:

1. Which tool generated or edited code?
2. Which parts did a human design, rewrite, or reject?
3. Which tests did the human run and inspect?
4. Which license or dependency checks changed?
5. Who can explain this code during an incident?

This is boring by design. Boring records are useful records. A reviewer should not need access to a private chat transcript to learn whether the author understood the change.

## Community debate shows the trust gap

The Hacker News thread did not treat Legal Layer's post as settled law. One highly visible comment argued that denial of certiorari in Thaler does not settle the issue nationwide. That pushback matters. Teams should avoid treating one legal blog post as a final answer.

But the debate still gave builders a useful signal. Even if courts sort out the exact rule later, teams need evidence now. If no one can show how a feature was designed, reviewed, and checked, the code already has a trust problem.

Lobsters added a second kind of skepticism. Commenters questioned the author and the article's framing, but they still engaged with the core issue: AI-generated code ownership feels unclear enough that working developers now ask about it in public.

That is the practical signal. The uncertainty itself changes the workflow.

## Reliability failures make ownership harder

The ownership question also overlaps with agent reliability. The Signal & Circuit community scan flagged an Anthropic Claude Code issue that drew 170 Hacker News points. The issue reports that Claude Code v2.1.111 injected a malware warning into Read and Grep results, and the reporter said Opus 4.7 subagents refused legitimate open-source edits in roughly 40 to 60 percent of attempts during a parallel refactor.

That case is not about copyright. It shows why invisible agent behavior belongs in the record.

If a hidden safety prompt can change how a coding agent reads files and edits code, then AI-assisted work needs more than a final diff. Teams need versioned tools, noted model settings, clear review paths, and enough context to reproduce why a change happened.

A human can't own a change they can't explain. A team can't defend a workflow it can't reconstruct.

## Spec files help prove human intent

Google AI's DEV.to post about using Gemini CLI for a complex RAG migration points at a stronger pattern. The author describes a spec-driven workflow with `product.md`, `tech-stack.md`, `tracks.md`, per-track `plan.md`, and `workflow.md`. The work crossed Terraform, Python, Next.js, BigQuery, AlloyDB, and docs. The important part was not the model. It was the scaffolding around the model.

That scaffolding creates evidence. It shows what the team wanted, how work was split, what constraints mattered, and where humans reviewed the result.

This is why spec files are becoming more than prompt aids. For agentic coding, specs can become ownership records. They show human intent before the model starts filling in code.

## What teams should do now

Teams don't need to wait for courts to settle every AI code question. They can make the work easier to own today.

Start with disclosure. Mark AI-assisted changes in the PR, not as a confession, but as context for review. Add a short human-authorship note for large generated diffs. Record what the author designed, what the model produced, and what changed after review.

Add license checks where generated code introduces new dependencies, copied snippets, or suspiciously specific implementations. Legal Layer's post frames license contamination as one of the hard risks because developers often don't know what training data influenced an output. Static tools won't solve every case, but silence solves none of them.

Keep prompts and agent logs when the change is high risk. That does not mean dumping every chat into Git. It means preserving enough context for security, legal, or incident review when the code touches auth, payments, infrastructure, customer data, or open-source releases.

Most of all, make one human accountable. The Linux kernel already moved in this direction with AI-assisted contribution policy. For private teams, the same idea applies without kernel process: a named engineer should be able to explain the change and stand behind it.

AI coding tools make code cheaper to create. They don't make code cheaper to own. Ownership still needs human decisions, review evidence, and a record that survives after the chat window closes.
