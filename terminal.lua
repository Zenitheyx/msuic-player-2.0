term.clear(); term.setCursorPos(1,1)
print("NEXUS Terminal")
print("Type 'help' for CraftOS-compatible basics or 'nps' for kernel processes.")
while true do
  write("nexus$ "); local line=read()
  if line=="exit" then break
  elseif line=="nps" then for _,p in ipairs(NEXUS.ps()) do print(p.pid,p.name,p.state) end
  elseif line=="nreboot" then os.reboot()
  elseif line=="nshutdown" then os.shutdown()
  elseif line~="" then shell.run(line) end
end
