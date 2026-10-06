term.clear(); term.setCursorPos(1,1); print("PROCESS MANAGER"); print("PID   STATE      NAME")
for _,p in ipairs(NEXUS.ps()) do print(string.format("%-5d %-10s %s",p.pid,p.state,p.name)) end
print("\nPress any key..."); os.pullEvent("key")
