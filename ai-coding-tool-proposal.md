# FORGEKEEPER: The AI Coding Tool of the Future

### A Collaborative Proposal by Claude Sonnet, Gemini 3 Pro, and GPT-5.3-Codex

> _"The winning tool won't be the one that writes the most code — it'll be the one that makes teams confidently ship the least necessary code."_

---

## The Problem: We've Been Optimizing the Wrong Thing

Every major AI coding tool today — Cursor, Copilot, Claude Code — optimizes for **token throughput**: how fast can we emit code? But the metric that actually matters is **time-to-trusted-merge**: how fast can we ship correct, secure, maintainable changes with low cognitive tax?

This mismatch has created a measurable crisis:

| Signal | Data Point |
|--------|-----------|
| Developer trust in AI code accuracy | **29% and falling** (Stack Overflow 2025) |
| Devs spending MORE time on AI-generated security issues | **68%** |
| Devs who feel faster but deliver slower | **The Productivity Paradox** |
| Code duplication trend | **Rising substantially** across AI-heavy codebases |

The tools are fast typewriters that don't know what story they're telling. We've made it trivially easy to generate code and catastrophically hard to verify it. The next generation must invert this.

---

## The Vision: An Evidence-First Software Teammate

**Forgekeeper** is not an IDE plugin. It is not an autocomplete engine. It is a **system-state engineer** — a tool that understands your system's architecture, enforces its invariants, and produces verifiable evidence for every change it makes.

Its north-star metric:

```
Trusted Merge Throughput = merged changes × confidence score ÷ downstream rework
```

---

## Core Principles

### 1. Understand the System, Not Just the Syntax

Current tools tokenize files. Forgekeeper ingests the entire repository into a **Semantic Knowledge Graph** — a continuously updated digital twin where nodes are functions, data models, API contracts, user flows, and domain boundaries. Edges represent dependencies, data flow, ownership, and — crucially — **intent**.

Every code change is linked to a Decision Record. If you try to modify a function that uses constant-time comparison for security reasons, Forgekeeper flags the architectural violation *before generating a single line of code*.

This is how you solve the context problem. Not with bigger context windows — with structured understanding.

### 2. Subtract, Don't Add

The biggest threat to software health is AI-generated sprawl. It's easier for an LLM to write a new function than to understand and refactor an old one. This leads to massive, compounding technical debt.

**The Refactor Gatekeeper**: Forgekeeper maintains a Complexity Budget. If a request can be solved by modifying existing abstractions rather than creating new ones, it *refuses to generate boilerplate* and presents a refactoring plan instead.

> _You ask for a "new user endpoint." Forgekeeper replies: "We already have a generic `ResourceController`. I can extend its configuration to handle Users with 12 lines of config, rather than writing a new 200-line controller. Proceed?"_

The tool actively rewards deletions, simplification, and reuse. A great AI should often return: **"Don't write new code. Use what's already here."**

### 3. Verification Is Not Optional — It's the Product

The Productivity Paradox exists because AI shifts effort from creation to validation. Forgekeeper eliminates this by making verification native.

**Proof-Carrying Diffs**: No change is presented to a developer without an Evidence Bundle:

- **Claims** extracted from the code ("this now retries idempotently", "auth check added")
- **Tests** mapped to each claim — if the code passes but lacks tests, Forgekeeper writes the test first
- **Security delta** — taint analysis, vulnerability assessment
- **Blast-radius map** — what existing behavior could break
- **Perf/memory regression forecast**
- **Rollback plan**

Reviewers don't just read code. They review **code + proof**.

**The Sandbox**: Forgekeeper runs its own generated code in a headless ephemeral environment against the project's test suite. If the code fails existing tests, the developer never sees it. The AI eats its own errors.

### 4. Resolve Ambiguity Before Writing Code

Most bugs are specification errors, not coding errors. Current tools ignore this layer entirely.

**The Requirement Compiler**: Before writing code, Forgekeeper compiles issue text, PRDs, and Slack threads into:

- Executable acceptance criteria
- Explicit assumptions
- Unresolved questions (assigned to humans)
- Risk tags (security / perf / data migration)

If ambiguity remains above a threshold, Forgekeeper **refuses autonomous coding** and asks targeted clarifying questions. This sounds slower. It prevents downstream churn that costs 10x more.

**Bi-Directional Spec Sync**: Forgekeeper maintains a natural-language System Spec always in sync with the code:

- *Top-down*: Edit the spec ("Users must verify email before login") → Forgekeeper highlights non-compliant code
- *Bottom-up*: Change the code → Forgekeeper alerts: "This contradicts the 'No PII in logs' policy. Update the spec or revert?"

### 5. Constrain Generation by Policy, Not Just Lint

Security scanning *after* code generation catches symptoms, not causes. AI keeps reproducing insecure patterns because it isn't constrained at generation time.

**Policy-Constrained Generation**: Org policies (security, privacy, architecture rules) are enforced *at decode time*, not as a post-hoc linter. Unsafe APIs, banned patterns, unapproved crypto, and data egress violations are blocked before they appear in diffs.

### 6. Controllable Autonomy

One size does not fit all. Different code, teams, and risk profiles demand different levels of AI independence.

**Autonomy Levels**:

| Level | Behavior | Use Case |
|-------|----------|----------|
| **Draft** | Suggest only | High-risk systems, new contributors |
| **Guarded** | Can edit, but requires complete Evidence Bundle | Standard development |
| **Delegated** | Runs full plan→code→test loops within defined scope/budget | Routine tasks, well-tested areas |

Autonomy is auditable and controllable per-repo, per-directory, or per-risk-level.

**Uncertainty Pricing**: Higher unresolved risk consumes more "autonomy budget." Teams stop celebrating raw diff volume and start optimizing confidence-adjusted delivery.

---

## Contrarian Ideas That Would Actually Work

### 🔴 Mandatory Adversarial Review
Every substantial AI diff gets attacked by a **different model** specialized in exploit discovery and logic-break analysis. Model monoculture is a risk amplifier. The adversary tries to break the code *before* a human ever sees it.

### 🟡 Slow Mode for Critical Paths
Deliberate latency checkpoints for high-risk changes (auth, billing, migrations): hypothesis → evidence → threat model → *then* code. Speed everywhere is irrational. The tool should slow you down at the right moments.

### 🟢 Meeting-to-Spec Automation
Convert call transcripts, Slack threads, and design docs into candidate specs, open questions, and decision logs. This attacks the *real* bottleneck — the 60% of developer time lost to non-coding friction.

### 🔵 Confidence Scoring, Not Binary Accept/Reject
Every block of generated code gets a Confidence Score based on:
1. **Determinism** — pure function (high) vs side-effect heavy (low)
2. **Test coverage** — existing tests cover this path?
3. **Security surface** — touches auth/crypto/PII?

Low-confidence code demands manual review. High-confidence code (boilerplate, simple transforms) auto-merges to a shadow branch for async review. Developers focus attention where it matters.

### 🟣 Outcome Telemetry
Track what actually happens to AI-authored code:
- Escaped defect rate
- Revert rate
- Mean time to resolution
- Review time per AI diff
- Security findings per AI change

Feed incidents back into policy and graph constraints automatically. The tool learns from its failures.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    FORGEKEEPER                          │
│                                                         │
│  ┌───────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │  Requirement  │  │   Semantic   │  │   Policy     │ │
│  │  Compiler     │──│  Knowledge   │──│   Engine     │ │
│  │  (Spec→Code)  │  │  Graph       │  │  (Guardrails)│ │
│  └───────┬───────┘  └──────┬───────┘  └──────┬───────┘ │
│          │                 │                  │         │
│  ┌───────▼─────────────────▼──────────────────▼───────┐ │
│  │              Generation Engine                     │ │
│  │  (Policy-constrained, architecture-aware LLM)      │ │
│  └───────────────────────┬────────────────────────────┘ │
│                          │                              │
│  ┌───────────────────────▼────────────────────────────┐ │
│  │            Verification Layer                      │ │
│  │  ┌──────────┐ ┌──────────┐ ┌────────────────────┐ │ │
│  │  │ Sandbox  │ │Adversary │ │  Evidence Bundle   │ │ │
│  │  │ (Test)   │ │ (Attack) │ │  Generator         │ │ │
│  │  └──────────┘ └──────────┘ └────────────────────┘ │ │
│  └───────────────────────┬────────────────────────────┘ │
│                          │                              │
│  ┌───────────────────────▼────────────────────────────┐ │
│  │         Delivery & Telemetry                       │ │
│  │  Confidence scoring │ Outcome tracking │ Learning  │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

---

## Roadmap

### Phase 1 — Foundation (Months 1–3)
**Goal**: Semantic Knowledge Graph + Refactor Gatekeeper

- Build the repo ingestion pipeline: AST parsing, dependency extraction, data flow analysis
- Create the Knowledge Graph with function, module, contract, and ownership nodes
- Implement the Complexity Budget and Refactor Gatekeeper logic
- Build basic Decision Record tracking (why was this code written this way?)
- Ship as a CLI tool that works alongside existing editors

**Key deliverable**: A tool that says "don't write new code, reuse this" with high accuracy

### Phase 2 — Verification (Months 4–6)
**Goal**: Evidence Bundles + Sandbox Execution

- Build the ephemeral sandbox (WASM/micro-VM) for pre-verification
- Implement test-first generation: write test → verify failure → write code → verify pass
- Create the Evidence Bundle format (claims, test mappings, blast-radius, rollback plan)
- Add Confidence Scoring to all generated output
- Integrate with CI/CD for automated verification gates

**Key deliverable**: No developer ever sees code that fails existing tests

### Phase 3 — Policy & Safety (Months 7–9)
**Goal**: Policy-Constrained Generation + Adversarial Review

- Build the Policy Engine for org-level security/architecture rules
- Implement decode-time constraint enforcement (not post-hoc linting)
- Deploy the adversarial second model for exploit/logic-break discovery
- Add autonomy levels (Draft / Guarded / Delegated) with per-repo configuration
- Implement uncertainty pricing for autonomy budget management

**Key deliverable**: Security issues caught at generation time, not in production

### Phase 4 — Spec Layer (Months 10–12)
**Goal**: Requirement Compiler + Bi-Directional Spec Sync

- Build the Requirement Compiler (issue text → acceptance criteria + assumptions + questions)
- Implement the bi-directional System Spec sync (spec↔code alignment)
- Add meeting-to-spec automation (transcript → structured decisions)
- Build Slack/Linear/Jira integration for spec sourcing
- Implement the "refuse to code" gate when ambiguity exceeds threshold

**Key deliverable**: Most bugs caught at the spec stage, before a line of code is written

### Phase 5 — Learning & Scale (Months 13–18)
**Goal**: Outcome Telemetry + Continuous Improvement

- Deploy outcome tracking (defect rate, revert rate, MTTR per AI change)
- Build the feedback loop: incidents → policy updates → graph constraints
- Add team-level dashboards for Trusted Merge Throughput
- Implement cross-repo learning (anonymized pattern sharing)
- Enterprise features: SSO, audit logs, compliance reporting, on-prem deployment

**Key deliverable**: The tool gets measurably better every week from real-world outcomes

---

## What Makes This Different

| Current Tools | Forgekeeper |
|--------------|-------------|
| Optimize for lines of code generated | Optimize for trusted merges shipped |
| Context = current file + maybe repo | Context = semantic graph of system + history + intent |
| Verification is the developer's problem | Verification is built into every output |
| More code = more productive | Less code, better code = more productive |
| Security scanned after generation | Security enforced during generation |
| One autonomy level (on/off) | Graduated autonomy with uncertainty pricing |
| Specs are someone else's job | Specs are the first thing the tool works on |
| Trust the AI or don't | Trust is earned, scored, and evidence-backed |

---

## Anvil: The Working Prototype

We don't have to wait for the full vision. **Anvil** is a custom Copilot CLI agent (`~/.copilot/agents/anvil.agent.md`) that implements the Forgekeeper philosophy using capabilities available today. It has been through **4 rounds of adversarial review** by Claude, GPT-5.3-Codex, Gemini 3 Pro, and Claude Opus 4.6.

| Forgekeeper Feature | Anvil Implementation |
|---|---|
| Refactor Gatekeeper | Mandatory codebase survey before generating new code; surfaces reuse opportunities with line-count comparison |
| Adversarial Review | 1 reviewer for Medium tasks, 3 frontier models in parallel for Large (GPT-5.3, Gemini 3 Pro, Opus 4.6) |
| Evidence Bundles | SQL-backed verification ledger — every check is an INSERT, bundle is a SELECT. Cannot be hallucinated. |
| Baseline Capture | Snapshots build/test/diagnostic state BEFORE changes, detects regressions by diffing |
| Verification Cascade | 3-tier: always (diagnostics), if exists (build/type/lint/test), fallback (import test/smoke script). Zero verification is never acceptable. |
| Requirement Compiler | Parses requests into goals, criteria, assumptions; boosts vague prompts into precise specs |
| Requirements Pushback | Challenges bad REQUIREMENTS, not just bad implementations. "This feature conflicts with existing behavior." |
| Session History Recall | Queries past sessions before planning. "Last time this file was modified, it caused X." |
| Confidence Scoring | Concrete definitions (High = merge without reading diff, Low = must state what would raise it) |
| Operational Readiness | Large tasks checked for observability, degradation handling, hardcoded secrets |
| Post-Task Learning | Stores build commands, patterns, and failure modes via `store_memory` for future sessions |
| Anti-Hallucination | SQL GATE markers at 3 critical points; verification requires tool-call proof, not prose |

### How to Work with Anvil

**Anvil is not autocomplete. It's a senior engineer who proves their work.**

Your role changes. You stop writing code and start:

**Stop doing:**
- Reviewing AI code line by line — read the Evidence Bundle instead
- Prescribing exact implementation — describe the outcome, not the code
- Accepting "tests passed" as sufficient — check baseline vs. after, check regressions, check what reviewers found
- Ignoring pushback — when Anvil says "this is a bad idea," it's usually right

**Start doing:**
- Writing tickets as outcomes + constraints, not implementation steps
- Reviewing the Plan (for Large tasks) — if the plan is right, the code will be right
- Checking the "Issues fixed before presenting" line — that's the bugs you never saw
- Feeding outcomes back: tell Anvil when something broke post-merge so it learns

**The new workflow:**
1. **State the problem** — what you want, not how to build it
2. **Negotiate** — Anvil may push back on your requirements or propose a simpler approach
3. **Approve the plan** (Large tasks) — not the code, the plan
4. **Review the Evidence Bundle** — baseline, verification, regressions, adversarial findings
5. **Merge with confidence** — or ask for the specific thing that would raise confidence

**Trust rule:** High confidence + no regressions = commit it. Low confidence = Anvil tells you exactly what would raise it.

**To use Anvil**: Run `/agent` in Copilot CLI and select "Anvil", or invoke directly.

---

## Who Built This Proposal

This document was produced through a structured collaboration between three AI systems, each bringing a distinct perspective:

- **Claude Sonnet 4.6** — Research synthesis, critical analysis of the productivity paradox, and document architecture
- **Gemini 3 Pro** — Proposed the "Origin" concept: Semantic Knowledge Graph, Refactor Gatekeeper, Proof-of-Work Sandbox, and the philosophy that the tool should be a "stabilizer, not an accelerator"
- **GPT-5.3-Codex** — Proposed the "Forgekeeper" concept: Evidence Bundles, Requirement Compiler, Policy-Constrained Generation, Uncertainty Pricing, and the core metric of Trusted Merge Throughput

The convergence was striking. All three models independently arrived at the same core insight: **the next great AI coding tool isn't faster — it's more trustworthy.** The proposals were merged under the Forgekeeper name with Origin's architectural ideas forming the foundation.

---

*February 2026*
