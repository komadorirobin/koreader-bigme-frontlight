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
int compat_jni_value(const char *);
int compat_jni_attach(void *,void **,void *); int compat_jni_detach(void *);
unsigned char compat_jni_exception(void *); void compat_jni_clear(void *); void compat_jni_delete(void *,void *);
void *compat_jni_class(void *,void *); void *compat_jni_find(void *,const char *);
void *compat_jni_method(void *,void *,const char *,const char *);
void *compat_jni_static_method(void *,void *,const char *,const char *);
void *compat_jni_call_object(void *,void *,void *,...);
unsigned char compat_jni_call_boolean(void *,void *,void *,...);
unsigned char compat_jni_call_static_boolean(void *,void *,void *,...);
void *compat_jni_string(void *,const char *); int32_t compat_jni_call_int(void *,void *,void *,...);
void *compat_jni_exception_object(void *); void *compat_jni_call_object_a(void *,void *,void *,const void *);
int32_t compat_jni_utf_length(void *,void *); const char *compat_jni_utf_chars(void *,void *,unsigned char *);
void compat_jni_utf_release(void *,void *,const char *);
]]
local lib=ffi.load(assert(os.getenv("BIGME_JNI_FIXTURE")))
local api=ffi.new("struct JNINativeInterface[1]")
local function bind(field,fn) api[0][field]=ffi.cast(ffi.typeof(api[0][field]),fn) end
bind("ExceptionCheck",lib.compat_jni_exception); bind("ExceptionClear",lib.compat_jni_clear)
bind("ExceptionOccurred",lib.compat_jni_exception_object)
bind("DeleteLocalRef",lib.compat_jni_delete); bind("GetObjectClass",lib.compat_jni_class)
bind("FindClass",lib.compat_jni_find); bind("GetMethodID",lib.compat_jni_method)
bind("GetStaticMethodID",lib.compat_jni_static_method); bind("CallObjectMethod",lib.compat_jni_call_object)
bind("CallBooleanMethod",lib.compat_jni_call_boolean); bind("CallStaticBooleanMethod",lib.compat_jni_call_static_boolean)
bind("NewStringUTF",lib.compat_jni_string); bind("CallStaticIntMethod",lib.compat_jni_call_int)
bind("CallObjectMethodA",lib.compat_jni_call_object_a); bind("GetStringUTFLength",lib.compat_jni_utf_length)
bind("GetStringUTFChars",lib.compat_jni_utf_chars); bind("ReleaseStringUTFChars",lib.compat_jni_utf_release)
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
if os.getenv("BIGME_PROVIDER_DRIVER")=="1" then
    print("1 legacy JNI negative-control test passed; provider driver uses the separate typed A-array fixture")
    return
end

local passed=1
for mode=0,10 do
    lib.compat_jni_reset(mode)
    local PowerD={}
    local powerd=setmetatable({stateChanged=function() end,updateResumeFrontlightState=function() end},PowerD)
    local Device={isAndroid=function() return true end,getPowerDevice=function() return powerd end}
    local hardware,closes=0,0
    local commands={}
    local warnings={}
    local fwrap={os="Linux",arch="arm64",new=ffi.new,sizeof=ffi.sizeof,string=ffi.string,NULL=ffi.cast("void*",0),
        C={O_WRONLY=1,getpid=function() return 17318 end,getuid=function() return 10203 end,
            open=function(path,flags)
                assert(path=="/dev/lm3630a" and flags==1); hardware=hardware+1; return 47
            end,
            ioctl=function(fd,request,pointer)
                assert(fd==47 and (request==0x7901 or request==0x7902))
                assert(ffi.istype("int32_t[1]",pointer)); commands[#commands+1]={request=request,value=tonumber(pointer[0])}; return 0
            end,
            close=function(fd) assert(fd==47); closes=closes+1; return 0 end},errno=ffi.errno}
    local modules={android=android,ffi=fwrap,["ffi/posix_h"]=true,device=Device,["device/android/powerd"]=PowerD,
        datastorage={getDataDir=function() return "/fixture" end},
        logger={info=function() end},["ui/uimanager"]={scheduleIn=function(_,_,fn) fn() end,
            show=function(_,message) warnings[#warnings+1]=message end},
        ["ui/widget/infomessage"]={new=function(_,attrs) return attrs end}}
    local sandbox=setmetatable({require=function(name) return assert(modules[name],name) end,
        io={open=function(path,mode)
            if path:match("^/fixture/patches/2%-bigme%-.+%.lua$") then assert(mode=="rb"); return nil,"not found" end
            if path=="/fixture/bigme-frontlight-local-test.log" then
                assert(mode=="a"); return {seek=function() return 0 end,write=function() return true end,close=function() return true end}
            end
            assert(path=="/proc/self/attr/current")
            return {read=function() return "u:r:untrusted_app_30:s0\n" end,close=function() return true end}
        end},G_reader_settings={readSetting=function() return nil end}},{__index=_G})
    sandbox._G=sandbox
    if mode==6 and os.getenv("BIGME_BASELINE_PATCH") then
        local baseline=assert(loadfile(os.getenv("BIGME_BASELINE_PATCH")))
        setfenv(baseline,sandbox); baseline()
        assert(not powerd._bigme_lm3630a and hardware==0 and #warnings==1)
        assert(lib.compat_jni_counter(8)==1 and lib.compat_jni_counter(3)==1,"Beta 2 must reproduce protected-key failure despite canWrite=1")
        assert(lib.compat_jni_counter(0)==lib.compat_jni_counter(1) and lib.compat_jni_counter(4)==lib.compat_jni_counter(5))
        print("PASS unchanged Beta 2 reproduces device protected-read failure despite permission; local candidate tested next")
        passed=passed+1; lib.compat_jni_reset(mode); warnings={}
    end
    local patch=assert(loadfile(os.getenv("BIGME_PATCH") or "2-bigme-frontlight.lua"))
    setfenv(patch,sandbox); patch()
    local activates=mode==0 or (mode>=6 and mode<=9)
    assert((powerd._bigme_lm3630a~=nil)==activates,"Unexpected activation for mode " .. mode)
    if activates then assert(powerd:frontlightIntensity()==12 and powerd:frontlightWarmthHW()==13) end
    assert(hardware==0 and lib.compat_jni_counter(7)==0,"Unexpected hardware/settings I/O at startup")
    if mode>=6 and mode<=9 then
        local accepted=powerd:setIntensity(26)
        assert(accepted==(mode==6))
        assert(lib.compat_jni_counter(8)==0,"Protected raw-key read attempted")
        if mode==6 then
            assert(hardware==1 and closes==1 and #commands==1 and commands[1].value==198)
            assert(lib.compat_jni_value("ColdValue")==26 and lib.compat_jni_value("screen_brightness_cold")==198)
            assert(lib.compat_jni_value("LightUser_Brightness")==26 and lib.compat_jni_counter(7)==9)
            assert(powerd:setWarmth(powerd:fromNativeWarmth(30)))
            assert(#commands==2 and commands[2].request==0x7902 and commands[2].value==210)
            assert(lib.compat_jni_value("WarmValue")==30 and lib.compat_jni_value("LightUser_ColorTemp")==30)
        else
            assert(hardware==0 and closes==0 and lib.compat_jni_counter(7)==0)
            assert(powerd._bigme_lm3630a.fault:find("putInt(screen_brightness_cold)",1,true))
            if mode==7 then assert(powerd._bigme_lm3630a.fault:find("java.lang.SecurityException",1,true)) end
            if mode==9 then assert(powerd._bigme_lm3630a.fault:find("Throwable unavailable",1,true)) end
        end
    end
    assert(lib.compat_jni_counter(2)==0,"Invalid JNI call")
    assert(lib.compat_jni_counter(0)==lib.compat_jni_counter(1),"Leaked local reference")
    assert(lib.compat_jni_counter(4)==lib.compat_jni_counter(5),"Unbalanced attach/detach")
    assert(lib.compat_jni_counter(6)==0 and JNI.env==nil,"Pending exception or attached context")
    assert(lib.compat_jni_counter(9)==lib.compat_jni_counter(10),"Leaked UTF chars")
    assert(#warnings==((mode==0 or mode==6) and 0 or 1))
    print("PASS actual JNI layout/context/C varargs: startup/denied/missing/exception mode " .. mode)
    passed=passed+1
end
lib.compat_jni_reset(0)
print(passed .. " JNI boundary tests passed; no real JVM, device or user data accessed")
