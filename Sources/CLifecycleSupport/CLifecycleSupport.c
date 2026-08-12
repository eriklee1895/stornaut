#include "CLifecycleSupport.h"

#include <bsm/audit.h>
#include <bsm/libbsm.h>
#include <errno.h>
#include <fcntl.h>
#include <grp.h>
#include <libproc.h>
#include <mach/mach.h>
#include <mach/mach_traps.h>
#include <mach/task_info.h>
#include <string.h>
#include <sys/proc.h>
#include <sys/wait.h>
#include <unistd.h>

typedef struct {
    int result;
    stornaut_lifecycle_identity identity;
} stornaut_lifecycle_identity_response;

static int
write_exact(int descriptor, const void *buffer, size_t byte_count)
{
    const uint8_t *bytes = buffer;
    size_t offset = 0;
    while (offset < byte_count) {
        ssize_t written = write(
            descriptor,
            bytes + offset,
            byte_count - offset
        );
        if (written < 0) {
            if (errno == EINTR) {
                continue;
            }
            return errno;
        }
        offset += (size_t)written;
    }
    return 0;
}

static int
read_exact(int descriptor, void *buffer, size_t byte_count)
{
    uint8_t *bytes = buffer;
    size_t offset = 0;
    while (offset < byte_count) {
        ssize_t count = read(
            descriptor,
            bytes + offset,
            byte_count - offset
        );
        if (count == 0) {
            return EPIPE;
        }
        if (count < 0) {
            if (errno == EINTR) {
                continue;
            }
            return errno;
        }
        offset += (size_t)count;
    }
    return 0;
}

int
stornaut_lifecycle_identity_for_pid(
    pid_t process_id,
    stornaut_lifecycle_identity *identity
)
{
    if (process_id <= 1 || identity == NULL) {
        return EINVAL;
    }

    task_name_t task = MACH_PORT_NULL;
    kern_return_t result = task_name_for_pid(
        mach_task_self(),
        process_id,
        &task
    );
    if (result != KERN_SUCCESS) {
        return result == KERN_INVALID_ARGUMENT ? ESRCH : EPERM;
    }

    audit_token_t token = {0};
    mach_msg_type_number_t count = TASK_AUDIT_TOKEN_COUNT;
    result = task_info(
        task,
        TASK_AUDIT_TOKEN,
        (task_info_t)&token,
        &count
    );
    mach_port_deallocate(mach_task_self(), task);
    if (result != KERN_SUCCESS || count != TASK_AUDIT_TOKEN_COUNT) {
        return result == KERN_INVALID_ARGUMENT ? ESRCH : EIO;
    }

    memset(identity, 0, sizeof(*identity));
    identity->process_id = audit_token_to_pid(token);
    identity->process_id_version = audit_token_to_pidversion(token);
    identity->audit_session_id = audit_token_to_asid(token);
    identity->effective_user_id = audit_token_to_euid(token);
    memcpy(
        identity->audit_token_words,
        token.val,
        sizeof(identity->audit_token_words)
    );

    if (identity->process_id != process_id) {
        memset(identity, 0, sizeof(*identity));
        return ESRCH;
    }
    return 0;
}

int
stornaut_lifecycle_identity_for_pid_as_user(
    pid_t process_id,
    uid_t expected_user_id,
    stornaut_lifecycle_identity *identity
)
{
    if (process_id <= 1 || expected_user_id == 0 || identity == NULL) {
        return EINVAL;
    }
    if (geteuid() != 0) {
        return EPERM;
    }

    struct proc_bsdshortinfo information = {0};
    int byte_count = proc_pidinfo(
        process_id,
        PROC_PIDT_SHORTBSDINFO,
        0,
        &information,
        sizeof(information)
    );
    if (byte_count != sizeof(information)) {
        return errno == 0 ? ESRCH : errno;
    }
    if (information.pbsi_uid != expected_user_id) {
        return EPERM;
    }

    int descriptors[2] = {-1, -1};
    if (pipe(descriptors) != 0) {
        return errno;
    }
    if (fcntl(descriptors[0], F_SETFD, FD_CLOEXEC) != 0 ||
        fcntl(descriptors[1], F_SETFD, FD_CLOEXEC) != 0) {
        int result = errno;
        close(descriptors[0]);
        close(descriptors[1]);
        return result;
    }

    pid_t reader = fork();
    if (reader < 0) {
        int result = errno;
        close(descriptors[0]);
        close(descriptors[1]);
        return result;
    }
    if (reader == 0) {
        close(descriptors[0]);
        stornaut_lifecycle_identity_response response = {0};
        if (setgroups(0, NULL) != 0 ||
            setgid(information.pbsi_gid) != 0 ||
            setuid(expected_user_id) != 0 ||
            geteuid() != expected_user_id) {
            response.result = errno == 0 ? EPERM : errno;
        } else {
            response.result = stornaut_lifecycle_identity_for_pid(
                process_id,
                &response.identity
            );
        }
        int result = write_exact(
            descriptors[1],
            &response,
            sizeof(response)
        );
        close(descriptors[1]);
        _exit(result == 0 ? 0 : 125);
    }

    close(descriptors[1]);
    stornaut_lifecycle_identity_response response = {0};
    int result = read_exact(
        descriptors[0],
        &response,
        sizeof(response)
    );
    close(descriptors[0]);

    int wait_status = 0;
    while (waitpid(reader, &wait_status, 0) < 0) {
        if (errno != EINTR) {
            return errno;
        }
    }
    if (result != 0) {
        return result;
    }
    if (!WIFEXITED(wait_status) || WEXITSTATUS(wait_status) != 0) {
        return EIO;
    }
    if (response.result != 0) {
        return response.result;
    }
    if (response.identity.process_id != process_id ||
        response.identity.effective_user_id != expected_user_id) {
        return ESRCH;
    }
    *identity = response.identity;
    return 0;
}

int
stornaut_lifecycle_signal_identity(
    const stornaut_lifecycle_identity *identity,
    int signal_number
)
{
    if (identity == NULL || identity->process_id <= 1 || signal_number <= 0) {
        return EINVAL;
    }

    audit_token_t token = {0};
    memcpy(
        token.val,
        identity->audit_token_words,
        sizeof(identity->audit_token_words)
    );
    if (audit_token_to_pid(token) != identity->process_id ||
        audit_token_to_pidversion(token) != identity->process_id_version ||
        audit_token_to_asid(token) != identity->audit_session_id ||
        audit_token_to_euid(token) != identity->effective_user_id) {
        return EINVAL;
    }
    return proc_signal_with_audittoken(&token, signal_number);
}

int
stornaut_lifecycle_current_audit_session_id(int32_t *audit_session_id)
{
    if (audit_session_id == NULL) {
        return EINVAL;
    }

    auditinfo_addr_t information = {0};
    if (getaudit_addr(&information, sizeof(information)) != 0) {
        return errno;
    }
    *audit_session_id = information.ai_asid;
    return 0;
}

int
stornaut_lifecycle_audit_session_for_pid(
    pid_t process_id,
    int32_t *audit_session_id
)
{
    if (process_id <= 1 || audit_session_id == NULL) {
        return EINVAL;
    }

    auditpinfo_addr_t information = {0};
    information.ap_pid = process_id;
    if (audit_get_pinfo_addr(&information, sizeof(information)) != 0) {
        return errno;
    }
    *audit_session_id = information.ap_asid;
    return 0;
}

int
stornaut_lifecycle_identity_is_stopped(
    const stornaut_lifecycle_identity *identity,
    int *is_stopped
)
{
    if (identity == NULL || is_stopped == NULL || identity->process_id <= 1) {
        return EINVAL;
    }

    stornaut_lifecycle_identity current = {0};
    int result = stornaut_lifecycle_identity_for_pid(
        identity->process_id,
        &current
    );
    if (result != 0) {
        return result;
    }
    if (current.process_id_version != identity->process_id_version ||
        current.audit_session_id != identity->audit_session_id ||
        current.effective_user_id != identity->effective_user_id ||
        memcmp(
            current.audit_token_words,
            identity->audit_token_words,
            sizeof(current.audit_token_words)
        ) != 0) {
        return ESRCH;
    }

    struct proc_bsdshortinfo information = {0};
    int byte_count = proc_pidinfo(
        identity->process_id,
        PROC_PIDT_SHORTBSDINFO,
        0,
        &information,
        sizeof(information)
    );
    if (byte_count != sizeof(information)) {
        return errno == 0 ? ESRCH : errno;
    }
    *is_stopped = information.pbsi_status == SSTOP;
    return 0;
}
