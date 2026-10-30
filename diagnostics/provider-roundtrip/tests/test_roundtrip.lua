-- MIT. Shared typed-FFI JNI host fixture; no Android/JVM/device is accessed.
local path=os.getenv("BIGME_ROUNDTRIP_PATCH") or "diagnostics/provider-roundtrip/2-bigme-settings-provider-roundtrip.lua"
local fixture=assert(loadfile("diagnostics/provider-current-values/tests/test_provider.lua"))("fixture",path)
local count=0
local function test(name,fn) fn(); count=count+1; print("PASS "..name) end
local function new(options)
    options=options or {}; options.roundtrip=true
    collectgarbage("collect")
    return fixture.new(options)
end
local function prepare(x)
    local p=assert(x:prompt()); assert(p.buttons)
    p.buttons[1][1].callback(); x:pump(); x:balanced()
    assert(#x.shown==2 and x.provider_calls==0 and x.journal==nil)
    return x.shown[2],p
end
local function run(x)
    local consent=prepare(x)
    assert(consent.buttons,consent.text)
    consent.buttons[1][1].callback(); x:pump(); x:balanced()
    assert(#x.shown==3)
    return x.shown[3],consent
end
local function has(value,needle) return type(value)=="string" and value:find(needle,1,true)~=nil end
local function pending(original,target)
    return "BIGME_PROVIDER_ROUNDTRIP_V1\nprofile=hibreak_eea/mt6877/arm64\nkey=ColdValue\noriginal="..original.."\ntarget="..target.."\nPENDING\n"
end
for _,original in ipairs({0,1,27,36}) do
    test("one bounded ColdValue step and verified restoration from "..original,function()
        local x=new{settings={ColdValue=original}}
        local result,consent=run(x)
        local target=original>0 and original-1 or 1
        assert(has(consent.title,tostring(original).." → "..target.." → "..original))
        assert(x.provider_calls==2 and x.call_values[1]==target and x.call_values[2]==original)
        assert(x.settings.ColdValue==original and x.settings.WarmValue==13 and x.settings.LightMode==4)
        assert(x.settings.LightUser_Brightness==27 and x.settings.LightUser_ColorTemp==13)
        assert(x.journal==pending(original,target).."RESTORED_VERIFIED\n")
        assert(has(x.log,"RESULT | VERIFIED") and has(result.text,"återställt och verifierat"))
        consent.buttons[1][1].callback(); x:pump(); assert(x.provider_calls==2)
    end)
end
test("unchanged/no-op provider is inconclusive, never a successful roundtrip",function()
    local x=new{no_op=true}; local result=run(x)
    assert(x.provider_calls==2 and x.settings.ColdValue==27 and has(x.log,"RESULT | INCONCLUSIVE"))
    assert(not has(x.log,"CHANGE_VERIFIED") and has(x.journal,"RESTORED_VERIFIED"))
    assert(has(result.text,"inte en felfri verifierad ändring"))
end)
test("null reply is not proof either way; real readback establishes roundtrip",function()
    local x=new{null_reply=true}; run(x)
    assert(x.provider_calls==2 and has(x.log,"RESULT | VERIFIED") and x.settings.ColdValue==27)
end)
for _,opt in ipairs({{change_applies_then_error=true},{restore_applies_then_error=true},{provider_error=true},
    {log_failure_after_change=true},{log_failure_after_change=true,change_applies_then_error=true}}) do
    test("restore and verify original despite a call/log error: "..tostring(next(opt)),function()
        local x=new(opt); run(x)
        assert(x.provider_calls==2 and x.settings.ColdValue==27 and has(x.journal,"RESTORED_VERIFIED"))
        assert(not has(x.log,"RESULT | VERIFIED"))
    end)
end
for _,opt in ipairs({{restore_error=true},{read_failure_after_change=true},{read_failure_after_restore=true},
    {concurrent_after=true},{concurrent_before_restore=true}}) do
    test("unconfirmed restore/concurrency leaves marker and manual recovery warning",function()
        local x=new(opt); local result=run(x)
        assert(x.provider_calls<=2 and x.journal==pending(27,26))
        assert(has(result.text,"ÅTERSTÄLLNING INTE BEKRÄFTAD") and has(result.text,"27"))
        assert(not has(x.log,"RESULT | VERIFIED"))
        if opt.concurrent_after then assert(x.provider_calls==1 and x.settings.WarmValue==14) end
        if opt.concurrent_before_restore then assert(x.provider_calls==1 and x.settings.ColdValue==17) end
    end)
end
for _,opt in ipairs({{journal_open_error=true},{journal_write_error=true},{journal_flush_error=true},{fail_before_provider=true}}) do
    test("failed journal/log checkpoint prevents test mutation",function()
        local x=new(opt); run(x)
        assert(x.provider_calls==0 and x.settings.ColdValue==27)
    end)
end
test("completed marker failure cannot hide actual readback or claim clean completion",function()
    local x=new{journal_complete_error=true}; local result=run(x)
    assert(x.settings.ColdValue==27 and x.provider_calls==2 and x.journal==pending(27,26))
    assert(has(result.text,"Originalvärdet är dock återläst") and not has(x.log,"RESULT | VERIFIED"))
end)
for _,content in ipairs({pending(27,26),pending(27,26).."RESTORED_VERIFIED\n","invalid",string.rep("x",4097)}) do
    test("any existing recovery record blocks restart without JNI or new writes",function()
        local x=new{recovery_content=content}; local result=x:prompt(); x:balanced()
        assert(not result.buttons and has(result.text,"återställningsfil"))
        assert(x.provider_calls==0 and x.ops==0 and x.journal==content and x.log_writes==0)
    end)
end
test("restart after failed restore never auto-restores",function()
    local x=new{restore_error=true}; run(x); local recovery=x.journal
    local y=new{recovery_content=recovery,settings={ColdValue=26}}
    local result=y:prompt(); y:balanced()
    assert(y.provider_calls==0 and y.settings.ColdValue==26 and has(result.text,"27"))
end)
for _,failed_restore in ipairs({false,true}) do
    test("context error after mutation cannot be reported as stopped before mutation",function()
        local x=new{context_error_after_mutation=true,restore_error=failed_restore}; local result=run(x)
        assert(x.provider_calls==2 and not has(result.text,"före någon inställningsändring"))
        if failed_restore then
            assert(x.journal==pending(27,26) and has(result.text,"ÅTERSTÄLLNING INTE BEKRÄFTAD"))
        else
            assert(has(x.journal,"RESTORED_VERIFIED") and has(result.text,"Originalvärdet är dock återläst"))
        end
    end)
end
test("changed plan after confirmation is rejected without a journal or mutation",function()
    local x=new(); local consent=prepare(x); x.settings.ColdValue=18
    consent.buttons[1][1].callback(); x:pump(); x:balanced()
    assert(x.provider_calls==0 and x.journal==nil and x.settings.ColdValue==18)
end)
test("both consent steps support cancellation/stale callbacks without mutation",function()
    local x=new(); local p=x:prompt(); p.buttons[2][1].callback(); p.buttons[1][1].callback(); x:pump(); x:balanced()
    assert(x.ops==0 and x.journal==nil)
    x=new(); local consent=prepare(x); consent.buttons[2][1].callback(); consent.buttons[1][1].callback(); x:pump(); x:balanced()
    assert(x.provider_calls==0 and x.journal==nil)
end)
test("unrelated topmost widget and child PID cannot run confirmation",function()
    local x=new(); local consent=prepare(x); x.top={}; consent.buttons[1][1].callback(); x:pump(); x:balanced(); assert(x.provider_calls==0)
    x=new(); consent=prepare(x); x.pid=17400; consent.buttons[1][1].callback(); x:pump(); x:balanced(); assert(x.provider_calls==0 and x.journal==nil)
    x=new(); consent=prepare(x); consent.buttons[1][1].callback(); x.pid=17400; x:pump(); x:balanced(); assert(x.provider_calls==0 and x.journal==nil)
end)
test("English plan, confirmation and restoration result",function()
    local x=new{language="en"}; local result,consent=run(x)
    assert(has(consent.title,"27 → 26 → 27") and has(result.text,"restored and verified"))
end)
for _,key in ipairs({"ColdValue","WarmValue","LightMode","LightUser_Brightness","LightUser_ColorTemp"}) do
    test("invalid input stops before confirmation: "..key,function()
        local x=new{settings={[key]=999}}; local result=prepare(x)
        assert(not result.buttons and x.provider_calls==0 and x.journal==nil)
    end)
end
for _,opt in ipairs({{missing_provider=true},{package="other"},{provider_class="other"},{authority="other"},{exported=false},{enabled=false},
    {flags=0},{write_permission="test.permission",permission_denied=true},{uid=2000},{context="u:r:shell:s0"},{log_failure=true},{log_full=true},
    {missing_method="getContentResolver"},{missing_field="exported"}}) do
    test("metadata/context/log/JNI guard stops prepare",function()
        local x=new(opt); local result=prepare(x); assert(not result.buttons and x.provider_calls==0 and x.journal==nil)
    end)
end
for _,name in ipairs({"call","<init>","putString","putInt"}) do
    test("all mutation/restore IDs resolved before marker and mutation: "..name,function()
        local x=new{missing_method=name}; run(x)
        assert(x.provider_calls==0 and x.journal==nil and x.settings.ColdValue==27)
    end)
end
for _,filename in ipairs({"2-bigme-frontlight.lua","2-bigme-frontlight-access-diagnostic.lua","2-bigme-frontlight-manual-test.lua",
    "2-bigme-frontlight-warm-test.lua","2-bigme-settings-readonly-diagnostic.lua","2-bigme-settings-provider-test.lua"}) do
    test("active earlier patch blocks all JNI: "..filename,function()
        local x=new{active_patch=filename}; local result=prepare(x)
        assert(not result.buttons and x.ops==0 and x.provider_calls==0 and x.journal==nil)
    end)
end
test("duplicate loading cannot create another plan or attempt",function()
    local x=new(); x:reload(); x:pump(); assert(#x.shown==1)
    run(x); x:reload(); x:pump(); x:balanced(); assert(#x.shown==3 and x.provider_calls==2)
end)
test("log failure after acquiring metadata UTF characters still releases them",function()
    local x=new{fail_log_stage="OK | GetStringUTFChars"}; local result=prepare(x)
    assert(not result.buttons and x.provider_calls==0 and x.utf_gets==x.utf_releases)
end)
fixture.close()
print(count.." roundtrip host tests passed; no real JVM/provider/hardware accessed")
