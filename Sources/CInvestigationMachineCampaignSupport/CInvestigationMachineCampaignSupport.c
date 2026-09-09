#define __STDC_WANT_LIB_EXT1__ 1
#include "CInvestigationMachineCampaignSupport.h"

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <libproc.h>
#include <pthread.h>
#include <readpassphrase.h>
#include <signal.h>
#include <spawn.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/poll.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>
#include <util.h>

int
stornaut_investigation_campaign_monotonic_nanoseconds(uint64_t *value)
{
    struct timespec now;
    if (value == NULL || clock_gettime(CLOCK_UPTIME_RAW, &now) != 0
        || now.tv_sec < 0 || now.tv_nsec < 0) {
        return errno != 0 ? errno : EIO;
    }
    uint64_t seconds = (uint64_t)now.tv_sec;
    if (seconds > (UINT64_MAX - (uint64_t)now.tv_nsec) / 1000000000ULL) {
        return EOVERFLOW;
    }
    *value = seconds * 1000000000ULL + (uint64_t)now.tv_nsec;
    return 0;
}

static void
stornaut_campaign_zero_credential(char *credential, size_t capacity)
{
    if (credential != NULL && capacity > 0) {
        (void)memset_s(credential, capacity, 0, capacity);
    }
}

#if defined(STORNAUT_INVESTIGATION_CAMPAIGN_TESTING)
static stornaut_investigation_campaign_test_fault stornaut_campaign_test_fault =
    STORNAUT_INVESTIGATION_CAMPAIGN_TEST_NO_FAULT;

void
stornaut_investigation_campaign_test_set_fault(
    stornaut_investigation_campaign_test_fault fault
)
{
    stornaut_campaign_test_fault = fault;
}

static int
stornaut_campaign_consume_test_fault(
    stornaut_investigation_campaign_test_fault fault
)
{
    if (stornaut_campaign_test_fault != fault) { return 0; }
    stornaut_campaign_test_fault =
        STORNAUT_INVESTIGATION_CAMPAIGN_TEST_NO_FAULT;
    errno = EIO;
    return 1;
}
#else
#define stornaut_campaign_consume_test_fault(fault) 0
#endif

static int
stornaut_campaign_wait_until(
    pid_t child, uint64_t deadline_nanoseconds, int *status
)
{
    for (;;) {
        pid_t result = waitpid(child, status, WNOHANG);
        if (result == child) { return 0; }
        if (result < 0 && errno != EINTR) {
            return errno != 0 ? errno : EIO;
        }
        uint64_t now = 0;
        int error_number =
            stornaut_investigation_campaign_monotonic_nanoseconds(&now);
        if (error_number != 0) { return error_number; }
        if (now >= deadline_nanoseconds) { return ETIMEDOUT; }
        (void)poll(NULL, 0, 10);
    }
}

static int
stornaut_campaign_terminate_and_reap(
    pid_t child, int *status, int *reaped
)
{
    if (reaped != NULL) { *reaped = 0; }
    if (child <= 1 || status == NULL || reaped == NULL) { return EINVAL; }
    int first_error = 0;
    int signal_result;
    do {
        signal_result = stornaut_campaign_consume_test_fault(
            STORNAUT_INVESTIGATION_CAMPAIGN_TEST_TERMINATE_SIGNAL_FAILURE
        ) ? -1 : kill(child, SIGTERM);
    }
    while (signal_result != 0 && errno == EINTR);
    if (signal_result != 0 && errno != ESRCH) {
        first_error = errno != 0 ? errno : EIO;
    }
    uint64_t now = 0;
    int result = stornaut_campaign_consume_test_fault(
        STORNAUT_INVESTIGATION_CAMPAIGN_TEST_TERMINATE_CLOCK_FAILURE
    ) ? EIO : stornaut_investigation_campaign_monotonic_nanoseconds(&now);
    if (result == 0 && now <= UINT64_MAX - 250000000ULL) {
        result = stornaut_campaign_consume_test_fault(
            STORNAUT_INVESTIGATION_CAMPAIGN_TEST_TERMINATE_WAIT_FAILURE
        ) ? EIO : stornaut_campaign_wait_until(
            child, now + 250000000ULL, status);
        if (result == 0) { *reaped = 1; return first_error; }
        if (result != ETIMEDOUT) { first_error = result; }
    } else {
        first_error = result != 0 ? result : EOVERFLOW;
    }
    do { signal_result = kill(child, SIGKILL); }
    while (signal_result != 0 && errno == EINTR);
    if (signal_result != 0 && errno != ESRCH) {
        if (first_error == 0) { first_error = errno != 0 ? errno : EIO; }
        return first_error;
    }
    pid_t wait_result;
    do { wait_result = waitpid(child, status, 0); }
    while (wait_result < 0 && errno == EINTR);
    if (wait_result != child) { return errno != 0 ? errno : EIO; }
    *reaped = 1;
    return first_error;
}

_Static_assert(
    sizeof(stornaut_investigation_campaign_child_failure_v1) == 16,
    "campaign bootstrap failure wire must remain 16 bytes"
);

static void
stornaut_campaign_initialize_spawn(stornaut_investigation_campaign_spawn *spawn)
{
    memset(spawn, 0, sizeof(*spawn));
    spawn->terminal_master_descriptor =
        STORNAUT_INVESTIGATION_CAMPAIGN_INVALID_FD;
    spawn->receipt_read_descriptor =
        STORNAUT_INVESTIGATION_CAMPAIGN_INVALID_FD;
    spawn->bootstrap_read_descriptor =
        STORNAUT_INVESTIGATION_CAMPAIGN_INVALID_FD;
}

static int
stornaut_campaign_close(int descriptor)
{
    if (descriptor < 0 || close(descriptor) == 0) {
        return 0;
    }
    return errno != 0 ? errno : EIO;
}

static void
stornaut_campaign_close_all(int *descriptors, size_t count)
{
    for (size_t index = 0; index < count; index += 1) {
        (void)stornaut_campaign_close(descriptors[index]);
        descriptors[index] = -1;
    }
}

static int
stornaut_campaign_set_descriptor_flag(int descriptor, int flag, int enabled)
{
    int flags = fcntl(descriptor, F_GETFD);
    if (flags < 0) {
        return errno != 0 ? errno : EIO;
    }
    flags = enabled ? flags | flag : flags & ~flag;
    if (fcntl(descriptor, F_SETFD, flags) != 0) {
        return errno != 0 ? errno : EIO;
    }
    return 0;
}

static int
stornaut_campaign_set_nonblocking(int descriptor)
{
    int flags = fcntl(descriptor, F_GETFL);
    if (flags < 0 || fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) != 0) {
        return errno != 0 ? errno : EIO;
    }
    return 0;
}

static int
stornaut_campaign_preserve_terminal_output_bytes(int descriptor)
{
    struct termios attributes;
    if (tcgetattr(descriptor, &attributes) != 0) {
        return errno != 0 ? errno : EIO;
    }
    attributes.c_oflag &= (tcflag_t)~ONLCR;
    if (tcsetattr(descriptor, TCSANOW, &attributes) != 0) {
        return errno != 0 ? errno : EIO;
    }
    if (tcgetattr(descriptor, &attributes) != 0) {
        return errno != 0 ? errno : EIO;
    }
    return (attributes.c_oflag & ONLCR) == 0 ? 0 : EIO;
}

static int
stornaut_campaign_relocate(int *descriptor)
{
    if (*descriptor > STORNAUT_INVESTIGATION_CAMPAIGN_BOOTSTRAP_FD) {
        return stornaut_campaign_set_descriptor_flag(
            *descriptor, FD_CLOEXEC, 1
        );
    }
    int replacement = fcntl(
        *descriptor, F_DUPFD_CLOEXEC,
        STORNAUT_INVESTIGATION_CAMPAIGN_BOOTSTRAP_FD + 1
    );
    if (replacement < 0) {
        return errno != 0 ? errno : EIO;
    }
    int result = stornaut_campaign_close(*descriptor);
    if (result != 0) {
        (void)stornaut_campaign_close(replacement);
        return result;
    }
    *descriptor = replacement;
    return 0;
}

static int
stornaut_campaign_add_actions(
    posix_spawn_file_actions_t *actions, const int *descriptors
)
{
    int result = posix_spawn_file_actions_adddup2(
        actions, descriptors[1], STORNAUT_INVESTIGATION_CAMPAIGN_TERMINAL_FD
    );
    if (result == 0) {
        result = posix_spawn_file_actions_adddup2(
            actions, descriptors[3], STORNAUT_INVESTIGATION_CAMPAIGN_RECEIPT_FD
        );
    }
    if (result == 0) {
        result = posix_spawn_file_actions_adddup2(
            actions, descriptors[5], STORNAUT_INVESTIGATION_CAMPAIGN_BOOTSTRAP_FD
        );
    }
    for (size_t index = 0; result == 0 && index < 6; index += 1) {
        result = posix_spawn_file_actions_addclose(actions, descriptors[index]);
    }
    return result;
}

static int
stornaut_campaign_configure_attributes(posix_spawnattr_t *attributes)
{
    sigset_t empty_mask;
    sigset_t default_signals;
    if (sigemptyset(&empty_mask) != 0 || sigfillset(&default_signals) != 0) {
        return errno != 0 ? errno : EIO;
    }
    short flags = POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSID
        | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF;
    int result = posix_spawnattr_setsigmask(attributes, &empty_mask);
    if (result == 0) {
        result = posix_spawnattr_setsigdefault(attributes, &default_signals);
    }
    if (result == 0) {
        result = posix_spawnattr_setflags(attributes, flags);
    }
    return result;
}

int
stornaut_investigation_campaign_spawn_fixed(
    const char *absolute_bootstrap_path,
    stornaut_investigation_campaign_spawn *spawn
)
{
    if (spawn == NULL) {
        return EINVAL;
    }
    stornaut_campaign_initialize_spawn(spawn);
    if (absolute_bootstrap_path == NULL || absolute_bootstrap_path[0] != '/'
        || absolute_bootstrap_path[1] == '\0') {
        return EINVAL;
    }

    int descriptors[6] = {-1, -1, -1, -1, -1, -1};
    if (openpty(&descriptors[0], &descriptors[1], NULL, NULL, NULL) != 0
        || pipe(&descriptors[2]) != 0 || pipe(&descriptors[4]) != 0) {
        int error_number = errno != 0 ? errno : EIO;
        stornaut_campaign_close_all(descriptors, 6);
        return error_number;
    }
    int terminal_result =
        stornaut_campaign_preserve_terminal_output_bytes(descriptors[1]);
    if (terminal_result != 0) {
        stornaut_campaign_close_all(descriptors, 6);
        return terminal_result;
    }
    for (size_t index = 0; index < 6; index += 1) {
        int result = stornaut_campaign_relocate(&descriptors[index]);
        if (result != 0) {
            stornaut_campaign_close_all(descriptors, 6);
            return result;
        }
    }
    for (size_t index = 0; index < 3; index += 1) {
        int result = stornaut_campaign_set_nonblocking(
            descriptors[(size_t[]){0, 2, 4}[index]]
        );
        if (result != 0) {
            stornaut_campaign_close_all(descriptors, 6);
            return result;
        }
    }

    posix_spawn_file_actions_t actions;
    int result = posix_spawn_file_actions_init(&actions);
    if (result != 0) {
        stornaut_campaign_close_all(descriptors, 6);
        return result;
    }
    result = stornaut_campaign_add_actions(&actions, descriptors);
    if (result != 0) {
        (void)posix_spawn_file_actions_destroy(&actions);
        stornaut_campaign_close_all(descriptors, 6);
        return result;
    }
    posix_spawnattr_t attributes;
    result = posix_spawnattr_init(&attributes);
    if (result != 0) {
        (void)posix_spawn_file_actions_destroy(&actions);
        stornaut_campaign_close_all(descriptors, 6);
        return result;
    }
    result = stornaut_campaign_configure_attributes(&attributes);
    if (result != 0) {
        (void)posix_spawnattr_destroy(&attributes);
        (void)posix_spawn_file_actions_destroy(&actions);
        stornaut_campaign_close_all(descriptors, 6);
        return result;
    }

    char *const arguments[] = {(char *)absolute_bootstrap_path, NULL};
    char *const environment[] = {NULL};
    pid_t child = 0;
    result = posix_spawn(
        &child, absolute_bootstrap_path, &actions, &attributes,
        arguments, environment
    );
    int attribute_destroy_error = posix_spawnattr_destroy(&attributes);
    int actions_destroy_error = posix_spawn_file_actions_destroy(&actions);
    if (result != 0) {
        stornaut_campaign_close_all(descriptors, 6);
        return result;
    }

    int close_error = stornaut_campaign_close(descriptors[1]);
    int next_error = stornaut_campaign_close(descriptors[3]);
    if (close_error == 0) { close_error = next_error; }
    next_error = stornaut_campaign_close(descriptors[5]);
    if (close_error == 0) { close_error = next_error; }
    if (close_error == 0) { close_error = attribute_destroy_error; }
    if (close_error == 0) { close_error = actions_destroy_error; }

    spawn->process_id = child;
    spawn->terminal_master_descriptor = descriptors[0];
    spawn->receipt_read_descriptor = descriptors[2];
    spawn->bootstrap_read_descriptor = descriptors[4];
    spawn->parent_transfer_close_error = close_error;
    return 0;
}

stornaut_investigation_campaign_credential_status
stornaut_investigation_campaign_readpassphrase_bounded(
    char *credential, size_t credential_capacity,
    uint64_t absolute_deadline_nanoseconds,
    size_t *credential_length, int32_t *error_number
)
{
    unsigned char frame[
        5 + STORNAUT_INVESTIGATION_CAMPAIGN_MAX_CREDENTIAL_BYTES
    ];
    stornaut_campaign_zero_credential((char *)frame, sizeof(frame));
    if (credential_length != NULL) { *credential_length = 0; }
    if (error_number != NULL) { *error_number = EINVAL; }
    if (credential == NULL || credential_capacity
            != STORNAUT_INVESTIGATION_CAMPAIGN_MAX_CREDENTIAL_BYTES + 2
        || credential_length == NULL || error_number == NULL
        || absolute_deadline_nanoseconds == 0) {
        return STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_FAILURE;
    }
    stornaut_campaign_zero_credential(credential, credential_capacity);

    int result = 0;
    uint64_t now = 0;
    int terminal_descriptor = -1;
    int pipe_descriptors[2] = {-1, -1};
    int actions_initialized = 0;
    int attributes_initialized = 0;
    int child_created = 0;
    int signal_mask_changed = 0;
    int foreground_changed = 0;
    int terminal_captured = 0;
    pid_t child = 0;
    pid_t parent_group = getpgrp();
    posix_spawn_file_actions_t actions;
    posix_spawnattr_t attributes;
    char executable_path[PROC_PIDPATHINFO_MAXSIZE];
    sigset_t job_control_set;
    sigset_t previous_mask;
    stornaut_investigation_campaign_credential_status status =
        STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_FAILURE;
    struct stat terminal_metadata;
    struct termios original_terminal;
    memset(executable_path, 0, sizeof(executable_path));
    int executable_length = proc_pidpath(
        getpid(), executable_path, sizeof(executable_path)
    );
    if (executable_length <= 1
        || executable_length >= (int)sizeof(executable_path)
        || executable_path[0] != '/'
        || strnlen(executable_path, sizeof(executable_path))
            != (size_t)executable_length) {
        *error_number = errno != 0 ? errno : EIO;
        goto cleanup;
    }
    result = stornaut_investigation_campaign_monotonic_nanoseconds(&now);
    if (result != 0) {
        *error_number = result;
        goto cleanup;
    }
    if (now >= absolute_deadline_nanoseconds) {
        *error_number = ETIMEDOUT;
        status = STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_DEADLINE;
        goto cleanup;
    }
    if (absolute_deadline_nanoseconds - now
        > 1400ULL * 1000ULL * 1000ULL * 1000ULL) {
        *error_number = EINVAL;
        goto cleanup;
    }
    terminal_descriptor = open("/dev/tty", O_RDWR | O_CLOEXEC | O_NOFOLLOW);
    if (terminal_descriptor < 0) {
        *error_number = errno != 0 ? errno : ENOTTY;
        goto cleanup;
    }
    if (fstat(terminal_descriptor, &terminal_metadata) != 0) {
        *error_number = errno != 0 ? errno : EIO;
        goto cleanup;
    }
    if (!S_ISCHR(terminal_metadata.st_mode) || !isatty(terminal_descriptor)) {
        *error_number = ENOTTY;
        goto cleanup;
    }
    errno = 0;
    pid_t foreground_group = tcgetpgrp(terminal_descriptor);
    if (foreground_group < 0) {
        *error_number = errno != 0 ? errno : ENOTTY;
        goto cleanup;
    }
    if (foreground_group != getpgrp()) {
        *error_number = EPERM;
        goto cleanup;
    }
    if (tcgetattr(terminal_descriptor, &original_terminal) != 0) {
        *error_number = errno != 0 ? errno : EIO;
        goto cleanup;
    }
    terminal_captured = 1;
    if (sigemptyset(&job_control_set) != 0
        || sigaddset(&job_control_set, SIGTTOU) != 0) {
        *error_number = errno != 0 ? errno : EIO;
        goto cleanup;
    }
    result = pthread_sigmask(SIG_BLOCK, &job_control_set, &previous_mask);
    if (result != 0) { *error_number = result; goto cleanup; }
    signal_mask_changed = 1;
    if (pipe(pipe_descriptors) != 0) {
        *error_number = errno != 0 ? errno : EIO;
        goto cleanup;
    }
    for (size_t index = 0; index < 2; index += 1) {
        if (pipe_descriptors[index]
            <= STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_FD) {
            int replacement = fcntl(
                pipe_descriptors[index], F_DUPFD_CLOEXEC,
                STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_FD + 1
            );
            if (replacement < 0) {
                *error_number = errno != 0 ? errno : EIO;
                goto cleanup;
            }
            (void)stornaut_campaign_close(pipe_descriptors[index]);
            pipe_descriptors[index] = replacement;
        }
    }
    result = stornaut_campaign_set_nonblocking(pipe_descriptors[0]);
    if (result != 0) { *error_number = result; goto cleanup; }
    result = posix_spawn_file_actions_init(&actions);
    if (result != 0) { *error_number = result; goto cleanup; }
    actions_initialized = 1;
    result = posix_spawn_file_actions_adddup2(
        &actions, pipe_descriptors[1],
        STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_FD
    );
    if (result == 0) {
        result = posix_spawn_file_actions_addclose(&actions, pipe_descriptors[0]);
    }
    if (result == 0) {
        result = posix_spawn_file_actions_addclose(&actions, pipe_descriptors[1]);
    }
    if (result != 0) { *error_number = result; goto cleanup; }
    result = posix_spawnattr_init(&attributes);
    if (result != 0) { *error_number = result; goto cleanup; }
    attributes_initialized = 1;
    sigset_t empty_mask;
    sigset_t default_signals;
    if (sigemptyset(&empty_mask) != 0 || sigfillset(&default_signals) != 0) {
        *error_number = errno != 0 ? errno : EIO;
        goto cleanup;
    }
    short flags = POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_START_SUSPENDED
        | POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_SETSIGMASK
        | POSIX_SPAWN_SETSIGDEF;
    result = posix_spawnattr_setsigmask(&attributes, &empty_mask);
    if (result == 0) {
        result = posix_spawnattr_setsigdefault(&attributes, &default_signals);
    }
    if (result == 0) { result = posix_spawnattr_setpgroup(&attributes, 0); }
    if (result == 0) { result = posix_spawnattr_setflags(&attributes, flags); }
    if (result != 0) { *error_number = result; goto cleanup; }
    char *const arguments[] = {
        executable_path,
        (char *)"--stornaut-credential-reader-v1", NULL,
    };
    char *const environment[] = {NULL};
    result = posix_spawn(
        &child, executable_path, &actions, &attributes,
        arguments, environment
    );
    if (result != 0 || child <= 1) {
        *error_number = result != 0 ? result : EIO;
        goto cleanup;
    }
    child_created = 1;
    if (tcsetpgrp(terminal_descriptor, child) != 0) {
        *error_number = errno != 0 ? errno : EIO;
        goto cleanup;
    }
    foreground_changed = 1;
    if (kill(child, SIGCONT) != 0) {
        *error_number = errno != 0 ? errno : EIO;
        goto cleanup;
    }
    (void)stornaut_campaign_close(pipe_descriptors[1]);
    pipe_descriptors[1] = -1;
    size_t used = 0;
    int reached_eof = 0;
    for (;;) {
        result = stornaut_investigation_campaign_monotonic_nanoseconds(&now);
        if (result != 0) { *error_number = result; break; }
        if (now >= absolute_deadline_nanoseconds) {
            *error_number = ETIMEDOUT;
            status = STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_DEADLINE;
            break;
        }
        uint64_t remaining = absolute_deadline_nanoseconds - now;
        uint64_t milliseconds = (remaining + 999999ULL) / 1000000ULL;
        int timeout = milliseconds > (uint64_t)INT_MAX
            ? INT_MAX : (int)milliseconds;
        struct pollfd event = {
            .fd = pipe_descriptors[0], .events = POLLIN | POLLHUP, .revents = 0,
        };
        result = poll(&event, 1, timeout);
        if (result == 0 || (result < 0 && errno == EINTR)) { continue; }
        if (result < 0 || (event.revents & (POLLIN | POLLHUP)) == 0) {
            *error_number = result < 0 && errno != 0 ? errno : EIO;
            break;
        }
        ssize_t count = read(
            pipe_descriptors[0], frame + used, sizeof(frame) - used
        );
        if (count < 0 && errno == EINTR) { continue; }
        if (count < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) { continue; }
        if (count < 0) {
            *error_number = errno != 0 ? errno : EIO;
            break;
        }
        if (count == 0) { reached_eof = 1; break; }
        used += (size_t)count;
        if (used == sizeof(frame)) { *error_number = EOVERFLOW; break; }
    }
    int child_status = 0;
    int reap_error = 0;
    pid_t wait_result = waitpid(child, &child_status, WNOHANG);
    if (wait_result == 0 && status != STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_DEADLINE) {
        while (wait_result == 0) {
            result = stornaut_investigation_campaign_monotonic_nanoseconds(&now);
            if (result != 0 || now >= absolute_deadline_nanoseconds) { break; }
            (void)poll(NULL, 0, 10);
            wait_result = waitpid(child, &child_status, WNOHANG);
        }
    }
    if (wait_result != child) {
        int reaped = 0;
        result = stornaut_campaign_terminate_and_reap(
            child, &child_status, &reaped
        );
        if (reaped) { wait_result = child; }
        if (result != 0) { reap_error = result; }
    }
    if (wait_result == child) { child_created = 0; }
    if (tcsetpgrp(terminal_descriptor, parent_group) != 0) {
        *error_number = errno != 0 ? errno : EIO;
        goto cleanup;
    }
    foreground_changed = 0;
    if (tcsetattr(terminal_descriptor, TCSAFLUSH | TCSASOFT,
                  &original_terminal) != 0) {
        *error_number = errno != 0 ? errno : EIO;
        goto cleanup;
    }
    if (reap_error != 0) {
        *error_number = reap_error;
        status = STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_FAILURE;
        goto cleanup;
    }
    result = stornaut_investigation_campaign_monotonic_nanoseconds(&now);
    if (result != 0) { *error_number = result; goto cleanup; }
    if (now >= absolute_deadline_nanoseconds) {
        *error_number = ETIMEDOUT;
        status = STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_DEADLINE;
        goto cleanup;
    }
    if (wait_result != child || !WIFEXITED(child_status)
        || !reached_eof || used < 4) {
        *error_number = wait_result == child && WIFEXITED(child_status)
            && WEXITSTATUS(child_status) == 65 ? EINVAL : EIO;
        goto cleanup;
    }
    if (WEXITSTATUS(child_status) != 0) {
        *error_number = WEXITSTATUS(child_status) == 65 ? EINVAL : EIO;
        goto cleanup;
    }
    size_t length = ((size_t)frame[0] << 24) | ((size_t)frame[1] << 16)
        | ((size_t)frame[2] << 8) | (size_t)frame[3];
    if (length == 0
        || length > STORNAUT_INVESTIGATION_CAMPAIGN_MAX_CREDENTIAL_BYTES
        || used != 4 + length) {
        *error_number = EINVAL;
        goto cleanup;
    }
    memcpy(credential, frame + 4, length);
    credential[length] = '\0';
    *credential_length = length;
    *error_number = 0;
    status = STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_SUCCESS;

cleanup:
    if (child_created) {
        int child_status = 0;
        int reaped = 0;
        result = stornaut_campaign_terminate_and_reap(
            child, &child_status, &reaped
        );
        if (reaped) {
            child_created = 0;
        }
        if (result != 0 || !reaped) {
            *error_number = result != 0 ? result : EIO;
            status = STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_FAILURE;
        }
    }
    if (foreground_changed
        && tcsetpgrp(terminal_descriptor, parent_group) != 0) {
        *error_number = errno != 0 ? errno : EIO;
        status = STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_FAILURE;
    }
    if (terminal_captured
        && tcsetattr(terminal_descriptor, TCSAFLUSH | TCSASOFT,
                     &original_terminal) != 0) {
        *error_number = errno != 0 ? errno : EIO;
        status = STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_FAILURE;
    }
    if (attributes_initialized) { (void)posix_spawnattr_destroy(&attributes); }
    if (actions_initialized) { (void)posix_spawn_file_actions_destroy(&actions); }
    stornaut_campaign_zero_credential((char *)frame, sizeof(frame));
    (void)stornaut_campaign_close(pipe_descriptors[0]);
    (void)stornaut_campaign_close(pipe_descriptors[1]);
    if (terminal_descriptor >= 0) {
        result = stornaut_campaign_close(terminal_descriptor);
        if (result != 0) {
            *error_number = result;
            status = STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_FAILURE;
        }
    }
    if (signal_mask_changed) {
        result = pthread_sigmask(SIG_SETMASK, &previous_mask, NULL);
        if (result != 0) {
            *error_number = result;
            status = STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_FAILURE;
        }
    }
    if (status != STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_SUCCESS) {
        *credential_length = 0;
        stornaut_campaign_zero_credential(credential, credential_capacity);
    }
    return status;
}

int
stornaut_investigation_campaign_credential_reader_child(void)
{
    char credential[
        STORNAUT_INVESTIGATION_CAMPAIGN_MAX_CREDENTIAL_BYTES + 2
    ];
    stornaut_campaign_zero_credential(credential, sizeof(credential));
    struct stat pipe_metadata;
    int pipe_flags = fcntl(
        STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_FD, F_GETFL
    );
    pid_t parent = getppid();
    int terminal_descriptor = open(
        "/dev/tty", O_RDWR | O_CLOEXEC | O_NOFOLLOW
    );
    struct sigaction ignore_pipe = {.sa_handler = SIG_IGN};
    int valid = sigemptyset(&ignore_pipe.sa_mask) == 0
        && sigaction(SIGPIPE, &ignore_pipe, NULL) == 0
        && parent > 1 && getpgrp() == getpid()
        && getsid(0) == getsid(parent)
        && terminal_descriptor >= 0
        && tcgetpgrp(terminal_descriptor) == getpid()
        && fstat(STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_FD,
                 &pipe_metadata) == 0
        && S_ISFIFO(pipe_metadata.st_mode)
        && pipe_flags >= 0 && (pipe_flags & O_ACCMODE) == O_WRONLY;
    (void)stornaut_campaign_close(terminal_descriptor);
    if (!valid) { return 64; }
    char *result = readpassphrase(
        "Stornaut Task 39 ii-c administrator authorization: ",
        credential, sizeof(credential), RPP_REQUIRE_TTY
    );
    size_t length = result == NULL ? 0 : strnlen(credential, sizeof(credential));
    if (length == 0
        || length > STORNAUT_INVESTIGATION_CAMPAIGN_MAX_CREDENTIAL_BYTES) {
        stornaut_campaign_zero_credential(credential, sizeof(credential));
        return 65;
    }
    unsigned char header[4] = {
        (unsigned char)(length >> 24), (unsigned char)(length >> 16),
        (unsigned char)(length >> 8), (unsigned char)length,
    };
    size_t offset = 0;
    while (offset < sizeof(header)) {
        ssize_t count = write(
            STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_FD,
            header + offset, sizeof(header) - offset
        );
        if (count > 0) { offset += (size_t)count; continue; }
        if (count < 0 && errno == EINTR) { continue; }
        stornaut_campaign_zero_credential(credential, sizeof(credential));
        return 66;
    }
    offset = 0;
    while (offset < length) {
        ssize_t count = write(
            STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_FD,
            credential + offset, length - offset
        );
        if (count > 0) { offset += (size_t)count; continue; }
        if (count < 0 && errno == EINTR) { continue; }
        stornaut_campaign_zero_credential(credential, sizeof(credential));
        return 67;
    }
    stornaut_campaign_zero_credential(credential, sizeof(credential));
    return 0;
}

static int
stornaut_campaign_bootstrap_fail(
    stornaut_investigation_campaign_child_stage stage, int error_number
)
{
    stornaut_investigation_campaign_child_failure_v1 failure = {
        .version = 1, .stage = (uint32_t)stage,
        .error_number = error_number != 0 ? error_number : EIO, .reserved = 0,
    };
    const uint8_t *bytes = (const uint8_t *)&failure;
    size_t offset = 0;
    while (offset < sizeof(failure)) {
        ssize_t count = write(
            STORNAUT_INVESTIGATION_CAMPAIGN_BOOTSTRAP_FD, bytes + offset,
            sizeof(failure) - offset
        );
        if (count > 0) { offset += (size_t)count; continue; }
        if (count < 0 && errno == EINTR) { continue; }
        break;
    }
    return 127;
}

int
stornaut_investigation_campaign_bootstrap_fixed(
    const char *absolute_coordinator_path
)
{
    if (absolute_coordinator_path == NULL
        || absolute_coordinator_path[0] != '/'
        || absolute_coordinator_path[1] == '\0') {
        return stornaut_campaign_bootstrap_fail(
            STORNAUT_INVESTIGATION_CAMPAIGN_CHILD_STAGE_EXECVE, EINVAL
        );
    }
    pid_t process_id = getpid();
    if (process_id <= 1 || getsid(0) != process_id
        || getpgrp() != process_id) {
        return stornaut_campaign_bootstrap_fail(
            STORNAUT_INVESTIGATION_CAMPAIGN_CHILD_STAGE_SESSION, EINVAL
        );
    }
    int zero = 0;
    if (ioctl(
            STORNAUT_INVESTIGATION_CAMPAIGN_TERMINAL_FD, TIOCSCTTY, &zero
        ) != 0) {
        return stornaut_campaign_bootstrap_fail(
            STORNAUT_INVESTIGATION_CAMPAIGN_CHILD_STAGE_TIOCSCTTY, errno
        );
    }
    if (tcsetpgrp(
            STORNAUT_INVESTIGATION_CAMPAIGN_TERMINAL_FD, process_id
        ) != 0) {
        return stornaut_campaign_bootstrap_fail(
            STORNAUT_INVESTIGATION_CAMPAIGN_CHILD_STAGE_TCSETPGRP, errno
        );
    }
    const int targets[] = {STDIN_FILENO, STDOUT_FILENO, STDERR_FILENO};
    const stornaut_investigation_campaign_child_stage stages[] = {
        STORNAUT_INVESTIGATION_CAMPAIGN_CHILD_STAGE_DUP_STDIN,
        STORNAUT_INVESTIGATION_CAMPAIGN_CHILD_STAGE_DUP_STDOUT,
        STORNAUT_INVESTIGATION_CAMPAIGN_CHILD_STAGE_DUP_STDERR,
    };
    for (size_t index = 0; index < 3; index += 1) {
        if (dup2(
                STORNAUT_INVESTIGATION_CAMPAIGN_TERMINAL_FD, targets[index]
            ) != targets[index]) {
            return stornaut_campaign_bootstrap_fail(stages[index], errno);
        }
    }
    if (stornaut_campaign_set_descriptor_flag(
            STORNAUT_INVESTIGATION_CAMPAIGN_RECEIPT_FD, FD_CLOEXEC, 0
        ) != 0
        || stornaut_campaign_set_descriptor_flag(
            STORNAUT_INVESTIGATION_CAMPAIGN_BOOTSTRAP_FD, FD_CLOEXEC, 1
        ) != 0
        || stornaut_campaign_close(
            STORNAUT_INVESTIGATION_CAMPAIGN_TERMINAL_FD
        ) != 0) {
        return stornaut_campaign_bootstrap_fail(
            STORNAUT_INVESTIGATION_CAMPAIGN_CHILD_STAGE_CLOSE, errno
        );
    }

    const uint8_t ready = STORNAUT_INVESTIGATION_CAMPAIGN_BOOTSTRAP_READY;
    if (write(
            STORNAUT_INVESTIGATION_CAMPAIGN_BOOTSTRAP_FD, &ready,
            sizeof(ready)
        ) != (ssize_t)sizeof(ready)) {
        return stornaut_campaign_bootstrap_fail(
            STORNAUT_INVESTIGATION_CAMPAIGN_CHILD_STAGE_BOOTSTRAP, errno
        );
    }
    char *const arguments[] = {(char *)absolute_coordinator_path, NULL};
    char *const environment[] = {NULL};
    execve(absolute_coordinator_path, arguments, environment);
    return stornaut_campaign_bootstrap_fail(
        STORNAUT_INVESTIGATION_CAMPAIGN_CHILD_STAGE_EXECVE, errno
    );
}
