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

/* ═══════════════════════════════════════════════════════════════════════════
 * 7. getRepositoryStatus(path: String): String
 *    Returns a JSON array of files with their current status:
 *    [ { "path": "file.txt", "status": "modified" }, ... ]
 * ═══════════════════════════════════════════════════════════════════════════ */
JNIEXPORT jstring JNICALL
Java_com_example_gitlane_GitBridge_getRepositoryStatus(
        JNIEnv *env, jobject obj, jstring jpath) {

    git_libgit2_init();
    const char *path = (*env)->GetStringUTFChars(env, jpath, NULL);

    git_repository   *repo    = NULL;
    git_status_list  *status  = NULL;
    char             *json    = NULL;
    int result = 0;

    json = (char *)malloc(32768); // Large buffer for status
    if (!json) {
        (*env)->ReleaseStringUTFChars(env, jpath, path);
        git_libgit2_shutdown();
        return (*env)->NewStringUTF(env, "[]");
    }

    result = git_repository_open(&repo, path);
    if (result < 0) {
        snprintf(json, 32768, "{\"error\":\"%s\"}", git_error_str(result));
        goto return_status;
    }

    git_status_options opts = GIT_STATUS_OPTIONS_INIT;
    opts.show  = GIT_STATUS_SHOW_INDEX_AND_WORKDIR;
    opts.flags = GIT_STATUS_OPT_INCLUDE_UNTRACKED | 
                 GIT_STATUS_OPT_RENAMES_HEAD_TO_INDEX |
                 GIT_STATUS_OPT_SORT_CASE_SENSITIVELY;

    result = git_status_list_new(&status, repo, &opts);
    if (result < 0) {
        snprintf(json, 32768, "{\"error\":\"%s\"}", git_error_str(result));
        goto return_status;
    }

    size_t count = git_status_list_entrycount(status);
    int pos = 0;
    pos += snprintf(json + pos, 32768 - pos, "[");

    for (size_t i = 0; i < count; i++) {
        const git_status_entry *entry = git_status_byindex(status, i);
        const char *file_path = NULL;
        const char *status_str = "unknown";

        if (entry->head_to_index) {
            file_path = entry->head_to_index->new_file.path;
        } else if (entry->index_to_workdir) {
            file_path = entry->index_to_workdir->new_file.path;
        }

        /* Determine status string */
        if (entry->status & GIT_STATUS_INDEX_NEW) status_str = "staged_new";
        else if (entry->status & GIT_STATUS_INDEX_MODIFIED) status_str = "staged_modified";
        else if (entry->status & GIT_STATUS_INDEX_DELETED) status_str = "staged_deleted";
        else if (entry->status & GIT_STATUS_INDEX_RENAMED) status_str = "staged_renamed";
        else if (entry->status & GIT_STATUS_WT_NEW) status_str = "untracked";
        else if (entry->status & GIT_STATUS_WT_MODIFIED) status_str = "modified";
        else if (entry->status & GIT_STATUS_WT_DELETED) status_str = "deleted";
        else if (entry->status & GIT_STATUS_WT_RENAMED) status_str = "renamed";

        if (file_path) {
            if (i > 0) pos += snprintf(json + pos, 32768 - pos, ",");
            pos += snprintf(json + pos, 32768 - pos, 
                           "{\"path\":\"%s\",\"status\":\"%s\"}", 
                           file_path, status_str);
        }
    }

    pos += snprintf(json + pos, 32768 - pos, "]");

return_status:
    if (status) git_status_list_free(status);
    if (repo) git_repository_free(repo);
    (*env)->ReleaseStringUTFChars(env, jpath, path);
    git_libgit2_shutdown();

    jstring result_str = (*env)->NewStringUTF(env, json);
    free(json);
    return result_str;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 8. gitAddFile(path: String, filePath: String): Int
 *    Stages a specific file (git add <file>).
 * ═══════════════════════════════════════════════════════════════════════════ */
JNIEXPORT jint JNICALL
Java_com_example_gitlane_GitBridge_gitAddFile(
        JNIEnv *env, jobject obj, jstring jpath, jstring jfile) {

    git_libgit2_init();
    const char *path = (*env)->GetStringUTFChars(env, jpath, NULL);
    const char *file = (*env)->GetStringUTFChars(env, jfile, NULL);

    git_repository *repo = NULL;
    git_index      *index = NULL;
    int result = 0;

    result = git_repository_open(&repo, path);
    if (result < 0) goto cleanup_add;

    result = git_repository_index(&index, repo);
    if (result < 0) goto cleanup_add;

    result = git_index_add_bypath(index, file);
    if (result < 0) goto cleanup_add;

    result = git_index_write(index);

cleanup_add:
    if (index) git_index_free(index);
    if (repo) git_repository_free(repo);
    (*env)->ReleaseStringUTFChars(env, jpath, path);
    (*env)->ReleaseStringUTFChars(env, jfile, file);
    git_libgit2_shutdown();

    return (jint) result;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 9. getCommitDiff(path: String, commitHash: String): String
 *    Returns the patch text (diff) for a specific commit hash.
 *    Diffs the commit against its first parent.
 * ═══════════════════════════════════════════════════════════════════════════ */
struct diff_payload {
    char *output;
    size_t size;
    size_t capacity;
};

static int diff_print_callback(
    const git_diff_delta *delta,
    const git_diff_hunk *hunk,
    const git_diff_line *line,
    void *payload) {
    
    struct diff_payload *p = (struct diff_payload *)payload;
    
    if (p->size + line->content_len + 1 > p->capacity) {
        p->capacity *= 2;
        p->output = realloc(p->output, p->capacity);
    }
    
    memcpy(p->output + p->size, line->content, line->content_len);
    p->size += line->content_len;
    p->output[p->size] = '\0';
    
    return 0;
}

JNIEXPORT jstring JNICALL
Java_com_example_gitlane_GitBridge_getCommitDiff(
        JNIEnv *env, jobject obj, jstring jpath, jstring jhash) {

    git_libgit2_init();
    const char *path = (*env)->GetStringUTFChars(env, jpath, NULL);
    const char *hash = (*env)->GetStringUTFChars(env, jhash, NULL);

    git_repository *repo = NULL;
    git_commit     *commit = NULL;
    git_commit     *parent = NULL;
    git_tree       *commit_tree = NULL;
    git_tree       *parent_tree = NULL;
    git_diff       *diff = NULL;
    git_oid         oid;
    int result = 0;

    struct diff_payload payload;
    payload.capacity = 16384;
    payload.size = 0;
    payload.output = malloc(payload.capacity);
    payload.output[0] = '\0';

    if (git_repository_open(&repo, path) < 0) goto cleanup_diff;
    if (git_oid_fromstr(&oid, hash) < 0) goto cleanup_diff;
    if (git_commit_lookup(&commit, repo, &oid) < 0) goto cleanup_diff;
    if (git_commit_tree(&commit_tree, commit) < 0) goto cleanup_diff;

    if (git_commit_parentcount(commit) > 0) {
        if (git_commit_parent(&parent, commit, 0) == 0) {
            git_commit_tree(&parent_tree, parent);
        }
    }

    /* Diff trees */
    if (git_diff_tree_to_tree(&diff, repo, parent_tree, commit_tree, NULL) == 0) {
        git_diff_print(diff, GIT_DIFF_FORMAT_PATCH, diff_print_callback, &payload);
    }

cleanup_diff:
    if (diff) git_diff_free(diff);
    if (parent_tree) git_tree_free(parent_tree);
    if (commit_tree) git_tree_free(commit_tree);
    if (parent) git_commit_free(parent);
    if (commit) git_commit_free(commit);
    if (repo) git_repository_free(repo);
    
    (*env)->ReleaseStringUTFChars(env, jpath, path);
    (*env)->ReleaseStringUTFChars(env, jhash, hash);
    git_libgit2_shutdown();

    jstring result_str = (*env)->NewStringUTF(env, payload.output);
    free(payload.output);
    return result_str;
}

/* ─── Callback: Clone Progress ─────────────────────────────────────────── */
static int fetch_progress_cb(const git_indexer_progress *stats, void *payload) {
    LOGI("Fetch Progress: %u/%u objects", stats->received_objects, stats->total_objects);
    return 0;
}

static void checkout_progress_cb(const char *path, size_t cur, size_t tot, void *payload) {
    if (path) LOGI("Checkout Progress: %s (%zu/%zu)", path, cur, tot);
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 10. cloneRepository(url: String, path: String): Int
 *     Clones a remote repository to a local path.
 *     Returns 0 on success, negative on failure.
 * ═══════════════════════════════════════════════════════════════════════════ */
JNIEXPORT jint JNICALL
Java_com_example_gitlane_GitBridge_cloneRepository(
        JNIEnv *env, jobject obj, jstring jurl, jstring jpath) {

    git_libgit2_init();
    const char *url  = (*env)->GetStringUTFChars(env, jurl,  NULL);
    const char *path = (*env)->GetStringUTFChars(env, jpath, NULL);

    git_repository *repo = NULL;
    git_clone_options clone_opts = GIT_CLONE_OPTIONS_INIT;
    git_fetch_options fetch_opts = GIT_FETCH_OPTIONS_INIT;
    git_checkout_options checkout_opts = GIT_CHECKOUT_OPTIONS_INIT;

    /* Set up progress callbacks */
    fetch_opts.callbacks.transfer_progress = fetch_progress_cb;
    clone_opts.fetch_opts = fetch_opts;

    checkout_opts.checkout_strategy = GIT_CHECKOUT_SAFE;
    checkout_opts.progress_cb = checkout_progress_cb;
    clone_opts.checkout_opts = checkout_opts;

    int result = git_clone(&repo, url, path, &clone_opts);
    
    if (result < 0) {
        LOGE("cloneRepository failed: %s", git_error_str(result));
    } else {
        LOGI("cloneRepository OK: %s -> %s", url, path);
    }

    if (repo) git_repository_free(repo);
    (*env)->ReleaseStringUTFChars(env, jurl,  url);
    (*env)->ReleaseStringUTFChars(env, jpath, path);
    git_libgit2_shutdown();

    return (jint) result;
}
