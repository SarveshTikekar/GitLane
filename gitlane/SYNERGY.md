# GitLane — Team Synergy & Native Bridge Roadmap

This document provides clear hand-off points for each feature area. If you are a subagent working on a specific branch, please follow the "Next Tasks" for your area.

---

## 🛠️ Native Bridge Status (as of Feb 21, 12:20)
**Branch:** `native-core`
**Stable Foundation:** `main` (pushed)
**Active MethodChannel:** `git_channel`

| Feature | Interface (Dart/MethodChannel) | Status | Next Step for UI/Backend Agent |
|---|---|---|---|
| **Local Ops** | `initRepository`, `commitAll` | ✅ Stable | Wire "Initialize Repository" button in UI. |
| **Branching** | `createBranch`, `checkoutBranch`, `mergeBranch` | ✅ Stable | Implement Branch Switcher and Merge UI. |
| **History** | `getCommitLog` | ✅ Stable | Build the Commit History list view. |
| **Diffs** | `getCommitDiff(hash)` | ✅ Stable | Build a "Diff View" using the returned patch text. |
| **Changes**| `getRepositoryStatus`, `gitAddFile` | ✅ Stable | Build the "Staging Area" UI (checkboxes for files). |
| **Cloning** | `cloneRepository(url, path)` | 🚧 Local-Only | Handled in JNI; HTTPS support requires libgit2 rebuild. |

---

## 🏗️ Technical Onboarding for Agents

### 1. Linking the Bridge
Ensure your `MainActivity.kt` and `GitBridge.kt` are pulled from `main`. The native library `libgit_bridge.so` is automatically linked via CMake.

### 2. Calling from Flutter (Example)
```dart
const platform = MethodChannel('git_channel');
final String commitLogJson = await platform.invokeMethod('getCommitLog', {'path': repoPath});
```

### 3. Build Requirements
- Android NDK 26.x
- CMake 3.22.x
- **Note:** Native code targets `arm64-v8a` and `x86_64`.

---

## 🎯 Current Milestone: Stability Merge
- **Status:** All core local operations are merged to `main`.
- **Handoff:** UI agents should assume `main` is the stable reference. 
- **Next Task:** Revisit mbedTLS integration for `https://` clones.
