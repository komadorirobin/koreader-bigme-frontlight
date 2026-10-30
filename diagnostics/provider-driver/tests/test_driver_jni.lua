-- MIT. Pinned real JNI layout/context and typed FFI callbacks; no real JVM/device.
local path=os.getenv("BIGME_PATCH") or "2-bigme-frontlight.lua"
local fixture=assert(loadfile("diagnostics/provider-current-values/tests/test_provider.lua"))("driver_fixture",path)
local count=0
local function test(name,fn) fn(); count=count+1; print("PASS "..name) end
local function new(options)
    collectgarbage("collect")
    options=options or {}; options.driver=true
    return fixture.new(options)
end
local function active(x) assert(x.powerd._bigme_lm3630a and not x.powerd._bigme_lm3630a.fault); x:balanced() end
local function has(s,part) return type(s)=="string" and s:find(part,1,true)~=nil end
test("startup/getters use checked A-array reads with zero provider/hardware writes",function()
    local x=new(); active(x)
    assert(x.powerd:frontlightIntensity()==27 and x.powerd:frontlightWarmthHW()==13)
    assert(x.provider_calls==0 and x.opens==0 and not x.powerd._bigme_lm3630a.raw_verified)
    x:balanced()
end)
test("cold/warm device arguments, six-key provider protocol and independent readable readback",function()
    local x=new(); assert(x.powerd:setIntensity(26)); active(x)
    assert(#x.commands==1 and x.commands[1].request==0x7901 and x.commands[1].raw==198)
    assert(x.provider_calls==9 and x.settings.ColdValue==26 and x.settings.screen_brightness_cold==198 and x.settings.LightUser_Brightness==26)
    assert(x.settings.WarmValue==13 and x.settings.LightUser_ColorTemp==13 and x.settings.LightMode==4)
    assert(x.powerd:setWarmthHW(30)); active(x)
    assert(#x.commands==2 and x.commands[2].request==0x7902 and x.commands[2].raw==210)
    assert(x.settings.WarmValue==30 and x.settings.LightUser_ColorTemp==30 and x.provider_calls==12)
    assert(x.opens==x.closes and has(x.log,"raw readback unavailable"))
end)
test("all OEM indices and warmth conversions stay bounded through actual jvalue layout",function()
    local x=new()
    for level=0,36 do
        x.powerd:setIntensity(level); active(x)
        assert(x.settings.ColdValue==level and x.settings.screen_brightness_cold==x.levels[level+1])
        assert(x.powerd:toNativeWarmth(x.powerd:fromNativeWarmth(level))==level)
        x.powerd:setWarmthHW(level); active(x)
        assert(x.settings.WarmValue==level and x.settings.screen_brightness_warm==x.levels[level+1])
    end
    assert(x.opens==x.closes)
end)
test("both channels turn off/on with remembered levels and no startup restoration",function()
    local x=new(); assert(x.powerd:turnOffFrontlight()); active(x)
    assert(x.settings.ColdValue==0 and x.settings.WarmValue==0)
    assert(x.saved.bigme_frontlight_restore.cold==27 and x.saved.bigme_frontlight_restore.warm==13)
    assert(x.powerd:turnOnFrontlight()); active(x)
    assert(x.settings.ColdValue==27 and x.settings.WarmValue==13 and #x.commands==4)
end)
test("noncustom mode does not write preset levels or mode",function()
    local x=new{settings={LightMode=1}}; assert(x.powerd:setIntensity(26)); active(x)
    assert(x.provider_calls==6 and x.settings.LightUser_Brightness==27 and x.settings.LightMode==1)
end)
for _,key in ipairs({"screen_brightness_cold","screen_brightness_warm","ColdValue","WarmValue","LightUser_Brightness","LightUser_ColorTemp"}) do
    test("provider Java denial before hardware: "..key,function()
        local x=new{denied_write_key=key}; active(x)
        assert(not x.powerd:setIntensity(26) and x.opens==0 and x.powerd._bigme_lm3630a.fault)
        local attempts=x.provider_calls
        assert(not x.powerd:setIntensity(26) and x.provider_calls==attempts)
        x:pump(); x:balanced()
        assert(#x.shown==1 and has(x.shown[1].text,"java.lang.SecurityException"))
    end)
end
for _,name in ipairs({"call","<init>","putString","putInt","parse"}) do
    test("missing write/restore-side method ID is never invoked: "..name,function()
        local x=new{missing_method=name}; active(x)
        assert(not x.powerd:setIntensity(26) and x.opens==0 and x.provider_calls==0)
        x:balanced()
    end)
end
for _,options in ipairs({{missing_provider=true},{package="other"},{provider_class="other"},{authority="other"},{flags=0},
    {exported=false},{enabled=false},{write_permission="test.permission",permission_denied=true},
    {missing_method="canWrite"},{missing_method="getInt"},{missing_field="exported"},{no_permission=true},{permission_error=true}}) do
    test("metadata/permission/missing-ID guard performs no mutation",function()
        local x=new(options); x:pump(); x:balanced()
        assert(not x.powerd._bigme_lm3630a and x.opens==0 and x.provider_calls==0 and #x.shown==1)
    end)
end
test("denied persistence after accepted hardware is latched without false rollback",function()
    local x=new{deny_after_hardware=true}; active(x)
    assert(not x.powerd:setIntensity(26) and #x.commands==1 and x.settings.ColdValue==27)
    assert(x.powerd._bigme_lm3630a.cold==26 and x.powerd._bigme_lm3630a.fault and x.opens==x.closes)
    local attempts=x.provider_calls
    assert(not x.powerd:setIntensity(27) and x.provider_calls==attempts and #x.commands==1)
    x:balanced()
end)
test("silently ignored provider is caught by target readback, not status",function()
    local x=new{no_op=true}; active(x)
    assert(not x.powerd:setIntensity(26) and #x.commands==1 and x.settings.ColdValue==27)
    assert(has(x.powerd._bigme_lm3630a.fault,"did not retain")); x:balanced()
end)
for _,options in ipairs({{null_reply=true},{ignore_raw=true}}) do
    test("null reply/raw no-op cannot become a raw-persistence claim",function()
        local x=new(options); assert(x.powerd:setIntensity(26)); active(x)
        assert(x.powerd._bigme_lm3630a.raw_verified==false and has(x.log,"not proof of persistence"))
        if options.ignore_raw then assert(x.settings.screen_brightness_cold==204) end
    end)
end
test("stale child process cannot touch JNI/provider/hardware",function()
    local x=new(); active(x); local calls,ops=x.provider_calls,x.ops; x.pid=17400
    assert(x.powerd:frontlightIntensity()==27 and not x.powerd:setIntensity(26))
    assert(x.provider_calls==calls and x.ops==ops and x.opens==0); x:balanced()
end)
for _,file in ipairs({"2-bigme-frontlight-access-diagnostic.lua","2-bigme-frontlight-manual-test.lua","2-bigme-frontlight-warm-test.lua",
    "2-bigme-settings-readonly-diagnostic.lua","2-bigme-settings-provider-test.lua","2-bigme-settings-provider-roundtrip.lua"}) do
    test("active old test is blocked before JNI: "..file,function()
        local x=new{active_patch=file}; x:pump(); x:balanced()
        assert(x.provider_calls==0 and x.opens==0 and x.ops==0 and not x.powerd._bigme_lm3630a)
    end)
end
test("duplicate exact-version loading never installs twice",function()
    local x=new(); active(x); local f=x.powerd.setIntensity; local ops=x.ops
    x:reload(); x:balanced(); assert(x.powerd.setIntensity==f and x.ops==ops and x.provider_calls==0)
end)
fixture.close()
print(count.." provider-driver JNI host tests passed; no real JVM/provider/hardware accessed")
