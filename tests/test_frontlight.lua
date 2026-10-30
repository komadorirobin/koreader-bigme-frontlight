-- All device, Android/JNI and settings I/O is mocked. No device is accessed.
local PATCH=os.getenv("BIGME_PATCH") or "2-bigme-frontlight.lua"
local UPSTREAM=arg[1] or os.getenv("BIGME_UPSTREAM")
assert(UPSTREAM,"pass directory containing pinned generic-powerd.lua, android-powerd.lua, frontlightwidget.lua")
local real_io,real_os=io,os
local function loadIn(env,path)
    if setfenv then local f=assert(loadfile(path)); setfenv(f,env); return f() end
    return assert(loadfile(path,"t",env))()
end
local function copy(t) local x={} for k,v in pairs(t) do x[k]=v end return x end
local function contains(s,part) return type(s)=="string" and s:find(part,1,true)~=nil end
local LEVELS={0,2,20,30,40,50,60,70,80,90,102,108,114,120,126,132,138,144,150,156,162,168,174,180,188,192,198,204,206,208,210,212,214,216,218,220,222}
local function run(options)
    local o=options or {}
    local s={commands={},opens=0,closes=0,errno=0,writes={},saved={},messages={},logs={},events=0,refs=0,deletes=0,contexts=0,detaches=0,
        permission_checks=0,legacy_permission_calls=0,settings_reads=0,method_calls=0}
    s.settings={ColdValue=12,WarmValue=13,screen_brightness_cold=114,screen_brightness_warm=120,LightMode=4,
        LightUser_Brightness=12,LightUser_ColorTemp=13}
    for k,v in pairs(o.settings or {}) do s.settings[k]=v end
    local methods={}
    function methods:extend(attrs) return setmetatable(attrs or {},{__index=self}) end
    function methods:refocusWidget() end
    local screen={}
    local Device={screen=screen,hasFrontlight=function() return true end,hasNaturalLight=function() return false end,
        isAndroid=function() return true end,hasNaturalLightMixer=function() return false end,hasNaturalLightApi=function() return false end}
    local NULL={}
    local native={
        O_WRONLY=o.flags or 1,getuid=function() return o.uid or 10203 end,getpid=function() return s.pid or 17318 end,
        open=function(path,flags,...)
            assert(path=="/dev/lm3630a" and flags==1 and select("#",...)==0)
            s.opens=s.opens+1
            if o.open_error then s.errno=o.open_error; return -1 end
            return o.fd or 47
        end,
        ioctl=function(fd,request,pointer,...)
            assert(fd==(o.fd or 47) and (request==0x7901 or request==0x7902) and select("#",...)==0)
            assert(type(pointer)=="table" and pointer.kind=="int32_t[1]", "owning int32 array required")
            local raw=pointer[0]
            local found=false; for _,value in ipairs(LEVELS) do if raw==value then found=true end end
            assert(found,"only OEM lookup-table values may be sent")
            s.commands[#s.commands+1]={request=request,raw=raw}
            if o.ioctl_throw then error("ioctl exception") end
            if o.ioctl_error or s.fail_ioctl or o.fail_request==request then
                s.errno=o.ioctl_error or s.fail_ioctl or 13; return -1
            end
            return 0
        end,
        close=function(fd)
            assert(fd==(o.fd or 47)); s.closes=s.closes+1
            s.errno=o.close_error or 999
            return o.close_error and -1 or 0
        end,
    }
    local C=setmetatable({}, {__index=function(_,key)
        if key==o.missing_symbol then error("missing " .. key) end
        assert(native[key]~=nil,"FORBIDDEN native operation " .. key); return native[key]
    end})
    local function allocated(value) s.refs=s.refs+1; return {ref=true,value=value} end
    local function checkedArgs(name,signature)
        assert(type(name)=="string" and type(signature)=="string"); return name
    end
    local api={
        ExceptionCheck=function() return s.java_exception and 1 or 0 end,
        ExceptionClear=function() s.java_exception=false end,
        DeleteLocalRef=function(_,ref) assert(ref.ref and not ref.deleted); ref.deleted=true; s.deletes=s.deletes+1 end,
        GetObjectClass=function() return o.null_activity_class and NULL or allocated("Activity") end,
        GetMethodID=function(_,_,name,signature)
            assert(name=="getContentResolver" and signature=="()Landroid/content/ContentResolver;")
            if o.null_method then return NULL end
            return checkedArgs(name,signature)
        end,
        CallObjectMethod=function(_,_,method)
            assert(method=="getContentResolver"); s.method_calls=s.method_calls+1
            return o.null_resolver and NULL or allocated("ContentResolver")
        end,
        FindClass=function(_,class)
            assert(class=="android/provider/Settings$System","public Android API only")
            if o.java_error then s.java_exception=true; return NULL end
            return allocated(class)
        end,
        GetStaticMethodID=function(_,_,name,signature)
            assert((name=="getInt" and signature=="(Landroid/content/ContentResolver;Ljava/lang/String;I)I")
                or (name=="putInt" and signature=="(Landroid/content/ContentResolver;Ljava/lang/String;I)Z")
                or (name=="canWrite" and signature=="(Landroid/content/Context;)Z"))
            if o.missing_static==name then
                s.java_exception=not o.null_without_exception
                return NULL
            end
            return checkedArgs(name,signature)
        end,
        NewStringUTF=function(_,value) return allocated(value) end,
        CallStaticIntMethod=function(_,_,method,resolver,key,default)
            assert(method=="getInt" and resolver.value=="ContentResolver" and default.kind=="int32_t" and default.value==-1)
            s.settings_reads=s.settings_reads+1
            if s.fail_read then s.java_exception=true; return -1 end
            return s.settings[key.value] or -1
        end,
        CallStaticBooleanMethod=function(_,_,method,resolver,key,value)
            if method=="canWrite" then
                assert(resolver==s.activity and key==nil and value==nil,"canWrite receives the Activity Context, no extra args")
                s.permission_checks=s.permission_checks+1
                if o.permission_exception then s.java_exception=true; return 0 end
                return not (o.no_permission or s.permission_revoked) and 1 or 0
            end
            assert(method=="putInt" and resolver.value=="ContentResolver" and value.kind=="int32_t")
            local allowed={ColdValue=true,WarmValue=true,screen_brightness_cold=true,screen_brightness_warm=true,
                LightUser_Brightness=true,LightUser_ColorTemp=true}
            assert(allowed[key.value],"FORBIDDEN system setting " .. key.value)
            assert(s.opens==s.closes or o.open_error,"close device before Android persistence")
            if s.fail_write or o.write_error then return 0 end
            if o.write_exception then s.java_exception=true; return 0 end
            s.settings[key.value]=value.value
            s.writes[#s.writes+1]={key=key.value,value=value.value}
            return 1
        end,
    }
    local ffi={os=o.os or "Linux",arch=o.arch or "arm64",C=C,NULL=NULL,
        sizeof=function(kind) assert(kind=="int32_t"); return o.int_size or 4 end,
        new=function(kind,value)
            assert(kind=="int32_t" or kind=="int32_t[1]")
            if kind=="int32_t[1]" and o.alloc_error then error("allocation failed") end
            return kind=="int32_t" and {kind=kind,value=value} or {kind=kind,[0]=value}
        end,errno=function() return s.errno end}
    s.activity={}
    local android={prop={manufacturer=o.manufacturer or "bigme",brand=o.brand or "bigme",model=o.model or "hibreak",
        hardware=o.hardware or "mt6877",product=o.product or "hibreak_eea"},app={activity={vm={},clazz=s.activity}},
        canWriteSettings=function()
            s.legacy_permission_calls=s.legacy_permission_calls+1
            error("Obsolete hasWriteSettingsPermission would cause native CallBooleanMethod(mid == null)")
        end,
        jni={context=function(self,_,callback)
            assert(self.env==nil,"never nest JNI contexts")
            s.contexts=s.contexts+1; self.env={[0]=api}
            local ok,a,b=pcall(callback,self)
            self.env=nil; s.detaches=s.detaches+1
            assert(ok,"Lua errors must not escape JNI runnable: " .. tostring(a))
            return a,b
        end}}
    local modules={android=android,ffi=ffi,["ffi/posix_h"]=true,device=Device,
        logger={info=function(m) s.logs[#s.logs+1]=m end,dbg=function() end},
        ["ui/event"]={new=function(_,name) return {name=name} end},
        optmath={round=function(x) return math.floor(x+0.5) end},["ui/time"]={s=function(x) return x end},
        ["ui/uimanager"]={scheduleIn=function(_,_,callback) callback() end,
            show=function(_,attrs) s.messages[#s.messages+1]=attrs end,setDirty=function() end,
            broadcastEvent=function(_,event) assert(event.name=="FrontlightStateChanged"); s.events=s.events+1 end},
        ["ui/widget/infomessage"]={new=function(_,attrs) return attrs end},
    }
    if o.native_ffi then
        -- Preserve real FFI arrays/pointers for device calls, while scalar JNI
        -- arguments remain mocked Java values; never access actual JNI/hardware.
        for k,v in pairs(o.native_ffi) do ffi[k]=v end
    end
    local env=setmetatable({
        require=function(name)
            if name==o.missing_module or (name=="android" and o.not_android) then error("missing module " .. name) end
            assert(modules[name]~=nil,"FORBIDDEN module " .. name); return modules[name]
        end,
        io={open=function(path,mode)
            assert(path=="/proc/self/attr/current" and mode=="r","only read process context")
            if o.context_missing then return nil,"denied" end
            return {read=function(_,limit) assert(limit==256); return o.context or "u:r:untrusted_app_30:s0:c203,c256,c512,c768\0\n" end,
                close=function() return true end}
        end},
        G_reader_settings={readSetting=function(_,key)
            if key=="language" then return o.language end
            assert(key=="bigme_frontlight_restore"); return s.saved[key] or o.restore
        end,saveSetting=function(_,key,value)
            assert(key=="bigme_frontlight_restore"); if not o.save_error then s.saved[key]=value end
        end},
    },{__index=_G})
    env._G=env
    modules["device/generic/powerd"]=loadIn(env,UPSTREAM .. "/generic-powerd.lua")
    local PowerD=loadIn(env,UPSTREAM .. "/android-powerd.lua")
    PowerD.__index=PowerD
    modules["device/android/powerd"]=PowerD
    s.powerd=setmetatable({device=Device,fl_intensity=1,fl_warmth=0,is_fl_on=true},PowerD)
    if o.custom_powerd then setmetatable(s.powerd,{__index=PowerD}) end
    Device.getPowerDevice=function() return s.powerd end
    s.powerd:UIManagerReady(modules["ui/uimanager"])
    s.original=Device.hasNaturalLight
    if o.missing_api then s.powerd[o.missing_api]=false end
    loadIn(env,PATCH)
    function s:reload() loadIn(env,PATCH) end
    function s:status() return self.powerd._bigme_lm3630a end
    function s:external(cold,warm)
        self.settings.ColdValue,self.settings.WarmValue=cold,warm
        self.settings.screen_brightness_cold,self.settings.screen_brightness_warm=LEVELS[cold+1],LEVELS[warm+1]
    end
    function s:widget()
        for _,name in ipairs({"ffi/blitbuffer","ui/widget/button","ui/widget/buttonprogresswidget","ui/widget/container/centercontainer",
            "ui/widget/container/framecontainer","ui/geometry","ui/gesturerange","ui/font","ui/widget/horizontalgroup",
            "ui/widget/horizontalspan","ui/widget/naturallightwidget","ui/widget/progresswidget","ui/size","ui/widget/textwidget",
            "ui/widget/titlebar","ui/widget/verticalgroup","ui/widget/verticalspan","ui/widget/container/widgetcontainer"}) do modules[name]={} end
        modules["ui/widget/focusmanager"]=methods
        modules.gettext=setmetatable({pgettext=function(_,x) return x end},{__call=function(_,x) return x end})
        local Widget=loadIn(env,UPSTREAM .. "/frontlightwidget.lua")
        local control={setPercentage=function() end,setPosition=function() end,setText=function() end,enable=function() end,disable=function() end}
        return setmetatable({powerd=self.powerd,fl={min=0,max=36,cur=self.powerd:frontlightIntensity()},
            nl={min=0,max=36,stride=2,cur=self.powerd:frontlightWarmthHW()},
            nl_progress=control,nl_level=control,nl_minus=control,nl_plus=control,
            fl_progress=control,fl_level=control,fl_minus=control,fl_plus=control,frame={dimen={}}}, {__index=Widget})
    end
    assert(s.contexts==s.detaches and s.refs==s.deletes,"clean all JNI contexts/local refs")
    return s
end
local passed=0
local function test(name,fn) fn(); passed=passed+1; print("PASS " .. name) end
local function active(s) assert(s:status() and not s:status().fault) end

test("startup bypasses the obsolete permission helper that caused the device abort",function()
    local s=run(); active(s)
    assert(s.legacy_permission_calls==0 and s.permission_checks==1 and s.settings_reads==5)
    assert(s.opens==0 and #s.writes==0 and #s.messages==0)
end)
for _,o in ipairs({{no_permission=true},{missing_static="canWrite"},
    {missing_static="canWrite",null_without_exception=true},{permission_exception=true}}) do
    test("permission denial/missing method/Java failure stays native-safe and leaves backend untouched",function()
        local s=run(o)
        assert(not s:status() and s.legacy_permission_calls==0 and s.opens==0 and #s.writes==0 and s.settings_reads==0)
        assert(s.powerd.device.hasNaturalLight==s.original and not s.java_exception)
        assert(s.refs==s.deletes and s.contexts==s.detaches and #s.messages==1)
    end)
end
test("permission revocation after startup prevents hardware writes",function()
    local s=run(); active(s); s.permission_revoked=true
    assert(not s.powerd:setIntensity(26) and s.opens==0 and #s.writes==0 and s:status().fault)
    local contexts=s.contexts
    assert(not s.powerd:setWarmth(80) and s.contexts==contexts and s.legacy_permission_calls==0)
end)
for _,o in ipairs({{null_activity_class=true},{null_resolver=true},{missing_static="getInt"}}) do
    test("invalid read-side JNI lookup never reaches a call with null method/object",function()
        local s=run(o)
        assert(not s:status() and s.opens==0 and #s.writes==0 and s.settings_reads==0)
        assert(s.refs==s.deletes and s.contexts==s.detaches and not s.java_exception)
    end)
end

test("real upstream PowerD loads; no startup hardware/settings writes",function()
    local s=run(); active(s)
    assert(s.opens==0 and #s.writes==0 and s.powerd.fl_max==36 and s.powerd.fl_warmth_max==36)
    assert(s.powerd:frontlightIntensity()==12 and s.powerd:frontlightWarmthHW()==13)
    assert(s.powerd.device:hasNaturalLight() and not s.powerd.device:hasNaturalLightMixer())
end)
test("verified cold command, warm preserved, OEM/custom preset synchronized",function()
    local s=run(); assert(s.powerd:setIntensity(26)); active(s)
    assert(#s.commands==1 and s.commands[1].request==0x7901 and s.commands[1].raw==198 and s.closes==1)
    assert(s.settings.ColdValue==26 and s.settings.screen_brightness_cold==198 and s.settings.LightUser_Brightness==26)
    assert(s.settings.WarmValue==13 and s.settings.screen_brightness_warm==120 and s.events==1)
end)
test("verified warm command, cold preserved; public/native warmth roundtrip",function()
    local s=run(); assert(s.powerd:setWarmth(s.powerd:fromNativeWarmth(30))); active(s)
    assert(#s.commands==1 and s.commands[1].request==0x7902 and s.commands[1].raw==210)
    assert(s.settings.WarmValue==30 and s.settings.screen_brightness_warm==210 and s.settings.LightUser_ColorTemp==30)
    assert(s.settings.ColdValue==12 and s.powerd:frontlightWarmthHW()==30)
end)
test("complete OEM table and all warmth roundtrips, no out-of-range writes",function()
    local s=run()
    for level=0,36 do
        s.powerd:setIntensity(level)
        assert(s.powerd:frontlightIntensity()==level and s.settings.screen_brightness_cold==LEVELS[level+1])
        local public=s.powerd:fromNativeWarmth(level)
        assert(s.powerd:toNativeWarmth(public)==level)
        s.powerd:setWarmth(public)
        assert(s.settings.screen_brightness_warm==LEVELS[level+1])
    end
    active(s); assert(s.opens==s.closes)
end)
test("unchanged/quantized levels do not issue redundant commands",function()
    local s=run(); assert(not s.powerd:setIntensity(12)); assert(not s.powerd:setWarmth(36))
    assert(s.opens==0 and #s.writes==0 and s.events==0)
end)
test("nonfinite/nonnumeric values rejected; finite requests bounded and rounded",function()
    local s=run()
    for _,v in ipairs({0/0,math.huge,-math.huge,"12",false,{}}) do
        assert(not s.powerd:setIntensity(v) and not s.powerd:setWarmth(v))
    end
    assert(s.opens==0); s.powerd:setIntensity(99); assert(s.settings.ColdValue==36)
    s.powerd:setIntensity(-4); assert(s.settings.ColdValue==0)
    s.powerd:setIntensity(12.6); assert(s.settings.ColdValue==13)
end)
test("off/on restores both channels and callback/event semantics",function()
    local s=run(); local callbacks=0
    assert(s.powerd:turnOffFrontlight(function() callbacks=callbacks+1 end))
    assert(not s.powerd:isFrontlightOn() and s.settings.ColdValue==0 and s.settings.WarmValue==0)
    assert(s.saved.bigme_frontlight_restore.cold==12 and s.saved.bigme_frontlight_restore.warm==13)
    assert(s.powerd:turnOnFrontlight(function() callbacks=callbacks+1 end))
    assert(s.settings.ColdValue==12 and s.settings.WarmValue==13 and callbacks==2 and s.events==2)
    assert(#s.commands==4 and s.closes==4)
end)
test("warm-only on state and toggle are supported",function()
    local s=run({settings={ColdValue=0,screen_brightness_cold=0}})
    assert(s.powerd:isFrontlightOn()); assert(s.powerd:toggleFrontlight()); assert(not s.powerd:isFrontlightOn())
    assert(s.powerd:toggleFrontlight()); assert(s.settings.ColdValue==0 and s.settings.WarmValue==13)
end)
test("failed restore-state save prevents both off commands",function()
    local s=run({save_error=true})
    assert(not s.powerd:turnOffFrontlight() and s.opens==0 and s:status().fault)
end)
test("saved off-state restoration has strict profile/range validation; no guessed defaults",function()
    local off={ColdValue=0,WarmValue=0,screen_brightness_cold=0,screen_brightness_warm=0}
    local s=run({settings=off,restore={profile="hibreak_eea/mt6877/arm64/lm3630a-table80-v1",cold=26,warm=30}})
    assert(s.opens==0 and s.powerd:turnOnFrontlight() and s.settings.ColdValue==26 and s.settings.WarmValue==30)
    for _,bad in ipairs({{}, {profile="other",cold=12,warm=13}, {profile="hibreak_eea/mt6877/arm64/lm3630a-table80-v1",cold=99,warm=13}}) do
        local x=run({settings=off,restore=bad}); assert(not x.powerd:turnOnFrontlight() and x.opens==0 and x:status().fault)
    end
end)
test("Android panel changes read back, without hardware writes on read",function()
    local s=run(); s:external(26,30)
    assert(s.powerd:frontlightIntensity()==26 and s.powerd:frontlightWarmthHW()==30 and s.opens==0)
    s.powerd:setIntensity(12); assert(s.settings.WarmValue==30)
end)
test("other OEM presets are not modified or switched",function()
    local s=run({settings={LightMode=1}}); s.powerd:setIntensity(26)
    assert(s.settings.LightUser_Brightness==12 and s.settings.LightMode==1 and #s.writes==2)
end)
test("no_broadcast honored; direct HW entry points use same backend",function()
    local s=run(); assert(s.powerd:setIntensityHW(26)); assert(s.events==0)
    assert(s.powerd:setWarmthHW(30)); assert(s.events==1 and #s.commands==2)
end)
test("actual stock frontlight widget brightness, warmth and toggle callbacks",function()
    local s=run(); local w=s:widget()
    w:setBrightness(26); assert(w.fl.cur==26 and s.settings.ColdValue==26)
    w:setWarmth(30,false); assert(w.nl.cur==30 and s.settings.WarmValue==30)
    w:setBrightness(0); assert(not s.powerd:isFrontlightOn())
    w:setBrightness(0); assert(s.settings.ColdValue==26 and s.settings.WarmValue==30)
end)
test("duplicate file loading cannot wrap or execute hardware twice",function()
    local s=run(); local fn=s.powerd.setIntensity; s:reload()
    assert(s.powerd.setIntensity==fn and s.opens==0)
end)
test("forked background worker uses cached levels and never touches JNI/hardware/UI",function()
    local s=run(); local contexts=s.contexts; s.pid=99999
    assert(s.powerd:frontlightIntensity()==12 and s.powerd:frontlightWarmthHW()==13)
    assert(not s.powerd:setIntensity(26) and not s.powerd:setWarmth(80) and not s.powerd:toggleFrontlight())
    assert(s.contexts==contexts and s.opens==0 and #s.messages==0 and not s:status().fault)
end)
for _,o in ipairs({{not_android=true},{manufacturer="Onyx",brand="Onyx"},{model="other"},{hardware="other"},{product="other"},
    {os="OSX"},{arch="arm"},{uid=0},{uid=2000},{context_missing=true},{context="u:r:shell:s0"},
    {no_permission=true},{flags=2},{int_size=8},{custom_powerd=true},{missing_api="updateResumeFrontlightState"}}) do
    local name=next(o)
    test("unsupported " .. name .. " leaves original backend untouched",function()
        local s=run(o); assert(not s:status() and s.opens==0 and #s.writes==0)
        assert(s.powerd.device.hasNaturalLight==s.original)
    end)
end
for _,key in ipairs({"ColdValue","WarmValue","screen_brightness_cold","screen_brightness_warm"}) do
    test("unknown/inconsistent initial setting " .. key .. " fails closed",function()
        local s=run({settings={[key]=999}}); assert(not s:status() and s.opens==0 and #s.writes==0)
    end)
end
for _,symbol in ipairs({"open","ioctl","close","getuid","getpid"}) do
    test("missing native " .. symbol .. " cannot partially install",function()
        local s=run({missing_symbol=symbol}); assert(not s:status() and s.opens==0)
    end)
end
for _,o in ipairs({{open_error=13},{ioctl_error=13},{ioctl_error=25},{ioctl_throw=true},{close_error=4},{alloc_error=true}}) do
    local name=next(o)
    test(name .. " fails without false success, settings writes or automatic retry",function()
        local s=run(o); assert(not s.powerd:setIntensity(26)); assert(s:status().fault and #s.writes==0)
        local count=s.opens; assert(not s.powerd:setWarmth(80) and s.opens==count)
        assert(s.opens==s.closes or o.open_error)
        if o.ioctl_error then assert(contains(s:status().fault,"errno=" .. o.ioctl_error)) end
    end)
end
test("valid descriptor zero closed correctly",function() local s=run({fd=0}); assert(s.powerd:setIntensity(26) and s.closes==1) end)
test("persistence failure after hardware command latches error but retains known commanded level",function()
    local s=run(); s.fail_write=true
    assert(not s.powerd:setIntensity(26) and #s.commands==1 and s.closes==1)
    assert(s:status().fault and s.powerd:frontlightIntensity()==26)
    assert(not s.powerd:setIntensity(12) and #s.commands==1)
end)
test("partial toggle failure reports error and does not fabricate fully off state",function()
    local s=run({fail_request=0x7902}); local callbacks=0
    assert(not s.powerd:turnOffFrontlight(function() callbacks=callbacks+1 end))
    assert(#s.commands==2 and s.closes==2 and s:status().cold==0 and s:status().warm==13)
    assert(s.settings.ColdValue==0 and s.settings.WarmValue==13 and s.powerd:isFrontlightOn())
    assert(s.saved.bigme_frontlight_restore.cold==12 and s.saved.bigme_frontlight_restore.warm==13)
    assert(callbacks==0 and s.events==0 and s:status().fault)
end)
for _,o in ipairs({{null_method=true},{java_error=true}}) do
    test("JNI lookup/Java exception fails cleanly without escaping attached context",function()
        local s=run(o); assert(not s:status() and s.opens==0)
        assert(s.refs==s.deletes and s.contexts==s.detaches and not s.java_exception)
    end)
end
test("JNI write exceptions cleared and references released after device cleanup",function()
    local s=run({write_exception=true}); assert(not s.powerd:setIntensity(26))
    assert(s.opens==s.closes and s.refs==s.deletes and s.contexts==s.detaches and not s.java_exception)
end)
test("read failure after installation cannot send any command",function()
    local s=run(); s.fail_read=true; assert(not s.powerd:setIntensity(26) and s.opens==0 and s:status().fault)
end)
for _,language in ipairs({"sv","sv_SE","SV-se","en","de"}) do
    test("warning language " .. language .. " and native dismissible notification",function()
        local s=run({language=language,no_permission=true}); assert(#s.messages==1 and s.messages[1].sui_native)
        assert(contains(s.messages[1].text,language:lower():match("^sv") and "Bigme-ljusstyrning" or "Bigme frontlight"))
    end)
end
test("source has fixed device/requests and no permission/security/shell/vendor changes",function()
    local f=assert(real_io.open(PATCH,"r")); local src=f:read("*a"); f:close()
    for _,bad in ipairs({"ffi.load","ffi.cdef","os.execute","io.popen","requestPermission","setenforce","hidden_api_policy"}) do
        assert(not contains(src,bad),bad)
    end
    local allowed={open=true,ioctl=true,close=true,O_WRONLY=true,getuid=true,getpid=true}
    for name in src:gmatch("C%.([%w_]+)") do assert(allowed[name],name) end
end)

local fixture=real_os.getenv("BIGME_NATIVE_FIXTURE")
if fixture then
    local ffi=require("ffi")
    ffi.cdef[[
        void compat_reset(int, int, int); unsigned int compat_getuid(void); int compat_getpid(void);
        int compat_open(const char *, int, ...); int compat_ioctl(int, int, ...); int compat_close(int);
        int compat_opens(void); int compat_closes(void); int compat_commands(void);
        int compat_request(int); int compat_value(int);
    ]]
    local lib=ffi.load(fixture)
    for _,errors in ipairs({{0,0,0},{13,0,0},{0,13,0},{0,0,4}}) do
        test("real FFI int32 array/varargs/errno with errors " .. table.concat(errors,","),function()
            lib.compat_reset(errors[1],errors[2],errors[3])
            local native={O_WRONLY=1,getuid=lib.compat_getuid,getpid=lib.compat_getpid,ioctl=lib.compat_ioctl,close=lib.compat_close,
                open=function(...)
                    local fd=lib.compat_open(...); collectgarbage("collect"); return fd
                end}
            local wrapped={C=native,errno=ffi.errno,sizeof=ffi.sizeof,new=function(kind,value)
                if kind=="int32_t[1]" then return ffi.new(kind,value) end
                assert(kind=="int32_t"); return {kind=kind,value=value}
            end}
            local s=run({native_ffi=wrapped})
            local accepted=s.powerd:setIntensity(26)
            assert(accepted==(errors[1]==0 and errors[2]==0 and errors[3]==0))
            assert(lib.compat_opens()==1 and lib.compat_closes()==(errors[1]==0 and 1 or 0))
            if errors[1]==0 then assert(lib.compat_request(0)==0x7901 and lib.compat_value(0)==198) end
            if accepted then
                assert(s.powerd:setWarmth(s.powerd:fromNativeWarmth(30)))
                assert(lib.compat_commands()==2 and lib.compat_request(1)==0x7902 and lib.compat_value(1)==210)
                assert(lib.compat_closes()==2)
            else assert(s:status().fault) end
        end)
    end
end
print(passed .. " tests passed; no real device, JNI or user settings touched")
