/* MIT. Host-only stand-in; no Android/JVM, files or hardware are accessed.
 * Extend the production JNI stand-in with checked Throwable and A-call paths.
 */
#include "../../../tests/jni_fixture.c"

typedef union { unsigned char z; signed char b; uint16_t c; int16_t s;
    int32_t i; int64_t j; float f; double d; void *l; } diag_value;
static int throwable, throwable_class, tostring_method;
static int diag_mode, reads, utf_acquired, utf_released, operations;
static const char *exception = "java.lang.SecurityException: diagnostic simulated denial";

void diag_reset(int m) {
    compat_jni_reset(m<=5 ? m : 0);
    diag_mode=m; reads=utf_acquired=utf_released=operations=0;
    if (m==9) pending=1;
}
int diag_counter(int n) {
    const int counters[]={reads,utf_acquired,utf_released,operations};
    return n>=0 && n<4 ? counters[n] : -1;
}
void *diag_exception(void *env) {
    (void)env;
    if (!pending) { ++bad_calls; return NULL; }
    ++refs; return &throwable;
}
void *diag_class(void *env,void *object) {
    ++operations;
    if (pending) { ++bad_calls; return NULL; }
    if (object==&throwable) { ++refs; return &throwable_class; }
    return compat_jni_class(env,object);
}
void *diag_method(void *env,void *cls,const char *name,const char *sig) {
    ++operations;
    if (pending) { ++bad_calls; return NULL; }
    if (cls==&throwable_class && !strcmp(name,"toString") && !strcmp(sig,"()Ljava/lang/String;")) {
        if (diag_mode==7) { pending=1; return NULL; }
        return &tostring_method;
    }
    return compat_jni_method(env,cls,name,sig);
}
void *diag_find(void *env,const char *name) {
    ++operations; return compat_jni_find(env,name);
}
void *diag_static_method(void *env,void *cls,const char *name,const char *sig) {
    ++operations; return compat_jni_static_method(env,cls,name,sig);
}
void *diag_string(void *env,const char *text) {
    ++operations; return compat_jni_string(env,text);
}
void *diag_object_a(void *env,void *object,void *method,const diag_value *args) {
    ++operations;
    if (pending || args) { ++bad_calls; return NULL; }
    if (object==&throwable && method==&tostring_method) return compat_jni_string(env,exception);
    return compat_jni_call_object(env,object,method);
}
void *diag_object(void *env,void *object,void *method,...) {
    ++operations; return compat_jni_call_object(env,object,method);
}
unsigned char diag_boolean(void *env,void *cls,void *method,...) {
    ++operations;
    if (diag_mode==8) { pending=1; return 0; }
    va_list args; va_start(args,method); void *context=va_arg(args,void *); va_end(args);
    return compat_jni_call_static_boolean(env,cls,method,context);
}
unsigned char diag_boolean_a(void *env,void *cls,void *method,const diag_value *args) {
    ++operations;
    if (!args) { ++bad_calls; return 0; }
    return compat_jni_call_static_boolean(env,cls,method,args[0].l);
}
static int32_t diag_read(void *env,void *cls,void *method,void *content,const char *key,int fallback) {
    ++reads;
    if ((diag_mode==6 || diag_mode==7) && !strcmp(key,"ColdValue")) { pending=1; return -1; }
    return compat_jni_call_int(env,cls,method,content,key,fallback);
}
int32_t diag_int(void *env,void *cls,void *method,...) {
    ++operations;
    va_list args; va_start(args,method);
    void *content=va_arg(args,void *); const char *key=va_arg(args,const char *); int fallback=va_arg(args,int);
    va_end(args);
    return diag_read(env,cls,method,content,key,fallback);
}
int32_t diag_int_a(void *env,void *cls,void *method,const diag_value *args) {
    ++operations;
    if (!args) { ++bad_calls; return -1; }
    return diag_read(env,cls,method,args[0].l,args[1].l,args[2].i);
}
static int valid_string(const char *s) {
    for (int i=0;i<string_count;++i) if (s && strings[i]==s) return 1;
    return 0;
}
int32_t diag_utf_length(void *env,void *string) {
    (void)env; ++operations;
    if (pending || !valid_string(string)) { ++bad_calls; return 0; }
    return (int32_t)strlen(string);
}
const char *diag_utf_chars(void *env,void *string,unsigned char *copy) {
    (void)env; (void)copy; ++operations;
    if (pending || !valid_string(string)) { ++bad_calls; return NULL; }
    ++utf_acquired; return string;
}
void diag_utf_release(void *env,void *string,const char *chars) {
    (void)env;
    if (string!=chars || !valid_string(string)) { ++bad_calls; return; }
    ++utf_released;
}
