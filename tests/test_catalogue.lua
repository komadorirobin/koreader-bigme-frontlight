-- Publisher check against local Ereader and Patch Manager checkouts.
local catalogue=assert(arg[1],"pass Ereader directory")
local manager=assert(arg[2],"pass ereader-patch-manager.koplugin directory")
local function read(path)
    local f=assert(io.open(path,"rb")); local s=f:read("*a"); f:close(); return s
end
local filename="2-bigme-frontlight.lua"
local source=read(filename)
assert(source==read(catalogue .. "/" .. filename),"catalogue and canonical source differ")
local Core=assert(loadfile(manager .. "/patchsync_core.lua"))()
local entry={type="blob",path=filename,sha="0123456789abcdef",size=#source}
local parsed=assert(Core.parseTree("{}",function() return {tree={entry}} end))
assert(#parsed.patches==1 and parsed.patches[1].path==filename,"Patch Manager did not discover root Lua patch")
assert(Core.validatePatch(parsed.patches[1],source),"Patch Manager rejected source/size/Lua syntax")
print("PASS identical catalogue bytes, actual Patch Manager discovery and source validation")
