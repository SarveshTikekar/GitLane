# Push Flow (Optimized + Simplified)

## Objective
Ensure a push failure (internet loss, timeout, app kill) never loses local commits, and outcomes are deterministic with ACID-style guarantees.

## Existing Runtime Path
1. UI: `lib/ui/screens/repository/repository_root_screen.dart` (`_pushRepo`)
2. Dart: `lib/services/git_service.dart` (`pushRepository`)
3. Kotlin channel handler: `android/app/src/main/kotlin/com/example/gitlane/MainActivity.kt`
4. JNI bridge: `android/app/src/main/kotlin/com/example/gitlane/GitBridge.kt`
5. Native libgit2 push: `android/app/src/main/cpp/git_bridge.c` (`Java_com_example_gitlane_GitBridge_pushRepository`)

## Minimal Reliable Transaction Model
Use one persistent push journal row per repo+branch.

### Fields
- `txId`
- `repoPath`
- `branch`
- `headOidAtStart`
- `state` (`PENDING`, `DONE`, `FAILED`)
- `attempt`
- `updatedAt`

### State Machine
- `PENDING` -> `DONE`
- `PENDING` -> `FAILED`

That is enough. No extra intermediate states required.

## Simplified Push Algorithm
1. Read current local HEAD OID.
2. Persist journal row as `PENDING`.
3. Acquire repo+branch mutex (prevent concurrent push/pull/checkout on same target).
4. Execute native push.
5. If push success: mark `DONE`.
6. If push failure/timeout:
   - Fetch remote.
   - Check whether remote branch contains `headOidAtStart`.
   - If yes: mark `DONE` (push actually succeeded; client lost response).
   - If no: mark `FAILED` (safe retry).
7. Release mutex.
8. On app startup, reconcile every `PENDING` row with step 6 and finalize.

## ACID Mapping (Practical)
- **Atomicity**: Every push tx ends only in `DONE` or `FAILED`.
- **Consistency**: Valid transitions only from `PENDING` to terminal state.
- **Isolation**: Mutex per repo+branch; one writer at a time.
- **Durability**: Journal persisted before network call and after final state.

## Rollback Policy
- Never auto-reset local commits on push failure.
- Local commits remain on branch + reflog.
- If remote undo is needed, use `revert` (compensating commit), not force destructive rollback.

## Optimizations
- Resolve current branch dynamically (do not hardcode `main`).
- Persist only minimal journal fields above.
- Retry with exponential backoff only for `FAILED` tx.
- Keep reconciliation logic identical for runtime failures and restart recovery.

## Expanded Test Matrix

### Test Case 1: Network down before remote update
**Given** local commit `C1` ahead of remote.

**When** push starts and network is unavailable.

**Then**
- local still has `C1`
- remote does not have `C1`
- tx transitions `PENDING -> FAILED`
- UI shows failed push and retry option.

### Test Case 2: Remote updated but client timed out
**Given** local commit `C2` ahead of remote.

**When** remote accepts push but client loses connection before success response.

**Then**
- reconciliation finds remote contains `C2`
- tx transitions `PENDING -> DONE`
- no duplicate commits
- UI eventually shows synced state.

### Test Case 3: App/process killed during push
**Given** tx is in `PENDING` and push call was in progress.

**When** app is force-killed and restarted.

**Then**
- startup recovery scans `PENDING` rows
- reconciliation finalizes tx to `DONE` (if remote has head OID) or `FAILED`
- no local commit loss.

### Test Case 4: User taps Push twice quickly
**Given** same repo+branch.

**When** second push request arrives while first is active.

**Then**
- mutex blocks second execution
- app returns `PUSH_ALREADY_RUNNING` (or queues it)
- only one tx row is active
- no race-induced inconsistent state.

### Test Case 5: Auth failure (bad/expired token)
**Given** invalid token.

**When** push is attempted.

**Then**
- push returns auth error
- tx transitions `PENDING -> FAILED`
- commit remains local
- UI prompts credential refresh (not blind retry loop).

### Test Case 6: Branch changed mid-flow
**Given** tx captured `branch=A`.

**When** user/app switches to `branch=B` before retry/recovery.

**Then**
- recovery reconciles using stored `branch=A` only
- no cross-branch corruption
- tx for `A` finishes independently.

## Architecture Simplified Further (Based on Test Matrix)

The matrix shows we only need 3 persistent concepts:
1. `PushTx` row (journal)
2. `RepoBranchLock` (in-memory mutex)
3. `Reconcile()` function (shared by failure path + startup recovery)

Everything else can stay stateless.

### Final Minimal Components
- `startPush(repo, branch)`:
  - create `PushTx(PENDING)`
  - run native push under lock
  - finalize via `finishOrReconcile(tx)`
- `finishOrReconcile(tx)`:
  - if push success -> `DONE`
  - else -> fetch+ancestry check -> `DONE` or `FAILED`
- `recoverPendingTxOnStartup()`:
  - iterate `PENDING`
  - call `finishOrReconcile(tx)`

### Why this is enough
- Handles network failures, crashes, duplicate taps, and ambiguous outcomes.
- Keeps ACID guarantees without multi-state orchestration complexity.
- Avoids destructive rollback and preserves local durability.
