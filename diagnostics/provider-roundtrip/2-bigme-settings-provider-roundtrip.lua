-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Robin Bolinsson and contributors
-- Temporary MANUAL one-step ColdValue write/read/restore test r1.
-- No device open/ioctl, PowerD hook, raw-field access, mode/preset write,
-- permission change, shell or network. Android observers may react.
-- Original value is journaled before mutation. No automatic startup restoration.

local ok,android=pcall(require,"android")
if not ok or type(android)~="table" or type(android.prop)~="table" then return end
local function norm(v) return type(v)=="string" and v:lower():match("^%s*(.-)%s*$") or "" end
local prop=android.prop
if (norm(prop.manufacturer)~="bigme" and norm(prop.brand)~="bigme") or norm(prop.model)~="hibreak"
    or norm(prop.product)~="hibreak_eea" or norm(prop.hardware)~="mt6877" then return end
local ffi=require("ffi")
if ffi.os~="Linux" or ffi.arch~="arm64" then return end
require("ffi/posix_h")
local bit=require("bit")
local owner_pid=tonumber(ffi.C.getpid())
local function owner() return owner_pid and owner_pid>0 and tonumber(ffi.C.getpid())==owner_pid end
local UIManager=require("ui/uimanager")
local DataStorage=require("datastorage")
local data_dir=DataStorage:getDataDir()
if type(data_dir)~="string" or data_dir=="" then return end
local marker="_bigme_settings_provider_roundtrip_r1"
if type(android[marker])=="table" and android[marker].pid==owner_pid then return end
android[marker]={pid=owner_pid} -- Own diagnostic guard only; no device/bridge hook.
local report_path=data_dir .. "/bigme-settings-provider-roundtrip.log"
local recovery_path=data_dir .. "/bigme-settings-provider-roundtrip.recovery"
local PROFILE="hibreak_eea/mt6877/arm64"
local AUTHORITY="com.xrz.SettingProvider"
local METHOD="setting_put_data_system"
local active_files={"2-bigme-frontlight.lua","2-bigme-frontlight-access-diagnostic.lua",
    "2-bigme-frontlight-manual-test.lua","2-bigme-frontlight-warm-test.lua","2-bigme-settings-readonly-diagnostic.lua","2-bigme-settings-provider-test.lua"}
local sv=false
if G_reader_settings and type(G_reader_settings.readSetting)=="function" then
    local got,language=pcall(G_reader_settings.readSetting,G_reader_settings,"language")
    sv=got and type(language)=="string" and language:lower():match("^sv")~=nil
end
local text=sv and {
    title="Bigme – ändra, läs och återställ",
    intro="Testar en verklig ändring av endast den lagrade kalla nivån: ett steg och tillbaka. Inga direkta ljuskommandon skickas, men Android kan reagera. Återställning kan inte garanteras vid avbrott.\n\nStäng Bigmes ljusmeny och pausa ljusautomatiseringar. Ljuspatchen och alla äldre tester ska vara avstängda. Först visas planen för separat bekräftelse.",
    prepare="Visa testplan",run="Kör ändring och återställning",close="Avbryt",
    confirm="Kall nivå (ColdValue): %d → %d → %d.\n\nBara ColdValue skrivs, högst två anrop. Originalvärdet sparas före ändringen. Rör inga andra ljusreglage under testet. Vill du köra?",
    verified="Den ändrade nivån lästes tillbaka och originalvärdet är återställt och verifierat.",
    inconclusive="Testet gav inte en felfri verifierad ändring. Originalvärdet är dock återläst och verifierat.",
    stopped="Testet stoppades före någon inställningsändring.",
    recovery="ÅTERSTÄLLNING INTE BEKRÄFTAD.\nAnvänd Bigmes egen meny för att kontrollera/återställa kall nivå %d. Fortsätt inte testa.",
    existing="En återställningsfil finns redan. Inget nytt test eller automatisk återställning körs.",
    completed="Filen visar att det tidigare testets originalvärde verifierades. Kör inte igen; skicka loggen och inaktivera testet.",
    journal_warning="Originalvärdet verifierades, men återställningsfilen kunde inte markeras klar. Behåll filen och kör inte igen.",
    invalid="Filen kan inte tolkas säkert. Ändra inget via testet; skicka loggen och återställningsfilen.",
    limit="Råfält, fysisk ljusstyrning och full synkning är fortfarande otestade.",
    report="Skicka loggen:",save_error="Loggfel – fotografera rutan och behåll återställningsfilen.",
} or {
    title="Bigme – change, read and restore",
    intro="Tests one real change to only the stored cold level: one step and back. No direct light command is sent, but Android may react. Restoration cannot be guaranteed after interruption.\n\nClose Bigme's panel, pause light automations and disable the driver/all earlier tests. A plan is shown for separate confirmation first.",
    prepare="Show test plan",run="Run change and restoration",close="Cancel",
    confirm="Cold level (ColdValue): %d → %d → %d.\n\nOnly ColdValue is written, at most two calls. The original is saved before mutation. Do not touch other light controls during the test. Run?",
    verified="The changed level was read back and the original was restored and verified.",
    inconclusive="A clean change was not verified. The original value was nevertheless read back and verified.",
    stopped="Stopped before any settings mutation was attempted.",
    recovery="RESTORATION NOT CONFIRMED.\nUse Bigme's own panel to check/restore cold level %d. Stop testing.",
    existing="A recovery file already exists. No new test or automatic restoration will run.",
    completed="It records verified restoration from the earlier test. Do not rerun; send the log and disable this test.",
    journal_warning="The original was verified, but the recovery file could not be marked complete. Preserve it and do not rerun.",
    invalid="Cannot safely interpret the file. Do not use the test; send the log and recovery file.",
    limit="Raw fields, physical light output and full synchronization remain untested.",
    report="Send the log:",save_error="Log error – photograph this dialog and preserve the recovery file.",
}
local function clean(v,n) return tostring(v==nil and "unavailable" or v):gsub("[%z\1-\31\127]"," "):sub(1,n or 2048) end
local report_error
local function record(stage,detail)
    if not owner() then error("Not the owning KOReader process",0) end
    local file,why=io.open(report_path,"a")
    if not file then report_error=clean(why); error("Cannot open diagnostic log: "..report_error,0) end
    local wrote,issue=pcall(function()
        local size=assert(file:seek("end"))
        assert(size<262144,"Diagnostic log full; move it aside before another run")
        assert(file:write(clean(stage,160).." | "..clean(detail).."\n"))
    end)
    local closed,value=pcall(file.close,file)
    if not wrote or not closed or not value then
        report_error=clean(issue or "Could not close diagnostic log"); error(report_error,0)
    end
end
local function read_recovery()
    local file=io.open(recovery_path,"rb")
    if not file then return nil end
    local ok,value=pcall(file.read,file,4097)
    local closed,done=pcall(file.close,file)
    assert(ok and closed and done and type(value)=="string" and #value<=4096,"Cannot safely read recovery file")
    return value
end
local function journal(plan)
    return "BIGME_PROVIDER_ROUNDTRIP_V1\nprofile="..PROFILE.."\nkey=ColdValue\noriginal="..plan.original
        .."\ntarget="..plan.target.."\nPENDING\n"
end
local function parse_recovery(value)
    if not value then return nil end
    local original,target,tail=value:match("^BIGME_PROVIDER_ROUNDTRIP_V1\nprofile=hibreak_eea/mt6877/arm64\nkey=ColdValue\noriginal=(%d+)\ntarget=(%d+)\nPENDING\n(.*)$")
    original,target=tonumber(original),tonumber(target)
    if not original or original<0 or original>36 or target~=(original>0 and original-1 or 1)
        or (tail~="" and tail~="RESTORED_VERIFIED\n") then return {invalid=true} end
    return {original=original,target=target,restored=tail=="RESTORED_VERIFIED\n"}
end
local function append_journal(value,expected,creating)
    local file=assert(io.open(recovery_path,creating and "a+" or "a"),"Cannot open recovery file")
    local wrote,issue=pcall(function()
        if creating then assert(file:seek("end")==0,"Refusing to overwrite an existing recovery file") end
        assert(file:write(value)); assert(file:flush())
    end)
    local closed,done=pcall(file.close,file)
    assert(wrote and closed and done,issue or "Cannot close recovery file")
    assert(read_recovery()==expected,"Recovery file verification failed")
end
local function create_journal(plan)
    assert(read_recovery()==nil,"Existing recovery file blocks this attempt")
    local value=journal(plan)
    append_journal(value,value,true)
end
local function complete_journal(plan)
    local pending=journal(plan)
    assert(read_recovery()==pending,"Recovery file changed; not overwriting it")
    append_journal("RESTORED_VERIFIED\n",pending.."RESTORED_VERIFIED\n",false)
end
local function context_test(plan)
    local stage="setup"
    local last_outcome
    local complete,result=pcall(function()
        record("SESSION","roundtrip-r1 UTC="..os.date("!%Y-%m-%dT%H:%M:%SZ").." PHASE="..(plan and "CONFIRMED" or "PREPARE").." HARDWARE_IO=false RAW_KEYS=false")
        assert(read_recovery()==nil,"Existing recovery file blocks test; no automatic restoration")
        for _,key in ipairs({"manufacturer","brand","model","product","hardware"}) do record("DEVICE "..key,prop[key]) end
        assert(tonumber(ffi.C.getuid())>=10000,"Requires ordinary Android app UID")
        for _,filename in ipairs(active_files) do
            local file=io.open(data_dir.."/patches/"..filename,"rb")
            if file then file:close(); error("Disable active patch first: "..filename,0) end
        end
        local file=assert(io.open("/proc/self/attr/current","r"),"Cannot check app context")
        local got,context=pcall(file.read,file,256); file:close()
        assert(got and type(context)=="string" and context:match("^u:r:untrusted_app[^:]*:"),"Unsupported app context")
        assert(type(android.jni)=="table" and type(android.jni.context)=="function","Missing JNI context API")
        local activity=assert(android.app and android.app.activity,"Missing Android activity")
        assert(activity.vm and activity.clazz,"Missing Android activity handles")
        return android.jni:context(activity.vm,function(jni)
            local env=jni.env
            local api,refs=env[0],{}
            local restoring=false
            local outcome={kind="STOPPED",attempted=false,changed=false,restored=false,pending=false}
            last_outcome=outcome
            local function trace(name,detail)
                if restoring then pcall(record,name,detail) else record(name,detail) end
            end
            local function nonnull(v) return v~=nil and v~=ffi.NULL end
            local function keep(v) if nonnull(v) then refs[#refs+1]=v end; return v end
            local function clear_secondary()
                if api.ExceptionCheck(env)~=0 then api.ExceptionClear(env); return false end
                return true
            end
            local function exception_text()
                local throwable=keep(api.ExceptionOccurred(env)); api.ExceptionClear(env)
                if not nonnull(throwable) then return "Java exception (object unavailable)" end
                local chars,string_ref
                local formatted,value=pcall(function()
                    local cls=keep(api.GetObjectClass(env,throwable))
                    assert(clear_secondary() and nonnull(cls),"Throwable class unavailable")
                    local method=api.GetMethodID(env,cls,"toString","()Ljava/lang/String;")
                    assert(clear_secondary() and nonnull(method),"Throwable.toString unavailable")
                    string_ref=keep(api.CallObjectMethodA(env,throwable,method,nil))
                    assert(clear_secondary() and nonnull(string_ref),"Throwable string unavailable")
                    local length=tonumber(api.GetStringUTFLength(env,string_ref))
                    assert(clear_secondary() and length and length>=0,"Throwable length unavailable")
                    chars=api.GetStringUTFChars(env,string_ref,nil)
                    assert(clear_secondary() and nonnull(chars),"Throwable characters unavailable")
                    return clean(ffi.string(chars,math.min(length,2048)))
                end)
                if nonnull(chars) then pcall(api.ReleaseStringUTFChars,env,string_ref,chars) end
                clear_secondary()
                return formatted and value or ("Java exception; Throwable unavailable: "..clean(value,256))
            end
            local function step(name,fn,reference,nullable)
                assert(owner(),"Not owning process")
                stage=name; trace("BEGIN",name)
                local value=fn()
                if reference then keep(value) end
                if api.ExceptionCheck(env)~=0 then error(exception_text(),0) end
                if not nullable then assert(nonnull(value),"Null JNI result") end
                trace("OK",name)
                return value
            end
            local function args(values)
                if #values==0 then return nil end
                local out=ffi.new("jvalue[?]",#values)
                for i,item in ipairs(values) do out[i-1][item[1]]=item[2] end
                return out
            end
            local function str(value) return step("NewStringUTF("..value..")",function() return api.NewStringUTF(env,value) end,true) end
            local function method(cls,name,sig,static)
                return step("GetMethodID("..name..")",function()
                    if static then return api.GetStaticMethodID(env,cls,name,sig) end
                    return api.GetMethodID(env,cls,name,sig)
                end)
            end
            local function class(name) return step("FindClass("..name..")",function() return api.FindClass(env,name) end,true) end
            local function object_class(obj) return step("GetObjectClass",function() return api.GetObjectClass(env,obj) end,true) end
            local function string_value(ref)
                if not nonnull(ref) then return nil end
                local chars
                local got,value=pcall(function()
                    local length=tonumber(step("GetStringUTFLength",function() return api.GetStringUTFLength(env,ref) end))
                    assert(length and length>=0 and length<=2048,"Unexpected metadata length")
                    step("GetStringUTFChars",function() chars=api.GetStringUTFChars(env,ref,nil); return chars end)
                    return ffi.string(chars,length)
                end)
                if nonnull(chars) then pcall(api.ReleaseStringUTFChars,env,ref,chars) end
                if not got then error(value,0) end
                return value
            end
            local success,value=pcall(function()
                if api.ExceptionCheck(env)~=0 then stage="pre-existing Java exception"; error(exception_text(),0) end
                local activity_cls=object_class(activity.clazz)
                local get_resolver=method(activity_cls,"getContentResolver","()Landroid/content/ContentResolver;")
                local resolver=step("Activity.getContentResolver",function() return api.CallObjectMethodA(env,activity.clazz,get_resolver,nil) end,true)
                local get_pm=method(activity_cls,"getPackageManager","()Landroid/content/pm/PackageManager;")
                local pm=step("Activity.getPackageManager",function() return api.CallObjectMethodA(env,activity.clazz,get_pm,nil) end,true)
                local pm_cls=object_class(pm)
                local resolve=method(pm_cls,"resolveContentProvider","(Ljava/lang/String;I)Landroid/content/pm/ProviderInfo;")
                local authority=str(AUTHORITY)
                local info=step("PackageManager.resolveContentProvider",function()
                    return api.CallObjectMethodA(env,pm,resolve,args({{"l",authority},{"i",0}}))
                end,true)
                local info_cls=object_class(info)
                local function field(obj,cls,name,sig,kind,nullable)
                    local id=step("GetFieldID("..name..")",function() return api.GetFieldID(env,cls,name,sig) end)
                    return step("GetField("..name..")",function()
                        if kind=="int" then return api.GetIntField(env,obj,id) end
                        if kind=="bool" then return api.GetBooleanField(env,obj,id) end
                        return api.GetObjectField(env,obj,id)
                    end,kind=="object",nullable)
                end
                local package=string_value(field(info,info_cls,"packageName","Ljava/lang/String;","object"))
                local name=string_value(field(info,info_cls,"name","Ljava/lang/String;","object"))
                local actual_authority=string_value(field(info,info_cls,"authority","Ljava/lang/String;","object"))
                local exported=tonumber(field(info,info_cls,"exported","Z","bool"))
                local enabled=tonumber(field(info,info_cls,"enabled","Z","bool"))
                trace("PROVIDER",clean(package).."/"..clean(name).." authority="..clean(actual_authority).." exported="..exported.." enabled="..enabled)
                assert(package=="com.xrz.settings" and name=="com.xrz.settings.provider.SettingProvider" and actual_authority==AUTHORITY,"Unexpected provider identity")
                assert(exported==1 and enabled==1,"Provider is not exported/enabled")
                local app_info=field(info,info_cls,"applicationInfo","Landroid/content/pm/ApplicationInfo;","object")
                local flags=tonumber(field(app_info,object_class(app_info),"flags","I","int"))
                trace("PROVIDER_FLAGS",flags)
                assert(flags and bit.band(flags,129)~=0,"Provider owner is not a system application")
                local check_permission
                for _,key in ipairs({"readPermission","writePermission"}) do
                    local permission=string_value(field(info,info_cls,key,"Ljava/lang/String;","object",true))
                    trace("PROVIDER "..key,permission or "none")
                    if permission and permission~="" then
                        check_permission=check_permission or method(activity_cls,"checkSelfPermission","(Ljava/lang/String;)I")
                        local permission_ref=str(permission)
                        local allowed=tonumber(step("Activity.checkSelfPermission",function()
                            return api.CallIntMethodA(env,activity.clazz,check_permission,args({{"l",permission_ref}}))
                        end))
                        assert(allowed==0,"Existing provider permission not granted; no request or change made")
                    end
                end
                local system=class("android/provider/Settings$System")
                local get_int=method(system,"getInt","(Landroid/content/ContentResolver;Ljava/lang/String;I)I",true)
                local function read_snapshot(label)
                    local values={}
                    local function read(key)
                        local key_ref=str(key)
                        local result=tonumber(step("Settings.System.getInt("..key..")",function()
                            return api.CallStaticIntMethodA(env,system,get_int,args({{"l",resolver},{"l",key_ref},{"i",-1}}))
                        end))
                        values[key]=result; trace(label.." VALUE",key.."="..tostring(result))
                        assert(result and result==math.floor(result) and result>=0 and result<=(key=="LightMode" and 4 or 36),"Invalid or missing current value: "..key)
                    end
                    read("ColdValue"); read("WarmValue"); read("LightMode")
                    if values.LightMode==4 then read("LightUser_Brightness"); read("LightUser_ColorTemp") end
                    return values
                end
                local initial=read_snapshot("INITIAL")
                local function matches(values,expected)
                    for key,v in pairs(expected) do if values[key]~=v then return false end end
                    for key,v in pairs(values) do if expected[key]~=v then return false end end
                    return true
                end
                local original=initial.ColdValue
                local target=original>0 and original-1 or 1
                if not plan then
                    trace("PLAN","ColdValue "..original.." -> "..target.." -> "..original.."; no mutation")
                    return {kind="PLAN",original=original,target=target,snapshot=initial}
                end
                assert(plan.original==original and plan.target==target and matches(initial,plan.snapshot),"Values changed since confirmation; no mutation")
                outcome.original=original; outcome.target=target
                local expected={}
                for key,v in pairs(initial) do expected[key]=v end
                expected.ColdValue=target
                local uri_cls=class("android/net/Uri")
                local parse=method(uri_cls,"parse","(Ljava/lang/String;)Landroid/net/Uri;",true)
                local uri_text=str("content://"..AUTHORITY)
                local uri=step("Uri.parse",function() return api.CallStaticObjectMethodA(env,uri_cls,parse,args({{"l",uri_text}})) end,true)
                local bundle_cls=class("android/os/Bundle")
                local constructor=method(bundle_cls,"<init>","()V")
                local put_string=method(bundle_cls,"putString","(Ljava/lang/String;Ljava/lang/String;)V")
                local put_int=method(bundle_cls,"putInt","(Ljava/lang/String;I)V")
                local call=method(object_class(resolver),"call","(Landroid/net/Uri;Ljava/lang/String;Ljava/lang/String;Landroid/os/Bundle;)Landroid/os/Bundle;")
                local call_method=str(METHOD)
                local name_key,type_key,value_key=str("name"),str("type"),str("value")
                local key_ref=str("ColdValue")
                local function make_bundle(level)
                    assert(level==original or level==target,"Out-of-plan value")
                    local bundle=step("Bundle.<init>",function() return api.NewObjectA(env,bundle_cls,constructor,nil) end,true)
                    step("Bundle.putString(name)",function() api.CallVoidMethodA(env,bundle,put_string,args({{"l",name_key},{"l",key_ref}})) end,false,true)
                    step("Bundle.putInt(type=1)",function() api.CallVoidMethodA(env,bundle,put_int,args({{"l",type_key},{"i",1}})) end,false,true)
                    step("Bundle.putInt(value)",function() api.CallVoidMethodA(env,bundle,put_int,args({{"l",value_key},{"i",level}})) end,false,true)
                    return bundle
                end
                -- Resolve and allocate BOTH calls before journaling or mutation.
                local change_bundle=make_bundle(target)
                local restore_bundle=make_bundle(original)
                assert(matches(read_snapshot("BEFORE_CHANGE"),initial),"Values changed before test; no mutation")
                stage="Create recovery record"
                create_journal(plan)
                outcome.pending=true
                trace("JOURNAL_VERIFIED","original="..original.." target="..target.." key=ColdValue")
                local function provider_call(label,bundle,is_change)
                    stage="ContentResolver.call("..label..")"
                    trace("PROVIDER_CALL_BEGIN",label.." ColdValue="..(is_change and target or original))
                    local reply=step("ContentResolver.call("..label..")",function()
                        assert(owner(),"Not owning process")
                        if is_change then outcome.attempted=true end
                        return api.CallObjectMethodA(env,resolver,call,args({{"l",uri},{"l",call_method},{"l",ffi.NULL},{"l",bundle}}))
                    end,true,true)
                    trace("PROVIDER_CALL_RETURNED",label.." response_bundle="..tostring(nonnull(reply)).."; status not used as proof")
                end
                local change_ok,change_error=pcall(function()
                    provider_call("CHANGE",change_bundle,true)
                    local observed=read_snapshot("AFTER_CHANGE")
                    outcome.changed=matches(observed,expected)
                    assert(outcome.changed,"Target value not observed, or another value changed")
                    trace("CHANGE_VERIFIED","ColdValue="..target.."; all other readable light values unchanged")
                end)
                if not change_ok then outcome.test_error=stage..": "..clean(change_error) end

                -- Restoration is a single compensating call, NOT a retry.
                -- Log failures must never prevent this safety path. All JNI IDs,
                -- state/range and owner checks remain mandatory.
                restoring=true
                local restore_ok,restore_error=pcall(function()
                    local current=read_snapshot("RESTORE_CHECK")
                    assert(matches(current,initial) or matches(current,expected),
                        "Current values differ from original/test state; refusing blind overwrite")
                    if outcome.attempted then provider_call("RESTORE",restore_bundle,false) end
                end)
                if not restore_ok then outcome.restore_error=stage..": "..clean(restore_error) end
                local verified,verify_error=pcall(function()
                    local current=read_snapshot("RESTORE_VERIFY")
                    assert(matches(current,initial),"Original state not verified")
                    outcome.restored=true
                    trace("ORIGINAL_VERIFIED","ColdValue="..original.."; other readable values match original")
                end)
                if not verified then outcome.verify_error=stage..": "..clean(verify_error) end
                if outcome.restored then
                    local saved,why=pcall(complete_journal,plan)
                    if saved then outcome.pending=false else outcome.journal_error=clean(why) end
                end
                outcome.kind=outcome.restored and "INCONCLUSIVE" or "RECOVERY_REQUIRED"
                if outcome.changed and change_ok and restore_ok and outcome.restored and not outcome.pending and not report_error then outcome.kind="VERIFIED" end
                trace("RESULT",outcome.kind.." changed="..tostring(outcome.changed).." original_verified="..tostring(outcome.restored).." recovery_pending="..tostring(outcome.pending))
                return outcome
            end)
            if api.ExceptionCheck(env)~=0 then api.ExceptionClear(env) end
            for i=#refs,1,-1 do pcall(api.DeleteLocalRef,env,refs[i]) end
            if api.ExceptionCheck(env)~=0 then api.ExceptionClear(env) end
            if not success then
                outcome.error=stage..": "..clean(value)
                if outcome.pending then outcome.kind="RECOVERY_REQUIRED" end
                return outcome
            end
            return value
        end)
    end)
    if not complete then
        local problem=stage..": "..clean(result)
        if last_outcome and (last_outcome.attempted or last_outcome.pending) then
            -- A context/cleanup error must not erase knowledge of a mutation.
            last_outcome.error=problem
            last_outcome.kind=last_outcome.restored and "INCONCLUSIVE" or "RECOVERY_REQUIRED"
            pcall(record,"CONTEXT_ERROR",problem)
            return last_outcome
        end
        pcall(record,"STOPPED",problem)
        return {kind="STOPPED",error=problem}
    end
    return result
end
local function notify(message)
    if not owner() then return end
    local InfoMessage=require("ui/widget/infomessage")
    UIManager:show(InfoMessage:new{text=text.title.."\n\n"..message,show_icon=false,dismissable=true,honor_silent_mode=false,sui_native=true})
end
local function show_result(result)
    local message
    if result.kind=="VERIFIED" then message=text.verified
    elseif result.restored then message=text.inconclusive
    elseif result.pending then message=string.format(text.recovery,result.original)
    else message=text.stopped end
    if result.restored and result.pending then message=message.."\n\n"..text.journal_warning end
    for _,key in ipairs({"error","test_error","restore_error","verify_error","journal_error"}) do
        if result[key] then message=message.."\n\n"..clean(result[key],300) end
    end
    notify(message.."\n\n"..text.limit.."\n\n"..(report_error and (text.save_error.."\n") or "")
        ..text.report.."\n"..report_path.."\n"..recovery_path)
end
local function show_sheet(title,button,on_run,on_cancel)
    local closed,sheet=false,nil
    local function close()
        if closed then return end
        closed=true; UIManager:close(sheet)
    end
    sheet=require("ui/widget/buttondialog"):new{title=text.title.."\n\n"..title,title_align="left",sui_native=true,buttons={
        {{text=button,callback=function()
            if closed or not owner() then return end
            if type(UIManager.getTopmostVisibleWidget)=="function" and UIManager:getTopmostVisibleWidget()~=sheet then return end
            close(); UIManager:scheduleIn(0,function() if owner() then on_run() end end)
        end}},
        {{text=text.close,callback=function() close(); if on_cancel then on_cancel() end end}},
    }}
    local original_close=sheet.onCloseWidget
    sheet.onCloseWidget=function(self,...) closed=true; if original_close then return original_close(self,...) end end
    UIManager:show(sheet)
end
UIManager:scheduleIn(0,function()
    if not owner() then return end
    local ok,contents=pcall(read_recovery)
    if not ok or contents~=nil then
        local info=ok and parse_recovery(contents)
        local message=text.existing.."\n\n"
        if info and not info.invalid then
            message=message..(info.restored and text.completed or string.format(text.recovery,info.original))
        else message=message..text.invalid end
        notify(message.."\n\n"..report_path.."\n"..recovery_path)
        return
    end
    show_sheet(text.intro,text.prepare,function()
        local result=context_test(nil)
        if result.kind~="PLAN" then show_result(result); return end
        show_sheet(string.format(text.confirm,result.original,result.target,result.original),text.run,function()
            show_result(context_test(result))
        end,function() pcall(record,"CANCELLED","No mutation; confirmation declined") end)
    end)
end)
