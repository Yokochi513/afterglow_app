---
name: implement-afterglow-issue
description: Implement an Afterglow (afterglow_app) GitHub Issue end to end by orchestrating the Codex CLI as the implementation worker. Use when asked to implement, fix, or complete an Issue in the afterglow_app repository. Claude fetches the Issue, branches, delegates coding to `codex exec`, runs validation, auto-iterates on failures, and opens the PR — the only human checkpoint is the final PR review.
---

# Implement an Afterglow Issue (Codex-delegated)

Afterglow is a Flutter + Firebase app (`lib/` Flutter client, `functions/` TypeScript Cloud Functions). GitHub repo: `Yokochi513/afterglow_app`. Default branch: `main`. Integration branch for Issue work: `dev`.

**Division of labor**: Claude is the orchestrator — it prepares the branch, writes the task brief, invokes Codex, validates, and ships the PR. Codex (`codex exec`) is the implementation worker — it edits code only. All intermediate steps run automatically without asking the user; the human's checkpoint is reviewing the final PR.

## Workflow

### 1. Prepare (Claude)

1. Fetch the requested Issue with `gh issue view <number>` and record its acceptance criteria, scope, exclusions, and any referenced spec sections.
2. Read the relevant parts of the canonical specifications under `docs/` — primarily `docs/要件定義.md` and `docs/詳細設計.md`. Treat them as read-only. `docs/prompts/phase1_roadmap.md` is background, not a spec.
3. Inspect `git status`. If the working tree is dirty, stop and ask the user to stash or commit unrelated changes before continuing (this is the one pre-flight condition that may interrupt).
4. Create one branch for this Issue off the latest `dev`:
   - `git switch dev && git pull --ff-only origin dev` (skip the pull if it fails), then `git switch -c <branch>`.
   - Branch name: `feat-<issue-number>-<short-english-slug>` for features, `fix-<issue-number>-<slug>` for fixes (kebab-case). Use the branch the user requests if given.
5. Run `flutter pub get` (and `npm --prefix functions ci` if the Issue touches `functions/`) **before** invoking Codex — the Codex sandbox has no network access, so dependencies must already be present.

### 2. Delegate implementation (Codex)

6. Write a self-contained task brief to a scratchpad file (e.g. `codex_task.md`). It must include:
   - The Issue number, title, full body, and acceptance criteria.
   - Repo rules Codex must follow: layer split (UI in `lib/pages`/`lib/widgets`, data access in `lib/services`, models in `lib/models`; widgets never touch Firestore/Storage directly), DI-style services (`PostService({FirebaseFirestore? firestore})` with `.instance` defaults), immutable models (`const` constructor + `factory fromSnapshot`, defaults for missing fields), collection names as `static const`, Japanese comments, `flutter_lints` clean.
   - Hard constraints: do **not** edit `docs/`, do **not** add dependencies beyond the Issue scope, do **not** run `git commit`/`git push`/`gh` (Claude owns git), do **not** touch secrets or generated outputs. Existing test mocks: `fake_cloud_firestore` / `firebase_storage_mocks` / `firebase_auth_mocks`.
   - The expectation to add/update tests under `test/` mirroring `models`/`services`/`widgets`.
7. Invoke Codex non-interactively from the repo root, feeding the brief via stdin:

   ```bash
   codex exec --sandbox workspace-write -o <scratchpad>/codex_last.txt - < <scratchpad>/codex_task.md
   ```

   Run it in the background (`run_in_background`) — implementation runs routinely exceed the foreground timeout. Wait for completion before proceeding; never fabricate its result.

   **Never pipe the Codex invocation into `tail`, `head`, `grep`, or any other filter.** Those buffer the whole stream, so the background output file stays empty until the process exits — you get zero visibility for the entire run, and a hang is indistinguishable from normal progress. Run the command bare and read the background output file directly when you need to check on it.

8. **Watch for a stall.** Codex hanging silently is a real failure mode — it has burned multi-hour runs after making only its first edit. Do not equate "still running" with "making progress":
   - The authoritative progress signal is **file mtime**, not process liveness: `ls -l` the files Codex is expected to touch. A `codex.exe` that is alive but has not written anything for a long stretch is hung, not thinking.
   - Treat **no file change for ~20 minutes** as a stall. Stop the task (`TaskStop`), then fall back to implementing directly per the Operating Rules — keep whatever partial diff Codex produced, but review it as untrusted (see below).
   - If you arm a polling monitor, keep the interval at **60s or longer** and do not run `git status` in the loop — a tight poll loop contends with Codex over the repo and can make `git` itself hang.

### 3. Validate and auto-iterate (Claude)

9. After Codex finishes, run every validation that applies to the touched files (see Validation below). Do not ask the user between rounds.
10. If validation fails or acceptance criteria are unmet, resume the same Codex session with the exact failure output and what remains:

   ```bash
   codex exec resume --last -o <scratchpad>/codex_last.txt - < <scratchpad>/codex_fix.md
   ```

   Repeat validate → resume up to **3 fix rounds**. If still failing after that, stop, keep the branch, and report the remaining failures to the user instead of opening a PR.
11. Review the final diff yourself: no `docs/` edits, no secrets or generated artifacts (`build/`, `functions/lib/`, keys, `.env`), no unrelated changes, every acceptance criterion mapped to a change or verification. Revert any forbidden files Codex touched (`git checkout -- <path>`) and re-validate. Small residual gaps (e.g. missing `dart format`) may be fixed directly by Claude rather than spending a Codex round.

### 4. Ship (Claude, automatic)

12. Commit, push, and open the PR **without asking for confirmation** — the PR is the human review gate:
    - Commit message and PR title/body in **Japanese**, Conventional Commits subject (`feat: ...`, `fix: ...`).
    - PR targets `dev`, body lists `Closes #<number>`, a checklist of satisfied acceptance criteria, the exact validation commands with results, and a note that implementation was performed by Codex CLI orchestrated by Claude.
    - Follow the `1 Issue = 1 branch = 1 PR` rule.
13. Report to the user: PR URL, commit hash, validation results, number of Codex fix rounds used, whether Codex stalled and triggered the direct-implementation fallback, and anything intentionally left out.

## Operating Rules

- Do not edit the canonical documents under `docs/`. If a spec change seems necessary, stop and report it on the Issue instead of implementing it.
- Do not add dependencies beyond the Issue scope. Existing stack: `flutter_map` + `latlong2` (map), Firebase (`firebase_auth`, `cloud_firestore`, `firebase_storage`), test mocks listed above.
- Stop and report genuine product ambiguity instead of letting Codex invent behavior; everything else proceeds automatically.
- Never commit secrets or generated outputs: service-account keys, `.env`, APNs keys, `*.keystore`, new `google-services.json` / `GoogleService-Info.plist`, `build/`, `functions/lib/`, or unrelated user changes. `lib/firebase_options.dart` and `.firebaserc` are already tracked — leave them as-is unless the Issue requires a change.
- If the `codex` CLI is unavailable, errors out, or **stalls** (see step 8), fall back to implementing directly (same rules and validation), and tell the user the fallback was used.
- A partial diff from a stalled or failed Codex run is **untrusted work in progress** — it may not even compile. Review it line by line and run the full validation before building on it, rather than assuming the finished parts are sound.

## Validation

Flutter (run whenever `lib/` or Dart/Flutter code changes):

- `flutter analyze` (keep warnings at zero)
- `dart format .` then `dart format --output=none --set-exit-if-changed .`
- `flutter test` (tests run offline via the Firebase mocks)

Cloud Functions (run only when `functions/` changes):

- `npm --prefix functions run build` (TypeScript compile via `tsc`; no lint/test script defined)

If Flutter stalls before producing output, inspect the Flutter/Dart processes and the SDK cache lock — the SDK may need permission to write its cache.
