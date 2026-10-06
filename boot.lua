-- NEXUS OS 0.4.0 bootloader
local function say(label, ok, detail)
  term.setTextColor(ok and colors.lime or colors.red)
  term.write(string.format("%-24s", label))
  term.write(ok and "OK" or "FAIL")
  if detail then term.setTextColor(colors.lightGray); term.write("  "..detail) end
  print()
end
term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(1,1)
print("NEXUS OS 0.4.0"); print("Advanced Computer Operating Environment"); print(string.rep("-", 44))
local required={"kernel/kernel.lua","system/init.lua","apps/desktop.lua","etc/network.cfg"}
for _,p in ipairs(required) do
  local ok=fs.exists(p) and not fs.isDir(p); say("Checking "..p,ok); if not ok then error("Missing: "..p,0) end
end
say("Filesystem",true)
say("Hardware discovery",true,tostring(#peripheral.getNames()).." peripherals")
say("Display", peripheral.find("monitor") ~= nil)
say("HTTP API", http ~= nil)
print(); print("Starting kernel...")
local ok,err=pcall(dofile,"kernel/kernel.lua")
if not ok then
  term.setBackgroundColor(colors.black); term.setTextColor(colors.red); term.clear(); term.setCursorPos(1,1)
  print("NEXUS KERNEL PANIC"); print(string.rep("=",30)); print(tostring(err)); print()
  term.setTextColor(colors.yellow); print("Recovery environment available.")
  if fs.exists("recovery/recovery.lua") then pcall(dofile,"recovery/recovery.lua") end
end
