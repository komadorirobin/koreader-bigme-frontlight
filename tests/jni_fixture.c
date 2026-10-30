/* MIT. Harmless host JNI stand-in: never opens a device or starts a JVM.
 * Invalid method calls are counted, not aborted, so regression tests stay safe.
 * Function signatures match the pinned official Android JNI declarations.
 */
#include <stdarg.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static int activity, activity_class, resolver, system_class;
static int permission_method, getter_method, read_method;
static int mode, pending, refs, deletes, bad_calls, permissions, attaches, detaches;
static void *test_env;
static char *strings[128];
static int string_count;

void compat_jni_reset(int m) {
    for (int i=0; i<string_count; ++i) free(strings[i]);
    string_count=0; mode=m; pending=refs=deletes=bad_calls=permissions=attaches=detaches=0;
}
void compat_jni_set_env(void *env) { test_env=env; }
void *compat_jni_activity(void) { return &activity; }
int compat_jni_counter(int n) {
    const int counters[]={refs,deletes,bad_calls,permissions,attaches,detaches,pending};
    return n>=0 && n<7 ? counters[n] : -1;
}
int compat_jni_get_env(void *vm, void **out, int version) {
    (void)vm;
    if (version!=0x00010006) { ++bad_calls; return -1; }
    *out=test_env; return 0;
}
int compat_jni_attach(void *vm, void **out, void *args) {
    (void)vm; (void)args; ++attaches; *out=test_env; return 0;
}
int compat_jni_detach(void *vm) { (void)vm; ++detaches; return 0; }
unsigned char compat_jni_exception(void *env) { (void)env; return (unsigned char)pending; }
void compat_jni_clear(void *env) { (void)env; pending=0; }
void compat_jni_delete(void *env, void *ref) {
    (void)env;
    if (!ref) { ++bad_calls; return; }
    ++deletes;
    for (int i=0; i<string_count; ++i) {
        if (strings[i]==ref) { free(strings[i]); strings[i]=NULL; return; }
    }
}
void *compat_jni_class(void *env, void *object) {
    (void)env;
    if (pending || object!=&activity) { ++bad_calls; return NULL; }
    ++refs; return &activity_class;
}
void *compat_jni_find(void *env, const char *name) {
    (void)env;
    if (pending || strcmp(name,"android/provider/Settings$System")) { ++bad_calls; return NULL; }
    ++refs; return &system_class;
}
void *compat_jni_method(void *env, void *cls, const char *name, const char *sig) {
    (void)env;
    if (pending || cls!=&activity_class) { ++bad_calls; return NULL; }
    if (!strcmp(name,"getContentResolver") && !strcmp(sig,"()Landroid/content/ContentResolver;")) return &getter_method;
    /* Mirrors the real missing legacy Java method, without a host abort. */
    pending=1; return NULL;
}
void *compat_jni_static_method(void *env, void *cls, const char *name, const char *sig) {
    (void)env;
    if (pending || cls!=&system_class) { ++bad_calls; return NULL; }
    if (!strcmp(name,"canWrite") && !strcmp(sig,"(Landroid/content/Context;)Z")) {
        if (mode==1 || mode==5) { pending=(mode==1); return NULL; }
        return &permission_method;
    }
    if (!strcmp(name,"getInt") && !strcmp(sig,"(Landroid/content/ContentResolver;Ljava/lang/String;I)I")) {
        if (mode==4) { pending=1; return NULL; }
        return &read_method;
    }
    pending=1; return NULL;
}
void *compat_jni_call_object(void *env, void *object, void *method, ...) {
    (void)env;
    if (pending || object!=&activity || method!=&getter_method) { ++bad_calls; return NULL; }
    ++refs; return &resolver;
}
unsigned char compat_jni_call_boolean(void *env, void *object, void *method, ...) {
    (void)env; (void)object; (void)method;
    ++bad_calls; return 0; /* Real Android aborts for a NULL method here. */
}
unsigned char compat_jni_call_static_boolean(void *env, void *cls, void *method, ...) {
    (void)env;
    if (pending || cls!=&system_class || method!=&permission_method) { ++bad_calls; return 0; }
    va_list args; va_start(args,method); void *context=va_arg(args,void *); va_end(args);
    if (context!=&activity) { ++bad_calls; return 0; }
    ++permissions;
    if (mode==3) { pending=1; return 0; }
    return mode==2 ? 0 : 1;
}
void *compat_jni_string(void *env, const char *text) {
    (void)env;
    if (pending || string_count>=128) { ++bad_calls; return NULL; }
    char *copy=malloc(strlen(text)+1);
    if (!copy) return NULL;
    strcpy(copy,text); strings[string_count++]=copy; ++refs; return copy;
}
int32_t compat_jni_call_int(void *env, void *cls, void *method, ...) {
    (void)env;
    if (pending || cls!=&system_class || method!=&read_method) { ++bad_calls; return -1; }
    va_list args; va_start(args,method);
    void *content=va_arg(args,void *); const char *key=va_arg(args,const char *); int fallback=va_arg(args,int);
    va_end(args);
    if (content!=&resolver || !key || fallback!=-1) { ++bad_calls; return -1; }
    if (!strcmp(key,"ColdValue")) return 12;
    if (!strcmp(key,"WarmValue")) return 13;
    if (!strcmp(key,"screen_brightness_cold")) return 114;
    if (!strcmp(key,"screen_brightness_warm")) return 120;
    if (!strcmp(key,"LightMode")) return 4;
    ++bad_calls; return -1;
}
