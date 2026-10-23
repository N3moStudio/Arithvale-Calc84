#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef void (*C84MegaCallback)(void *context, int error, const char *result);
void *c84mega_create(const char *appKey);
void c84mega_destroy(void *client);
void c84mega_login(void *client, const char *email, const char *password, const char *code, C84MegaCallback callback, void *context);
void c84mega_resume(void *client, const char *session, C84MegaCallback callback, void *context);
void c84mega_fetch(void *client, C84MegaCallback callback, void *context);
void c84mega_mkdir(void *client, const char *parent, const char *name, C84MegaCallback callback, void *context);
int64_t c84mega_size(void *client, const char *path);
void c84mega_list(void *client, const char *after, int32_t limit, C84MegaCallback callback, void *context);
void c84mega_upload(void *client, const char *local, const char *parent, const char *name, C84MegaCallback callback, void *context);
void c84mega_download(void *client, const char *path, const char *local, C84MegaCallback callback, void *context);
void c84mega_cancel(void *client);
#ifdef __cplusplus
}
#endif
