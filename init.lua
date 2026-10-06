-- NEXUS PID-1 style service manager
local function config()
  if not fs.exists("etc/network.cfg") then return {backend=""} end
  local f=fs.open("etc/network.cfg","r"); local s=f.readAll(); f.close()
  local ok,t=pcall(textutils.unserialize,s); return ok and type(t)=="table" and t or {backend=""}
end
NEXUS.config=config(); _G.NEXUS_CONFIG=NEXUS.config
local function service(name,fn)
  local pid=NEXUS.spawn(name,fn); NEXUS.services[name]={pid=pid}; return pid
end
service("device-manager",function()
  while true do
    os.pullEvent("peripheral"); NEXUS.refreshDevices(); os.queueEvent("nexus_devices_changed")
  end
end)
service("desktop",function() dofile("apps/desktop.lua") end)
while true do
  os.pullEvent("nexus_restart_desktop")
end
