package com.example.gitlane

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class MainActivity : FlutterActivity() {

    private val CHANNEL = "git_channel"
    private val scope = CoroutineScope(Dispatchers.Main + Job())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val bridge = GitBridge()
        val sshManager = SSHManager(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                scope.launch {
                    val response = withContext(Dispatchers.IO) {
                        try {
                            when (call.method) {
                                "initRepository" -> {
                                    val path = call.argument<String>("path")!!
                                    bridge.initRepository(path)
                                }
                                "commitAll" -> {
                                    val path = call.argument<String>("path")!!
                                    val message = call.argument<String>("message")!!
                                    bridge.commitAll(path, message)
                                }
                                "createBranch" -> {
                                    val path = call.argument<String>("path")!!
                                    val branchName = call.argument<String>("branchName")!!
                                    bridge.createBranch(path, branchName)
                                }
                                "checkoutBranch" -> {
                                    val path = call.argument<String>("path")!!
                                    val branchName = call.argument<String>("branchName")!!
                                    bridge.checkoutBranch(path, branchName)
                                }
                                "mergeBranch" -> {
                                    val path = call.argument<String>("path")!!
                                    val branchName = call.argument<String>("branchName")!!
                                    bridge.mergeBranch(path, branchName)
                                }
                                "getCommitLog" -> {
                                    val path = call.argument<String>("path")!!
                                    bridge.getCommitLog(path)
                                }
                                "getRepositoryStatus" -> {
                                    val path = call.argument<String>("path")!!
                                    bridge.getRepositoryStatus(path)
                                }
                                "gitAddFile" -> {
                                    val path = call.argument<String>("path")!!
                                    val filePath = call.argument<String>("filePath")!!
                                    bridge.gitAddFile(path, filePath)
                                }
                                "getCommitDiff" -> {
                                    val path = call.argument<String>("path")!!
                                    val hash = call.argument<String>("commitHash")!!
                                    bridge.getCommitDiff(path, hash)
                                }
                                "cloneRepository" -> {
                                    val url = call.argument<String>("url")!!
                                    val path = call.argument<String>("path")!!
                                    bridge.cloneRepository(url, path)
                                }
                                "getBranches" -> {
                                    val path = call.argument<String>("path")!!
                                    bridge.getBranches(path)
                                }
                                "getCurrentBranch" -> {
                                    val path = call.argument<String>("path")!!
                                    bridge.getCurrentBranch(path)
                                }
                                "deleteBranch" -> {
                                    val path = call.argument<String>("path")!!
                                    val branchName = call.argument<String>("branchName")!!
                                    bridge.deleteBranch(path, branchName)
                                }
                                "getConflicts" -> {
                                    val path = call.argument<String>("path")!!
                                    bridge.getConflicts(path)
                                }
                                "stashSave" -> {
                                    val path = call.argument<String>("path")!!
                                    val message = call.argument<String>("message")!!
                                    bridge.stashSave(path, message)
                                }
                                "stashPop" -> {
                                    val path = call.argument<String>("path")!!
                                    val index = call.argument<Int>("index")!!
                                    bridge.stashPop(path, index)
                                }
                                "getStashes" -> {
                                    val path = call.argument<String>("path")!!
                                    bridge.getStashes(path)
                                }
                                "pushRepository" -> {
                                    val path = call.argument<String>("path")!!
                                    val token = call.argument<String>("token")!!
                                    bridge.pushRepository(path, token)
                                }
                                "pullRepository" -> {
                                    val path = call.argument<String>("path")!!
                                    val token = call.argument<String>("token")!!
                                    bridge.pullRepository(path, token)
                                }
                                "getRemoteUrl" -> {
                                    val path = call.argument<String>("path")!!
                                    bridge.getRemoteUrl(path)
                                }
                                "getReflog" -> {
                                    val path = call.argument<String>("path")!!
                                    bridge.getReflog(path)
                                }
                                "getSyncStatus" -> {
                                    val path = call.argument<String>("path")!!
                                    bridge.getSyncStatus(path)
                                }
                                "getConflictChunks" -> {
                                    val path = call.argument<String>("path")!!
                                    val filePath = call.argument<String>("filePath")!!
                                    bridge.getConflictChunks(path, filePath)
                                }
                                "resolveConflict" -> {
                                    val path = call.argument<String>("path")!!
                                    val filePath = call.argument<String>("filePath")!!
                                    val content = call.argument<String>("content")!!
                                    bridge.resolveConflict(path, filePath, content)
                                }
                                "runGitCommand" -> {
                                    val path = call.argument<String>("path")!!
                                    val command = call.argument<String>("command")!!
                                    bridge.runGitCommand(path, command)
                                }
                                "getTags" -> {
                                    val path = call.argument<String>("path")!!
                                    bridge.getTags(path)
                                }
                                "createTag" -> {
                                    val path = call.argument<String>("path")!!
                                    val tagName = call.argument<String>("tagName")!!
                                    val targetHash = call.argument<String>("targetHash")!!
                                    bridge.createTag(path, tagName, targetHash)
                                }
                                "deleteTag" -> {
                                    val path = call.argument<String>("path")!!
                                    val tagName = call.argument<String>("tagName")!!
                                    bridge.deleteTag(path, tagName)
                                }
                                "getRemotes" -> {
                                    val path = call.argument<String>("path")!!
                                    bridge.getRemotes(path)
                                }
                                "addRemote" -> {
                                    val path = call.argument<String>("path")!!
                                    val name = call.argument<String>("name")!!
                                    val url = call.argument<String>("url")!!
                                    bridge.addRemote(path, name, url)
                                }
                                "deleteRemote" -> {
                                    val path = call.argument<String>("path")!!
                                    val name = call.argument<String>("name")!!
                                    bridge.deleteRemote(path, name)
                                }
                                "setRemoteUrl" -> {
                                    val path = call.argument<String>("path")!!
                                    val name = call.argument<String>("name")!!
                                    val url = call.argument<String>("url")!!
                                    bridge.setRemoteUrl(path, name, url)
                                }
                                "getBlame" -> {
                                    val path = call.argument<String>("path")!!
                                    val filePath = call.argument<String>("filePath")!!
                                    bridge.getBlame(path, filePath)
                                }
                                "getDiffHunks" -> {
                                    val path = call.argument<String>("path")!!
                                    val filePath = call.argument<String>("filePath")!!
                                    bridge.getDiffHunks(path, filePath)
                                }
                                "applyPatchToIndex" -> {
                                    val path = call.argument<String>("path")!!
                                    val patch = call.argument<String>("patch")!!
                                    bridge.applyPatchToIndex(path, patch)
                                }
                                "rebaseInit" -> {
                                    val path = call.argument<String>("path")!!
                                    val upstream = call.argument<String>("upstream")!!
                                    val onto = call.argument<String>("onto")!!
                                    bridge.rebaseInit(path, upstream, onto)
                                }
                                "rebaseNext" -> {
                                    val path = call.argument<String>("path")!!
                                    bridge.rebaseNext(path)
                                }
                                "rebaseCommit" -> {
                                    val path = call.argument<String>("path")!!
                                    val authorName = call.argument<String>("authorName")!!
                                    val authorEmail = call.argument<String>("authorEmail")!!
                                    val message = call.argument<String>("message")!!
                                    bridge.rebaseCommit(path, authorName, authorEmail, message)
                                }
                                "rebaseAbort" -> {
                                    val path = call.argument<String>("path")!!
                                    bridge.rebaseAbort(path)
                                }
                                "rebaseFinish" -> {
                                    val path = call.argument<String>("path")!!
                                    bridge.rebaseFinish(path)
                                }
                                "generateSSHKey" -> {
                                    val label = call.argument<String>("label")!!
                                    val type = call.argument<String>("type")!!
                                    val bits = call.argument<Int>("bits") ?: 2048
                                    sshManager.generateKeyPair(label, type, bits)
                                }
                                "listSSHKeys" -> {
                                    sshManager.listKeys()
                                }
                                "deleteSSHKey" -> {
                                    val label = call.argument<String>("label")!!
                                    sshManager.deleteKey(label)
                                }
                                "getSSHPublicKey" -> {
                                    val label = call.argument<String>("label")!!
                                    sshManager.getPublicKey(label)
                                }
                                else -> "NOT_IMPLEMENTED"
                            }
                        } catch (e: Exception) {
                            e
                        }
                    }

                    // On Main Thread
                    when (response) {
                        "NOT_IMPLEMENTED" -> result.notImplemented()
                        is Exception -> result.error("KOTLIN_ERROR", response.message, null)
                        is Int -> {
                            if (response >= 0 || (call.method == "mergeBranch" && response == -100)) {
                                result.success(response)
                            } else {
                                result.error("GIT_ERROR", "${call.method} failed: $response", response)
                            }
                        }
                        is String -> result.success(response)
                        else -> result.success(response)
                    }
                }
            }
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
    }
}
