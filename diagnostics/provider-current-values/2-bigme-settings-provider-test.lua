-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Robin Bolinsson and contributors
-- Temporary, manually triggered Bigme provider SAME-VALUE test r1.
-- No device open/ioctl, PowerD hook, new light level, raw-key write, mode change,
-- permission request, secure/global operation, shell command or network access.
-- Same-value provider calls can still notify Android observers. Not read-only.

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
local marker="_bigme_settings_provider_test_r1"
if type(android[marker])=="table" and android[marker].pid==owner_pid then return end
android[marker]={pid=owner_pid} -- Own diagnostic guard only; no device/bridge hook.
local report_path=data_dir .. "/bigme-settings-provider-test.log"
local AUTHORITY="com.xrz.SettingProvider"
local METHOD="setting_put_data_system"
local active_files={"2-bigme-frontlight.lua","2-bigme-frontlight-access-diagnostic.lua",
    "2-bigme-frontlight-manual-test.lua","2-bigme-frontlight-warm-test.lua","2-bigme-settings-readonly-diagnostic.lua"}
local sv=false
if G_reader_settings and type(G_reader_settings.readSetting)=="function" then
    local got,language=pcall(G_reader_settings.readSetting,G_reader_settings,"language")
    sv=got and type(language)=="string" and language:lower():match("^sv")~=nil
end
local text=sv and {
    title="Bigme – test av inställningstjänst",
    intro="Testet sparar tillbaka de aktuella läsbara ljusnivåerna via Bigmes tjänst. Det väljer inga nya nivåer och skickar inga ljuskommandon. Det är inte enbart avläsning.\n\nStäng Bigmes ljusmeny och pausa ljusautomatiseringar. Ljuspatchen och alla äldre tester måste vara avstängda. Kör en gång och skicka loggen.",
    run="Prova aktuella värden",close="Stäng utan test",stopped="Testet stoppades:",
    returned="Anropen returnerade utan Java-fel och de läsbara värdena är oförändrade.",
    limit="Det bevisar inte att skrivningar verkställs. Råfält och full ljussynkning är inte testade.",
    safe="Testet har inte skickat några ljuskommandon eller begärt/ändrat behörigheter.",
    report="Skicka loggen:",save_error="Loggen kunde inte sparas. Fotografera rutan.",
} or {
    title="Bigme – settings provider test",
    intro="This test saves the current readable light levels back through Bigme's provider. It chooses no new levels and sends no light commands. It is not read-only.\n\nClose Bigme's light panel and pause light automations. Disable the frontlight patch and all earlier tests. Run once and send the log.",
    run="Try current values",close="Close without test",stopped="Test stopped:",
    returned="Calls returned without Java errors and readable values are unchanged.",
    limit="This does not prove writes took effect. Raw fields and full light synchronization were not tested.",
    safe="This test sent no light commands and did not request/change permissions.",
    report="Send the log:",save_error="Could not save the log. Photograph this dialog.",
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
local used,closed,prompt=false,false,nil
local function run_test()
    local stage="setup"
    local complete,result=pcall(function()
        record("SESSION","provider-r1 UTC="..os.date("!%Y-%m-%dT%H:%M:%SZ").." SAME_VALUE_ONLY=true HARDWARE_IO=false RAW_KEYS=false")
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
                stage=name; record("BEGIN",name)
                local value=fn()
                if reference then keep(value) end
                if api.ExceptionCheck(env)~=0 then error(exception_text(),0) end
                if not nullable then assert(nonnull(value),"Null JNI result") end
                record("OK",name)
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
                    chars=step("GetStringUTFChars",function() return api.GetStringUTFChars(env,ref,nil) end)
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
                record("PROVIDER",clean(package).."/"..clean(name).." authority="..clean(actual_authority).." exported="..exported.." enabled="..enabled)
                assert(package=="com.xrz.settings" and name=="com.xrz.settings.provider.SettingProvider" and actual_authority==AUTHORITY,"Unexpected provider identity")
                assert(exported==1 and enabled==1,"Provider is not exported/enabled")
                local app_info=field(info,info_cls,"applicationInfo","Landroid/content/pm/ApplicationInfo;","object")
                local flags=tonumber(field(app_info,object_class(app_info),"flags","I","int"))
                record("PROVIDER_FLAGS",flags)
                assert(flags and bit.band(flags,129)~=0,"Provider owner is not a system application")
                local check_permission
                for _,key in ipairs({"readPermission","writePermission"}) do
                    local permission=string_value(field(info,info_cls,key,"Ljava/lang/String;","object",true))
                    record("PROVIDER "..key,permission or "none")
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
                        values[key]=result; record(label.." VALUE",key.."="..tostring(result))
                        assert(result and result==math.floor(result) and result>=0 and result<=(key=="LightMode" and 4 or 36),"Invalid or missing current value: "..key)
                    end
                    read("ColdValue"); read("WarmValue"); read("LightMode")
                    if values.LightMode==4 then read("LightUser_Brightness"); read("LightUser_ColorTemp") end
                    return values
                end
                local initial=read_snapshot("INITIAL")
                local function unchanged(values)
                    for key,v in pairs(initial) do assert(values[key]==v,"Current values changed at "..key.."; stopping, no restore/retry") end
                    for key,v in pairs(values) do assert(initial[key]==v,"Current mode changed; stopping, no restore/retry") end
                end
                local uri_cls=class("android/net/Uri")
                local parse=method(uri_cls,"parse","(Ljava/lang/String;)Landroid/net/Uri;",true)
                local uri_text=str("content://"..AUTHORITY)
                local uri=step("Uri.parse",function() return api.CallStaticObjectMethodA(env,uri_cls,parse,args({{"l",uri_text}})) end,true)
                local bundle_cls=class("android/os/Bundle")
                local constructor=method(bundle_cls,"<init>","()V")
                local put_string=method(bundle_cls,"putString","(Ljava/lang/String;Ljava/lang/String;)V")
                local put_int=method(bundle_cls,"putInt","(Ljava/lang/String;I)V")
                local contains=method(bundle_cls,"containsKey","(Ljava/lang/String;)Z")
                local bundle_get=method(bundle_cls,"getInt","(Ljava/lang/String;I)I")
                local call=method(object_class(resolver),"call","(Landroid/net/Uri;Ljava/lang/String;Ljava/lang/String;Landroid/os/Bundle;)Landroid/os/Bundle;")
                local call_method=str(METHOD)
                local name_key,type_key,value_key,status_key=str("name"),str("type"),str("value"),str("status")
                local keys={"ColdValue","WarmValue"}
                if initial.LightMode==4 then keys[#keys+1]="LightUser_Brightness"; keys[#keys+1]="LightUser_ColorTemp" end
                for _,key in ipairs(keys) do
                    local current=initial[key]
                    local key_ref=str(key)
                    local bundle=step("Bundle.<init>",function() return api.NewObjectA(env,bundle_cls,constructor,nil) end,true)
                    step("Bundle.putString(name)",function() api.CallVoidMethodA(env,bundle,put_string,args({{"l",name_key},{"l",key_ref}})) end,false,true)
                    step("Bundle.putInt(type=1)",function() api.CallVoidMethodA(env,bundle,put_int,args({{"l",type_key},{"i",1}})) end,false,true)
                    step("Bundle.putInt(value)",function() api.CallVoidMethodA(env,bundle,put_int,args({{"l",value_key},{"i",current}})) end,false,true)
                    unchanged(read_snapshot("BEFORE "..key))
                    record("PROVIDER_CALL_BEGIN",METHOD.." "..key.."="..current.." SAME_VALUE_ONLY=true")
                    local reply=step("ContentResolver.call("..key..")",function()
                        return api.CallObjectMethodA(env,resolver,call,args({{"l",uri},{"l",call_method},{"l",ffi.NULL},{"l",bundle}}))
                    end,true,true)
                    unchanged(read_snapshot("AFTER "..key))
                    assert(nonnull(reply),"Provider returned no Bundle; effect unconfirmed, no retry")
                    local has_status=tonumber(step("Bundle.containsKey(status)",function()
                        return api.CallBooleanMethodA(env,reply,contains,args({{"l",status_key}}))
                    end))
                    local status="absent"
                    if has_status==1 then status=tonumber(step("Bundle.getInt(status)",function()
                        return api.CallIntMethodA(env,reply,bundle_get,args({{"l",status_key},{"i",-2147483647}}))
                    end)) end
                    record("PROVIDER_CALL_RETURNED",key.." status="..tostring(status).." readable_values_unchanged=true WRITE_EFFECT_UNCONFIRMED=true")
                    -- OEM code initializes status=-1 and does not update it on
                    -- this branch. Never interpret it or unchanged readback as
                    -- successful mutation. Do not probe any other operation.
                end
                record("COMPLETE","SAME_VALUE_CALLS_RETURNED; NOT_PROOF_OF_WRITE_EFFECT; RAW_KEYS_UNTESTED; NO_HARDWARE_COMMANDS")
                return true
            end)
            if api.ExceptionCheck(env)~=0 then api.ExceptionClear(env) end
            for i=#refs,1,-1 do pcall(api.DeleteLocalRef,env,refs[i]) end
            if api.ExceptionCheck(env)~=0 then api.ExceptionClear(env) end
            return {ok=success,error=not success and (stage..": "..clean(value)) or nil}
        end)
    end)
    local passed=complete and type(result)=="table" and result.ok
    local problem=not complete and clean(result) or (type(result)=="table" and result.error or "Missing diagnostic result")
    if not passed then pcall(record,"STOPPED",problem) end
    if not owner() then return end
    local InfoMessage=require("ui/widget/infomessage")
    UIManager:show(InfoMessage:new{text=text.title.."\n\n"..(passed and (text.returned.."\n\n"..text.limit) or (text.stopped.."\n"..clean(problem,480)))
        .."\n\n"..text.safe.."\n\n"..(report_error and text.save_error or (text.report.."\n"..report_path)),
        show_icon=false,dismissable=true,honor_silent_mode=false,sui_native=true})
end
UIManager:scheduleIn(0,function()
    if not owner() then return end
    local ButtonDialog=require("ui/widget/buttondialog")
    local function close()
        if closed then return end
        closed=true; UIManager:close(prompt)
    end
    prompt=ButtonDialog:new{title=text.title.."\n\n"..text.intro,title_align="left",sui_native=true,buttons={
        {{text=text.run,callback=function()
            if used or closed or not owner() then return end
            if type(UIManager.getTopmostVisibleWidget)=="function" and UIManager:getTopmostVisibleWidget()~=prompt then return end
            used=true; close(); UIManager:scheduleIn(0,function() if owner() then run_test() end end)
        end}},
        {{text=text.close,callback=close}},
    }}
    local original_close=prompt.onCloseWidget
    prompt.onCloseWidget=function(self,...) closed=true; if original_close then return original_close(self,...) end end
    UIManager:show(prompt)
end)
