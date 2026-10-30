/* Host-only FFI fixture, MIT. No file/device access or real ioctl/JNI calls. */
#include <errno.h>
#include <stdint.h>
#include <stdarg.h>
#include <string.h>
static int open_error, ioctl_error, close_error, opens, closes, count;
static int requests[80], values[80];
void compat_reset(int oe,int ie,int ce) { open_error=oe;ioctl_error=ie;close_error=ce;opens=closes=count=0; }
unsigned int compat_getuid(void) { return 10203; }
int compat_getpid(void) { return 17318; }
int compat_opens(void) { return opens; }
int compat_closes(void) { return closes; }
int compat_commands(void) { return count; }
int compat_request(int n) { return n>=0 && n<count ? requests[n] : -1; }
int compat_value(int n) { return n>=0 && n<count ? values[n] : -1; }
int compat_open(const char *path,int flags,...) {
    ++opens;
    if (strcmp(path,"/dev/lm3630a") || flags!=1) { errno=EINVAL;return -1; }
    if (open_error) { errno=open_error;return -1; }
    return 47;
}
int compat_ioctl(int fd,int request,...) {
    va_list args;va_start(args,request);void *p=va_arg(args,void *);va_end(args);
    if (fd!=47 || (request!=0x7901 && request!=0x7902) || !p || count>=80) { errno=EINVAL;return -1; }
    requests[count]=request;values[count++]=*(int32_t *)p;
    if (ioctl_error) { errno=ioctl_error;return -1; }
    return 0;
}
int compat_close(int fd) {
    ++closes;
    if (fd!=47) { errno=EBADF;return -1; }
    if (close_error) { errno=close_error;return -1; }
    errno=999;return 0;
}
