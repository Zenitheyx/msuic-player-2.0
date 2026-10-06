-- NEXUS 0.4.0 installer. Run from CraftOS root.
local BASE="https://raw.githubusercontent.com/Zenitheyx/msuic-player-2.0/main/"
local files={
 {"boot/boot.lua","boot/boot.lua"},{"kernel/kernel.lua","kernel/kernel.lua"},{"system/init.lua","system/init.lua"},{"etc/network.cfg","etc/network.cfg"},{"recovery/recovery.lua","recovery/recovery.lua"},{"apps/desktop.lua","apps/desktop.lua"},{"apps/browser.lua","apps/browser.lua"},{"apps/files.lua","apps/files.lua"},{"apps/terminal.lua","apps/terminal.lua"},{"apps/ps.lua","apps/ps.lua"},{"apps/devices.lua","apps/devices.lua"},{"apps/sysinfo.lua","apps/sysinfo.lua"}}
local dirs={"boot","kernel","system","etc","recovery","apps","dev","var","home","lib","drivers","bin"}
local function die(s) error("NEXUS installer: "..s,0) end
local function fetch(u) local h,e=http.get(u); if not h then die(e or ("download failed: "..u)) end; local s=h.readAll(); h.close(); if not s or #s==0 then die("empty: "..u) end; return s end
local function valid(p,s) local f,e=load(s,"@"..p,"t",_ENV); if not f then die("Lua syntax error in "..p..": "..e) end end
term.clear(); term.setCursorPos(1,1); print("NEXUS OS 0.4.0 INSTALLER"); print(string.rep("=",32)); if not http then die("HTTP API unavailable") end
for _,d in ipairs(dirs) do if not fs.exists(d) then fs.makeDir(d) elseif not fs.isDir(d) then die(d.." is not a directory") end end
local staged={}
for _,p in ipairs(files) do write("Checking "..p[1].." ... "); local s=fetch(BASE..p[1]); valid(p[2],s); staged[#staged+1]={p[2],s}; print("OK") end
local startup='dofile("boot/boot.lua")\n'; valid("startup.lua",startup)
for _,x in ipairs(staged) do local f=fs.open(x[1],"w"); if not f then die("cannot write "..x[1]) end; f.write(x[2]); f.close() end
local f=fs.open("startup.lua","w"); if not f then die("cannot write startup.lua") end; f.write(startup); f.close()
-- Remove only legacy flat NEXUS files, never ROM.
for _,n in ipairs({"boot.lua","kernel.lua","init.lua","network.cfg","recovery.lua","desktop.lua","browser.lua","files.lua","terminal.lua","ps.lua","devices.lua","sysinfo.lua"}) do if fs.exists(n) and not fs.isDir(n) then fs.delete(n) end end
print(); print("INSTALL COMPLETE"); print("NEXUS 0.4.0 is ready."); print("rom/ was not modified."); print("Reboot to start NEXUS.")
