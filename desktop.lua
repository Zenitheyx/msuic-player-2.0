-- NEXUS desktop shell: deliberately thin; the kernel remains independent.
local mon
for _,n in ipairs(peripheral.getNames()) do if peripheral.getType(n)=="monitor" then mon=peripheral.wrap(n); break end end
local out=mon or term.current()
local function draw()
  term.redirect(out)
  out.setBackgroundColor(colors.black); out.clear(); out.setCursorPos(1,1)
  out.setTextColor(colors.cyan)
  print("NEXUS OS")
  out.setTextColor(colors.lightGray)
  print("Kernel online  |  Processes: "..#NEXUS.ps())
  print("")
  out.setTextColor(colors.white)
  print("[1] Terminal     [2] Browser")
  print("[3] Processes    [4] Devices")
  print("[5] System Info  [Q] Shutdown")
  print("")
  print("Touch the monitor or use the keyboard.")
  term.redirect(term.native())
end

draw()
while true do
  local e={os.pullEvent()}
  if e[1]=="monitor_touch" or e[1]=="key" or e[1]=="char" then
    local key=nil
    if e[1]=="char" then key=e[2]
    elseif e[1]=="key" then key=keys.getName(e[2]) end
    if key=="1" then shell.run("apps/terminal.lua")
    elseif key=="2" then shell.run("apps/browser.lua")
    elseif key=="3" then shell.run("apps/ps.lua")
    elseif key=="4" then shell.run("apps/devices.lua")
    elseif key=="5" then shell.run("apps/sysinfo.lua")
    elseif key=="q" then os.shutdown() end
    draw()
  end
end
