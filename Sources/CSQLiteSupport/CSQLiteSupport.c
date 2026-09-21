#include "CSQLiteSupport.h"

int stornaut_sqlite_enable_defensive(sqlite3 *database, int *enabled) {
    return sqlite3_db_config(
        database,
        SQLITE_DBCONFIG_DEFENSIVE,
        1,
        enabled
    );
}
