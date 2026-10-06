-- NEXUS kernel: event-driven cooperative kernel for CC:Tweaked.
local K = {}
K.version = "0.1.0"
K.bootTime = os.clock()
K.processes = {}
K.nextPid = 1
K.services = {}
K.devices = {}
K.events = {}

local function now() return os.clock() end
local function log(msg)
  if fs.exists("var") then
    local f = fs.open("var/kernel.log", "a")
    if f then f.writeLine(string.format("[%0.3f] %s", now(), msg)); f.close() end
  end
end

function K.registerDevice(name, kind, handle)
  K.devices[name] = {name=name, kind=kind, handle=handle, online=true}
  log("device online: "..name.." ("..kind..")")
end

function K.spawn(name, fn, args)
  local pid = K.nextPid; K.nextPid = pid + 1
  local co = coroutine.create(function() return fn(table.unpack(args or {})) end)
  K.processes[pid] = {pid=pid,name=name,state="ready",co=co,started=now(),exit=nil}
  log("spawn pid="..pid.." name="..name)
  return pid
end

function K.kill(pid, reason)
  local p = K.processes[pid]
  if p then p.state="dead"; p.exit=reason or "killed"; log("kill pid="..pid.." reason="..tostring(reason)) end
end

function K.ps()
  local out={}
  for pid,p in pairs(K.processes) do
    out[#out+1]={pid=pid,name=p.name,state=p.state,uptime=now()-p.started}
  end
  table.sort(out,function(a,b)return a.pid<b.pid end)
  return out
end

local function matches(filter, eventName)
  return filter == nil or filter == eventName
end

-- Event-driven cooperative scheduler. Each process yields through os.pullEvent,
-- which returns the requested event filter to the kernel. The kernel then fans
-- matching events out to every waiting process instead of allowing one process
-- to consume the global event queue.
local function schedulerStep()
  local progressed = false
  for pid,p in pairs(K.processes) do
    if p.state ~= "dead" and p.state ~= "crashed" and p.state ~= "exited" then
      p.state="running"
      local ok, yielded = coroutine.resume(p.co)
      progressed = true
      if not ok then
        p.state="crashed"; p.exit=tostring(yielded); log("crash pid="..pid..": "..p.exit)
      elseif coroutine.status(p.co)=="dead" then
        p.state="exited"; p.exit=yielded
      else
        p.state="waiting"; p.filter=yielded
      end
    end
  end
  return progressed
end

local function dispatch(event)
  local name=event[1]
  for pid,p in pairs(K.processes) do
    if p.state=="waiting" and matches(p.filter,name) then
      p.state="ready"
      local ok, yielded=coroutine.resume(p.co, table.unpack(event))
      if not ok then
        p.state="crashed"; p.exit=tostring(yielded); log("crash pid="..pid..": "..p.exit)
      elseif coroutine.status(p.co)=="dead" then
        p.state="exited"; p.exit=yielded
      else
        p.state="waiting"; p.filter=yielded
      end
    end
  end
end

local function hardwareScan()
  for _, name in ipairs(peripheral.getNames()) do
    local kind = peripheral.getType(name)
    local ok, h = pcall(peripheral.wrap, name)
    if ok and h then K.registerDevice(name, kind or "unknown", h) end
  end
  if term then K.registerDevice("terminal", "terminal", term.current()) end
end

local function launchInit()
  K.spawn("init", function() shell.run("system/init.lua") end)
end

function K.run()
  term.clear(); term.setCursorPos(1,1)
  print("NEXUS kernel "..K.version)
  print("Initializing hardware...")
  hardwareScan()
  print("Devices: "..tostring(#peripheral.getNames()))
  launchInit()
  log("kernel online")
  schedulerStep()
  while true do
    local e = {os.pullEventRaw()}
    if e[1] == "terminate" then
      log("terminate requested")
      for pid in pairs(K.processes) do K.kill(pid, "system terminate") end
      break
    end
    dispatch(e)
    -- Give newly-woken processes a scheduling slice before waiting again.
    schedulerStep()
  end
end

_G.NEXUS = K
K.run()
