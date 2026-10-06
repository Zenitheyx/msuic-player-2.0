-- NEXUS Desktop 0.2.0
-- Event-driven graphical shell for a 3x2 Advanced Monitor wall.
-- Uses monitor_touch coordinates, keyboard input, and a single compositor loop.

local monitor = peripheral.find("monitor")
local out = monitor or term.current()
local native = term.current()
local isMonitor = monitor ~= nil

local C = colors
local W,H = out.getSize()
local backend = (NEXUS_CONFIG and NEXUS_CONFIG.backend) or ""
local state = {
  page = "home", launcher = false, browserUrl = "", browserTitle = "NEXUS Browser",
  browserText = "", browserLinks = {}, browserStatus = backend ~= "" and "Backend configured" or "Backend not configured", browserLinkActions = {},
  terminal = "", terminalInput = "", notification = nil, notificationUntil = 0,
  clock = "", cpu = 0, selected = nil, files = {}, scroll = 0
}

local function refreshSize()
  W,H = out.getSize()
  if isMonitor then pcall(out.setTextScale, 0.5) end
end
refreshSize()

local function setBG(c) out.setBackgroundColor(c) end
local function setFG(c) out.setTextColor(c) end
local function clear() setBG(C.black); out.clear(); out.setCursorPos(1,1) end
local function clip(s,n) s=tostring(s or ""); if #s>n then return s:sub(1,n-1).."…" end return s end
local function fill(x,y,w,h,ch,bg,fg)
  if x<1 then w=w-(1-x); x=1 end; if y<1 then h=h-(1-y); y=1 end
  if w<=0 or h<=0 then return end
  setBG(bg or C.black); setFG(fg or C.white)
  for yy=y,y+h-1 do out.setCursorPos(x,yy); out.write(string.rep(ch or " ",w)) end
end
local function text(x,y,s,fg,bg)
  if y<1 or y>H or x>W then return end
  s=clip(s,math.max(0,W-x+1)); if #s<=0 then return end
  if bg then setBG(bg) end; if fg then setFG(fg) end; out.setCursorPos(x,y); out.write(s)
end
local function center(y,s,fg,bg)
  s=clip(s,W); text(math.max(1,math.floor((W-#s)/2)+1),y,s,fg,bg)
end
local function button(x,y,w,label,action,active)
  local bg=active and C.blue or C.gray; local fg=active and C.white or C.lightGray
  fill(x,y,w,1," ",bg,fg); local s="[ "..label.." ]"; s=clip(s,w)
  text(x+math.max(0,math.floor((w-#s)/2)),y,s,fg,bg)
  return {x=x,y=y,w=w,h=1,action=action}
end

local buttons={}
local function addButton(x,y,w,label,action,active) buttons[#buttons+1]=button(x,y,w,label,action,active) end
local function hit(x,y)
  for i=#buttons,1,-1 do local b=buttons[i]; if x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h then return b.action end end
end

local function notify(msg)
  state.notification=tostring(msg); state.notificationUntil=os.clock()+4
end

local function header(title, subtitle)
  setBG(C.black); setFG(C.white); fill(1,1,W,2," ",C.black,C.white)
  text(2,1,"NEXUS",C.cyan,C.black); text(9,1,title,C.white,C.black)
  text(2,2,clip(subtitle or "",W-4),C.lightGray,C.black)
end

local function drawTaskbar()
  fill(1,H-1,W,2," ",C.black,C.white)
  text(2,H,"◆",C.cyan,C.black)
  text(5,H,"NEXUS",C.white,C.black)
  local items={{"Home","home"},{"Browser","browser"},{"Terminal","terminal"},{"Files","files"},{"System","system"}}
  local x=14
  for _,it in ipairs(items) do
    local ww=#it[1]+4; addButton(x,H,ww,it[1],it[2],state.page==it[2]); x=x+ww+1
  end
  local clk=os.date("%H:%M:%S")
  text(math.max(1,W-10),H,clk,C.lightGray,C.black)
end

local function drawHome()
  header("Desktop","NEXUS 0.2.0  •  kernel session active")
  local left=3; local top=5; local cardW=math.max(18,math.floor((W-9)/3)); local cardH=6
  local apps={{"WEB","Browser","browser",C.blue},{">_","Terminal","terminal",C.green},{"▦","Files","files",C.orange},{"◎","Processes","processes",C.purple},{"⚙","Devices","devices",C.red},{"i","System","system",C.cyan}}
  for i,a in ipairs(apps) do
    local col=(i-1)%3; local row=math.floor((i-1)/3)
    local x=left+col*(cardW+2); local y=top+row*(cardH+2)
    fill(x,y,cardW,cardH," ",C.gray,C.white)
    text(x+2,y+1,a[1],a[4],C.gray); text(x+2,y+3,a[2],C.white,C.gray)
    text(x+2,y+4,"Open",C.lightGray,C.gray)
    buttons[#buttons+1]={x=x,y=y,w=cardW,h=cardH,action=a[3]}
  end
  local statusY=H-5
  fill(3,statusY,W-5,3," ",C.gray,C.white)
  text(5,statusY+1,"SYSTEM",C.cyan,C.gray)
  local procs=NEXUS and NEXUS.ps and NEXUS.ps() or {}
  text(15,statusY+1,"Processes: "..#procs,C.white,C.gray)
  text(32,statusY+1,"Devices: "..#peripheral.getNames(),C.white,C.gray)
  text(50,statusY+1,"Display: "..W.."×"..H,C.white,C.gray)
  text(5,statusY+2,"Network: "..(backend~="" and "BACKEND READY" or "NOT CONFIGURED"),backend~="" and C.lime or C.red,C.gray)
  text(35,statusY+2,"Touch: ENABLED",C.lime,C.gray)
end

local function drawBrowser()
  header("Browser","Backend-powered web reader")
  fill(2,4,W-4,2," ",C.gray,C.white)
  text(4,5,clip(state.browserUrl~="" and state.browserUrl or "Enter URL or search query with keyboard",W-8),C.white,C.gray)
  addButton(W-15,4,13,"GO","browser-go")
  local y=7
  text(3,y,"Status: "..clip(state.browserStatus,W-12),state.browserStatus:find("error") and C.red or C.lime,C.black); y=y+2
  if state.browserText~="" then
    text(3,y,state.browserTitle,C.cyan,C.black); y=y+2
    for line in state.browserText:gmatch("[^\n]+") do
      if y>=H-3 then break end
      text(3,y,clip(line,W-6),C.lightGray,C.black); y=y+1
    end
    if #state.browserLinks>0 and y<H-3 then
      y=y+1; text(3,y,"LINKS — touch a result to open",C.cyan,C.black); y=y+1
      state.browserLinkActions={}
      for i,l in ipairs(state.browserLinks) do
        if y>=H-2 then break end
        local label=string.format("%d. %s",i,clip(l.title or l.url or "link",W-8))
        fill(3,y,W-6,1," ",C.gray,C.white); text(4,y,label,C.blue,C.gray)
        local yy=y; state.browserLinkActions[#state.browserLinkActions+1]={y=yy,link=l.url}
        buttons[#buttons+1]={x=3,y=yy,w=W-6,h=1,action="browser-link:"..tostring(#state.browserLinkActions)}
        y=y+1
      end
    end
  else
    center(math.floor(H/2)-1,"Type a URL (https://...) or a search term",C.white,C.black)
    center(math.floor(H/2)+1,"Keyboard input is active",C.lightGray,C.black)
  end
end

local function encode(s)
  return tostring(s):gsub("[^%w%-%._~]",function(c)return string.format("%%%02X",string.byte(c))end)
end
local function browserGet(path)
  if backend=="" then return nil,"Backend is not configured" end
  local h,err=http.get(backend..path,{["Accept"]="application/json"})
  if not h then return nil,err or "HTTP request failed" end
  local body=h.readAll(); h.close()
  local ok,data=pcall(textutils.unserializeJSON,body)
  if not ok or type(data)~="table" then return nil,"Invalid backend response" end
  return data
end
local function browserGo()
  local q=state.browserUrl
  if q=="" then state.browserStatus="error: empty query"; return end
  state.browserStatus="Loading..."; state.browserText=""; state.browserLinks={}; state.browserTitle="NEXUS Browser"
  local ok,data=pcall(function()
    if q:match("^https?://") then return browserGet("/fetch?url="..encode(q)) else return browserGet("/search?q="..encode(q)) end
  end)
  if not ok then state.browserStatus="error: "..tostring(data); return end
  if not data then state.browserStatus="error: backend unavailable"; return end
  if data.type=="search" then
    state.browserTitle="Search results"
    local lines={}
    for i,r in ipairs(data.results or {}) do lines[#lines+1]=string.format("%d. %s",i,r.title or r.url or "result"); lines[#lines+1]="   "..(r.url or "") end
    state.browserText=table.concat(lines,"\n"); state.browserLinks=data.results or {}; state.browserStatus="Search complete"
  else
    state.browserTitle=data.title or q; state.browserText=data.text or "(no readable text returned)"; state.browserLinks=data.links or {}; state.browserStatus="Page loaded"
  end
end

local function drawTerminal()
  header("Terminal","NEXUS shell")
  fill(2,4,W-4,H-7," ",C.black,C.lightGray)
  local lines={}
  for line in state.terminal:gmatch("[^\n]*") do lines[#lines+1]=line end
  local start=math.max(1,#lines-(H-10))
  local y=5
  for i=start,#lines do text(3,y,clip(lines[i],W-6),C.lightGray,C.black); y=y+1 end
  fill(3,H-4,W-6,1," ",C.gray,C.white); text(4,H-4,"nexus$ "..state.terminalInput.."_",C.white,C.gray)
  text(3,H-2,"Type commands: help, ps, devices, sysinfo, clear, reboot, shutdown",C.lightGray,C.black)
end
local function terminalRun(line)
  if line=="" then return end
  state.terminal=state.terminal.."\nnexus$ "..line
  if line=="help" then state.terminal=state.terminal.."\nhelp  ps  devices  sysinfo  clear  reboot  shutdown"
  elseif line=="ps" then for _,p in ipairs(NEXUS.ps()) do state.terminal=state.terminal..string.format("\n%d %-10s %s",p.pid,p.state,p.name) end
  elseif line=="devices" then for n,d in pairs(NEXUS.devices) do state.terminal=state.terminal.."\n"..n.." ["..d.kind.."] "..(d.online and "ONLINE" or "OFFLINE") end
  elseif line=="sysinfo" then state.terminal=state.terminal.."\nNEXUS 0.2.0 | ID "..os.getComputerID().." | Display "..W.."x"..H
  elseif line=="clear" then state.terminal=""
  elseif line=="reboot" then os.reboot()
  elseif line=="shutdown" then os.shutdown()
  else state.terminal=state.terminal.."\nUnknown command: "..line end
end

local function drawFiles()
  header("Files","Persistent NEXUS storage")
  local ok,items=pcall(fs.list, "/")
  if not ok then items={} end
  local y=5
  for _,name in ipairs(items) do
    if name~="rom" and y<H-3 then
      local kind=fs.isDir(name) and "DIR " or "FILE"
      text(4,y,kind,C.cyan,C.black); text(10,y,clip(name,W-14),C.white,C.black); y=y+1
    end
  end
  text(3,H-3,"rom/ is protected and is not modified by NEXUS.",C.lightGray,C.black)
end

local function drawList(title, rows)
  header(title,"Live kernel/device information")
  local y=5
  for _,r in ipairs(rows) do if y<H-3 then text(3,y,clip(r,W-6),C.lightGray,C.black); y=y+1 end end
end

local function draw()
  refreshSize(); buttons={}; clear()
  if state.page=="home" then drawHome()
  elseif state.page=="browser" then drawBrowser()
  elseif state.page=="terminal" then drawTerminal()
  elseif state.page=="files" then drawFiles()
  elseif state.page=="processes" then
    local rows={"PID     STATE       NAME"}; for _,p in ipairs(NEXUS.ps()) do rows[#rows+1]=string.format("%-7d %-11s %s",p.pid,p.state,p.name) end; drawList("Processes",rows)
  elseif state.page=="devices" then
    local rows={"DEVICE                         TYPE"}; for n,d in pairs(NEXUS.devices) do rows[#rows+1]=string.format("%-30s %s",n,d.kind) end; drawList("Devices",rows)
  elseif state.page=="system" then
    local rows={"NEXUS 0.2.0","Kernel: "..NEXUS.version,"Computer ID: "..os.getComputerID(),"Uptime: "..string.format("%.1fs",os.clock()-NEXUS.bootTime),"Display: "..W.." × "..H,"Peripherals: "..#peripheral.getNames(),"Backend: "..(backend~="" and backend or "not configured")}; drawList("System",rows)
  end
  drawTaskbar()
  if state.notification and os.clock()<state.notificationUntil then
    local nw=math.min(W-6,math.max(24,#state.notification+4)); fill(W-nw-2,3,nw,2," ",C.blue,C.white); text(W-nw,4,clip(state.notification,nw-2),C.white,C.blue)
  end
end

local function action(a)
  if not a then return end
  if a=="home" or a=="browser" or a=="terminal" or a=="files" or a=="processes" or a=="devices" or a=="system" then state.page=a; draw(); return end
  if a=="browser-go" then browserGo(); draw(); return end
  if a:match("^browser%-link:") then
    local idx=tonumber(a:match("^browser%-link:(%d+)$")); local l=state.browserLinkActions[idx]
    if l and l.link then state.browserUrl=l.link; browserGo(); draw(); return end
  end
end

state.terminal="NEXUS Terminal ready.\nType 'help' for commands."
notify("NEXUS desktop online")
draw()

while true do
  local e={os.pullEventRaw()}
  if e[1]=="monitor_resize" then draw()
  elseif e[1]=="monitor_touch" then
    local _,side,x,y=e
    local a=hit(x,y)
    if a then action(a) else
      if state.page=="browser" and y>=4 and y<=5 then notify("Type your URL/search on the computer keyboard") end
    end
  elseif e[1]=="char" then
    if state.page=="browser" then state.browserUrl=state.browserUrl..e[2]; draw()
    elseif state.page=="terminal" then state.terminalInput=state.terminalInput..e[2]; draw() end
  elseif e[1]=="key" then
    local k=e[2]
    if state.page=="browser" then
      if k==keys.backspace then state.browserUrl=state.browserUrl:sub(1,-2); draw()
      elseif k==keys.enter then browserGo(); draw()
      elseif k==keys.escape then state.page="home"; draw() end
    elseif state.page=="terminal" then
      if k==keys.backspace then state.terminalInput=state.terminalInput:sub(1,-2); draw()
      elseif k==keys.enter then local l=state.terminalInput; state.terminalInput=""; terminalRun(l); draw()
      elseif k==keys.escape then state.page="home"; draw() end
    else
      local n=keys.getName(k)
      if n=="escape" then state.page="home"; draw()
      elseif n=="b" then state.page="browser"; draw()
      elseif n=="t" then state.page="terminal"; draw()
      elseif n=="f" then state.page="files"; draw()
      elseif n=="p" then state.page="processes"; draw()
      elseif n=="d" then state.page="devices"; draw()
      elseif n=="s" then state.page="system"; draw()
      end
    end
  elseif e[1]=="terminate" then return end
end
