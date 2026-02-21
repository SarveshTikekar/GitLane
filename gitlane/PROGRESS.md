# Project Progress: `native-core` Branch

This file tracks the status of the native Git engine. Teammates should check this to see which JNI methods are ready for use.

---

## ✅ WHAT IS DONE (Pushed to GitHub)

### 🚀 Core Flutter/Android Setup
- [x] Flutter project scaffolded (`gitlane`)
- [x] NDK integration verified (CMake 3.22.1)
- [x] ABI Support: `arm64-v8a`, `x86_64` (Restricted for performance/size)
- [x] libgit2 v1.7.2 custom build pipeline (Patched for C99 compatibility)
- [x] Automatic build script: `build_libgit2_android.ps1`

### 🏗️ Git Engine Features (Stable)
| Method | Description | Return |
|---|---|---|
| `initRepository` | Creates a new `.git` repo | Int (0=Success) |
| `cloneRepository`| Clones from GitHub/GitLab (HTTPS) | Int (0=Success) |
| `commitAll` | Stages all files and creates a commit | Int (0=Success) |
| `createBranch`| Creates a new branch from current HEAD | Int (0=Success) |
| `deleteBranch`| Deletes a local branch | Int (0=Success) |
| `checkoutBranch`| Switches to a different branch | Int (0=Success) |
| `mergeBranch` | Merges branch into current (FF or Commit) | Int (0=Success) |
| `getCommitLog` | Returns the commit history | JSON String |
| `getRepositoryStatus` | Summary of modified/staged files | JSON String |
| `getConflicts` | List files with merge conflicts | JSON String |
| `gitAddFile` | Stages a specific file (git add) | Int (0=Success) |
| `getCommitDiff` | Returns patch text for a commit hash | String (Patch) |

---

## 🛠️ WHAT NEEDS TO BE DONE (Current Focus)

### 📂 Phase 5: Enhanced Local Operations
- [ ] **Stash Management**: Native support for `git stash` operations (save, pop, list).
- [ ] **Partial Staging**: Support staging Hunk/Line level changes via native API.

### 🌐 Phase 6: Remote Operations
- [x] **HTTPS Integration**: Re-enabled HTTPS backend (MbedTLS) supporting remotes.
- [x] **`cloneRepository(url, path)`**: Support cloning from GitHub/GitLab.
- [ ] **`push`/`pull`**: Support syncing with remotes (requires auth helper).
- [ ] **SSH Support**: Support cloning/pushing via SSH keys.

### 🔒 Phase 7: App Security & Performance
- [ ] **Background Threading**: Move JNI calls to background threads to keep Flutter UI buttery smooth.
- [ ] **Memory Monitoring**: Stress test native memory allocation during large log parsing.

---

## 💡 Notes for Teammates
- **Using the Bridge**: Call these via `MethodChannel('git_channel')`. 
- **Extending the Bridge**: If you need a new Git feature, add it to `git_bridge.c` first.
