-- MIT. Real LuaJIT JNI layout/context against a host C stand-in, not Android.
local ffi=require("ffi")
local function read(path) local f=assert(io.open(path,"rb")); local s=f:read("*a"); f:close(); return s end
local source=read(".cache/upstream/android.lua")
ffi.cdef(assert(source:match("ffi%.cdef%[%[(.-)%]%]")))
ffi.cdef[[
void diag_reset(int); int diag_counter(int);
void compat_jni_set_env(void *); void *compat_jni_activity(void); int compat_jni_counter(int);
int compat_jni_get_env(void *,void **,int); int compat_jni_attach(void *,void **,void *);
int compat_jni_detach(void *); unsigned char compat_jni_exception(void *);
void compat_jni_clear(void *); void compat_jni_delete(void *,void *);
void *diag_exception(void *); void *diag_class(void *,void *);
void *diag_find(void *,const char *); void *diag_method(void *,void *,const char *,const char *);
void *diag_static_method(void *,void *,const char *,const char *);
void *diag_string(void *,const char *); void *diag_object(void *,void *,void *,...);
void *diag_object_a(void *,void *,void *,const jvalue *);
unsigned char diag_boolean(void *,void *,void *,...);
unsigned char diag_boolean_a(void *,void *,void *,const jvalue *);
int32_t diag_int(void *,void *,void *,...); int32_t diag_int_a(void *,void *,void *,const jvalue *);
int32_t diag_utf_length(void *,void *); const char *diag_utf_chars(void *,void *,unsigned char *);
void diag_utf_release(void *,void *,const char *);
]]
local lib=ffi.load(assert(os.getenv("BIGME_DIAG_FIXTURE")))
local api=ffi.new("struct JNINativeInterface[1]")
for field,name in pairs({ExceptionCheck="compat_jni_exception",ExceptionClear="compat_jni_clear",
    DeleteLocalRef="compat_jni_delete",ExceptionOccurred="diag_exception",GetObjectClass="diag_class",
    FindClass="diag_find",GetMethodID="diag_method",GetStaticMethodID="diag_static_method",
    NewStringUTF="diag_string",CallObjectMethod="diag_object",CallObjectMethodA="diag_object_a",
    CallStaticBooleanMethod="diag_boolean",CallStaticBooleanMethodA="diag_boolean_a",
    CallStaticIntMethod="diag_int",CallStaticIntMethodA="diag_int_a",
    GetStringUTFLength="diag_utf_length",GetStringUTFChars="diag_utf_chars",ReleaseStringUTFChars="diag_utf_release",
}) do api[0][field]=ffi.cast(ffi.typeof(api[0][field]),lib[name]) end
local env=ffi.new("JNIEnv[1]",ffi.cast("JNIEnv",api)); lib.compat_jni_set_env(env)
local vm_api=ffi.new("struct JNIInvokeInterface[1]")
for field,name in pairs({GetEnv="compat_jni_get_env",AttachCurrentThread="compat_jni_attach",DetachCurrentThread="compat_jni_detach"}) do
    vm_api[0][field]=ffi.cast(ffi.typeof(vm_api[0][field]),lib[name])
end
local vm=ffi.new("JavaVM[1]",ffi.cast("JavaVM",vm_api))
local JNI={}
local context=assert(loadstring(assert(source:match("(function JNI:context%(.-)\nfunction JNI:callVoidMethod"))))
setfenv(context,setmetatable({ffi=ffi,C=ffi.C,JNI=JNI},{__index=_G})); context()
local diag_path=os.getenv("BIGME_DIAG_PATCH") or "diagnostics/android-settings-readonly/2-bigme-settings-readonly-diagnostic.lua"
local diag_source=read(diag_path)
for _,token in ipairs({"C.open", "C.ioctl", "os.execute", "io.popen", "putInt", "saveSetting", "requestPermission", "device/android/powerd"}) do
    assert(not diag_source:find(token,1,true),"Forbidden production operation: "..token)
end

local count=0
local function test(name,fn)
    fn(); count=count+1; print("PASS "..name)
end
local function fixture(options)
    local opt=options or {}; lib.diag_reset(opt.mode or 0)
    local state={log="",queue={},shown={},pid=17318,writes=0,closed=0,contexts=0}
    local UI={}
    function UI:scheduleIn(_,fn) state.queue[#state.queue+1]=fn end
    function UI:show(widget) state.shown[#state.shown+1]=widget; state.top=widget end
    function UI:close(widget)
        state.closed=state.closed+1; if state.top==widget then state.top=nil end
        if widget.onCloseWidget then widget:onCloseWidget() end
    end
    function UI:getTopmostVisibleWidget() return state.top end
    local function pump()
        local max=20
        while #state.queue>0 do max=max-1; assert(max>0,"Unexpected polling"); table.remove(state.queue,1)() end
    end
    local android={prop={manufacturer="bigme",brand="bigme",model="hibreak",product="hibreak_eea",hardware="mt6877"},
        app={activity={vm=vm,clazz=lib.compat_jni_activity()}},jni={context=function(_,jvm,fn)
            state.contexts=state.contexts+1; return JNI:context(jvm,fn)
        end}}
    if opt.model then android.prop.model=opt.model end
    if opt.missing_context then android.jni={} end
    if opt.missing_activity then android.app.activity=nil end
    local fwrap={os=opt.os or "Linux",arch=opt.arch or "arm64",new=ffi.new,string=ffi.string,NULL=ffi.cast("void*",0),
        C=setmetatable({getpid=function() return state.pid end,getuid=function() return opt.uid or 10203 end},
        {__index=function(_,key) error("Forbidden C call: "..key) end})}
    local function widget(_,attrs) assert(attrs.sui_native==true); return attrs end
    local modules={android=android,ffi=fwrap,["ffi/posix_h"]=true,["ui/uimanager"]=UI,
        datastorage={getDataDir=function() return "/fixture" end},
        ["ui/widget/buttondialog"]={new=widget},["ui/widget/infomessage"]={new=widget}}
    local sandbox=setmetatable({
        require=function(name) return assert(modules[name],"Forbidden module: "..name) end,
        G_reader_settings={readSetting=function(_,key) assert(key=="language"); return opt.language or "sv" end},
        io={open=function(path,mode)
            if path=="/fixture/bigme-settings-readonly-diagnostic.log" then
                assert(mode=="a"); if opt.log_failure then return nil,"Simulated log error" end
                return {
                    seek=function(_,where) assert(where=="end"); return opt.log_full and 262145 or #state.log end,
                    write=function(_,value) assert(value:sub(-1)=="\n"); state.writes=state.writes+1; state.log=state.log..value; return true end,
                    close=function() return true end,
                }
            elseif path=="/proc/self/attr/current" then
                assert(mode=="r"); return {read=function(_,n) assert(n==256); return opt.context or "u:r:untrusted_app_30:s0" end,close=function() return true end}
            elseif path:match("^/fixture/patches/2%-bigme%-frontlight.*%.lua$") then
                assert(mode=="rb")
                if path=="/fixture/patches/"..tostring(opt.active) then return {close=function() return true end} end
                return nil,"Not found"
            end
            error("Forbidden file access: "..path)
        end},
    },{__index=_G}); sandbox._G=sandbox
    local patch=assert(loadfile(diag_path)); setfenv(patch,sandbox); patch()
    assert(state.contexts==0 and state.writes==0 and lib.diag_counter(3)==0,"Native test ran before user consent")
    state.pump=pump
    function state:prompt() pump(); return self.shown[1] end
    function state:run()
        local prompt=self:prompt(); assert(prompt and prompt.title:find("Bigme",1,true))
        prompt.buttons[1][1].callback(); pump()
        assert(#self.shown==2,"Result dialog missing")
        return prompt,self.shown[2]
    end
    function state:balanced()
        assert(lib.compat_jni_counter(2)==0,"Invalid JNI call")
        assert(lib.compat_jni_counter(0)==lib.compat_jni_counter(1),"Local JNI references leaked")
        assert(lib.diag_counter(1)==lib.diag_counter(2),"UTF chars leaked")
        assert(lib.compat_jni_counter(4)==lib.compat_jni_counter(5),"Unbalanced thread attach/detach")
        assert(lib.compat_jni_counter(6)==0 and JNI.env==nil,"Pending exception/context leaked")
    end
    return state
end

test("explicit run, native prompt text, VARARGS + ARRAY values, no settings/hardware operations",function()
    local s=fixture(); local p,result=s:run()
    assert(p.title:find("Detta test läser bara",1,true) and p.buttons[1][1].text=="Kör avläsning")
    assert(s.contexts==2 and lib.diag_counter(0)==10)
    for _,style in ipairs({"VARARGS","ARRAY"}) do
        assert(s.log:find(style.." COMPLETE",1,true))
        for _,value in ipairs({"canWrite=1","ColdValue=12","WarmValue=13","screen_brightness_cold=114","screen_brightness_warm=120","LightMode=4"}) do
            assert(s.log:find(style.." VALUE | "..value,1,true),value)
        end
    end
    assert(result.text:find("VARARGS: OK",1,true) and result.text:find("ARRAY: OK",1,true))
    assert(not s.log:find("unavailable",1,true)); s:balanced()
    local before=s.contexts; p.buttons[1][1].callback(); s.pump(); assert(s.contexts==before)
end)
for mode=1,9 do test("checked JNI error and cleanup mode "..mode,function()
    local s=fixture{mode=mode}; s:run(); s:balanced()
    assert(s.log:find("ERROR",1,true) and s.log:find("END | No hardware",1,true))
    if mode==1 or mode==3 or mode==4 or mode==6 or mode==8 or mode==9 then
        assert(s.log:find("java.lang.SecurityException: diagnostic simulated denial",1,true))
    end
    if mode==5 then assert(s.log:find("Null JNI result",1,true)) end
    if mode==7 then
        assert(s.log:find("Settings.System.getInt(ColdValue)",1,true))
        assert(s.log:find("could not format Throwable",1,true))
    end
    if mode==8 then assert(s.log:find("VARARGS ERROR",1,true) and s.log:find("ARRAY COMPLETE",1,true)) end
    if mode==9 then assert(s.log:find("pre-existing Java exception",1,true)) end
    if mode==2 then assert(lib.diag_counter(0)==0 and s.log:find("WRITE_SETTINGS denied",1,true)) end
end) end
for _,name in ipairs({"2-bigme-frontlight.lua","2-bigme-frontlight-access-diagnostic.lua","2-bigme-frontlight-manual-test.lua","2-bigme-frontlight-warm-test.lua"}) do
    test("active patch blocks all JNI: "..name,function()
        local s=fixture{active=name}; s:run(); assert(s.contexts==0 and s.log:find("Disable active patch",1,true)); s:balanced()
    end)
end
for _,opt in ipairs({{uid=2000},{context="u:r:shell:s0"},{missing_context=true},{missing_activity=true},{log_failure=true},{log_full=true}}) do
    test("unsafe context or unsaved report blocks JNI",function()
        local s=fixture(opt); s:run(); assert(s.contexts==0); s:balanced()
    end)
end
test("English consent and result",function()
    local s=fixture{language="en_US"}; local p,result=s:run()
    assert(p.title:find("This test only reads",1,true) and p.buttons[1][1].text=="Run read-only test")
    assert(result.text:find("Send the log:",1,true)); s:balanced()
end)
test("dismissal, stale callback and unrelated topmost dialog never run JNI",function()
    local s=fixture(); local p=s:prompt(); p.buttons[2][1].callback(); p.buttons[1][1].callback(); s.pump()
    assert(s.contexts==0 and s.writes==0); s:balanced()
    s=fixture(); p=s:prompt(); s.top={}; p.buttons[1][1].callback(); s.pump(); assert(s.contexts==0); s:balanced()
    s=fixture(); p=s:prompt(); p:onCloseWidget(); p.buttons[1][1].callback(); s.pump(); assert(s.contexts==0); s:balanced()
end)
test("child PID never runs a captured callback",function()
    local s=fixture(); local p=s:prompt(); s.pid=17400; p.buttons[1][1].callback(); s.pump(); assert(s.contexts==0 and s.writes==0); s:balanced()
    s=fixture(); s.pid=17400; s.pump(); assert(#s.shown==0 and s.contexts==0); s:balanced()
end)
for _,opt in ipairs({{model="other"},{os="OSX"},{arch="x64"}}) do test("unsupported profile is inert",function()
    local s=fixture(opt); s.pump(); assert(#s.shown==0 and s.contexts==0 and s.writes==0); s:balanced()
end) end
lib.diag_reset(0)
print(count.." diagnostic host tests passed; not an Android/hardware acceptance test")
