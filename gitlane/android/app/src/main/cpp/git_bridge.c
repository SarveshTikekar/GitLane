/**
 * git_bridge.c
 * GitLane — Native Git Core Layer
 *
 * Exposes 6 Git operations to Flutter via JNI + libgit2.
 * Each function:
 *   - Calls git_libgit2_init() / git_libgit2_shutdown()
 *   - Performs full memory cleanup (git_*_free)
 *   - Returns jint (0 = success, negative = libgit2 error code)
 *     or jstring (JSON payload)
 *
 * STRICT SCOPE: No UI logic. No business logic. Native Git only.
 */

#include <jni.h>
#include <android/log.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <git2.h>

#define LOG_TAG "GitBridge"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)

/* ─── Utility: Convert libgit2 error to readable string ─────────────────── */
static const char *git_error_str(int error) {
    const git_error *e = git_error_last();
    if (e && e->message) return e->message;
    return "Unknown libgit2 error";
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 1. initRepository(path: String): Int
 *    Creates a new bare Git repository at the given path.
 *    Returns 0 on success, negative error code on failure.
 * ═══════════════════════════════════════════════════════════════════════════ */
JNIEXPORT jint JNICALL
Java_com_example_gitlane_GitBridge_initRepository(
        JNIEnv *env, jobject obj, jstring jpath) {

    git_libgit2_init();

    const char *path = (*env)->GetStringUTFChars(env, jpath, NULL);
    git_repository *repo = NULL;

    int result = git_repository_init(&repo, path, 0);
    if (result < 0) {
        LOGE("initRepository failed: %s", git_error_str(result));
    } else {
        LOGI("initRepository OK at: %s", path);
    }

    git_repository_free(repo);
    (*env)->ReleaseStringUTFChars(env, jpath, path);
    git_libgit2_shutdown();

    return (jint) result;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 2. commitAll(path: String, message: String): Int
 *    Stages all changes (index add -A) and creates a commit with the
 *    provided message using a default "GitLane" committer signature.
 *    Returns 0 on success, negative error code on failure.
 * ═══════════════════════════════════════════════════════════════════════════ */
JNIEXPORT jint JNICALL
Java_com_example_gitlane_GitBridge_commitAll(
        JNIEnv *env, jobject obj, jstring jpath, jstring jmessage) {

    git_libgit2_init();

    const char *path    = (*env)->GetStringUTFChars(env, jpath,    NULL);
    const char *message = (*env)->GetStringUTFChars(env, jmessage, NULL);

    git_repository *repo  = NULL;
    git_index      *index = NULL;
    git_oid         tree_oid, commit_oid, parent_oid;
    git_tree       *tree   = NULL;
    git_commit     *parent = NULL;
    git_signature  *sig    = NULL;
    int result = 0;

    /* Open existing repo */
    result = git_repository_open(&repo, path);
    if (result < 0) { LOGE("commitAll: open failed: %s", git_error_str(result)); goto cleanup_commit; }

    /* Stage all files — equivalent to `git add -A` */
    result = git_repository_index(&index, repo);
    if (result < 0) { LOGE("commitAll: index failed: %s", git_error_str(result)); goto cleanup_commit; }

    result = git_index_add_all(index, NULL, 0, NULL, NULL);
    if (result < 0) { LOGE("commitAll: add_all failed: %s", git_error_str(result)); goto cleanup_commit; }

    result = git_index_write(index);
    if (result < 0) { LOGE("commitAll: index write failed: %s", git_error_str(result)); goto cleanup_commit; }

    /* Build tree from index */
    result = git_index_write_tree(&tree_oid, index);
    if (result < 0) { LOGE("commitAll: write_tree failed: %s", git_error_str(result)); goto cleanup_commit; }

    result = git_tree_lookup(&tree, repo, &tree_oid);
    if (result < 0) { LOGE("commitAll: tree_lookup failed: %s", git_error_str(result)); goto cleanup_commit; }

    /* Create committer/author signature */
    result = git_signature_now(&sig, "GitLane", "gitlane@local");
    if (result < 0) { LOGE("commitAll: signature failed: %s", git_error_str(result)); goto cleanup_commit; }

    /* Try to get HEAD parent commit — may not exist for initial commit */
    int has_parent = (git_reference_name_to_id(&parent_oid, repo, "HEAD") == 0)
                  && (git_commit_lookup(&parent, repo, &parent_oid) == 0);

    if (has_parent) {
        result = git_commit_create_v(
                &commit_oid, repo, "HEAD", sig, sig,
                NULL, message, tree, 1, parent);
    } else {
        /* Initial commit — no parent */
        result = git_commit_create_v(
                &commit_oid, repo, "HEAD", sig, sig,
                NULL, message, tree, 0);
    }

    if (result < 0) {
        LOGE("commitAll: commit create failed: %s", git_error_str(result));
    } else {
        LOGI("commitAll OK: %s", message);
    }

cleanup_commit:
    git_commit_free(parent);
    git_tree_free(tree);
    git_signature_free(sig);
    git_index_free(index);
    git_repository_free(repo);
    (*env)->ReleaseStringUTFChars(env, jpath,    path);
    (*env)->ReleaseStringUTFChars(env, jmessage, message);
    git_libgit2_shutdown();

    return (jint) result;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 3. createBranch(path: String, branchName: String): Int
 *    Creates a new branch pointing at current HEAD.
 *    Returns 0 on success, negative error code on failure.
 * ═══════════════════════════════════════════════════════════════════════════ */
JNIEXPORT jint JNICALL
Java_com_example_gitlane_GitBridge_createBranch(
        JNIEnv *env, jobject obj, jstring jpath, jstring jbranch) {

    git_libgit2_init();

    const char *path   = (*env)->GetStringUTFChars(env, jpath,   NULL);
    const char *branch = (*env)->GetStringUTFChars(env, jbranch, NULL);

    git_repository *repo   = NULL;
    git_reference  *ref    = NULL;
    git_commit     *commit = NULL;
    git_oid         head_oid;
    int result = 0;

    result = git_repository_open(&repo, path);
    if (result < 0) { LOGE("createBranch: open failed: %s", git_error_str(result)); goto cleanup_create; }

    result = git_reference_name_to_id(&head_oid, repo, "HEAD");
    if (result < 0) { LOGE("createBranch: HEAD lookup failed: %s", git_error_str(result)); goto cleanup_create; }

    result = git_commit_lookup(&commit, repo, &head_oid);
    if (result < 0) { LOGE("createBranch: commit lookup failed: %s", git_error_str(result)); goto cleanup_create; }

    /* 0 = do not force-overwrite existing branch */
    result = git_branch_create(&ref, repo, branch, commit, 0);
    if (result < 0) {
        LOGE("createBranch: branch_create failed: %s", git_error_str(result));
    } else {
        LOGI("createBranch OK: %s", branch);
    }

cleanup_create:
    git_reference_free(ref);
    git_commit_free(commit);
    git_repository_free(repo);
    (*env)->ReleaseStringUTFChars(env, jpath,   path);
    (*env)->ReleaseStringUTFChars(env, jbranch, branch);
    git_libgit2_shutdown();

    return (jint) result;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 4. checkoutBranch(path: String, branchName: String): Int
 *    Checks out an existing branch (updates HEAD + working directory).
 *    Returns 0 on success, negative error code on failure.
 * ═══════════════════════════════════════════════════════════════════════════ */
JNIEXPORT jint JNICALL
Java_com_example_gitlane_GitBridge_checkoutBranch(
        JNIEnv *env, jobject obj, jstring jpath, jstring jbranch) {

    git_libgit2_init();

    const char *path   = (*env)->GetStringUTFChars(env, jpath,   NULL);
    const char *branch = (*env)->GetStringUTFChars(env, jbranch, NULL);

    git_repository *repo      = NULL;
    git_reference  *branch_ref = NULL;
    git_object     *treeish   = NULL;
    int result = 0;

    /* Build "refs/heads/<branch>" canonical name */
    char ref_name[512];
    snprintf(ref_name, sizeof(ref_name), "refs/heads/%s", branch);

    result = git_repository_open(&repo, path);
    if (result < 0) { LOGE("checkoutBranch: open failed: %s", git_error_str(result)); goto cleanup_checkout; }

    result = git_reference_lookup(&branch_ref, repo, ref_name);
    if (result < 0) { LOGE("checkoutBranch: ref lookup failed: %s", git_error_str(result)); goto cleanup_checkout; }

    result = git_reference_peel(&treeish, branch_ref, GIT_OBJECT_COMMIT);
    if (result < 0) { LOGE("checkoutBranch: peel failed: %s", git_error_str(result)); goto cleanup_checkout; }

    /* Checkout options */
    git_checkout_options opts = GIT_CHECKOUT_OPTIONS_INIT;
    opts.checkout_strategy = GIT_CHECKOUT_SAFE;

    result = git_checkout_tree(repo, treeish, &opts);
    if (result < 0) { LOGE("checkoutBranch: checkout_tree failed: %s", git_error_str(result)); goto cleanup_checkout; }

    /* Update HEAD to point to the new branch */
    result = git_repository_set_head(repo, ref_name);
    if (result < 0) {
        LOGE("checkoutBranch: set_head failed: %s", git_error_str(result));
    } else {
        LOGI("checkoutBranch OK: %s", branch);
    }

cleanup_checkout:
    git_object_free(treeish);
    git_reference_free(branch_ref);
    git_repository_free(repo);
    (*env)->ReleaseStringUTFChars(env, jpath,   path);
    (*env)->ReleaseStringUTFChars(env, jbranch, branch);
    git_libgit2_shutdown();

    return (jint) result;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 5. mergeBranch(path: String, branchName: String): Int
 *    Merges the named branch into the current HEAD branch.
 *    Performs fast-forward or creates a merge commit.
 *    Returns 0 on success, 1 if already up-to-date, negative on failure.
 * ═══════════════════════════════════════════════════════════════════════════ */
JNIEXPORT jint JNICALL
Java_com_example_gitlane_GitBridge_mergeBranch(
        JNIEnv *env, jobject obj, jstring jpath, jstring jbranch) {

    git_libgit2_init();

    const char *path   = (*env)->GetStringUTFChars(env, jpath,   NULL);
    const char *branch = (*env)->GetStringUTFChars(env, jbranch, NULL);

    git_repository       *repo        = NULL;
    git_reference        *branch_ref  = NULL;
    git_annotated_commit *ann_commit  = NULL;
    git_merge_analysis_t  analysis;
    git_merge_preference_t preference;
    int result = 0;

    char ref_name[512];
    snprintf(ref_name, sizeof(ref_name), "refs/heads/%s", branch);

    result = git_repository_open(&repo, path);
    if (result < 0) { LOGE("mergeBranch: open failed: %s", git_error_str(result)); goto cleanup_merge; }

    result = git_reference_lookup(&branch_ref, repo, ref_name);
    if (result < 0) { LOGE("mergeBranch: ref lookup failed: %s", git_error_str(result)); goto cleanup_merge; }

    result = git_annotated_commit_from_ref(&ann_commit, repo, branch_ref);
    if (result < 0) { LOGE("mergeBranch: annotated_commit failed: %s", git_error_str(result)); goto cleanup_merge; }

    result = git_merge_analysis(&analysis, &preference, repo,
                                (const git_annotated_commit **)&ann_commit, 1);
    if (result < 0) { LOGE("mergeBranch: analysis failed: %s", git_error_str(result)); goto cleanup_merge; }

    if (analysis & GIT_MERGE_ANALYSIS_UP_TO_DATE) {
        LOGI("mergeBranch: already up-to-date");
        result = 1;  /* Signal: already current */
        goto cleanup_merge;
    }

    if (analysis & GIT_MERGE_ANALYSIS_FASTFORWARD) {
        /* Fast-forward: just move HEAD to branch tip */
        git_oid target_oid;
        result = git_annotated_commit_id(ann_commit) ? 0 : -1;
        target_oid = *git_annotated_commit_id(ann_commit);

        git_object *target = NULL;
        result = git_object_lookup(&target, repo, &target_oid, GIT_OBJECT_COMMIT);
        if (result < 0) { git_object_free(target); LOGE("mergeBranch: ff obj lookup failed"); goto cleanup_merge; }

        git_checkout_options co_opts = GIT_CHECKOUT_OPTIONS_INIT;
        co_opts.checkout_strategy = GIT_CHECKOUT_SAFE;
        result = git_checkout_tree(repo, target, &co_opts);
        git_object_free(target);
        if (result < 0) { LOGE("mergeBranch: ff checkout failed: %s", git_error_str(result)); goto cleanup_merge; }

        result = git_repository_set_head(repo, ref_name);
        LOGI("mergeBranch fast-forward OK: %s", branch);

    } else if (analysis & GIT_MERGE_ANALYSIS_NORMAL) {
        /* Normal merge — create merge commit */
        git_merge_options merge_opts = GIT_MERGE_OPTIONS_INIT;
        git_checkout_options co_opts  = GIT_CHECKOUT_OPTIONS_INIT;
        co_opts.checkout_strategy = GIT_CHECKOUT_FORCE;

        result = git_merge(repo,
                           (const git_annotated_commit **)&ann_commit, 1,
                           &merge_opts, &co_opts);
        if (result < 0) { LOGE("mergeBranch: merge failed: %s", git_error_str(result)); goto cleanup_merge; }

        /* Create merge commit */
        git_index      *index      = NULL;
        git_oid         tree_oid;
        git_tree       *tree       = NULL;
        git_signature  *sig       = NULL;
        git_oid         head_oid, their_oid;
        git_commit     *head_commit = NULL, *their_commit = NULL;
        git_oid         merge_oid;

        git_repository_index(&index, repo);
        git_index_write_tree(&tree_oid, index);
        git_tree_lookup(&tree, repo, &tree_oid);
        git_signature_now(&sig, "GitLane", "gitlane@local");
        git_reference_name_to_id(&head_oid, repo, "HEAD");
        git_commit_lookup(&head_commit, repo, &head_oid);
        their_oid = *git_annotated_commit_id(ann_commit);
        git_commit_lookup(&their_commit, repo, &their_oid);

        char merge_msg[512];
        snprintf(merge_msg, sizeof(merge_msg), "Merge branch '%s'", branch);

        result = git_commit_create_v(
                &merge_oid, repo, "HEAD", sig, sig,
                NULL, merge_msg, tree, 2, head_commit, their_commit);

        git_commit_free(head_commit);
        git_commit_free(their_commit);
        git_tree_free(tree);
        git_signature_free(sig);
        git_index_free(index);

        if (result < 0) {
            LOGE("mergeBranch: commit create failed: %s", git_error_str(result));
        } else {
            git_repository_state_cleanup(repo);
            LOGI("mergeBranch merge commit OK: %s", branch);
        }
    }

cleanup_merge:
    git_annotated_commit_free(ann_commit);
    git_reference_free(branch_ref);
    git_repository_free(repo);
    (*env)->ReleaseStringUTFChars(env, jpath,   path);
    (*env)->ReleaseStringUTFChars(env, jbranch, branch);
    git_libgit2_shutdown();

    return (jint) result;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 6. getCommitLog(path: String): String
 *    Returns a JSON array of commits on the current HEAD branch.
 *    Each entry: { "hash": "...", "message": "...", "author": "...", "time": 0 }
 *    Returns JSON error object on failure: { "error": "..." }
 *    Capped at 100 commits to avoid large allocations.
 * ═══════════════════════════════════════════════════════════════════════════ */
#define MAX_COMMITS 100
#define JSON_BUFFER_SIZE (MAX_COMMITS * 512 + 64)

JNIEXPORT jstring JNICALL
Java_com_example_gitlane_GitBridge_getCommitLog(
        JNIEnv *env, jobject obj, jstring jpath) {

    git_libgit2_init();

    const char *path = (*env)->GetStringUTFChars(env, jpath, NULL);

    git_repository  *repo    = NULL;
    git_revwalk     *walker  = NULL;
    char            *json    = NULL;
    int result = 0;

    json = (char *)malloc(JSON_BUFFER_SIZE);
    if (!json) {
        (*env)->ReleaseStringUTFChars(env, jpath, path);
        git_libgit2_shutdown();
        return (*env)->NewStringUTF(env, "{\"error\":\"Out of memory\"}");
    }

    result = git_repository_open(&repo, path);
    if (result < 0) {
        snprintf(json, JSON_BUFFER_SIZE, "{\"error\":\"%s\"}", git_error_str(result));
        goto return_log;
    }

    result = git_revwalk_new(&walker, repo);
    if (result < 0) {
        snprintf(json, JSON_BUFFER_SIZE, "{\"error\":\"%s\"}", git_error_str(result));
        goto return_log;
    }

    git_revwalk_sorting(walker, GIT_SORT_TIME);
    result = git_revwalk_push_head(walker);
    if (result < 0) {
        snprintf(json, JSON_BUFFER_SIZE, "{\"error\":\"%s\"}", git_error_str(result));
        goto return_log;
    }

    /* Build JSON array */
    int pos = 0;
    pos += snprintf(json + pos, JSON_BUFFER_SIZE - pos, "[");

    git_oid oid;
    int count = 0;
    int first = 1;

    while (git_revwalk_next(&oid, walker) == 0 && count < MAX_COMMITS) {
        git_commit *commit = NULL;
        if (git_commit_lookup(&commit, repo, &oid) != 0) continue;

        char hash_str[GIT_OID_SHA1_HEXSIZE + 1];
        git_oid_tostr(hash_str, sizeof(hash_str), &oid);

        const char *msg     = git_commit_message(commit);
        const char *author  = git_commit_author(commit)->name;
        git_time_t  ts      = git_commit_author(commit)->when.time;

        /* Escape double-quotes in message/author for JSON safety */
        char safe_msg[256]    = {0};
        char safe_author[128] = {0};
        int mi = 0, ai = 0;
        for (int i = 0; msg[i] && mi < 254; i++) {
            if (msg[i] == '"' || msg[i] == '\\') safe_msg[mi++] = '\\';
            if (msg[i] == '\n' || msg[i] == '\r') { safe_msg[mi++] = '\\'; safe_msg[mi++] = 'n'; continue; }
            safe_msg[mi++] = msg[i];
        }
        for (int i = 0; author[i] && ai < 126; i++) {
            if (author[i] == '"' || author[i] == '\\') safe_author[ai++] = '\\';
            safe_author[ai++] = author[i];
        }

        if (!first) pos += snprintf(json + pos, JSON_BUFFER_SIZE - pos, ",");
        pos += snprintf(json + pos, JSON_BUFFER_SIZE - pos,
                        "{\"hash\":\"%s\",\"message\":\"%s\",\"author\":\"%s\",\"time\":%ld}",
                        hash_str, safe_msg, safe_author, (long)ts);

        git_commit_free(commit);
        first = 0;
        count++;
    }

    pos += snprintf(json + pos, JSON_BUFFER_SIZE - pos, "]");
    LOGI("getCommitLog OK: %d commits", count);

return_log:
    git_revwalk_free(walker);
    git_repository_free(repo);
    (*env)->ReleaseStringUTFChars(env, jpath, path);
    git_libgit2_shutdown();

    jstring result_str = (*env)->NewStringUTF(env, json);
    free(json);
    return result_str;
}
