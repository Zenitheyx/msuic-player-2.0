-- PID 1 style init/service manager
local function loadConfig()
  if fs.exists("etc/network.cfg") then
    local f=fs.open("etc/network.cfg","r"); local t=f.readAll(); f.close()
    local ok,cfg=pcall(textutils.unserialize,t); if ok and type(cfg)=="table" then return cfg end
  end
  return {backend=""}
end

local cfg=loadConfig()
_G.NEXUS_CONFIG=cfg

local function service(name, fn)
  local pid=NEXUS.spawn(name, fn)
  NEXUS.services[name]={pid=pid}
end

service("deviced", function() while true do os.pullEvent("peripheral"); os.queueEvent("nexus_device_refresh") end end)
service("logger", function() while true do os.pullEvent(); end end)
service("desktop", function() shell.run("apps/desktop.lua") end)

-- Keep init alive and restart the desktop if it exits.
while true do
  os.pullEvent("nexus_device_refresh")
  for _,p in pairs(NEXUS.ps()) do
    if p.name=="desktop" and (p.state=="exited" or p.state=="crashed") then
      service("desktop", function() shell.run("apps/desktop.lua") end)
    end
  end
end
