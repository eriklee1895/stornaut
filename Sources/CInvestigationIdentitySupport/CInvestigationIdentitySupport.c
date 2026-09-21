#include "CInvestigationIdentitySupport.h"

#include <bsm/audit.h>
#include <bsm/libbsm.h>
#include <errno.h>
#include <libproc.h>
#include <mach/mach.h>
#include <mach/mach_traps.h>
#include <mach/task_info.h>
#include <string.h>
#include <sys/param.h>
#include <sys/proc.h>
#include <sys/sysctl.h>
#include <unistd.h>

_Static_assert(
    NGROUPS == STORNAUT_INVESTIGATION_MAX_SUPPLEMENTARY_GROUPS,
    "stornaut process snapshot group capacity must match kinfo_proc"
);

static int
stornaut_investigation_read_bsd_information(
    pid_t process_id,
    struct proc_bsdinfo *information
)
{
    memset(information, 0, sizeof(*information));
    errno = 0;
    int byte_count = proc_pidinfo(
        process_id,
        PROC_PIDTBSDINFO,
        0,
        information,
        sizeof(*information)
    );
    if (byte_count <= 0) {
        int error = errno;
        return error != 0 ? error : ESRCH;
    }
    if (byte_count != sizeof(*information)) {
        return EIO;
    }
    if ((pid_t)information->pbi_pid != process_id) {
        return ESRCH;
    }
    return 0;
}

static int
stornaut_investigation_bsd_identity_matches(
    const struct proc_bsdinfo *first,
    const struct proc_bsdinfo *second
)
{
    return first->pbi_pid == second->pbi_pid &&
        first->pbi_ppid == second->pbi_ppid &&
        first->pbi_pgid == second->pbi_pgid &&
        first->pbi_ruid == second->pbi_ruid &&
        first->pbi_uid == second->pbi_uid &&
        first->pbi_svuid == second->pbi_svuid &&
        first->pbi_rgid == second->pbi_rgid &&
        first->pbi_gid == second->pbi_gid &&
        first->pbi_svgid == second->pbi_svgid &&
        first->pbi_start_tvsec == second->pbi_start_tvsec &&
        first->pbi_start_tvusec == second->pbi_start_tvusec;
}

static int
stornaut_investigation_read_kernel_information(
    pid_t process_id,
    struct kinfo_proc *information
)
{
    memset(information, 0, sizeof(*information));
    size_t information_size = sizeof(*information);
    int process_mib[] = {
        CTL_KERN,
        KERN_PROC,
        KERN_PROC_PID,
        process_id,
    };
    errno = 0;
    if (sysctl(
            process_mib,
            sizeof(process_mib) / sizeof(process_mib[0]),
            information,
            &information_size,
            NULL,
            0
        ) != 0) {
        int error = errno;
        return error != 0 ? error : EIO;
    }
    if (information_size == 0) {
        return ESRCH;
    }
    if (information_size != sizeof(*information)) {
        return EIO;
    }
    if (information->kp_proc.p_pid != process_id) {
        return ESRCH;
    }
    return 0;
}

static int
stornaut_investigation_kernel_identity_matches(
    const struct kinfo_proc *first,
    const struct kinfo_proc *second
)
{
    int first_group_count = first->kp_eproc.e_ucred.cr_ngroups;
    int second_group_count = second->kp_eproc.e_ucred.cr_ngroups;
    if (first_group_count < 1 ||
        first_group_count > STORNAUT_INVESTIGATION_MAX_SUPPLEMENTARY_GROUPS ||
        first_group_count != second_group_count) {
        return 0;
    }
    return first->kp_proc.p_pid == second->kp_proc.p_pid &&
        first->kp_eproc.e_ppid == second->kp_eproc.e_ppid &&
        first->kp_eproc.e_pgid == second->kp_eproc.e_pgid &&
        first->kp_eproc.e_pcred.p_ruid == second->kp_eproc.e_pcred.p_ruid &&
        first->kp_eproc.e_ucred.cr_uid == second->kp_eproc.e_ucred.cr_uid &&
        first->kp_eproc.e_pcred.p_svuid == second->kp_eproc.e_pcred.p_svuid &&
        first->kp_eproc.e_pcred.p_rgid == second->kp_eproc.e_pcred.p_rgid &&
        first->kp_eproc.e_ucred.cr_groups[0]
            == second->kp_eproc.e_ucred.cr_groups[0] &&
        first->kp_eproc.e_pcred.p_svgid == second->kp_eproc.e_pcred.p_svgid &&
        first->kp_proc.p_starttime.tv_sec
            == second->kp_proc.p_starttime.tv_sec &&
        first->kp_proc.p_starttime.tv_usec
            == second->kp_proc.p_starttime.tv_usec &&
        memcmp(
            first->kp_eproc.e_ucred.cr_groups,
            second->kp_eproc.e_ucred.cr_groups,
            (size_t)first_group_count *
                sizeof(first->kp_eproc.e_ucred.cr_groups[0])
        ) == 0;
}

static int
stornaut_investigation_bsd_matches_kernel_and_audit(
    const struct proc_bsdinfo *bsd_information,
    const struct kinfo_proc *kernel_information,
    const auditpinfo_addr_t *audit_information,
    pid_t process_id
)
{
    return (pid_t)bsd_information->pbi_pid == process_id &&
        kernel_information->kp_proc.p_pid == process_id &&
        audit_information->ap_pid == process_id &&
        audit_information->ap_asid > 0 &&
        (pid_t)bsd_information->pbi_ppid ==
            kernel_information->kp_eproc.e_ppid &&
        (pid_t)bsd_information->pbi_pgid ==
            kernel_information->kp_eproc.e_pgid &&
        bsd_information->pbi_ruid ==
            kernel_information->kp_eproc.e_pcred.p_ruid &&
        bsd_information->pbi_uid ==
            kernel_information->kp_eproc.e_ucred.cr_uid &&
        bsd_information->pbi_svuid ==
            kernel_information->kp_eproc.e_pcred.p_svuid &&
        bsd_information->pbi_rgid ==
            kernel_information->kp_eproc.e_pcred.p_rgid &&
        bsd_information->pbi_gid ==
            kernel_information->kp_eproc.e_ucred.cr_groups[0] &&
        bsd_information->pbi_svgid ==
            kernel_information->kp_eproc.e_pcred.p_svgid &&
        bsd_information->pbi_start_tvsec ==
            (uint64_t)kernel_information->kp_proc.p_starttime.tv_sec &&
        bsd_information->pbi_start_tvusec ==
            (uint64_t)kernel_information->kp_proc.p_starttime.tv_usec;
}

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

int
stornaut_investigation_process_snapshot_for_pid(
    pid_t process_id,
    stornaut_investigation_process_snapshot *snapshot
)
{
    if (snapshot == NULL) {
        return EINVAL;
    }
    memset(snapshot, 0, sizeof(*snapshot));
    if (process_id <= 1) {
        return EINVAL;
    }

    struct proc_bsdinfo bsd_information = {0};
    int result = stornaut_investigation_read_bsd_information(
        process_id,
        &bsd_information
    );
    if (result != 0) {
        return result;
    }

    struct kinfo_proc kernel_information = {0};
    size_t kernel_information_size = sizeof(kernel_information);
    int process_mib[] = {
        CTL_KERN,
        KERN_PROC,
        KERN_PROC_PID,
        process_id,
    };
    errno = 0;
    if (sysctl(
            process_mib,
            sizeof(process_mib) / sizeof(process_mib[0]),
            &kernel_information,
            &kernel_information_size,
            NULL,
            0
        ) != 0) {
        int error = errno;
        return error != 0 ? error : EIO;
    }
    if (kernel_information_size == 0) {
        return ESRCH;
    }
    if (kernel_information_size != sizeof(kernel_information)) {
        return EIO;
    }
    if (kernel_information.kp_proc.p_pid != process_id) {
        return ESRCH;
    }

    int group_count = kernel_information.kp_eproc.e_ucred.cr_ngroups;
    if (group_count < 1 ||
        group_count > STORNAUT_INVESTIGATION_MAX_SUPPLEMENTARY_GROUPS) {
        return EIO;
    }

    if (kernel_information.kp_proc.p_starttime.tv_sec < 0 ||
        kernel_information.kp_proc.p_starttime.tv_usec < 0) {
        return EIO;
    }

    auditpinfo_addr_t audit_information = {0};
    audit_information.ap_pid = process_id;
    errno = 0;
    if (audit_get_pinfo_addr(
            &audit_information,
            sizeof(audit_information)
        ) != 0) {
        int error = errno;
        return error != 0 ? error : EIO;
    }
    if (!stornaut_investigation_bsd_matches_kernel_and_audit(
            &bsd_information,
            &kernel_information,
            &audit_information,
            process_id
        )) {
        return STORNAUT_INVESTIGATION_IDENTITY_MISMATCH;
    }

    struct proc_bsdinfo final_bsd_information = {0};
    result = stornaut_investigation_read_bsd_information(
        process_id,
        &final_bsd_information
    );
    if (result != 0) {
        return result;
    }
    if (!stornaut_investigation_bsd_matches_kernel_and_audit(
            &final_bsd_information,
            &kernel_information,
            &audit_information,
            process_id
        ) ||
        !stornaut_investigation_bsd_identity_matches(
            &bsd_information,
            &final_bsd_information
        )) {
        return STORNAUT_INVESTIGATION_IDENTITY_MISMATCH;
    }

    stornaut_investigation_process_snapshot completed_snapshot = {0};
    completed_snapshot.process_id = process_id;
    completed_snapshot.parent_process_id =
        kernel_information.kp_eproc.e_ppid;
    completed_snapshot.process_group_id =
        kernel_information.kp_eproc.e_pgid;
    completed_snapshot.start_time_seconds =
        bsd_information.pbi_start_tvsec;
    completed_snapshot.start_time_microseconds =
        bsd_information.pbi_start_tvusec;
    completed_snapshot.real_user_id =
        kernel_information.kp_eproc.e_pcred.p_ruid;
    completed_snapshot.effective_user_id =
        kernel_information.kp_eproc.e_ucred.cr_uid;
    completed_snapshot.saved_user_id =
        kernel_information.kp_eproc.e_pcred.p_svuid;
    completed_snapshot.real_group_id =
        kernel_information.kp_eproc.e_pcred.p_rgid;
    completed_snapshot.effective_group_id =
        kernel_information.kp_eproc.e_ucred.cr_groups[0];
    completed_snapshot.saved_group_id =
        kernel_information.kp_eproc.e_pcred.p_svgid;
    completed_snapshot.audit_user_id = audit_information.ap_auid;
    completed_snapshot.audit_session_id = audit_information.ap_asid;
    completed_snapshot.supplementary_group_count = (uint32_t)group_count;
    memcpy(
        completed_snapshot.supplementary_groups,
        kernel_information.kp_eproc.e_ucred.cr_groups,
        (size_t)group_count *
            sizeof(completed_snapshot.supplementary_groups[0])
    );

    *snapshot = completed_snapshot;
    return 0;
}

int
stornaut_investigation_cross_uid_process_snapshot_for_pid(
    pid_t process_id,
    stornaut_investigation_cross_uid_process_snapshot *snapshot
)
{
    if (snapshot == NULL) {
        return EINVAL;
    }
    memset(snapshot, 0, sizeof(*snapshot));
    if (process_id <= 1) {
        return EINVAL;
    }

    struct kinfo_proc first = {0};
    int result = stornaut_investigation_read_kernel_information(
        process_id,
        &first
    );
    if (result != 0) {
        return result;
    }
    int group_count = first.kp_eproc.e_ucred.cr_ngroups;
    if (group_count < 1 ||
        group_count > STORNAUT_INVESTIGATION_MAX_SUPPLEMENTARY_GROUPS ||
        first.kp_proc.p_starttime.tv_sec <= 0 ||
        first.kp_proc.p_starttime.tv_usec < 0 ||
        first.kp_proc.p_starttime.tv_usec >= 1000000) {
        return EIO;
    }

    errno = 0;
    pid_t first_session_id = getsid(process_id);
    if (first_session_id <= 0) {
        int error = errno;
        return error != 0 ? error : EIO;
    }

    struct kinfo_proc second = {0};
    result = stornaut_investigation_read_kernel_information(
        process_id,
        &second
    );
    if (result != 0) {
        return result;
    }
    if (!stornaut_investigation_kernel_identity_matches(&first, &second)) {
        return STORNAUT_INVESTIGATION_IDENTITY_MISMATCH;
    }
    stornaut_investigation_cross_uid_process_snapshot completed_snapshot = {0};
    completed_snapshot.process_id = process_id;
    completed_snapshot.parent_process_id = first.kp_eproc.e_ppid;
    completed_snapshot.process_group_id = first.kp_eproc.e_pgid;
    completed_snapshot.session_id = first_session_id;
    completed_snapshot.start_time_seconds = first.kp_proc.p_starttime.tv_sec;
    completed_snapshot.start_time_microseconds = first.kp_proc.p_starttime.tv_usec;
    completed_snapshot.real_user_id = first.kp_eproc.e_pcred.p_ruid;
    completed_snapshot.effective_user_id = first.kp_eproc.e_ucred.cr_uid;
    completed_snapshot.saved_user_id = first.kp_eproc.e_pcred.p_svuid;
    completed_snapshot.real_group_id = first.kp_eproc.e_pcred.p_rgid;
    completed_snapshot.effective_group_id = first.kp_eproc.e_ucred.cr_groups[0];
    completed_snapshot.saved_group_id = first.kp_eproc.e_pcred.p_svgid;
    completed_snapshot.supplementary_group_count = (uint32_t)group_count;
    memcpy(
        completed_snapshot.supplementary_groups,
        first.kp_eproc.e_ucred.cr_groups,
        (size_t)group_count *
            sizeof(completed_snapshot.supplementary_groups[0])
    );
    *snapshot = completed_snapshot;
    return 0;
}

int
stornaut_investigation_current_audit_identity_read(
    stornaut_investigation_current_audit_identity *identity
)
{
    if (identity == NULL) {
        return EINVAL;
    }
    memset(identity, 0, sizeof(*identity));

    auditinfo_addr_t information = {0};
    errno = 0;
    if (getaudit_addr(&information, sizeof(information)) != 0) {
        int error = errno;
        return error != 0 ? error : EIO;
    }
    if (information.ai_auid == AU_DEFAUDITID || information.ai_asid <= 0) {
        return STORNAUT_INVESTIGATION_IDENTITY_MISMATCH;
    }

    stornaut_investigation_current_audit_identity completed_identity = {0};
    completed_identity.audit_user_id = information.ai_auid;
    completed_identity.audit_session_id = information.ai_asid;
    *identity = completed_identity;
    return 0;
}
