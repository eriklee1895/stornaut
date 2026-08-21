#include "CInvestigationIdentitySupport.h"

#include <bsm/audit.h>
#include <bsm/libbsm.h>
#include <errno.h>
#include <libproc.h>
#include <mach/mach.h>
#include <mach/mach_traps.h>
#include <mach/task_info.h>
#include <string.h>
#include <sys/proc.h>

int
stornaut_investigation_identity_for_pid(
    pid_t process_id,
    stornaut_investigation_identity *identity
)
{
    if (process_id <= 1 || identity == NULL) {
        return EINVAL;
    }
    memset(identity, 0, sizeof(*identity));

    task_name_t task = MACH_PORT_NULL;
    kern_return_t result = task_name_for_pid(
        mach_task_self(),
        process_id,
        &task
    );
    if (result != KERN_SUCCESS) {
        if (result == KERN_INVALID_ARGUMENT) {
            return ESRCH;
        }

        struct proc_bsdshortinfo information = {0};
        errno = 0;
        int byte_count = proc_pidinfo(
            process_id,
            PROC_PIDT_SHORTBSDINFO,
            0,
            &information,
            sizeof(information)
        );
        if (byte_count != sizeof(information) &&
            (errno == 0 || errno == ESRCH)) {
            return ESRCH;
        }
        return EPERM;
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
