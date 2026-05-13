---
title: 'CI cache poisoning is now an agent credential problem'
date: 2026-05-13
category: 'security'
tags:
  - 'ai-agents'
  - 'supply-chain'
  - 'developer-tools'
  - 'security'
  - 'ci'
excerpt: 'The TanStack npm compromise shows why agent workspaces need to treat CI caches, trusted publishing, and install scripts as credential boundaries.'
author: 'X Node Dev'
authorImage: ''
authorBio: ''
image: '/images/articles/tech-marketing-3d-ci-cache-agent-credential-boundary.png'
sources:
  - 'https://tanstack.com/blog/npm-supply-chain-compromise-postmortem'
  - 'https://news.ycombinator.com/item?id=48100706'
  - 'https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#pull_request_target'
  - 'https://docs.github.com/en/actions/concepts/security/openid-connect'
type: 'article'
draft: false
---

A package install can turn a clean build into a credential search.

TanStack's May 2026 npm compromise made that plain. The TanStack postmortem says an attacker published 84 malicious versions across 42 `@tanstack/*` packages. The attack used GitHub Actions `pull_request_target`, cache poisoning across fork and base trust boundaries, and runtime extraction of an OpenID Connect token from the runner.

That chain matters for agent teams because coding agents live near the same systems. They install packages. They run tests. They touch local env files. They can trigger continuous integration, or CI, workflows through pull requests. A package event can cross from normal dev work into credential theft fast.

## The cache became part of the trust boundary

TanStack says the attacker used GitHub Actions cache behavior across fork and base workflows. That detail should change how teams think about CI. A cache can look like build speed. In this incident, TanStack says it helped bridge the gap between untrusted pull request work and trusted release work.

GitHub's documentation says `pull_request_target` runs in the context of the base repository. GitHub warns that this event can expose secrets and grant write permission when used with untrusted code. That warning has existed for years, but the TanStack incident gives it a fresh agent-era shape.

Agents make pull requests easier to create and update. They also make it easier to produce a lot of generated dependency changes, test runs, and workflow churn. That extra volume raises the chance that a risky workflow pattern sits in the path.

## Trusted publishing still needs small rooms

TanStack says no npm tokens were stolen. That is good news. It also shows why the next layer matters.

The TanStack postmortem says the malicious payload extracted an OpenID Connect token from the runner. GitHub describes OpenID Connect, or OIDC, as a way for workflows to request short-lived tokens from cloud providers or other services without storing long-lived secrets. That pattern improves security when teams scope it well.

Short-lived tokens still need narrow permissions. A workflow that can mint broad tokens can still become a release risk. The TanStack incident shows that the secret no longer has to sit in a repo setting as a static npm token. Trust can appear at runtime, inside the job, when the workflow asks for it.

For builders, that shifts the review target. You have to inspect which jobs can request identity. You have to inspect which branches can influence those jobs. You have to inspect which caches and artifacts cross from one trust zone to another.

## Install scripts see more than teams expect

TanStack says the payload harvested cloud, Kubernetes, Vault, npm, GitHub, and SSH credentials from install hosts. That target list reads like a map of modern developer authority.

An agent workspace often contains the same authority. The repo has package locks and build scripts. The shell has model keys. The editor has agent state. The terminal may hold cloud auth. The CI system may hold deploy rights. A compromised install path can scan all of that before a human notices.

This is why package install permissions belong in agent policy. A coding agent that can add a package, run install hooks, and push a branch can move dangerous code into the path of a trusted workflow. The model does not need bad intent. It only needs to accept a dependency suggestion that carries risk.

## Agent policy has to reach CI

Most agent guardrail talk stops at the local machine. Teams block `rm -rf`, protect `.env`, or ask for approval before a shell command runs. Those controls help. The TanStack incident points at the next boundary: the remote workflow that runs after the agent opens the pull request.

Agent policy should include CI rules. Generated pull requests should not change workflow files without human review. They should not add install scripts without a second check. They should not widen package-manager permissions, cache keys, release jobs, or OIDC scopes without a named owner signing off.

That review has to happen before the build runs with real authority. Once a workflow crosses into a trusted runner, the security model depends on every cache, artifact, token scope, and install hook that came before it.

## The boring checklist wins

The useful response here looks simple. Audit every `pull_request_target` workflow. Separate cache keys for untrusted and trusted jobs. Treat workflow file edits as security changes. Keep OIDC token permissions narrow. Block release jobs from fork-shaped inputs. Review package install scripts before they run in privileged jobs.

TanStack's postmortem gives teams a concrete incident to study. GitHub's docs give teams the shape of the risky event and the identity system. Together, they point to a plain rule for agent-era development: if an agent can influence a build input, that input belongs in the credential boundary.

AI coding raises throughput. Security reviews have to move with it. The build system now sits between generated code and real tokens, so teams need to treat CI like part of the agent runtime.