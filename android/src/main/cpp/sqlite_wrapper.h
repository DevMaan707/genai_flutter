#ifndef GENAI_SQLITE_WRAPPER_H
#define GENAI_SQLITE_WRAPPER_H

#include <sqlite3.h>

// The functions below are already included in sqlite3.h,
// so these declarations are not necessary, but kept for reference

#ifdef __cplusplus
extern "C" {
#endif

// extern int sqlite3_open(const char *filename, sqlite3 **ppDb);
// extern int sqlite3_close(sqlite3*);
// extern int sqlite3_exec(sqlite3*, const char *sql, int (*callback)(void*,int,char**,char**), void *, char **errmsg);
// extern void sqlite3_free(void*);
// Add other SQLite functions as needed

#ifdef __cplusplus
}
#endif

#endif
