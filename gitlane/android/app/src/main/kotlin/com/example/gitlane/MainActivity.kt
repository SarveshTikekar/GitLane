package com.example.gitlane

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity.kt
 * GitLane — Flutter MethodChannel Host
 *
 * Registers the "git_channel" MethodChannel and routes all 6 Git method calls
 * to GitBridge (JNI → C → libgit2).
 *
 * STRICT SCOPE: Channel routing only. No UI logic.
 */
class MainActivity : FlutterActivity() {

    private val CHANNEL = "git_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val bridge = GitBridge()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "initRepository" -> {
                        val path = call.argument<String>("path")
                        if (path == null) { result.error("INVALID_ARG", "path is required", null); return@setMethodCallHandler }
                        val code = bridge.initRepository(path)
                        if (code == 0) result.success(code) else result.error("GIT_ERROR", "initRepository failed: $code", code)
                    }

                    "commitAll" -> {
                        val path    = call.argument<String>("path")
                        val message = call.argument<String>("message")
                        if (path == null || message == null) { result.error("INVALID_ARG", "path and message are required", null); return@setMethodCallHandler }
                        val code = bridge.commitAll(path, message)
                        if (code == 0) result.success(code) else result.error("GIT_ERROR", "commitAll failed: $code", code)
                    }

                    "createBranch" -> {
                        val path       = call.argument<String>("path")
                        val branchName = call.argument<String>("branchName")
                        if (path == null || branchName == null) { result.error("INVALID_ARG", "path and branchName are required", null); return@setMethodCallHandler }
                        val code = bridge.createBranch(path, branchName)
                        if (code == 0) result.success(code) else result.error("GIT_ERROR", "createBranch failed: $code", code)
                    }

                    "checkoutBranch" -> {
                        val path       = call.argument<String>("path")
                        val branchName = call.argument<String>("branchName")
                        if (path == null || branchName == null) { result.error("INVALID_ARG", "path and branchName are required", null); return@setMethodCallHandler }
                        val code = bridge.checkoutBranch(path, branchName)
                        if (code == 0) result.success(code) else result.error("GIT_ERROR", "checkoutBranch failed: $code", code)
                    }

                    "mergeBranch" -> {
                        val path       = call.argument<String>("path")
                        val branchName = call.argument<String>("branchName")
                        if (path == null || branchName == null) { result.error("INVALID_ARG", "path and branchName are required", null); return@setMethodCallHandler }
                        val code = bridge.mergeBranch(path, branchName)
                        // 0 = merged, 1 = already up-to-date
                        if (code >= 0) result.success(code) else result.error("GIT_ERROR", "mergeBranch failed: $code", code)
                    }

                    "getCommitLog" -> {
                        val path = call.argument<String>("path")
                        if (path == null) { result.error("INVALID_ARG", "path is required", null); return@setMethodCallHandler }
                        result.success(bridge.getCommitLog(path))
                    }

                    "getRepositoryStatus" -> {
                        val path = call.argument<String>("path")
                        if (path == null) { result.error("INVALID_ARG", "path is required", null); return@setMethodCallHandler }
                        result.success(bridge.getRepositoryStatus(path))
                    }

                    "gitAddFile" -> {
                        val path     = call.argument<String>("path")
                        val filePath = call.argument<String>("filePath")
                        if (path == null || filePath == null) { result.error("INVALID_ARG", "path and filePath are required", null); return@setMethodCallHandler }
                        val code = bridge.gitAddFile(path, filePath)
                        if (code >= 0) result.success(code) else result.error("GIT_ERROR", "gitAddFile failed: $code", code)
                    }

                    "getCommitDiff" -> {
                        val path = call.argument<String>("path")
                        val hash = call.argument<String>("commitHash")
                        if (path == null || hash == null) { result.error("INVALID_ARG", "path and commitHash are required", null); return@setMethodCallHandler }
                        result.success(bridge.getCommitDiff(path, hash))
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
