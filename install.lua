-- NEXUS OS installer 0.1.1
-- Installs the flat GitHub repository layout into the real NEXUS filesystem.
-- Never deletes rom/ and only touches NEXUS-owned paths.
local BASE = "https://raw.githubusercontent.com/Zenitheyx/msuic-player-2.0/main/"
local files = {
  {"boot.lua", "boot/boot.lua"},
  {"kernel.lua", "kernel/kernel.lua"},
  {"init.lua", "system/init.lua"},
  {"network.cfg", "etc/network.cfg"},
  {"recovery.lua", "recovery/recovery.lua"},
  {"desktop.lua", "apps/desktop.lua"},
  {"browser.lua", "apps/browser.lua"},
  {"terminal.lua", "apps/terminal.lua"},
  {"ps.lua", "apps/ps.lua"},
  {"sysinfo.lua", "apps/sysinfo.lua"},
}

local startup = [[-- NEXUS OS startup
local ok, err = pcall(function() shell.run("boot/boot.lua") end)
if not ok then
  term.clear(); term.setCursorPos(1,1)
  term.setTextColor(colors.red)
  print("NEXUS BOOT FAILURE")
  print(tostring(err))
  term.setTextColor(colors.white)
  print("Recovery: reboot, then hold/press the termination key if needed.")
end
]]

local dirs = {"boot","kernel","system","etc","recovery","apps","dev","var","home","lib","drivers","bin"}
local function fail(msg)
  error("NEXUS installer: " .. msg, 0)
end
local function ensureDir(path)
  if not fs.exists(path) then fs.makeDir(path) end
  if not fs.isDir(path) then fail(path .. " is not a directory") end
end
local function fetch(url)
  local h, err = http.get(url, { ["User-Agent"] = "NEXUS-Installer/0.1.1" })
  if not h then fail("download failed: " .. url .. "\n" .. tostring(err)) end
  local body = h.readAll(); h.close()
  if not body or #body == 0 then fail("empty download: " .. url) end
  return body
end
local function validateLua(path, body)
  local fn, err = load(body, "@" .. path, "t", _ENV)
  if not fn then fail("Lua validation failed for " .. path .. ": " .. tostring(err)) end
end

term.clear(); term.setCursorPos(1,1)
print("NEXUS OS 0.1.1 INSTALLER")
print("=========================")
print("Checking HTTP and filesystem...")
if not http then fail("HTTP API is unavailable") end
for _,d in ipairs(dirs) do ensureDir(d) end
print("[OK] prerequisites")

local staged = {}
for _,pair in ipairs(files) do
  local src, dst = pair[1], pair[2]
  write("Downloading " .. src .. " ... ")
  local body = fetch(BASE .. src)
  validateLua(dst, body)
  staged[#staged+1] = {dst, body}
  print("OK")
end

-- Validate the startup program before making it bootable.
validateLua("startup.lua", startup)
print("[OK] Lua validation")

-- Commit only after every file validates.
for _,item in ipairs(staged) do
  local path, body = item[1], item[2]
  local f = fs.open(path, "w")
  if not f then fail("cannot write " .. path) end
  f.write(body); f.close()
end
local f = fs.open("startup.lua", "w")
if not f then fail("cannot write startup.lua") end
f.write(startup); f.close()

-- Remove only the old flat NEXUS files after a successful commit.
for _,pair in ipairs(files) do
  local src = pair[1]
  if fs.exists(src) and not fs.isDir(src) then fs.delete(src) end
end

print("[OK] NEXUS filesystem installed")
print("[OK] startup installed last")
print("")
print("NEXUS OS 0.1.1 is ready.")
print("Reboot to start NEXUS.")
