#ifndef STORNAUT_C_INVESTIGATION_MACHINE_CAMPAIGN_SUPPORT_H
#define STORNAUT_C_INVESTIGATION_MACHINE_CAMPAIGN_SUPPORT_H

#include <stdint.h>
#include <stddef.h>
#include <sys/types.h>

#define STORNAUT_INVESTIGATION_CAMPAIGN_RECEIPT_FD 3
#define STORNAUT_INVESTIGATION_CAMPAIGN_TERMINAL_FD 4
#define STORNAUT_INVESTIGATION_CAMPAIGN_BOOTSTRAP_FD 5
#define STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_FD 6
#define STORNAUT_INVESTIGATION_CAMPAIGN_INVALID_FD (-1)
#define STORNAUT_INVESTIGATION_CAMPAIGN_BOOTSTRAP_READY 0xA5
#define STORNAUT_INVESTIGATION_CAMPAIGN_MAX_CREDENTIAL_BYTES 1023

typedef enum {
    STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_SUCCESS = 0,
    STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_DEADLINE = 1,
    STORNAUT_INVESTIGATION_CAMPAIGN_CREDENTIAL_FAILURE = 2
} stornaut_investigation_campaign_credential_status;

typedef enum {
    STORNAUT_INVESTIGATION_CAMPAIGN_CHILD_STAGE_SESSION = 1,
    STORNAUT_INVESTIGATION_CAMPAIGN_CHILD_STAGE_TIOCSCTTY = 2,
    STORNAUT_INVESTIGATION_CAMPAIGN_CHILD_STAGE_TCSETPGRP = 3,
    STORNAUT_INVESTIGATION_CAMPAIGN_CHILD_STAGE_DUP_STDIN = 4,
    STORNAUT_INVESTIGATION_CAMPAIGN_CHILD_STAGE_DUP_STDOUT = 5,
    STORNAUT_INVESTIGATION_CAMPAIGN_CHILD_STAGE_DUP_STDERR = 6,
    STORNAUT_INVESTIGATION_CAMPAIGN_CHILD_STAGE_CLOSE = 7,
    STORNAUT_INVESTIGATION_CAMPAIGN_CHILD_STAGE_BOOTSTRAP = 8,
    STORNAUT_INVESTIGATION_CAMPAIGN_CHILD_STAGE_EXECVE = 9
} stornaut_investigation_campaign_child_stage;

typedef struct {
    uint32_t version;
    uint32_t stage;
    int32_t error_number;
    int32_t reserved;
} stornaut_investigation_campaign_child_failure_v1;

typedef struct {
    pid_t process_id;
    int32_t terminal_master_descriptor;
    int32_t receipt_read_descriptor;
    int32_t bootstrap_read_descriptor;
    int32_t parent_transfer_close_error;
} stornaut_investigation_campaign_spawn;

/*
 * A nonzero return means no child was created. A zero return means the caller
 * owns process_id until exact reap. parent_transfer_close_error != 0 further
 * marks post-spawn transfer cleanup as uncertain without erasing child ownership.
 */
int stornaut_investigation_campaign_spawn_fixed(
    const char *absolute_bootstrap_path,
    stornaut_investigation_campaign_spawn *spawn
);

int stornaut_investigation_campaign_bootstrap_fixed(
    const char *absolute_coordinator_path
);

stornaut_investigation_campaign_credential_status
stornaut_investigation_campaign_readpassphrase_bounded(
    char *credential, size_t credential_capacity,
    uint64_t absolute_deadline_nanoseconds, size_t *credential_length,
    int32_t *error_number
);

/*
 * Relays exactly one credential line to a canonical, no-echo terminal and
 * follows it with that terminal's VEOF character. The VEOF makes a rejected
 * first sudo authentication attempt fail closed instead of waiting for an
 * unowned retry until the whole campaign deadline.
 */
int stornaut_investigation_campaign_relay_single_credential(
    int terminal_descriptor, const char *credential, size_t credential_length,
    uint64_t absolute_deadline_nanoseconds
);

int stornaut_investigation_campaign_monotonic_nanoseconds(uint64_t *value);

typedef enum {
    STORNAUT_INVESTIGATION_CAMPAIGN_TEST_NO_FAULT = 0,
    STORNAUT_INVESTIGATION_CAMPAIGN_TEST_TERMINATE_SIGNAL_FAILURE = 1,
    STORNAUT_INVESTIGATION_CAMPAIGN_TEST_TERMINATE_CLOCK_FAILURE = 2,
    STORNAUT_INVESTIGATION_CAMPAIGN_TEST_TERMINATE_WAIT_FAILURE = 3
} stornaut_investigation_campaign_test_fault;

#if defined(STORNAUT_INVESTIGATION_CAMPAIGN_TESTING)
void stornaut_investigation_campaign_test_set_fault(
    stornaut_investigation_campaign_test_fault fault
);
#endif

int stornaut_investigation_campaign_credential_reader_child(void);

#endif
