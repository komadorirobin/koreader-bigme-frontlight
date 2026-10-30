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
static int write_method, compat_throwable, compat_throwable_class, compat_tostring_method;
static int mode, pending, refs, deletes, bad_calls, permissions, attaches, detaches;
static int writes, raw_reads, utf_gets, utf_releases, compat_reads;
static const char *exception_message;
static int cold, warm, raw_cold, raw_warm, preset_cold, preset_warm;
static void *test_env;
static char *strings[128];
static int string_count;

void compat_jni_reset(int m) {
    for (int i=0; i<string_count; ++i) free(strings[i]);
    string_count=0; mode=m; pending=refs=deletes=bad_calls=permissions=attaches=detaches=0;
    writes=raw_reads=utf_gets=utf_releases=compat_reads=0;
    cold=preset_cold=12; warm=preset_warm=13; raw_cold=114; raw_warm=120;
    exception_message="java.lang.SecurityException: simulated Android failure";
}
void compat_jni_set_env(void *env) { test_env=env; }
void *compat_jni_activity(void) { return &activity; }
int compat_jni_counter(int n) {
    const int counters[]={refs,deletes,bad_calls,permissions,attaches,detaches,pending,writes,raw_reads,utf_gets,utf_releases,compat_reads};
    return n>=0 && n<12 ? counters[n] : -1;
}
int compat_jni_value(const char *key) {
    if (!strcmp(key,"ColdValue")) return cold;
    if (!strcmp(key,"WarmValue")) return warm;
    if (!strcmp(key,"screen_brightness_cold")) return raw_cold;
    if (!strcmp(key,"screen_brightness_warm")) return raw_warm;
    if (!strcmp(key,"LightUser_Brightness")) return preset_cold;
    if (!strcmp(key,"LightUser_ColorTemp")) return preset_warm;
    if (!strcmp(key,"LightMode")) return 4;
    ++bad_calls; return -1;
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
    if (!pending && object==&compat_throwable) { ++refs; return &compat_throwable_class; }
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
    if (!pending && cls==&compat_throwable_class && !strcmp(name,"toString") && !strcmp(sig,"()Ljava/lang/String;")) {
        if (mode==9) { pending=1; return NULL; }
        return &compat_tostring_method;
    }
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
    if (!strcmp(name,"putInt") && !strcmp(sig,"(Landroid/content/ContentResolver;Ljava/lang/String;I)Z")) return &write_method;
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
    if (!pending && cls==&system_class && method==&write_method) {
        va_list args; va_start(args,method);
        void *content=va_arg(args,void *); const char *key=va_arg(args,const char *); int value=va_arg(args,int);
        va_end(args);
        if (content!=&resolver || !key) { ++bad_calls; return 0; }
        if ((mode==7 || mode==9) && !strcmp(key,"screen_brightness_cold")) {
            pending=1; exception_message="java.lang.SecurityException: write denied for screen_brightness_cold"; return 0;
        }
        if (mode==8) return 0;
        int *target=NULL;
        if (!strcmp(key,"ColdValue")) target=&cold;
        if (!strcmp(key,"WarmValue")) target=&warm;
        if (!strcmp(key,"screen_brightness_cold")) target=&raw_cold;
        if (!strcmp(key,"screen_brightness_warm")) target=&raw_warm;
        if (!strcmp(key,"LightUser_Brightness")) target=&preset_cold;
        if (!strcmp(key,"LightUser_ColorTemp")) target=&preset_warm;
        if (!target) { ++bad_calls; return 0; }
        *target=value; ++writes; return 1;
    }
    if (pending || cls!=&system_class || method!=&permission_method) { ++bad_calls; return 0; }
    va_list args; va_start(args,method); void *context=va_arg(args,void *); va_end(args);
    if (context!=&activity) { ++bad_calls; return 0; }
    ++permissions;
    if (mode==3) { pending=1; return 0; }
    return mode==2 ? 0 : 1;
}
void *compat_jni_string(void *env, const char *text) {
    (void)env;
    if (pending) { ++bad_calls; return NULL; }
    int slot=0; while (slot<string_count && strings[slot]) ++slot;
    if (slot>=128) { ++bad_calls; return NULL; }
    char *copy=malloc(strlen(text)+1);
    if (!copy) return NULL;
    strcpy(copy,text); strings[slot]=copy; if (slot==string_count) ++string_count;
    ++refs; return copy;
}
int32_t compat_jni_call_int(void *env, void *cls, void *method, ...) {
    (void)env;
    if (pending || cls!=&system_class || method!=&read_method) { ++bad_calls; return -1; }
    va_list args; va_start(args,method);
    void *content=va_arg(args,void *); const char *key=va_arg(args,const char *); int fallback=va_arg(args,int);
    va_end(args);
    if (content!=&resolver || !key || fallback!=-1) { ++bad_calls; return -1; }
    ++compat_reads;
    if (!strcmp(key,"screen_brightness_cold") || !strcmp(key,"screen_brightness_warm")) {
        ++raw_reads;
        if (mode>=6) {
            pending=1; exception_message="java.lang.SecurityException: Settings key: <screen_brightness_cold> is not readable"; return -1;
        }
    }
    if (mode==10 && !strcmp(key,"LightMode")) { pending=1; return -1; }
    return compat_jni_value(key);
}
void *compat_jni_exception_object(void *env) {
    (void)env;
    if (!pending) { ++bad_calls; return NULL; }
    ++refs; return &compat_throwable;
}
void *compat_jni_call_object_a(void *env, void *object, void *method, const void *args) {
    if (pending || args || object!=&compat_throwable || method!=&compat_tostring_method) { ++bad_calls; return NULL; }
    return compat_jni_string(env,exception_message);
}
static int compat_valid_string(void *s) {
    for (int i=0;i<string_count;++i) if (s && strings[i]==s) return 1;
    return 0;
}
int32_t compat_jni_utf_length(void *env,void *s) {
    (void)env;
    if (pending || !compat_valid_string(s)) { ++bad_calls; return 0; }
    return (int32_t)strlen(s);
}
const char *compat_jni_utf_chars(void *env,void *s,unsigned char *copy) {
    (void)env; (void)copy;
    if (pending || !compat_valid_string(s)) { ++bad_calls; return NULL; }
    ++utf_gets; return s;
}
void compat_jni_utf_release(void *env,void *s,const char *chars) {
    (void)env;
    if (!compat_valid_string(s) || s!=chars) { ++bad_calls; return; }
    ++utf_releases;
}
