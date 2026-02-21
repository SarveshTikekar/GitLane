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

    companion object {
        init {
            System.loadLibrary("git_bridge")
        }
    }
}
