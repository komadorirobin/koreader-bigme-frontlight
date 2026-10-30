-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Robin Bolinsson and contributors
-- Temporary Bigme Android-settings READ-ONLY diagnostic r1.
-- No light device access, settings writes, permission changes or PowerD hooks.
-- JNI runs only after an explicit button press, once per KOReader process.

local ok, android = pcall(require, "android")
if not ok or type(android) ~= "table" or type(android.prop) ~= "table" then return end
local function norm(v) return type(v) == "string" and v:lower():match("^%s*(.-)%s*$") or "" end
local prop = android.prop
if (norm(prop.manufacturer) ~= "bigme" and norm(prop.brand) ~= "bigme")
    or norm(prop.model) ~= "hibreak" or norm(prop.product) ~= "hibreak_eea"
    or norm(prop.hardware) ~= "mt6877" then return end
local ffi = require("ffi")
if ffi.os ~= "Linux" or ffi.arch ~= "arm64" then return end
require("ffi/posix_h")
local owner_pid = tonumber(ffi.C.getpid())
local function owner() return owner_pid and owner_pid > 0 and tonumber(ffi.C.getpid()) == owner_pid end
local UIManager = require("ui/uimanager")
local DataStorage = require("datastorage")
local data_dir = DataStorage:getDataDir()
if type(data_dir) ~= "string" or data_dir == "" then return end
local report_path = data_dir .. "/bigme-settings-readonly-diagnostic.log"
local sv = false
if G_reader_settings and type(G_reader_settings.readSetting) == "function" then
    local got, language = pcall(G_reader_settings.readSetting, G_reader_settings, "language")
    sv = got and type(language) == "string" and language:lower():match("^sv") ~= nil
end
local text = sv and {
    title="Bigme – avläsningsdiagnostik",
    intro="Detta test läser bara Androids ljusinställningar. Det styr inte ljuset och ändrar inga inställningar eller behörigheter.\n\nLjuspatchen och alla tidigare ljus-testpatchar måste vara avstängda. Testet jämför två anropssätt och sparar anropens namn och Java-feltext.\n\nKör en gång, skicka loggen och inaktivera sedan diagnostikpatchen.",
    run="Kör avläsning", close="Stäng utan test", report="Skicka loggen:",
    safe="Inga ljuskommandon eller inställningsändringar har gjorts av denna diagnostik.",
    blocked="Testet stoppades:", saved_error="Loggen kunde inte sparas. Fotografera rutan.",
} or {
    title="Bigme – read-only settings diagnostic",
    intro="This test only reads Android light settings. It does not control lights, change settings or request permissions.\n\nDisable the frontlight patch and all previous light-test patches first. The test compares two call styles and logs operation names and Java exception text.\n\nRun once, send the log, then disable this diagnostic patch.",
    run="Run read-only test", close="Close without test", report="Send the log:",
    safe="This diagnostic sent no light commands and changed no settings.",
    blocked="Test stopped:", saved_error="Could not save the log. Photograph this dialog.",
}
local function clean(v, limit)
    return tostring(v == nil and "unavailable" or v):gsub("[%z\1-\31\127]", " "):sub(1, limit or 2048)
end
local report_error
local function record(stage, detail)
    if not owner() then error("Not the owning KOReader process", 0) end
    local file, why = io.open(report_path, "a")
    if not file then report_error=clean(why); error("Cannot open diagnostic log: " .. report_error, 0) end
    local wrote, problem = pcall(function()
        assert(file:seek("end") <= 262144, "Diagnostic log is full; move it aside before retrying")
        assert(file:write(clean(stage, 160) .. " | " .. clean(detail) .. "\n"))
    end)
    local closed, closed_result = pcall(file.close, file)
    if not wrote or not closed or not closed_result then
        report_error=clean(problem or "Could not close diagnostic log")
        error(report_error, 0)
    end
end
local function notify(message)
    if not owner() then return end
    local InfoMessage = require("ui/widget/infomessage")
    UIManager:show(InfoMessage:new{ text=text.title .. "\n\n" .. message,
        show_icon=false, dismissable=true, honor_silent_mode=false, sui_native=true })
end
local active_files = {
    "2-bigme-frontlight.lua", "2-bigme-frontlight-access-diagnostic.lua",
    "2-bigme-frontlight-manual-test.lua", "2-bigme-frontlight-warm-test.lua",
}
local used, prompt, closed = false, nil, false
local function run_test()
    local summaries = {}
    local ran_ok, failure = pcall(function()
        record("SESSION", "r1 UTC=" .. os.date("!%Y-%m-%dT%H:%M:%SZ") .. " READ_ONLY=true HARDWARE_IO=false SETTINGS_WRITES=false")
        for _, key in ipairs({"manufacturer", "brand", "model", "product", "hardware"}) do record("DEVICE " .. key, prop[key]) end
        assert(tonumber(ffi.C.getuid()) >= 10000, "Requires ordinary Android app UID")
        for _, filename in ipairs(active_files) do
            local file = io.open(data_dir .. "/patches/" .. filename, "rb")
            if file then file:close(); error("Disable active patch first: " .. filename, 0) end
        end
        local file = assert(io.open("/proc/self/attr/current", "r"), "Cannot check app context")
        local got, context = pcall(file.read, file, 256)
        file:close()
        assert(got and type(context)=="string" and context:match("^u:r:untrusted_app[^:]*:"), "Unsupported app context")
        assert(type(android.jni)=="table" and type(android.jni.context)=="function", "Missing JNI context API")
        local activity = assert(android.app and android.app.activity, "Missing Android activity")
        assert(activity.vm and activity.clazz, "Missing Android activity handles")

        for _, style in ipairs({"VARARGS", "ARRAY"}) do
            local current_stage = "context"
            record(style .. " BEGIN", current_stage)
            local attached, result = pcall(android.jni.context, android.jni, activity.vm, function(jni)
                local env = jni.env
                local api, refs = env[0], {}
                local function nonnull(v) return v ~= nil and v ~= ffi.NULL end
                local function keep(v) if nonnull(v) then refs[#refs+1]=v end; return v end
                local function clear_secondary()
                    if api.ExceptionCheck(env) ~= 0 then api.ExceptionClear(env); return false end
                    return true
                end
                -- Capture the original Throwable BEFORE clearing. All other
                -- JNI calls wait until after ExceptionClear. Formatting failures
                -- never replace the original failing operation in the report.
                local function exception_text()
                    local throwable = keep(api.ExceptionOccurred(env))
                    api.ExceptionClear(env)
                    if not nonnull(throwable) then return "Java exception (object unavailable)" end
                    local chars, string_ref
                    local formatted, value = pcall(function()
                        local cls=keep(api.GetObjectClass(env,throwable))
                        assert(clear_secondary() and nonnull(cls), "Throwable class unavailable")
                        local method=api.GetMethodID(env,cls,"toString","()Ljava/lang/String;")
                        assert(clear_secondary() and nonnull(method), "Throwable.toString unavailable")
                        string_ref=keep(api.CallObjectMethodA(env,throwable,method,nil))
                        assert(clear_secondary() and nonnull(string_ref), "Throwable string unavailable")
                        local length=tonumber(api.GetStringUTFLength(env,string_ref))
                        assert(clear_secondary() and length and length>=0, "Throwable UTF length unavailable")
                        chars=api.GetStringUTFChars(env,string_ref,nil)
                        assert(clear_secondary() and nonnull(chars), "Throwable UTF characters unavailable")
                        return clean(ffi.string(chars,math.min(length,2048)))
                    end)
                    if nonnull(chars) then pcall(api.ReleaseStringUTFChars,env,string_ref,chars) end
                    clear_secondary()
                    return formatted and value or ("Java exception; could not format Throwable: " .. clean(value,256))
                end
                local function check(value, reference)
                    if reference then keep(value) end
                    if api.ExceptionCheck(env) ~= 0 then
                        record(style .. " JAVA_EXCEPTION",current_stage)
                        error(exception_text(),0)
                    end
                    assert(nonnull(value), "Null JNI result")
                    return value
                end
                local function step(name, callback, reference)
                    current_stage=name
                    record(style .. " BEGIN",name)
                    local value=check(callback(),reference)
                    record(style .. " OK",name)
                    return value
                end
                local success, issue = pcall(function()
                    if api.ExceptionCheck(env) ~= 0 then
                        current_stage="pre-existing Java exception"
                        record(style .. " JAVA_EXCEPTION",current_stage)
                        error(exception_text(),0)
                    end
                    local system=step("FindClass(Settings.System)",function()
                        return api.FindClass(env,"android/provider/Settings$System")
                    end,true)
                    local permission=step("GetStaticMethodID(canWrite)",function()
                        return api.GetStaticMethodID(env,system,"canWrite","(Landroid/content/Context;)Z")
                    end)
                    local allowed=step("Settings.System.canWrite(Context)",function()
                        if style=="VARARGS" then return api.CallStaticBooleanMethod(env,system,permission,activity.clazz) end
                        local args=ffi.new("jvalue[1]"); args[0].l=activity.clazz
                        return api.CallStaticBooleanMethodA(env,system,permission,args)
                    end)
                    record(style .. " VALUE","canWrite=" .. tostring(tonumber(allowed)))
                    assert(tonumber(allowed)==1,"WRITE_SETTINGS denied; no permission requested or changed")
                    local cls=step("GetObjectClass(Activity)",function() return api.GetObjectClass(env,activity.clazz) end,true)
                    local getter=step("GetMethodID(getContentResolver)",function()
                        return api.GetMethodID(env,cls,"getContentResolver","()Landroid/content/ContentResolver;")
                    end)
                    local resolver=step("Activity.getContentResolver()",function()
                        if style=="VARARGS" then return api.CallObjectMethod(env,activity.clazz,getter) end
                        return api.CallObjectMethodA(env,activity.clazz,getter,nil)
                    end,true)
                    local get_int=step("GetStaticMethodID(getInt)",function()
                        return api.GetStaticMethodID(env,system,"getInt","(Landroid/content/ContentResolver;Ljava/lang/String;I)I")
                    end)
                    for _, key in ipairs({"ColdValue","WarmValue","screen_brightness_cold","screen_brightness_warm","LightMode"}) do
                        local name=step("NewStringUTF(" .. key .. ")",function() return api.NewStringUTF(env,key) end,true)
                        local value=step("Settings.System.getInt(" .. key .. ")",function()
                            if style=="VARARGS" then return api.CallStaticIntMethod(env,system,get_int,resolver,name,ffi.new("int32_t",-1)) end
                            local args=ffi.new("jvalue[3]"); args[0].l=resolver; args[1].l=name; args[2].i=-1
                            return api.CallStaticIntMethodA(env,system,get_int,args)
                        end)
                        record(style .. " VALUE",key .. "=" .. tostring(tonumber(value)))
                    end
                end)
                if api.ExceptionCheck(env) ~= 0 then api.ExceptionClear(env) end
                for i=#refs,1,-1 do pcall(api.DeleteLocalRef,env,refs[i]) end
                if api.ExceptionCheck(env) ~= 0 then api.ExceptionClear(env) end
                return {ok=success,stage=current_stage,error=not success and clean(issue) or nil}
            end)
            if not attached then result={ok=false,stage=current_stage,error=clean(result)} end
            assert(type(result)=="table", "JNI context did not return diagnostic result")
            record(style .. (result.ok and " COMPLETE" or " ERROR"),result.stage .. (result.error and " | " .. result.error or ""))
            summaries[#summaries+1]=style .. ": " .. (result.ok and "OK" or (result.stage .. "\n" .. clean(result.error,280)))
            if report_error then error(report_error,0) end
        end
        record("END","No hardware I/O, settings writes, permission requests or PowerD changes")
    end)
    if not ran_ok then
        pcall(record,"STOPPED",failure)
        summaries[#summaries+1]=text.blocked .. "\n" .. clean(failure,350)
    end
    notify(table.concat(summaries,"\n\n") .. "\n\n" .. text.safe .. "\n\n"
        .. (report_error and (text.saved_error .. "\n" .. clean(report_error,250)) or (text.report .. "\n" .. report_path)))
end

UIManager:scheduleIn(0,function()
    if not owner() then return end
    local ButtonDialog=require("ui/widget/buttondialog")
    local function close()
        if closed then return end
        closed=true; UIManager:close(prompt)
    end
    -- Native ButtonDialog displays its explanatory text through `title`, not `text`.
    prompt=ButtonDialog:new{title=text.title .. "\n\n" .. text.intro,title_align="left",sui_native=true,
        buttons={
          {
            {text=text.run,callback=function()
                if used or closed or not owner() then return end
                if type(UIManager.getTopmostVisibleWidget)=="function" and UIManager:getTopmostVisibleWidget()~=prompt then return end
                used=true; close()
                UIManager:scheduleIn(0,function() if owner() then run_test() end end)
            end},
          },{
            {text=text.close,callback=close},
          },
        },}
    local original_close=prompt.onCloseWidget
    prompt.onCloseWidget=function(self,...)
        closed=true
        if original_close then return original_close(self,...) end
    end
    UIManager:show(prompt)
end)
