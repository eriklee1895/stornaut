#include "CInvestigationMachineCampaignSupport.h"

#include <errno.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>
#include <util.h>

static int
echo_enabled(int descriptor)
{
    struct termios attributes;
    if (tcgetattr(descriptor, &attributes) != 0) {
        return -1;
    }
    return (attributes.c_lflag & ECHO) != 0 ? 1 : 0;
}

static int
run_child(uint64_t deadline_nanoseconds, uint64_t pre_entry_delay_microseconds)
{
    int before_echo = echo_enabled(STDIN_FILENO);
    char credential[
        STORNAUT_INVESTIGATION_CAMPAIGN_MAX_CREDENTIAL_BYTES + 2
    ];
    memset(credential, 0x5a, sizeof(credential));
    size_t length = 99;
    int32_t error_number = -1;
    printf("fixture-ready\n");
    fflush(stdout);
    uint64_t now = 0;
    if (stornaut_investigation_campaign_monotonic_nanoseconds(&now) != 0
        || now > UINT64_MAX - deadline_nanoseconds) {
        return 70;
    }
    uint64_t absolute_deadline_nanoseconds = now + deadline_nanoseconds;
    if (pre_entry_delay_microseconds > 0) {
        usleep((useconds_t)pre_entry_delay_microseconds);
    }
    if (pre_entry_delay_microseconds == 1) {
        stornaut_investigation_campaign_test_set_fault(
            STORNAUT_INVESTIGATION_CAMPAIGN_TEST_TERMINATE_SIGNAL_FAILURE
        );
    } else if (pre_entry_delay_microseconds == 2) {
        stornaut_investigation_campaign_test_set_fault(
            STORNAUT_INVESTIGATION_CAMPAIGN_TEST_TERMINATE_CLOCK_FAILURE
        );
    } else if (pre_entry_delay_microseconds == 3) {
        stornaut_investigation_campaign_test_set_fault(
            STORNAUT_INVESTIGATION_CAMPAIGN_TEST_TERMINATE_WAIT_FAILURE
        );
    }
    stornaut_investigation_campaign_credential_status status =
        stornaut_investigation_campaign_readpassphrase_bounded(
            credential, sizeof(credential), absolute_deadline_nanoseconds, &length,
            &error_number
        );
    int after_echo = echo_enabled(STDIN_FILENO);
    errno = 0;
    int child_residue = waitpid(-1, NULL, WNOHANG) != -1 || errno != ECHILD;
    int zeroed = 1;
    if (status != STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_SUCCESS) {
        for (size_t index = 0; index < sizeof(credential); index += 1) {
            if (credential[index] != 0) {
                zeroed = 0;
                break;
            }
        }
    }
    printf(
        "status=%d error=%d length=%zu beforeEcho=%d afterEcho=%d zeroed=%d childResidue=%d\n",
        (int)status, (int)error_number, length, before_echo, after_echo, zeroed,
        child_residue
    );
    volatile unsigned char *wipe = (volatile unsigned char *)credential;
    for (size_t index = 0; index < sizeof(credential); index += 1) {
        wipe[index] = 0;
    }
    return 0;
}

static int
run_single_attempt_child(const char *expected, int enable_inlcr)
{
    struct termios original;
    if (expected == NULL || tcgetattr(STDIN_FILENO, &original) != 0) {
        return 70;
    }
    struct termios hidden = original;
    hidden.c_lflag |= ICANON;
    hidden.c_lflag &= (tcflag_t)~(ECHO | ECHONL);
    if (enable_inlcr) { hidden.c_iflag |= INLCR; }
    if (tcsetattr(STDIN_FILENO, TCSANOW, &hidden) != 0) { return 71; }
    printf("single-attempt-ready\n");
    fflush(stdout);

    char first[2048];
    memset(first, 0, sizeof(first));
    ssize_t first_count;
    do { first_count = read(STDIN_FILENO, first, sizeof(first)); }
    while (first_count < 0 && errno == EINTR);
    char second = 0;
    ssize_t second_count;
    do { second_count = read(STDIN_FILENO, &second, 1); }
    while (second_count < 0 && errno == EINTR);
    int first_match = first_count == (ssize_t)(strlen(expected) + 1)
        && memcmp(first, expected, strlen(expected)) == 0
        && first[first_count - 1] == '\n';
    int second_eof = second_count == 0;
    if (tcsetattr(STDIN_FILENO, TCSAFLUSH | TCSASOFT, &original) != 0) {
        return 72;
    }
    printf(
        "firstMatch=%d secondEOF=%d afterEcho=%d\n",
        first_match, second_eof, echo_enabled(STDIN_FILENO)
    );
    fflush(stdout);
    return first_match && second_eof ? 0 : 73;
}

static int
output_contains(const char *output, size_t count, const char *needle)
{
    size_t needle_count = strlen(needle);
    if (needle_count == 0 || needle_count > count) {
        return 0;
    }
    for (size_t offset = 0; offset <= count - needle_count; offset += 1) {
        if (memcmp(output + offset, needle, needle_count) == 0) {
            return 1;
        }
    }
    return 0;
}

int
main(int argc, char **argv)
{
    if (argc == 2
        && strcmp(argv[1], "--stornaut-credential-reader-v1") == 0) {
        return stornaut_investigation_campaign_credential_reader_child();
    }
    if (argc < 3 || argc > 4
        || (strcmp(argv[1], "timeout") != 0
            && strcmp(argv[1], "success") != 0
            && strcmp(argv[1], "empty") != 0
            && strcmp(argv[1], "interrupt") != 0
            && strcmp(argv[1], "overflow") != 0
            && strcmp(argv[1], "expired") != 0
            && strcmp(argv[1], "reap-signal") != 0
            && strcmp(argv[1], "reap-clock") != 0
            && strcmp(argv[1], "reap-wait") != 0
            && strcmp(argv[1], "single-attempt-relay") != 0
            && strcmp(argv[1], "single-attempt-inlcr") != 0
            && strcmp(argv[1], "single-attempt-nul") != 0
            && strcmp(argv[1], "reader-nul") != 0)) {
        return 64;
    }
    char *end = NULL;
    errno = 0;
    unsigned long long parsed = strtoull(argv[2], &end, 10);
    if (errno != 0 || end == argv[2] || *end != '\0' || parsed == 0
        || (strcmp(argv[1], "timeout") != 0
            && strcmp(argv[1], "interrupt") != 0
            && strcmp(argv[1], "expired") != 0
            && strcmp(argv[1], "reap-signal") != 0
            && strcmp(argv[1], "reap-clock") != 0
            && strcmp(argv[1], "reap-wait") != 0
            && (argc != 4 || argv[3][0] == '\0'))
        || ((strcmp(argv[1], "timeout") == 0
                || strcmp(argv[1], "interrupt") == 0
                || strcmp(argv[1], "expired") == 0
                || strcmp(argv[1], "reap-signal") == 0
                || strcmp(argv[1], "reap-clock") == 0
                || strcmp(argv[1], "reap-wait") == 0) && argc != 3)) {
        return 65;
    }

    int master = -1;
    pid_t child = forkpty(&master, NULL, NULL, NULL);
    if (child < 0) {
        return 66;
    }
    if (child == 0) {
        if (strcmp(argv[1], "single-attempt-relay") == 0
            || strcmp(argv[1], "single-attempt-inlcr") == 0
            || strcmp(argv[1], "single-attempt-nul") == 0) {
            return run_single_attempt_child(
                argv[3], strcmp(argv[1], "single-attempt-inlcr") == 0
            );
        }
        return run_child(
            (uint64_t)parsed,
            strcmp(argv[1], "expired") == 0 ? 200000
                : strcmp(argv[1], "reap-signal") == 0 ? 1
                : strcmp(argv[1], "reap-clock") == 0 ? 2
                : strcmp(argv[1], "reap-wait") == 0 ? 3 : 0
        );
    }

    char output[8192];
    size_t used = 0;
    int sent = strcmp(argv[1], "timeout") == 0
        || strcmp(argv[1], "expired") == 0
        || strcmp(argv[1], "reap-signal") == 0
        || strcmp(argv[1], "reap-clock") == 0
        || strcmp(argv[1], "reap-wait") == 0;
    int child_status = 0;
    int child_reaped = 0;
    int relay_status = -1;
    for (int iteration = 0; iteration < 200 && used < sizeof(output); iteration += 1) {
        struct pollfd event = {.fd = master, .events = POLLIN | POLLHUP, .revents = 0};
        int ready = poll(&event, 1, 50);
        if (ready < 0 && errno == EINTR) {
            continue;
        }
        if (ready < 0) {
            break;
        }
        if (ready > 0 && (event.revents & (POLLIN | POLLHUP)) != 0) {
            ssize_t count = read(master, output + used, sizeof(output) - used);
            if (count > 0) {
                used += (size_t)count;
            } else if (count == 0 || errno == EIO) {
                break;
            } else if (errno != EINTR) {
                break;
            }
        }
        int single_attempt = strcmp(argv[1], "single-attempt-relay") == 0
            || strcmp(argv[1], "single-attempt-inlcr") == 0
            || strcmp(argv[1], "single-attempt-nul") == 0;
        const char *ready_line = single_attempt
            ? "single-attempt-ready\r\n" : "fixture-ready\r\n";
        if (!sent && output_contains(output, used, ready_line)) {
            struct termios attributes;
            pid_t foreground = tcgetpgrp(master);
            int foreground_matches = single_attempt
                ? foreground == child : foreground > 1 && foreground != child;
            if (foreground_matches
                && tcgetattr(master, &attributes) == 0
                && (attributes.c_lflag & (ECHO | ECHONL)) == 0) {
                if (single_attempt) {
                    uint64_t now = 0;
                    if (stornaut_investigation_campaign_monotonic_nanoseconds(
                            &now) != 0 || now > UINT64_MAX - parsed) {
                        break;
                    }
                    if (strcmp(argv[1], "single-attempt-nul") == 0) {
                        const char embedded_nul[] = {'a', '\0', (char)0xa5, 'b'};
                        relay_status =
                            stornaut_investigation_campaign_relay_single_credential(
                                master, embedded_nul, sizeof(embedded_nul),
                                now + parsed
                            );
                    } else {
                        relay_status =
                            stornaut_investigation_campaign_relay_single_credential(
                                master, argv[3], strlen(argv[3]), now + parsed
                            );
                    }
                    if (relay_status != 0) {
                        if (kill(child, SIGKILL) != 0) {
                            break;
                        }
                    }
                } else {
                    const unsigned char reader_nul[] = {'a', 0, 0xa5, 'b'};
                    const char *input = strcmp(argv[1], "empty") == 0
                        ? "" : strcmp(argv[1], "interrupt") == 0
                        ? "\003" : argv[3];
                    size_t input_count = strcmp(argv[1], "reader-nul") == 0
                        ? sizeof(reader_nul) : strlen(input);
                    const void *input_bytes = strcmp(argv[1], "reader-nul") == 0
                        ? reader_nul : (const void *)input;
                    if ((input_count > 0
                            && write(master, input_bytes, input_count)
                                != (ssize_t)input_count)
                        || (strcmp(argv[1], "interrupt") != 0
                            && write(master, "\n", 1) != 1)) {
                        break;
                    }
                }
                sent = 1;
            }
        }
        pid_t wait_result = waitpid(child, &child_status, WNOHANG);
        if (wait_result == child) {
            child_reaped = 1;
            if ((event.revents & (POLLIN | POLLHUP)) == 0) {
                break;
            }
        } else if (wait_result < 0) {
            break;
        }
    }
    if (!child_reaped && waitpid(child, &child_status, 0) != child) {
        (void)close(master);
        return 67;
    }
    (void)close(master);
    if (strcmp(argv[1], "single-attempt-relay") == 0
        || strcmp(argv[1], "single-attempt-inlcr") == 0
        || strcmp(argv[1], "single-attempt-nul") == 0) {
        errno = 0;
        int child_residue = waitpid(-1, NULL, WNOHANG) != -1 || errno != ECHILD;
        int child_exit = WIFEXITED(child_status) ? WEXITSTATUS(child_status)
            : WIFSIGNALED(child_status) ? 128 + WTERMSIG(child_status) : -1;
        printf(
            "relayStatus=%d childExit=%d childResidue=%d ",
            relay_status, child_exit, child_residue
        );
    }
    if (write(STDOUT_FILENO, output, used) != (ssize_t)used) {
        return 68;
    }
    if (strcmp(argv[1], "single-attempt-relay") == 0
        || strcmp(argv[1], "single-attempt-inlcr") == 0
        || strcmp(argv[1], "single-attempt-nul") == 0) { return 0; }
    return WIFEXITED(child_status) ? WEXITSTATUS(child_status) : 69;
}
