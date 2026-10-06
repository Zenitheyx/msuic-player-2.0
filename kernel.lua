-- NEXUS kernel 0.4.0
-- Cooperative process/event kernel. It deliberately uses documented CC:Tweaked primitives.
local K={version="0.4.0", bootTime=os.clock(), processes={}, nextPid=1, devices={}, services={}}
_G.NEXUS=K
local function log(s)
  if fs.exists("var") then local f=fs.open("var/kernel.log","a"); if f then f.writeLine(os.date("!%Y-%m-%dT%H:%M:%SZ").." "..s); f.close() end end
end
function K.spawn(name,fn,...)
  local pid=K.nextPid; K.nextPid=pid+1
  local args={...}
  local co=coroutine.create(function() return fn(table.unpack(args)) end)
  K.processes[pid]={pid=pid,name=name,state="ready",co=co,started=os.clock(),filter=nil,exit=nil}
  log("spawn "..pid.." "..name); return pid
end
function K.kill(pid,reason)
  local p=K.processes[pid]; if p and p.state~="dead" then p.state="dead"; p.exit=reason or "killed"; log("kill "..pid) end
end
function K.ps()
  local a={}; for _,p in pairs(K.processes) do a[#a+1]={pid=p.pid,name=p.name,state=p.state,uptime=os.clock()-p.started,exit=p.exit} end
  table.sort(a,function(x,y)return x.pid<y.pid end); return a
end
function K.refreshDevices()
  K.devices={}
  for _,name in ipairs(peripheral.getNames()) do
    local types={peripheral.getType(name)}; local kind=types[1] or "unknown"
    local ok,h=pcall(peripheral.wrap,name)
    K.devices[name]={name=name,kind=kind,types=types,handle=ok and h or nil,online=ok and h~=nil}
  end
  K.devices.terminal={name="terminal",kind="terminal",handle=term.current(),online=true}
end
local function resume(p,...)
  if p.state=="dead" or p.state=="crashed" or p.state=="exited" then return end
  p.state="running"; local ok,y=coroutine.resume(p.co,...)
  if not ok then p.state="crashed"; p.exit=tostring(y); log("crash "..p.pid.." "..p.exit)
  elseif coroutine.status(p.co)=="dead" then p.state="exited"; p.exit=y; log("exit "..p.pid)
  else p.state="waiting"; p.filter=y end
end
function K.run()
  fs.makeDir("var")
  K.refreshDevices()
  K.spawn("init",function() dofile("system/init.lua") end)
  while true do
    local e={os.pullEventRaw()}
    if e[1]=="terminate" then for pid in pairs(K.processes) do K.kill(pid,"terminate") end; return end
    for _,p in pairs(K.processes) do
      if p.state=="waiting" and (p.filter==nil or p.filter==e[1]) then resume(p,table.unpack(e)) end
    end
    for _,p in pairs(K.processes) do if p.state=="ready" then resume(p) end end
  end
end
K.run()
