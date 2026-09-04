#include "CInvestigationMachineCampaignSupport.h"

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <spawn.h>
#include <string.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>
#include <util.h>

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
