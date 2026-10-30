-- Real LuaJIT FFI + the pinned official JNI layouts/context/legacy helper.
-- The C table is a harmless host stand-in, NOT Android or a hardware test.
local ffi=require("ffi")
local refs=assert(arg[1],"pass pinned reference directory")
local function read(path) local f=assert(io.open(path,"rb")); local x=f:read("*a"); f:close(); return x end
local source=read(refs .. "/android.lua")
local kotlin=read(refs .. "/MainActivity.kt")
assert(kotlin:find("fun canWriteSystemSettings()",1,true))
assert(not kotlin:find("fun hasWriteSettingsPermission(",1,true))
ffi.cdef(assert(source:match("ffi%.cdef%[%[(.-)%]%]")))
ffi.cdef[[
void compat_jni_reset(int); void compat_jni_set_env(void *); void *compat_jni_activity(void);
int compat_jni_counter(int); int compat_jni_get_env(void *,void **,int);
int compat_jni_attach(void *,void **,void *); int compat_jni_detach(void *);
unsigned char compat_jni_exception(void *); void compat_jni_clear(void *); void compat_jni_delete(void *,void *);
void *compat_jni_class(void *,void *); void *compat_jni_find(void *,const char *);
void *compat_jni_method(void *,void *,const char *,const char *);
void *compat_jni_static_method(void *,void *,const char *,const char *);
void *compat_jni_call_object(void *,void *,void *,...);
unsigned char compat_jni_call_boolean(void *,void *,void *,...);
unsigned char compat_jni_call_static_boolean(void *,void *,void *,...);
void *compat_jni_string(void *,const char *); int32_t compat_jni_call_int(void *,void *,void *,...);
]]
local lib=ffi.load(assert(os.getenv("BIGME_JNI_FIXTURE")))
local api=ffi.new("struct JNINativeInterface[1]")
local function bind(field,fn) api[0][field]=ffi.cast(ffi.typeof(api[0][field]),fn) end
bind("ExceptionCheck",lib.compat_jni_exception); bind("ExceptionClear",lib.compat_jni_clear)
bind("DeleteLocalRef",lib.compat_jni_delete); bind("GetObjectClass",lib.compat_jni_class)
bind("FindClass",lib.compat_jni_find); bind("GetMethodID",lib.compat_jni_method)
bind("GetStaticMethodID",lib.compat_jni_static_method); bind("CallObjectMethod",lib.compat_jni_call_object)
bind("CallBooleanMethod",lib.compat_jni_call_boolean); bind("CallStaticBooleanMethod",lib.compat_jni_call_static_boolean)
bind("NewStringUTF",lib.compat_jni_string); bind("CallStaticIntMethod",lib.compat_jni_call_int)
local env=ffi.new("JNIEnv[1]",ffi.cast("JNIEnv",api))
lib.compat_jni_set_env(env)
local vm_api=ffi.new("struct JNIInvokeInterface[1]")
vm_api[0].GetEnv=ffi.cast(ffi.typeof(vm_api[0].GetEnv),lib.compat_jni_get_env)
vm_api[0].AttachCurrentThread=ffi.cast(ffi.typeof(vm_api[0].AttachCurrentThread),lib.compat_jni_attach)
vm_api[0].DetachCurrentThread=ffi.cast(ffi.typeof(vm_api[0].DetachCurrentThread),lib.compat_jni_detach)
local vm=ffi.new("JavaVM[1]",ffi.cast("JavaVM",vm_api))
local JNI={}
local android={app={activity={vm=vm,clazz=lib.compat_jni_activity()}},DEBUG=function() end,
    prop={manufacturer="bigme",brand="bigme",model="hibreak",product="hibreak_eea",hardware="mt6877"},jni=JNI}
local code_env=setmetatable({ffi=ffi,C=ffi.C,JNI=JNI,android=android},{__index=_G})
local function load_source(code)
    local chunk=assert(loadstring(code)); setfenv(chunk,code_env); chunk()
end
load_source(assert(source:match("(function JNI:context%(.-)\nfunction JNI:callVoidMethod")))
load_source(assert(source:match("(function JNI:callBooleanMethod%(.-)\nfunction JNI:callStaticBooleanMethod")))
load_source(assert(source:match("(    android%.canWriteSettings = function%(.-)\n\n    android%.getClipboardText")))

-- Negative control: execute the unchanged legacy bridge and observe its null
-- call in C. The stand-in returns safely where Android would abort the process.
lib.compat_jni_reset(0)
assert(android.canWriteSettings()==false and lib.compat_jni_counter(2)==1)
assert(lib.compat_jni_counter(4)==lib.compat_jni_counter(5))
api[0].ExceptionClear(env)
print("PASS original official legacy permission helper reaches a NULL JNI method (safe host reproduction)")

local passed=1
for mode=0,5 do
    lib.compat_jni_reset(mode)
    local PowerD={}
    local powerd=setmetatable({stateChanged=function() end,updateResumeFrontlightState=function() end},PowerD)
    local Device={isAndroid=function() return true end,getPowerDevice=function() return powerd end}
    local hardware=0
    local function forbidden() hardware=hardware+1; error("No hardware command permitted in startup test") end
    local warnings={}
    local fwrap={os="Linux",arch="arm64",new=ffi.new,sizeof=ffi.sizeof,NULL=ffi.cast("void*",0),
        C={O_WRONLY=1,getpid=function() return 17318 end,getuid=function() return 10203 end,
            open=forbidden,ioctl=forbidden,close=forbidden},errno=ffi.errno}
    local modules={android=android,ffi=fwrap,["ffi/posix_h"]=true,device=Device,["device/android/powerd"]=PowerD,
        logger={info=function() end},["ui/uimanager"]={scheduleIn=function(_,_,fn) fn() end,
            show=function(_,message) warnings[#warnings+1]=message end},
        ["ui/widget/infomessage"]={new=function(_,attrs) return attrs end}}
    local sandbox=setmetatable({require=function(name) return assert(modules[name],name) end,
        io={open=function(path)
            assert(path=="/proc/self/attr/current")
            return {read=function() return "u:r:untrusted_app_30:s0\n" end,close=function() return true end}
        end},G_reader_settings={readSetting=function() return nil end}},{__index=_G})
    sandbox._G=sandbox
    local patch=assert(loadfile(os.getenv("BIGME_PATCH") or "2-bigme-frontlight.lua"))
    setfenv(patch,sandbox); patch()
    assert((powerd._bigme_lm3630a~=nil)==(mode==0),"Unexpected activation for mode " .. mode)
    if mode==0 then assert(powerd:frontlightIntensity()==12 and powerd:frontlightWarmthHW()==13) end
    assert(hardware==0 and lib.compat_jni_counter(2)==0,"Invalid JNI call or hardware I/O")
    assert(lib.compat_jni_counter(0)==lib.compat_jni_counter(1),"Leaked local reference")
    assert(lib.compat_jni_counter(4)==lib.compat_jni_counter(5),"Unbalanced attach/detach")
    assert(lib.compat_jni_counter(6)==0 and JNI.env==nil,"Pending exception or attached context")
    assert(#warnings==(mode==0 and 0 or 1))
    print("PASS actual JNI layout/context/C varargs: startup/denied/missing/exception mode " .. mode)
    passed=passed+1
end
lib.compat_jni_reset(0)
print(passed .. " JNI boundary tests passed; no real JVM, device or user data accessed")
