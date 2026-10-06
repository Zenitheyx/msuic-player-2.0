-- NEXUS Browser client. Uses an external backend for HTML extraction/search.
local cfg=NEXUS_CONFIG or {}
local backend=cfg.backend or ""
if backend=="" then print("Browser backend is not configured."); print("Edit etc/network.cfg and set backend=... ."); return end
local function get(path)
  local h,err=http.get(backend..path,{["Accept"]="application/json"})
  if not h then error(err or "HTTP request failed") end
  local body=h.readAll(); h.close(); local ok,data=pcall(textutils.unserializeJSON,body)
  if not ok then error("Invalid backend response") end
  return data
end
local function esc(s) return tostring(s):gsub("[^%w%-%._~]",function(c)return string.format("%%%02X",string.byte(c))end) end
term.clear(); term.setCursorPos(1,1)
print("NEXUS BROWSER")
print("Backend: "..backend)
while true do
  write("URL/search (blank=exit)> "); local q=read()
  if q=="" then break end
  local ok,data=pcall(function()
    if q:match("^https?://") then return get("/fetch?url="..esc(q)) else return get("/search?q="..esc(q)) end
  end)
  if not ok then print("Browser error: ",data)
  elseif data.type=="search" then
    print("SEARCH RESULTS")
    for i,r in ipairs(data.results or {}) do print(i..") "..r.title); print("   "..r.url) end
    write("Open result # (blank=back)> "); local n=read(); local r=data.results and data.results[tonumber(n)]
    if r then local d=get("/fetch?url="..esc(r.url)); term.clear(); print(d.title or r.title); print(string.rep("=",30)); print(d.text or ""); print("\nURL: "..r.url) end
  else
    term.clear(); print(data.title or "PAGE"); print(string.rep("=",30)); print(data.text or "")
    print("\nLinks:")
    for i,l in ipairs(data.links or {}) do print(i..") "..l.title.." -> "..l.url) end
  end
end
