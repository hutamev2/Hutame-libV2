-- No local files or GitHub token required. Returns the library for your hub.
local url = "https://raw.githubusercontent.com/hutamev2/Hutame-libV2/main/dist/Hutame.lua"
local ok, source = pcall(function() return game:HttpGet(url) end)
assert(ok and type(source) == "string", "Hutame download failed; check your network")
local chunk, compileError = loadstring(source, "@Hutame")
assert(chunk, compileError)
return chunk()
