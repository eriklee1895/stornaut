#ifndef CSTORNAUT_SQLITE_SUPPORT_H
#define CSTORNAUT_SQLITE_SUPPORT_H

#include <sqlite3.h>

int stornaut_sqlite_enable_defensive(sqlite3 *database, int *enabled);

#endif
