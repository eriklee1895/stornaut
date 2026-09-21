# Codex Capability-First Documentation Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every current Stornaut specification describe Codex as a
high-quality, full-featured read-only investigator while preserving Swift's
exclusive authority over writes and cleanup.

**Architecture:** ADR 0004 is the normative capability boundary. Current
product and implementation documents must inherit it directly; historical
studies, ADR evidence and validation reports retain their measured facts but
receive an explicit supersession note so they cannot be mistaken for current
policy.

**Tech Stack:** Markdown, repository link checker, ripgrep, Git.

## Global Constraints

- Quick Scan never invokes Codex.
- Codex may directly read files and use shell/unified exec, live web search,
  browser/direct fetch, image inspection, supported skills and subagents.
- Live search is high-context and has no public destination-domain allowlist; cached or
  indexed fallback must be reported as degraded coverage.
- Public command/subprocess network is allowed without a Bash/executable
  allowlist or per-command approval.
- Localhost, private/link-local networks and arbitrary Unix sockets remain
  blocked unless a future product decision explicitly enables them.
- Codex and every descendant process remain unable to create, modify, move,
  rename or delete user data; `danger-full-access` is not an acceptable
  shortcut.
- Codex cannot invoke Trash, Registered Actions, Policy Gate or Executor.
- Swift canonicalization, policy, revalidation, explicit user selection and
  typed execution remain mandatory.
- Historical measurements remain factual history; do not rewrite them as if
  the old Broker-only gate had passed.
- Preserve and do not commit unrelated Phase C work already present in the
  dirty worktree.

---

### Task 1: Audit and classify every restrictive statement

**Files:**
- Inspect: every repository `*.md` file
- Reference: `docs/adr/0004-codex-file-read-isolation.md`

**Interfaces:**
- Consumes: accepted ADR 0004 capability-first decision
- Produces: a file list split into current normative text, current status text
  and immutable historical evidence

- [x] **Step 1: Find restrictive phrases**

  Run repository-wide `rg` searches for Broker-only, Probe-Broker-only,
  arbitrary-shell denial, direct-read denial, network denial, tool allowlists,
  and Deep Dive no-go/paused wording.

- [x] **Step 2: Classify each occurrence**

  Treat PRD, architecture, approved design, AGENTS/handoff, roadmap and indexes
  as current normative/status text. Treat completed plans, upstream studies,
  ADR measurements and validation reports as historical evidence.

### Task 2: Synchronize current product and engineering contracts

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `docs/README.md`
- Modify: `docs/product/PRD.md`
- Modify: `docs/architecture/system-architecture.md`
- Modify: `docs/design/agent-disk-governance.md`
- Modify: `docs/design/ui-ux.md`
- Modify: `docs/agent/coding-agent-handoff.md`
- Modify: `docs/plans/roadmap.md`

**Interfaces:**
- Consumes: ADR 0004 capability profile and invariant write/Executor boundary
- Produces: one consistent current product contract

- [x] **Step 1: Replace Broker-only product invariants**

  State that Probe Broker is preferred structured evidence, not the exclusive
  interface. Direct reads and Agent investigation tools are permitted.

- [x] **Step 2: Replace capability-denial language**

  Explicitly permit live search, public network, shell/unified exec,
  browser/direct fetch, image inspection, supported skills and subagents.

- [x] **Step 3: Preserve narrow integrity controls**

  Keep OS-enforced write denial, no cleanup authority, Swift Policy Gate,
  revalidation, explicit user selection and typed Executor requirements.

- [x] **Step 4: Update Deep Dive status language**

  Describe Deep Dive as awaiting a capability-first implementation/evidence
  gate, not blocked by missing Broker-only enforcement.

### Task 3: Qualify historical evidence without rewriting it

**Files:**
- Modify: ADR/study/report/completed-plan indexes and primary historical files
  returned by Task 1
- Modify: relevant UI concept provenance notes returned by Task 1

**Interfaces:**
- Consumes: historical Broker-only/no-go findings
- Produces: explicit labels distinguishing historical measurement from current
  accepted product policy

- [x] **Step 1: Add supersession notices**

  Add concise 2026-08-11 notes linking to ADR 0004 wherever a standalone
  historical document could otherwise be read as current policy.

- [x] **Step 2: Correct current-tense summaries**

  Indexes and roadmaps must say the historical gate failed but was superseded
  by the user's capability-first decision.

- [x] **Step 3: Preserve historical outcomes**

  Keep old test results, measured no-go decisions and task acceptance evidence
  unchanged inside clearly historical sections.

### Task 4: Verify consistency and publish only this sync

**Files:**
- Verify: every changed Markdown file
- Preserve: unrelated dirty/untracked Phase C files and hunks

**Interfaces:**
- Consumes: synchronized documentation set
- Produces: one reviewable documentation commit on `origin/main`

- [x] **Step 1: Run residual-language audit**

  Every remaining restrictive occurrence must either be an explicitly
  historical fact or a write/Executor/local-service integrity boundary.

- [x] **Step 2: Run validation**

  Run `scripts/check-doc-links` and `git diff --check`. Inspect the final diff
  for contradictions, placeholders and accidental Phase C inclusion.

- [x] **Step 3: Commit and push**

  Stage only capability-first documentation changes, commit with
  `docs: align Codex capability-first boundary`, unset stale GitHub token
  environment variables, and push `main` to `origin`.
