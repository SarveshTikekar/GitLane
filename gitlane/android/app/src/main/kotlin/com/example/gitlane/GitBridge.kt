package com.example.gitlane

/**
 * GitBridge.kt
 * GitLane — Kotlin JNI Bridge
 *
 * Declares the 6 native Git operations implemented in git_bridge.c.
 * Loads the shared library "git_bridge" (compiled by CMake → libgit_bridge.so).
 *
 * STRICT SCOPE: No UI logic. No business logic. JNI declarations only.
 */
class GitBridge {

    /** Creates a new Git repository at [path]. Returns 0 on success, negative on failure. */
    external fun initRepository(path: String): Int

    /** Stages all changes and commits with [message]. Returns 0 on success, negative on failure. */
    external fun commitAll(path: String, message: String): Int

    /** Creates a new branch named [branchName] from current HEAD. Returns 0 on success. */
    external fun createBranch(path: String, branchName: String): Int

    /** Checks out the branch named [branchName]. Returns 0 on success. */
    external fun checkoutBranch(path: String, branchName: String): Int

    /**
     * Merges [branchName] into current HEAD branch.
     * Returns 0 on success, 1 if already up-to-date, negative on failure.
     */
    external fun mergeBranch(path: String, branchName: String): Int

    /**
     * Returns a JSON string: array of commits on HEAD branch.
     * Each entry: `{"hash":"...","message":"...","author":"...","time":0}`
     * Returns `{"error":"..."}` on failure.
     */
    external fun getCommitLog(path: String): String
    external fun getRepositoryStatus(path: String): String
    external fun gitAddFile(path: String, filePath: String): Int
    external fun getCommitDiff(path: String, commitHash: String): String
    external fun cloneRepository(url: String, path: String): Int
    external fun getCurrentBranch(path: String): String
    external fun getBranches(path: String): String
    external fun getConflicts(path: String): String
    external fun deleteBranch(path: String, branchName: String): Int
    external fun stashSave(path: String, message: String): Int
    external fun stashPop(path: String, index: Int): Int
    external fun stashApply(path: String, index: Int): Int
    external fun stashDrop(path: String, index: Int): Int
    external fun getStashes(path: String): String
    external fun pushRepository(path: String, token: String): Int
    external fun pullRepository(path: String, token: String): Int
    external fun getRemoteUrl(path: String): String
    external fun getReflog(path: String): String
    external fun getSyncStatus(path: String): String
    external fun getConflictChunks(path: String, filePath: String): String
    external fun resolveConflict(path: String, filePath: String, content: String): Int
    external fun runGitCommand(path: String, command: String): String
    external fun getTags(path: String): String
    external fun createTag(path: String, tagName: String, targetHash: String): Int
    external fun deleteTag(path: String, tagName: String): Int
    external fun getRemotes(path: String): String
    external fun addRemote(path: String, name: String, url: String): Int
    external fun deleteRemote(path: String, name: String): Int
    external fun setRemoteUrl(path: String, name: String, url: String): Int
    external fun getBlame(path: String, filePath: String): String
    external fun getDiffHunks(path: String, filePath: String): String
    external fun applyPatchToIndex(path: String, patch: String): Int
    external fun rebaseInit(path: String, upstream: String, onto: String): Int
    external fun rebaseNext(path: String): String
    external fun rebaseCommit(path: String, authorName: String, authorEmail: String, message: String): Int
    external fun rebaseAbort(path: String): Int
    external fun rebaseFinish(path: String): Int
    external fun commitSigned(path: String, message: String, signature: String): Int
    external fun getCommitContent(path: String, message: String): String

    companion object {
        init {
            System.loadLibrary("git_bridge")
        }
    }
}
