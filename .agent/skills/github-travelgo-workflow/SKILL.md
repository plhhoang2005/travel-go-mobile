---
name: github-travelgo-workflow
description: Deliver approved TravelGO changes through safe feature branches, selective staging, conventional commits, GitHub pull requests, and bounded CI remediation. Use when an implementation is ready for Git/GitHub handoff. Do not use for Issues, releases, merging, repository settings, secrets, or branch-protection changes.
---

# GitHub TravelGO Workflow

## Purpose

Move an already approved and implemented TravelGO task from the local quality gate to a reviewable GitHub pull request without absorbing unrelated work or bypassing the Human Merge Gate.

This skill does not authorize implementation work. Follow `AGENTS.md`, `.agent/rules.md`, and `.agent/workflow.md` first; if they conflict with this skill, the stricter safety or approval rule wins.

## Authority

After the task's Stage-Gate approval, this workflow may:

- create or reuse a task-specific `feat/*` or `fix/*` branch;
- selectively stage only files in the approved task scope;
- create a conventional commit after the required quality gate passes;
- push the feature branch and set its upstream;
- create a pull request containing the verified handover evidence;
- inspect CI and perform at most three in-scope remediation cycles.

It must never:

- commit or push directly to `main` or `master`;
- force-push, rewrite published history, merge, close, or approve a pull request;
- change repository settings, secrets, environments, permissions, or branch protection;
- create Issues, tags, releases, or release notes;
- install or authenticate GitHub tooling on the user's behalf;
- weaken tests or broaden the task merely to make CI pass.

## 1. Preflight

Before any Git mutation:

1. Inspect the current branch, default remote branch, worktree status, and scoped diff.
2. List the exact files owned by the task and keep the total within the project limit of five.
3. Treat pre-existing modified or untracked files as user-owned. Do not stage, edit, stash, move, delete, or restore them.
4. Reuse the checkout only when its branch and existing changes belong to the same task. Otherwise use a clean isolated worktree based on the intended base revision.
5. Stop if the task boundary cannot be separated safely.

Never use `git add .`, `git add -A`, `git commit -a`, `git reset --hard`, or `git checkout --` in this workflow.

## 2. Branch

- Use `feat/<short-slug>` for a feature and `fix/<short-slug>` for a defect.
- Determine the repository's actual default branch rather than assuming it.
- Never create a task commit while checked out on `main` or `master`.
- Reuse an existing feature branch only when it is demonstrably for the same task.
- Do not rebase, amend, squash, or otherwise rewrite history unless the Tech Lead explicitly requests that operation.

## 3. Quality Gate

Before staging or committing, run and observe:

```text
flutter analyze  -> No issues found!
flutter test     -> All tests passed!
```

Run any additional task-specific verification from the approved plan. For a new or changed skill, also run the `skill-creator` validator against the skill directory.

A timeout, missing output, unavailable tool, absent test, or skipped check is not a pass. Report it as unverified and do not commit or push. Respect the project command timeout and bounded RCA policy.

## 4. Selective Staging and Commit

1. Show the proposed staged file list.
2. Stage each approved path explicitly.
3. Inspect the staged diff and staged file list.
4. Abort if either contains a file outside the approved task scope, a generated artifact, or a secret.
5. Create one focused conventional commit when practical.

Use `<type>(<scope>): <description>` with one of `feat`, `fix`, `docs`, `test`, `refactor`, or `chore`. The description states the delivered outcome, not a generic action such as "update files".

## 5. Push and Pull Request

After the commit and quality gate succeed:

1. Push only the feature branch and set its upstream when needed. Never use force flags.
2. If authentication, authorization, or network access fails, report the failure and stop; do not request, print, or persist credentials.
3. Create a pull request against the verified default branch.
4. Attach the created pull request to the current Codex task when that capability is available.

The pull request body must include:

- outcome and scope;
- changed files and their roles;
- architecture or safety rationale;
- observed local verification results;
- known risks, limitations, or unverified checks;
- confirmation that no unrelated file, generated artifact, or credential was included;
- an explicit note that only the Human Tech Lead may merge.

Do not represent an absent CI configuration or a pull request with no checks as green CI. Report it as `CI NOT CONFIGURED` or `CI NOT OBSERVED`.

## 6. CI Triage and Bounded Remediation

Classify a failed check before editing:

- **Task-caused:** reproducible failure introduced by the pull request. It may be fixed within the approved scope.
- **Pre-existing or out-of-scope:** failure unrelated to the pull request. Report evidence and stop.
- **Infrastructure or transient:** runner, service, network, quota, or permission failure. Retry only when the check itself provides a safe retry mechanism; do not change application code speculatively.

For a task-caused failure, perform at most three cycles:

```text
inspect failed check and logs
  -> identify root cause
  -> reproduce locally when possible
  -> make the smallest in-scope correction
  -> rerun local quality gates
  -> selectively stage and commit
  -> push the same feature branch
  -> observe CI again
```

Each cycle must preserve the five-file task limit, test integrity, architecture laws, and permission boundaries. Dependency or native-platform changes require a new approval gate.

After three unsuccessful cycles, activate the circuit breaker: stop changing code, preserve the branch and logs, and report the blocker to the Tech Lead.

## 7. Completion

Completion means the pull request exists and its true verification state is reported. It does not mean the pull request was merged.

Provide the standard five-part TravelGO handover:

1. **Changed**
2. **Why**
3. **Testing**
4. **Problems**
5. **Lesson Candidate**

Also provide the post-code cross-agent review prompt required by `.agent/skills/cross-agent-review/SKILL.md`.
