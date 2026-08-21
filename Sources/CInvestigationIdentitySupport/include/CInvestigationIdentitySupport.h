#ifndef STORNAUT_C_INVESTIGATION_IDENTITY_SUPPORT_H
#define STORNAUT_C_INVESTIGATION_IDENTITY_SUPPORT_H

#include <stdint.h>
#include <sys/types.h>

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

#endif
