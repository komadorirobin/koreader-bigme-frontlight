-- MIT. Real pinned JNI layout/context + typed LuaJIT FFI callbacks.
-- No JVM, Android device, settings provider, user data or hardware is accessed.
local ffi=require("ffi")
local fixture_mode,override_path=...
require("jit").off()
local function read(path) local f=assert(io.open(path,"rb")); local s=f:read("*a"); f:close(); return s end
local source=read(".cache/upstream/android.lua")
ffi.cdef(assert(source:match("ffi%.cdef%[%[(.-)%]%]")))
local path=override_path or os.getenv("BIGME_PROVIDER_PATCH") or "diagnostics/provider-current-values/2-bigme-settings-provider-test.lua"
local patch_source=read(path)
for _,forbidden in ipairs({"C.open","C.ioctl","ffi.load","os.execute","io.popen","saveSetting","requestPermission",
    "screen_brightness_","setting_put_secure","setting_put_global","device/android/powerd"}) do
    local driver_allowed=fixture_mode=="driver_fixture" and (forbidden=="C.open" or forbidden=="C.ioctl"
        or forbidden=="saveSetting" or forbidden=="screen_brightness_" or forbidden=="device/android/powerd")
    assert(driver_allowed or not patch_source:find(forbidden,1,true),forbidden)
end
local null=ffi.cast("void*",0)
local api=ffi.new("struct JNINativeInterface[1]")
local env=ffi.new("JNIEnv[1]",ffi.cast("JNIEnv",api))
local vm_api=ffi.new("struct JNIInvokeInterface[1]")
local vm=ffi.new("JavaVM[1]",ffi.cast("JavaVM",vm_api))
local callbacks={}
local s
local function ptr(v) return tostring(ffi.cast("void*",v)) end
local function object(v) assert(v~=nil and v~=null,"NULL object used"); return assert(s.objects[ptr(v)],"Unknown object") end
local function token(data,local_ref)
    local buffer=ffi.new("int8_t[1]")
    data.buffer=buffer; data.local_ref=local_ref; data.deleted=false
    local ref=ffi.cast("void*",buffer); s.objects[ptr(ref)]=data
    if local_ref then s.refs=s.refs+1 end
    return ref
end
local function ref(class,data) return token({class=class,data=data},true) end
local function string_ref(value)
    local chars=ffi.new("char[?]",#value+1); ffi.copy(chars,value)
    return token({class="java/lang/String",value=value,chars=chars},true)
end
local function jstring(v) local o=object(v); assert(o.class=="java/lang/String" and not o.deleted); return o.value end
local function usable(v) local o=object(v); assert(not o.deleted); return o end
local function before() assert(not s.pending,"JNI called with a pending exception"); s.ops=s.ops+1 end
local signatures={
    canWrite="(Landroid/content/Context;)Z",
    getContentResolver="()Landroid/content/ContentResolver;",getPackageManager="()Landroid/content/pm/PackageManager;",
    resolveContentProvider="(Ljava/lang/String;I)Landroid/content/pm/ProviderInfo;",checkSelfPermission="(Ljava/lang/String;)I",
    getInt="(Landroid/content/ContentResolver;Ljava/lang/String;I)I",parse="(Ljava/lang/String;)Landroid/net/Uri;",
    ["<init>"]="()V",putString="(Ljava/lang/String;Ljava/lang/String;)V",putInt="(Ljava/lang/String;I)V",
    containsKey="(Ljava/lang/String;)Z",call="(Landroid/net/Uri;Ljava/lang/String;Ljava/lang/String;Landroid/os/Bundle;)Landroid/os/Bundle;",
    toString="()Ljava/lang/String;",
}
local field_sigs={packageName="Ljava/lang/String;",name="Ljava/lang/String;",authority="Ljava/lang/String;",exported="Z",enabled="Z",
    applicationInfo="Landroid/content/pm/ApplicationInfo;",flags="I",readPermission="Ljava/lang/String;",writePermission="Ljava/lang/String;"}
local function bind(table,name,fn,default)
    local cb=ffi.cast(ffi.typeof(table[0][name]),function(...)
        local ok,value=pcall(fn,...)
        if not ok then s.bad=s.bad+1; s.last_error="Host fixture error in "..name..": "..tostring(value); s.pending=s.last_error; return default end
        return value
    end)
    callbacks[#callbacks+1]=cb; table[0][name]=cb
end
bind(vm_api,"GetEnv",function(_,out,version) assert(version==0x10006); ffi.cast("void**",out)[0]=env; return 0 end,-1)
bind(vm_api,"AttachCurrentThread",function(_,out) s.attaches=s.attaches+1; out[0]=env; return 0 end,-1)
bind(vm_api,"DetachCurrentThread",function() s.detaches=s.detaches+1; return 0 end,-1)
bind(api,"ExceptionCheck",function() return s.pending and 1 or 0 end,0)
bind(api,"ExceptionClear",function() s.pending=nil end)
bind(api,"ExceptionOccurred",function() assert(s.pending); return ref("java/lang/Throwable",{message=s.pending}) end,null)
bind(api,"DeleteLocalRef",function(_,v)
    local o=usable(v); assert(o.local_ref); o.deleted=true; s.deletes=s.deletes+1
end)
bind(api,"FindClass",function(_,name) before(); return ref("Class",{name=ffi.string(name)}) end,null)
bind(api,"GetObjectClass",function(_,v) before(); return ref("Class",{name=usable(v).class}) end,null)
local function method(_,class,name,sig,static)
    before(); local owner=usable(class).data.name; name=ffi.string(name); sig=ffi.string(sig)
    local expected=signatures[name]
    if owner=="android/os/Bundle" and name=="getInt" then expected="(Ljava/lang/String;I)I" end
    assert(expected==sig,"Unexpected method signature: "..name..sig)
    if s.opt.missing_method==name or (s.opt.throwable_failure and name=="toString") then
        s.pending="java.lang.NoSuchMethodError: "..name; return null
    end
    return token({class="Method",name=name,owner=owner,static=static},false)
end
bind(api,"GetMethodID",function(...) return method(...) end,null)
bind(api,"GetStaticMethodID",function(env,class,name,sig) return method(env,class,name,sig,true) end,null)
bind(api,"GetFieldID",function(_,class,name,sig)
    before(); usable(class); name=ffi.string(name); assert(field_sigs[name]==ffi.string(sig))
    if s.opt.missing_field==name then s.pending="java.lang.NoSuchFieldError: "..name; return null end
    return token({class="Field",name=name},false)
end,null)
local function field(v,id) usable(v); return usable(id).name end
bind(api,"GetObjectField",function(_,v,id)
    before(); local name=field(v,id)
    if name=="applicationInfo" then return ref("android/content/pm/ApplicationInfo",{}) end
    local values={packageName=s.opt.package or "com.xrz.settings",name=s.opt.provider_class or "com.xrz.settings.provider.SettingProvider",
        authority=s.opt.authority or "com.xrz.SettingProvider",readPermission=s.opt.read_permission,writePermission=s.opt.write_permission}
    return values[name] and string_ref(values[name]) or null
end,null)
bind(api,"GetIntField",function(_,v,id) before(); assert(field(v,id)=="flags"); return s.opt.flags or 1 end,0)
bind(api,"GetBooleanField",function(_,v,id)
    before(); local name=field(v,id); assert(name=="exported" or name=="enabled")
    return s.opt[name]==false and 0 or 1
end,0)
bind(api,"NewStringUTF",function(_,value) before(); return string_ref(ffi.string(value)) end,null)
bind(api,"GetStringUTFLength",function(_,v) before(); return #jstring(v) end,0)
bind(api,"GetStringUTFChars",function(_,v) before(); local o=usable(v); assert(o.chars); s.utf_gets=s.utf_gets+1; return o.chars end,null)
bind(api,"ReleaseStringUTFChars",function(_,v,chars)
    local o=usable(v); assert(ffi.cast("const char*",o.chars)==chars); s.utf_releases=s.utf_releases+1
end)
bind(api,"NewObjectA",function(_,class,id,args)
    before(); assert(usable(class).data.name=="android/os/Bundle" and usable(id).name=="<init>" and args==nil)
    return ref("android/os/Bundle",{})
end,null)
bind(api,"CallStaticObjectMethodA",function(_,class,id,args)
    before(); assert(usable(class).data.name=="android/net/Uri" and usable(id).name=="parse")
    local uri=jstring(args[0].l); assert(uri=="content://com.xrz.SettingProvider"); return ref("android/net/Uri",{uri=uri})
end,null)
bind(api,"CallStaticIntMethodA",function(_,class,id,args)
    before(); assert(usable(class).data.name=="android/provider/Settings$System" and usable(id).name=="getInt")
    assert(usable(args[0].l).class=="android/content/ContentResolver" and args[2].i==-1)
    local key=jstring(args[1].l); local allowed={ColdValue=true,WarmValue=true,LightMode=true,LightUser_Brightness=true,LightUser_ColorTemp=true}
    assert(allowed[key],"Forbidden settings read: "..key)
    s.reads=s.reads+1
    if s.opt.roundtrip and s.provider_calls==1 and key=="ColdValue" then
        s.post_change_reads=s.post_change_reads+1
        if s.opt.concurrent_before_restore and s.post_change_reads>=2 then s.settings.ColdValue=17 end
    end
    if s.opt.concurrent_before and s.reads==(s.settings.LightMode==4 and 6 or 4) then s.settings.ColdValue=s.settings.ColdValue+1 end
    if s.opt.roundtrip and ((s.opt.read_failure_after_change and s.provider_calls==1)
        or (s.opt.read_failure_after_restore and s.provider_calls==2)) then
        s.pending="java.lang.SecurityException: injected readback failure"; return -1
    end
    if s.opt.read_error==key then s.pending="java.lang.SecurityException: read denied"; return -1 end
    return s.settings[key] or -1
end,-1)
bind(api,"CallStaticBooleanMethodA",function(_,class,id,args)
    before(); assert(s.opt.driver and usable(class).data.name=="android/provider/Settings$System" and usable(id).name=="canWrite")
    assert(usable(args[0].l).class=="android/app/Activity")
    if s.opt.permission_error then s.pending="java.lang.SecurityException: permission failed"; return 0 end
    return s.opt.no_permission and 0 or 1
end,0)
bind(api,"CallVoidMethodA",function(_,v,id,args)
    before(); local bundle=usable(v); assert(bundle.class=="android/os/Bundle"); local name=usable(id).name
    local key=jstring(args[0].l)
    if name=="putString" then assert(key=="name"); bundle.data[key]=jstring(args[1].l)
    else assert(name=="putInt" and (key=="type" or key=="value")); bundle.data[key]=tonumber(args[1].i) end
end)
bind(api,"CallObjectMethodA",function(_,v,id,args)
    before(); local obj=usable(v); local name=usable(id).name
    if name=="getContentResolver" then assert(args==nil); return ref("android/content/ContentResolver",{}) end
    if name=="getPackageManager" then assert(args==nil); return ref("android/content/pm/PackageManager",{}) end
    if name=="resolveContentProvider" then
        assert(jstring(args[0].l)=="com.xrz.SettingProvider" and args[1].i==0)
        if s.opt.missing_provider then return null end
        return ref("android/content/pm/ProviderInfo",{})
    end
    if name=="toString" then assert(args==nil and obj.class=="java/lang/Throwable"); return string_ref(obj.data.message) end
    assert(name=="call" and obj.class=="android/content/ContentResolver")
    assert(usable(args[0].l).data.uri=="content://com.xrz.SettingProvider")
    assert(jstring(args[1].l)=="setting_put_data_system" and args[2].l==nil)
    local bundle=usable(args[3].l); assert(bundle.class=="android/os/Bundle")
    local data=bundle.data
    local allowed={ColdValue=true,WarmValue=true,LightUser_Brightness=true,LightUser_ColorTemp=true}
    if s.opt.roundtrip then
        local expected=s.provider_calls==0 and (s.original_cold>0 and s.original_cold-1 or 1) or s.original_cold
        assert(data.name=="ColdValue" and data.type==1 and data.value==expected and s.provider_calls<2,"Only the planned one-step change and one restoration may be sent")
        assert(s.journal and s.journal:find("PENDING",1,true),"Recovery record must precede mutation")
    elseif s.opt.driver then
        allowed.screen_brightness_cold=true; allowed.screen_brightness_warm=true
        assert(allowed[data.name] and data.type==1 and data.value==math.floor(data.value),"Unexpected driver write")
        if data.name:find("screen_brightness_",1,true) then
            local found=false; for _,v in ipairs(s.levels) do if data.value==v then found=true end end
            assert(found,"Raw value outside OEM table")
        else assert(data.value>=0 and data.value<=36) end
        assert(s.opens==s.closes,"Hardware descriptor must be closed before persistence")
    else assert(allowed[data.name] and data.type==1 and data.value==s.settings[data.name],"Only exact existing levels may be sent") end
    for key in pairs(data) do assert(key=="name" or key=="type" or key=="value") end
    s.provider_calls=s.provider_calls+1; s.called_keys[#s.called_keys+1]=data.name
    s.call_values[#s.call_values+1]=data.value
    if s.opt.provider_error or (s.opt.denied_write_key==data.name) or (s.opt.deny_after_hardware and #s.commands>0) then
        s.pending="java.lang.SecurityException: provider denied"; return null
    end
    if s.opt.driver and not s.opt.no_op and not (s.opt.ignore_raw and data.name:find("screen_brightness_",1,true)) then
        s.settings[data.name]=data.value
    end
    if s.opt.roundtrip then
        if s.provider_calls==2 and s.opt.restore_error then s.pending="java.lang.SecurityException: restore denied"; return null end
        if not s.opt.no_op then s.settings.ColdValue=data.value end
        if (s.provider_calls==1 and s.opt.change_applies_then_error) or (s.provider_calls==2 and s.opt.restore_applies_then_error) then
            s.pending="java.lang.SecurityException: injected error after persistence"; return null
        end
    end
    if s.opt.null_reply then return null end
    if s.opt.concurrent_after then s.settings.WarmValue=s.settings.WarmValue+1 end
    -- Intentionally do NOT mutate settings: a no-op provider must not be
    -- misrepresented as a proven successful writer by this same-value test.
    return ref("android/os/Bundle",s.opt.no_status and {} or {status=-1})
end,null)
bind(api,"CallBooleanMethodA",function(_,v,id,args)
    before(); assert(usable(id).name=="containsKey"); return usable(v).data[jstring(args[0].l)]~=nil and 1 or 0
end,0)
bind(api,"CallIntMethodA",function(_,v,id,args)
    before(); local name=usable(id).name; usable(v)
    if name=="checkSelfPermission" then s.permission_checks=s.permission_checks+1; jstring(args[0].l); return s.opt.permission_denied and -1 or 0 end
    assert(name=="getInt"); return usable(v).data[jstring(args[0].l)] or tonumber(args[1].i)
end,-1)
local JNI={}
local context=assert(loadstring(assert(source:match("(function JNI:context%(.-)\nfunction JNI:callVoidMethod"))))
setfenv(context,setmetatable({ffi=ffi,C=ffi.C,JNI=JNI},{__index=_G})); context()
local function fixture(options)
    s={opt=options or {},objects={},refs=0,deletes=0,utf_gets=0,utf_releases=0,ops=0,bad=0,attaches=0,detaches=0,
        provider_calls=0,called_keys={},call_values={},permission_checks=0,reads=0,post_change_reads=0,pid=17318,log="",log_writes=0,queue={},shown={},
        commands={},opens=0,closes=0,saved={}}
    local state=s; local opt=s.opt
    s.settings={ColdValue=27,WarmValue=13,LightMode=4,LightUser_Brightness=27,LightUser_ColorTemp=13}
    for key,value in pairs(opt.settings or {}) do s.settings[key]=value end
    s.original_cold=s.settings.ColdValue; s.journal=opt.recovery_content
    s.levels={0,2,20,30,40,50,60,70,80,90,102,108,114,120,126,132,138,144,150,156,162,168,174,180,188,192,198,204,206,208,210,212,214,216,218,220,222}
    if opt.driver then
        s.settings.screen_brightness_cold=s.levels[s.settings.ColdValue+1]
        s.settings.screen_brightness_warm=s.levels[s.settings.WarmValue+1]
    end
    local UI={}
    function UI:scheduleIn(_,fn) state.queue[#state.queue+1]=fn end
    function UI:show(w) state.shown[#state.shown+1]=w; state.top=w end
    function UI:close(w) if state.top==w then state.top=nil end; if w.onCloseWidget then w:onCloseWidget() end end
    function UI:getTopmostVisibleWidget() return state.top end
    local activity=token({class="android/app/Activity"},false)
    local android={prop={manufacturer="bigme",brand="bigme",model=opt.model or "hibreak",product="hibreak_eea",hardware="mt6877"},
        app={activity={vm=vm,clazz=activity}},jni=JNI}
    if opt.context_error_after_mutation then
        android.jni={context=function(_,jvm,fn)
            local result=JNI:context(jvm,fn)
            if state.provider_calls>0 then error("Injected context error after mutation") end
            return result
        end}
    end
    if opt.missing_activity then android.app.activity=nil end
    local fwrap={os=opt.os or "Linux",arch=opt.arch or "arm64",new=ffi.new,string=ffi.string,sizeof=ffi.sizeof,NULL=null,errno=ffi.errno,
        C=setmetatable({getpid=function() return state.pid end,getuid=function() return opt.uid or 10203 end},
        {__index=function(_,key) error("Forbidden C operation: "..key) end})}
    local PowerD={}
    local powerd=setmetatable({stateChanged=function() state.events=(state.events or 0)+1 end,
        updateResumeFrontlightState=function() end},PowerD)
    s.powerd=powerd
    if opt.driver then
        fwrap.C.O_WRONLY=1
        fwrap.C.open=function(device,flags)
            assert(device=="/dev/lm3630a" and flags==1); state.opens=state.opens+1; return 47
        end
        fwrap.C.ioctl=function(fd,request,argument)
            assert(fd==47 and (request==0x7901 or request==0x7902) and ffi.istype("int32_t[1]",argument))
            state.commands[#state.commands+1]={request=request,raw=tonumber(argument[0])}; return 0
        end
        fwrap.C.close=function(fd) assert(fd==47); state.closes=state.closes+1; return 0 end
    end
    local modules={android=android,ffi=fwrap,["ffi/posix_h"]=true,bit=require("bit"),["ui/uimanager"]=UI,
        device={isAndroid=function() return true end,getPowerDevice=function() return powerd end},["device/android/powerd"]=PowerD,
        logger={info=function() end},
        datastorage={getDataDir=function() return "/fixture" end},
        ["ui/widget/buttondialog"]={new=function(_,attrs) assert(attrs.sui_native); return attrs end},
        ["ui/widget/infomessage"]={new=function(_,attrs) assert(attrs.sui_native); return attrs end}}
    local sandbox=setmetatable({require=function(name) return assert(modules[name],"Forbidden module: "..name) end,
        G_reader_settings={readSetting=function(_,key)
            if key=="language" then return opt.language or "sv" end
            assert(opt.driver and key=="bigme_frontlight_restore"); return state.saved[key]
        end,saveSetting=function(_,key,value) assert(opt.driver and key=="bigme_frontlight_restore"); state.saved[key]=value end},
        io={open=function(path,mode)
            if path=="/fixture/bigme-settings-provider-test.log" or path=="/fixture/bigme-settings-provider-roundtrip.log"
                or (opt.driver and path=="/fixture/bigme-frontlight-local-test.log") then
                assert(mode=="a"); if opt.log_failure then return nil,"Simulated log failure" end
                return {seek=function(_,where) assert(where=="end"); return opt.log_full and 262144 or #state.log end,
                    write=function(_,value)
                        if opt.fail_before_provider and value:find("PROVIDER_CALL_BEGIN",1,true) then return nil,"Simulated log failure" end
                        if opt.fail_log_stage and value:find(opt.fail_log_stage,1,true) then return nil,"Simulated stage log failure" end
                        if opt.log_failure_after_change and state.provider_calls>0 then return nil,"Simulated log failure after mutation" end
                        state.log=state.log..value; state.log_writes=state.log_writes+1; return true
                    end,close=function() return true end}
            end
            if path=="/fixture/bigme-settings-provider-roundtrip.recovery" then
                if opt.journal_open_error then return nil,"Simulated journal open failure" end
                if mode=="rb" then
                    if state.journal==nil then return nil,"not found" end
                    return {read=function(_,n) assert(n==4097); return state.journal end,close=function() return true end}
                end
                assert(mode=="a+" or mode=="a")
                state.journal=state.journal or ""
                return {seek=function(_,where) assert(where=="end"); return #state.journal end,
                    write=function(_,value)
                        if opt.journal_write_error or (opt.journal_complete_error and state.provider_calls>0) then return nil,"Journal write failure" end
                        state.journal=state.journal..value; return true
                    end,flush=function() return not opt.journal_flush_error end,close=function() return true end}
            end
            if path=="/proc/self/attr/current" then assert(mode=="r"); return {read=function(_,n) assert(n==256); return opt.context or "u:r:untrusted_app_30:s0" end,close=function() return true end} end
            if path:match("^/fixture/patches/2%-bigme%-.+%.lua$") then
                assert(mode=="rb"); if path=="/fixture/patches/"..tostring(opt.active_patch) then return {close=function() return true end} end
                return nil,"not found"
            end
            error("Forbidden file: "..path)
        end},
    },{__index=_G}); sandbox._G=sandbox
    local patch=assert(loadfile(path)); setfenv(patch,sandbox); patch()
    if opt.driver then assert(state.provider_calls==0 and state.opens==0,"Startup writes or hardware access")
    else assert(state.ops==0 and state.provider_calls==0 and state.log_writes==0,"Work ran before consent") end
    function state:pump()
        local limit=20
        while #self.queue>0 do limit=limit-1; assert(limit>0,"Unexpected polling"); table.remove(self.queue,1)() end
    end
    function state:prompt() self:pump(); return self.shown[1] end
    function state:reload() local again=assert(loadfile(path)); setfenv(again,sandbox); again() end
    function state:run() local p=assert(self:prompt()); p.buttons[1][1].callback(); self:pump(); assert(#self.shown==2); return self.shown[2] end
    function state:balanced()
        assert(self.bad==0,self.last_error or "Invalid fixture JNI call")
        assert(self.refs==self.deletes,"Leaked local references: "..self.refs.."/"..self.deletes)
        assert(self.utf_gets==self.utf_releases,"Leaked UTF buffer")
        assert(self.attaches==self.detaches and not self.pending and JNI.env==nil,"Leaked thread/exception")
    end
    return state
end
if fixture_mode=="fixture" or fixture_mode=="driver_fixture" then
    -- JNI pointer fields do not own their backing FFI arrays. Keep the tables
    -- alive when this chunk returns to another test runner.
    return {new=fixture,owners={api,env,vm_api,vm,callbacks},close=function() for _,cb in ipairs(callbacks) do cb:free() end end}
end
local count=0
local function test(name,fn) fn(); count=count+1; print("PASS "..name) end
test("current readable values only, exact provider protocol/A arguments, no-op response never claimed as proof",function()
    local x=fixture(); local result=x:run(); x:balanced()
    assert(x.provider_calls==4 and table.concat(x.called_keys,",")=="ColdValue,WarmValue,LightUser_Brightness,LightUser_ColorTemp")
    assert(x.log:find("NOT_PROOF_OF_WRITE_EFFECT",1,true) and x.log:find("status=-1",1,true))
    assert(result.text:find("Det bevisar inte",1,true) and not x.log:find("STOPPED",1,true))
    assert(x.settings.ColdValue==27 and x.settings.WarmValue==13)
    local p=x.shown[1]; p.buttons[1][1].callback(); x:pump(); assert(x.provider_calls==4)
end)
test("non-custom mode never touches custom presets",function()
    local x=fixture{settings={LightMode=1,LightUser_Brightness=999,LightUser_ColorTemp=999}}; x:run(); x:balanced(); assert(x.provider_calls==2)
end)
for _,opt in ipairs({{missing_provider=true},{package="other"},{provider_class="other"},{authority="other"},{exported=false},{enabled=false},{flags=0},
    {read_permission="test.permission",permission_denied=true},{write_permission="test.permission",permission_denied=true},
    {missing_method="call"},{missing_method="<init>"},{missing_field="exported"},{settings={ColdValue=99}},{settings={WarmValue=-1}},
    {settings={LightMode=5}},{settings={LightUser_Brightness=99}},{read_error="ColdValue"},{concurrent_before=true},
    {log_failure=true},{log_full=true},{fail_before_provider=true},{uid=2000},{context="u:r:shell:s0"},{missing_activity=true}}) do
    test("guard/error stops before provider mutation: "..tostring(next(opt)),function()
        local x=fixture(opt); x:run(); x:balanced(); assert(x.provider_calls==0 and x.log:find("COMPLETE",1,true)==nil)
    end)
end
for _,opt in ipairs({{provider_error=true},{provider_error=true,throwable_failure=true},{null_reply=true},{concurrent_after=true}}) do
    test("provider failure/no reply/concurrency stops without retry or restore",function()
        local x=fixture(opt); x:run(); x:balanced(); assert(x.provider_calls==1 and x.log:find("STOPPED",1,true))
        assert(not x.log:find("COMPLETE",1,true))
        if opt.provider_error and not opt.throwable_failure then assert(x.log:find("java.lang.SecurityException: provider denied",1,true)) end
    end)
end
for _,filename in ipairs({"2-bigme-frontlight.lua","2-bigme-frontlight-access-diagnostic.lua","2-bigme-frontlight-manual-test.lua",
    "2-bigme-frontlight-warm-test.lua","2-bigme-settings-readonly-diagnostic.lua"}) do
    test("active earlier patch blocks all JNI: "..filename,function()
        local x=fixture{active_patch=filename}; x:run(); x:balanced(); assert(x.ops==0 and x.provider_calls==0)
    end)
end
test("existing granted provider permission is checked without requesting changes",function()
    local x=fixture{write_permission="test.permission"}; x:run(); x:balanced(); assert(x.permission_checks==1 and x.provider_calls==4)
end)
test("English text and missing status remain explicitly inconclusive",function()
    local x=fixture{language="en",no_status=true}; local result=x:run(); x:balanced()
    assert(result.text:find("does not prove",1,true) and x.log:find("status=absent",1,true))
end)
test("close, stale callback and unrelated topmost dialog do nothing",function()
    local x=fixture(); local p=x:prompt(); p.buttons[2][1].callback(); p.buttons[1][1].callback(); x:pump(); x:balanced(); assert(x.ops==0 and x.log_writes==0)
    x=fixture(); p=x:prompt(); x.top={}; p.buttons[1][1].callback(); x:pump(); x:balanced(); assert(x.ops==0)
end)
test("forked process cannot show prompt, run or write log",function()
    local x=fixture(); x.pid=17400; x:pump(); x:balanced(); assert(#x.shown==0 and x.log_writes==0)
    x=fixture(); local p=x:prompt(); x.pid=17400; p.buttons[1][1].callback(); x:pump(); x:balanced(); assert(x.ops==0 and x.log_writes==0)
    x=fixture(); p=x:prompt(); p.buttons[1][1].callback(); x.pid=17400; x:pump(); x:balanced(); assert(x.ops==0 and x.log_writes==0)
end)
test("pre-existing Java exception is captured without provider calls",function()
    local x=fixture(); x.pending="java.lang.SecurityException: pre-existing test exception"; x:run(); x:balanced()
    assert(x.provider_calls==0 and x.log:find("pre-existing Java exception",1,true))
end)
test("duplicate loading cannot create another run in the same process",function()
    local x=fixture(); x:reload(); x:pump(); assert(#x.shown==1)
    x:run(); x:reload(); x:pump(); x:balanced(); assert(#x.shown==2 and x.provider_calls==4)
end)
for _,opt in ipairs({{model="other"},{os="OSX"},{arch="x64"}}) do
    test("unsupported profile stays inert",function() local x=fixture(opt); x:pump(); x:balanced(); assert(#x.shown==0 and x.log_writes==0) end)
end
for _,cb in ipairs(callbacks) do cb:free() end
print(count.." provider host tests passed; no real JVM/provider/hardware accessed")
