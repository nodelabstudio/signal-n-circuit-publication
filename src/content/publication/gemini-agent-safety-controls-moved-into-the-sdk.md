---
title: 'Gemini agent safety controls moved into the SDK'
date: 2026-05-22
category: 'release-watch'
tags:
  - 'ai-agents'
  - 'developer-tools'
  - 'gemini'
  - 'agent-safety'
  - 'release-watch'
excerpt: 'Google GenAI SDK v2.6.0 added prompt-injection detection for Gemini Computer Use, while Gemini CLI tightened shell safety and automation behavior.'
author: 'X Node Dev'
authorImage: ''
authorBio: ''
image: '/images/articles/gemini-agent-safety-release-watch.png'
sources:
  - 'https://github.com/googleapis/python-genai/releases/tag/v2.6.0'
  - 'https://github.com/googleapis/js-genai/releases/tag/v2.6.0'
  - 'https://www.npmjs.com/package/@google/genai/v/2.6.0'
  - 'https://pypi.org/project/google-genai/2.6.0/'
  - 'https://github.com/google-gemini/gemini-cli/releases/tag/v0.43.0'
  - 'https://www.npmjs.com/package/@google/gemini-cli/v/0.43.0'
  - 'https://github.com/google-gemini/gemini-cli/releases/tag/v0.44.0-preview.0'
type: 'article'
draft: false
---

Computer-use agents need safety controls in the code path where actions happen.

Google's May 22 release wave put more of that control inside developer tools. The Python and JavaScript Google GenAI SDK v2.6.0 releases added `enable_prompt_injection_detection` for Gemini API Computer Use. The same releases added a `budget_exceeded` status and exposed `gemini-3.5-flash` in the SDK surface.

That combination matters for builders who wire Gemini into browser or desktop action loops. A prompt-injection flag belongs near the call that lets an agent read pages, click controls, and pass data into tools. A budget status belongs near the run loop that decides whether to keep going or stop before a task burns money.

## What shipped in GenAI SDK v2.6.0

Google published matching v2.6.0 release notes for `googleapis/python-genai` and `googleapis/js-genai`. npm lists `@google/genai` v2.6.0, and PyPI lists `google-genai` v2.6.0.

The named Computer Use change is the clearest signal. Google added `enable_prompt_injection_detection` to the SDK surface. That gives developers a direct switch for a risk that shows up when agents follow instructions from web pages, emails, documents, and other untrusted text.

Prompt injection has a simple shape. The outside world tells the agent to ignore the user, leak data, call the wrong tool, or change the goal. A computer-use agent raises the stakes because it can act through a browser or another machine interface. Detection in the SDK does not make a workflow safe by itself, but it gives teams a real place to wire policy.

The `budget_exceeded` status also deserves attention. Long agent runs need clean stop reasons. A vague failure wastes review time. A named budget stop lets the calling app show the user what happened, save the session, and decide whether to retry with a smaller task.

Google also exposed `gemini-3.5-flash` through the SDK releases. That connects the release to the larger Gemini 3.5 product wave. For developers, the practical issue is access from normal package surfaces, not keynote wording.

## Gemini CLI tightened the run loop

The same scan found Gemini CLI v0.43.0 stable and v0.44.0 preview. Google published v0.43.0 on npm and GitHub, with v0.44.0-preview.0 landing nearby.

The stable release steers the model toward surgical edit-tool usage. That sounds small until a coding agent edits the wrong file. Edit discipline becomes a safety feature when the agent can patch a repo faster than a human can review every line.

Google also documented Auto Memory behavior, added shell-command safety evaluations, improved Model Context Protocol list behavior in untrusted folders, fixed context-manager chat corruption, prevented silent OAuth hangs, randomized sandbox container names, and added JSON output for `AgentExecutionStopped` in non-interactive mode.

Those are operator details. They decide whether Gemini CLI can run inside scripts, cron jobs, local sandboxes, and team workflows without turning every failure into a guessing game.

The v0.44.0 preview adds another set of control points. Google says the preview uses first-wins agent registration with project priority, merges Auto modes, preserves OAuth refresh tokens during rotation, refreshes Model Context Protocol OAuth token usage after re-auth, isolates subagent thread context, and bounds shell output and live UI buffers.

Subagent context isolation is the kind of fix teams will care about once agents do parallel work. A subagent should not leak the wrong thread state into another task. Output bounds also matter because uncontrolled shell text can flood a session, slow a run, or bury the signal a human needs.

## The release signal is where Google placed the controls

This release wave points to a clear product direction. Google is moving agent safety and run-state controls into the SDK, the command-line interface, and the automation output path.

That is where working builders need them. Policy outside the run loop becomes advice. Policy inside the SDK and CLI can stop a call, tag a failure, constrain output, preserve auth, and record the reason a task ended.

Teams using Gemini for action-capable agents should test these changes with boring tasks first. Open a page with untrusted text. Run a shell command that should trip a safety check. Force a budget stop. Rotate auth. Run a non-interactive task and inspect the JSON error path.

The useful question after v2.6.0 and v0.43.0 is direct: can the tool tell a builder why the agent stopped, what it trusted, what it edited, and which safety control fired?

If the answer is yes, Gemini-based agent workflows get easier to operate. If the answer is no, the new flags become another setting nobody can prove during a real incident.