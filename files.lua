local out=peripheral.find("monitor") or term.current(); local function render(path)
 out.clear(); out.setCursorPos(1,1); out.setBackgroundColor(colors.gray); out.setTextColor(colors.white); out.write(" NEXUS FILE MANAGER  "); out.setCursorPos(2,3); out.write("PATH: /"..path)
 local items=fs.list(path=="" and "." or path); local y=5
 for i,n in ipairs(items) do if y>out.getSize() then break end; local p=(path=="" and n or fs.combine(path,n)); local tag=fs.isDir(p) and "[DIR] " or "      "; out.setCursorPos(2,y); out.write(tag..n:sub(1,math.max(1,out.getSize()-9))); y=y+1 end
 out.setCursorPos(2,out.getSize()); out.write("Q = exit")
end
render(""); while true do local e={os.pullEvent()}; if e[1]=="char" and e[2]=="q" then return end end
