term.clear(); term.setCursorPos(1,1); print("DEVICE MANAGER")
for n,d in pairs(NEXUS.devices) do print(string.format("%-24s %-16s %s",n,d.kind,d.online and "ONLINE" or "OFFLINE")) end
print("\nPress any key..."); os.pullEvent("key")
