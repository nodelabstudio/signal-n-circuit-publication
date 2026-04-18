---
title: 'OpenClaw v2026.4.14 Shipped 5 Security Fixes in One Day. Here Is What Actually Changed.'
date: 2026-04-15
category: 'release-watch'
tags:
  - 'openclaw'
  - 'security'
  - 'ai-agents'
  - 'release-watch'
excerpt: 'One release, five discrete security fixes across ReDoS, allowlist bypasses, SSRF gaps, and command injection. This is what hardening looks like when it is not performative.'
author: 'X Node Dev'
authorImage: ''
authorBio: ''
image: '/images/articles/regenerated-openclaw-v2026-4-14-security-hardening-what-actually-shipped.jpg'
sources:
  - 'https://github.com/nousresearch/openclaw/releases/tag/v2026.4.14'
  - 'https://github.com/nousresearch/openclaw/issues/46707'
  - 'https://github.com/nousresearch/openclaw/issues/62006'
  - 'https://github.com/nousresearch/openclaw/issues/66028'
  - 'https://github.com/nousresearch/openclaw/issues/66022'
  - 'https://github.com/nousresearch/openclaw/issues/63175'
type: 'article'
draft: false
---

# OpenClaw v2026.4.14 Shipped 5 Security Fixes in One Day. Here Is What Actually Changed.

OpenClaw v2026.4.14 dropped on April 14, 2026. The release banner said "model provider improvements and critical security hardening." The banner undersold it.

Five discrete security issues landed in one release. Not fuzzed vulnerabilities. Not theoretical risks. Known issue numbers with specific fix descriptions.

## The Five Fixes

**ReDoS via `marked.js` (#46707).** The markdown parser in the agent was vulnerable to regular expression denial of service. A specially crafted markdown input could trigger catastrophic backtracking and hang the agent. The fix: replace `marked.js` with `markdown-it`. That is a direct dependency swap on a parsing surface that processes untrusted input. If you are running OpenClaw and parsing markdown from external sources, you want this patch.

**Gateway-tool dangerous flags via `config.patch` (#62006).** The `config.patch` mechanism accepted flags that should have been rejected. An attacker or a compromised workflow able to pass arbitrary config flags could alter gateway behavior in ways the allowlist was supposed to prevent. The fix: reject dangerous flags at the `config.patch` boundary.

**Slack allowlist bypass on `block-actions` (#66028).** The Slack adapter was not correctly validating `block-actions` payloads against the channel allowlist. A crafted payload could trigger actions on channels outside the configured allowlist. Fixed with proper validation on the `block-actions` event type.

**`realpath` error bypassing allowlist (#66022).** The filesystem allowlist check used `realpath` to resolve symlinks and relative paths before comparison. If `realpath` failed on a path, the allowlist check would silently pass, allowing access to paths that should have been blocked. The fix: fail-closed when canonical resolution fails. If the system cannot determine the real path, it treats it as blocked.

**Ollama slow local model wrong stream timeout (#63175).** When an Ollama backend model was slow to respond, the stream timeout logic was incorrectly applied, causing the agent to misinterpret timeout conditions for local models. Fixed with correct timeout handling for the Ollama streaming path.

## The Beta Track Also Landed

The same day, v2026.4.14-beta.1 shipped with additional hardening for the browser and UI layer:

- Heartbeat owner downgrade for untrusted `hook:wake` signals
- Browser SSRF policy enforcement
- Teams SSO allowlist checks
- Config redaction improvements

The beta track is now meaningfully distinct from stable in terms of security hardening. If you are running OpenClaw in a multi-user or networked environment, the beta is worth tracking closely.

## What This Tells You

AI agent frameworks are processing untrusted input, hitting the filesystem, calling external APIs, and running user-supplied code in subprocesses. That is a large attack surface. OpenClaw is shipping security fixes at the same pace as a mature web framework.

The `realpath` fail-closed fix is the most instructive. Many allowlist implementations would have logged the error and moved on. OpenClaw chose to block. That is the right call for a system running in an environment where the worst-case outcome is a compromised agent acting on behalf of a user with paid API access.

## If You Are Running OpenClaw

Upgrade to v2026.4.14 or later. The dependency swap on the markdown parser is the highest priority if you are on an older release. The `realpath` and Slack bypass fixes matter if you are using the filesystem allowlist or the Slack integration.

Check your current version and upgrade path at the OpenClaw releases page.
