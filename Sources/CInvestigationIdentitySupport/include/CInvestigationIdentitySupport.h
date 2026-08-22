#ifndef STORNAUT_C_INVESTIGATION_IDENTITY_SUPPORT_H
#define STORNAUT_C_INVESTIGATION_IDENTITY_SUPPORT_H

#include <stdint.h>
#include <sys/types.h>

#define STORNAUT_INVESTIGATION_MAX_SUPPLEMENTARY_GROUPS 16
#define STORNAUT_INVESTIGATION_IDENTITY_MISMATCH 20001

typedef struct {
    pid_t process_id;
    int32_t process_id_version;
    int32_t audit_session_id;
    uid_t effective_user_id;
    uint32_t audit_token_words[8];
} stornaut_investigation_identity;

int stornaut_investigation_identity_for_pid(
    pid_t process_id,
    stornaut_investigation_identity *identity
);

typedef struct {
    pid_t process_id;
    pid_t parent_process_id;
    pid_t process_group_id;
    uint64_t start_time_seconds;
    uint64_t start_time_microseconds;
    uid_t real_user_id;
    uid_t effective_user_id;
    uid_t saved_user_id;
    gid_t real_group_id;
    gid_t effective_group_id;
    gid_t saved_group_id;
    uid_t audit_user_id;
    int32_t audit_session_id;
    uint32_t supplementary_group_count;
    gid_t supplementary_groups[
        STORNAUT_INVESTIGATION_MAX_SUPPLEMENTARY_GROUPS
    ];
} stornaut_investigation_process_snapshot;

int stornaut_investigation_process_snapshot_for_pid(
    pid_t process_id,
    stornaut_investigation_process_snapshot *snapshot
);

#endif
