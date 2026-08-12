#ifndef STORNAUT_C_LIFECYCLE_SUPPORT_H
#define STORNAUT_C_LIFECYCLE_SUPPORT_H

#include <stdint.h>
#include <sys/types.h>

#define STORNAUT_AUDIT_TOKEN_WORD_COUNT 8

typedef struct {
    pid_t process_id;
    int32_t process_id_version;
    int32_t audit_session_id;
    uid_t effective_user_id;
    uint32_t audit_token_words[STORNAUT_AUDIT_TOKEN_WORD_COUNT];
} stornaut_lifecycle_identity;

int stornaut_lifecycle_identity_for_pid(
    pid_t process_id,
    stornaut_lifecycle_identity *identity
);

int stornaut_lifecycle_identity_for_pid_as_user(
    pid_t process_id,
    uid_t expected_user_id,
    stornaut_lifecycle_identity *identity
);

int stornaut_lifecycle_signal_identity(
    const stornaut_lifecycle_identity *identity,
    int signal_number
);

int stornaut_lifecycle_current_audit_session_id(int32_t *audit_session_id);

int stornaut_lifecycle_audit_session_for_pid(
    pid_t process_id,
    int32_t *audit_session_id
);

int stornaut_lifecycle_identity_is_stopped(
    const stornaut_lifecycle_identity *identity,
    int *is_stopped
);

#endif
