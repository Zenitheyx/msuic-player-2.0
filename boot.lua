-- NEXUS OS bootloader
local fs = fs
term.clear(); term.setCursorPos(1,1)
print("NEXUS OS Bootloader")
print("-------------------")
local required = {"kernel/kernel.lua", "system/init.lua"}
for _, p in ipairs(required) do
  if not fs.exists(p) then error("Missing system component: " .. p, 0) end
end
print("[OK] filesystem")
print("[OK] kernel image")
print("[OK] init system")
print("Starting kernel...")
local ok, err = pcall(function() shell.run("kernel/kernel.lua") end)
if not ok then
  term.setTextColor(colors.red)
  print("KERNEL PANIC: " .. tostring(err))
  term.setTextColor(colors.white)
  print("Entering recovery shell.")
  shell.run("recovery/recovery.lua")
end
