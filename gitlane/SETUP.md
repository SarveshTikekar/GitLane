# GitLane — `native-core` Branch Setup Guide

> **For teammates and AI agents (Antigravity) onboarding this branch.**
> This branch owns the **native Git engine**: libgit2 → JNI (C) → Kotlin Bridge → Flutter MethodChannel.

---

## Architecture

```
Flutter Dart (lib/)
    ↓  MethodChannel("git_channel")
MainActivity.kt
    ↓  GitBridge()
GitBridge.kt         ← JNI declarations
    ↓  System.loadLibrary("git_bridge")
git_bridge.c         ← libgit2 C API calls
    ↓  links against
libgit2.a            ← prebuilt static lib (YOU must build this — see below)
```

---

## Prerequisites

| Tool | Version | Where |
|---|---|---|
| Flutter | 3.x | `flutter --version` |
| Android NDK | `26.3.11579264` | Android Studio → SDK Manager → SDK Tools |
| Android SDK CMake | `3.22.1` | Android Studio → SDK Manager → SDK Tools |
| Git | any | `git --version` |

---

## Step 1 — Build `libgit2` for Android (ONE TIME)

The prebuilt `.a` static libraries are **not tracked in git** (they're ~15MB each).
You must build them once on your machine before the Flutter project will compile.

```powershell
# From the gitlane/ project root:
powershell -ExecutionPolicy Bypass -File .\build_libgit2_android.ps1
```

This script will:
1. Clone libgit2 v1.7.2 to `%TEMP%\libgit2_src`
2. Copy headers to `android/app/src/main/cpp/include/`
3. Cross-compile for `arm64-v8a` and `x86_64` using NDK 26.3 + CMake 3.22
4. Place `libgit2.a` in `android/app/src/main/cpp/jniLibs/<ABI>/`

Expected output: `ALL DONE - libgit2 built for all ABIs`

> **If the script fails:** The most common issue is NDK/CMake path mismatch.
> Check `$SDK_ROOT` at the top of `build_libgit2_android.ps1` matches your
> `%LOCALAPPDATA%\Android\Sdk` path.

---

## Step 2 — Verify the Build

```powershell
flutter build apk --debug
```

A successful build proves:
- `git_bridge.c` compiles against libgit2 headers ✅
- `libgit_bridge.so` is linked against `libgit2.a` ✅
- JNI symbols are correctly named ✅

---

## Key Files (Touch Only These)

| File | Purpose |
|---|---|
| `android/app/src/main/cpp/git_bridge.c` | **JNI C functions** — the core Git engine |
| `android/app/src/main/cpp/CMakeLists.txt` | CMake build config |
| `android/app/src/main/kotlin/.../GitBridge.kt` | Kotlin JNI declarations |
| `android/app/src/main/kotlin/.../MainActivity.kt` | Flutter MethodChannel router |
| `build_libgit2_android.ps1` | One-time libgit2 cross-compile script |

---

## Implemented Git Operations

All 6 functions in `git_bridge.c` are complete:

| Flutter Channel Method | C Function | Returns |
|---|---|---|
| `initRepository` | `git_repository_init()` | `Int` (0 = OK) |
| `commitAll` | stage all + `git_commit_create_v()` | `Int` |
| `createBranch` | `git_branch_create()` | `Int` |
| `checkoutBranch` | `git_checkout_tree()` + set HEAD | `Int` |
| `mergeBranch` | fast-forward or merge commit | `Int` (0=merged, 1=up-to-date) |
| `getCommitLog` | `git_revwalk` | `String` (JSON array) |
| `getRepositoryStatus`| `git_status_list` | `String` (JSON array) |
| `gitAddFile` | `git_index_add_bypath` | `Int` |
| `getCommitDiff` | `git_diff_tree_to_tree` | `String` (Patch text) |
| `cloneRepository` | `git_clone` | `Int` (Local path only for now) |

### Flutter usage example (from `lib/`):
```dart
static const platform = MethodChannel('git_channel');

// Init a repo
final result = await platform.invokeMethod('initRepository', {'path': '/data/user/0/com.example.gitlane/files/myrepo'});

// Get commit log (returns JSON string)
final log = await platform.invokeMethod('getCommitLog', {'path': repoPath});
```

---

## How to Add a New Git Operation

1. Add the C function to `git_bridge.c` (follow existing pattern — init/shutdown/cleanup)
2. Add `external fun` declaration to `GitBridge.kt`
3. Add handler to `when (call.method)` block in `MainActivity.kt`
4. Notify the Flutter UI person of the new method name + args

---

## Branch Strategy

```
main
 ├─ native-core   ← YOU ARE HERE (libgit2 + JNI + Bridge)
 ├─ kotlin-bridge  (depends on this branch's GitBridge.kt)
 ├─ flutter-ui     (calls git_channel methods)
 └─ graph-ui       (visualizes getCommitLog JSON)
```

Once `native-core` is merged → all other branches switch from mock data to real git calls.

---

## Antigravity Agent Context Prompt

If you are an AI agent continuing work on this branch:

```
CONTEXT: GitLane Flutter Android app — native-core branch.
SCOPE: ONLY android/app/src/main/cpp/ and Kotlin bridge layer.
DO NOT: touch /lib/, change Gradle versions, modify pubspec.yaml.
libgit2 v1.7.2 static libs are at:
  android/app/src/main/cpp/jniLibs/arm64-v8a/libgit2.a
  android/app/src/main/cpp/jniLibs/x86_64/libgit2.a
Headers at: android/app/src/main/cpp/include/git2.h
9 operations implemented: initRepository, commitAll, createBranch, checkoutBranch, mergeBranch, getCommitLog, getRepositoryStatus, gitAddFile, getCommitDiff.
cloneRepository is implemented in JNI but requires HTTPS transport fix for remote URLs.
Build with: powershell -ExecutionPolicy Bypass -File build_libgit2_android.ps1
```
