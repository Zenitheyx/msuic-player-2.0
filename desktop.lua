-- NEXUS desktop: event-driven, low-flicker compositor-style shell.
local mon=peripheral.find("monitor")
local out=mon or term.current()
if mon then mon.setTextScale(0.5) end
local W,H=out.getSize(); local running=true; local app="home"; local dirty=true; local lastClock=""
local C={bg=colors.black,panel=colors.gray,card=colors.lightGray,fg=colors.white,muted=colors.lightGray,accent=colors.cyan,good=colors.lime,warn=colors.yellow,red=colors.red}
local function set(bg,fg) out.setBackgroundColor(bg); out.setTextColor(fg) end
local function fill(y,bg,ch) set(bg,bg); out.setCursorPos(1,y); out.write(string.rep(ch or " ",W)) end
local function text(x,y,s,fg,bg)
  s=tostring(s); if #s>W-x+1 then s=s:sub(1,W-x+1) end; set(bg or C.bg,fg or C.fg); out.setCursorPos(x,y); out.write(s)
end
local function box(x,y,w,h,bg) set(bg); for i=0,h-1 do out.setCursorPos(x,y+i); out.write(string.rep(" ",math.max(0,w))) end end
local function button(x,y,w,label,id,selected)
  box(x,y,w,3,selected and C.accent or C.card); text(x+1,y+1,label,selected and C.bg or C.bg,selected and C.accent or C.card); return {x=x,y=y,w=w,h=3,id=id}
end
local hit={}
local function header(title,sub)
  fill(1,C.panel); text(2,1,"NEXUS",C.accent,C.panel); text(10,1,title,C.fg,C.panel); text(2,2,sub or "",C.muted,C.panel)
end
local function taskbar()
  fill(H,C.panel); text(2,H,"NEXUS",C.accent,C.panel); text(11,H,"HOME",C.fg,C.panel); text(18,H,"BROWSER",C.fg,C.panel); text(29,H,"FILES",C.fg,C.panel); text(37,H,"TERMINAL",C.fg,C.panel)
  local clock=os.date("%H:%M:%S"); text(math.max(1,W-10),H,clock,C.fg,C.panel)
end
local function home()
  header("Desktop","Advanced Computer • "..#peripheral.getNames().." peripherals detected")
  hit={}
  local cols=3; local gap=2; local bw=math.floor((W-8)/cols); local y=5
  local cards={{"BROWSER","Internet gateway", "browser"},{"FILES","File manager","files"},{"TERMINAL","System shell","terminal"},{"PROCESSES","Kernel process table","ps"},{"DEVICES","Hardware manager","devices"},{"SYSTEM","System information","sysinfo"}}
  for i,c in ipairs(cards) do local col=(i-1)%cols; local row=math.floor((i-1)/cols); local x=2+col*(bw+gap); local yy=y+row*5; box(x,yy,bw,4,C.card); text(x+2,yy+1,c[1],C.bg,C.card); text(x+2,yy+2,c[2],C.bg,C.card); hit[#hit+1]={x=x,y=yy,w=bw,h=4,id=c[3]} end
  local p=NEXUS.ps(); local backend=(NEXUS_CONFIG and NEXUS_CONFIG.backend) or ""; local net=backend~="" and "BACKEND CONFIGURED" or "BACKEND NOT CONFIGURED"
  text(2,H-2,"Kernel "..NEXUS.version.."   Processes "..#p.."   "..net,C.muted,C.bg)
  taskbar()
end
local function simpleScreen(title,draw)
  header(title,"NEXUS application"); hit={}; draw(); taskbar()
end
local function launch(id)
  app=id; dirty=true
  if id=="home" then return end
  if id=="browser" then dofile("apps/browser.lua")
  elseif id=="files" then dofile("apps/files.lua")
  elseif id=="terminal" then dofile("apps/terminal.lua")
  elseif id=="ps" then dofile("apps/ps.lua")
  elseif id=="devices" then dofile("apps/devices.lua")
  elseif id=="sysinfo" then dofile("apps/sysinfo.lua") end
  app="home"; dirty=true
end
local function draw() if not dirty then return end; dirty=false; set(C.bg,C.fg); out.clear(); if app=="home" then home() end end
local function touch(x,y)
  if y==H then if x<9 then launch("home") elseif x<18 then launch("browser") elseif x<28 then launch("files") elseif x<39 then launch("terminal") end; return end
  for _,b in ipairs(hit) do if x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h then launch(b.id); return end end
end
local function monitorName() for _,n in ipairs(peripheral.getNames()) do if peripheral.getType(n)=="monitor" then return n end end end
while running do
  draw()
  local e={os.pullEvent()}
  if e[1]=="monitor_resize" then W,H=out.getSize(); dirty=true
  elseif e[1]=="monitor_touch" then local side,x,y=e[2],e[3],e[4]; if not monitorName() or side==monitorName() then touch(x,y) end
  elseif e[1]=="key" then local k=e[2]; if k==keys.getName and false then end; if k==keys.q then running=false elseif k==keys.home then app="home"; dirty=true end
  elseif e[1]=="char" and e[2]=="q" then running=false
  elseif e[1]=="timer" then dirty=true end
end
