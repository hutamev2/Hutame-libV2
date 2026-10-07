-- Personal private-repository loader. Never commit a token or share it in a hub.
-- Defaults to hutamev2/Hutame-libV2; HUTAME_REPOSITORY can override it.
-- Supply a read-only repo token via HUTAME_GITHUB_TOKEN or hutame/github-token.txt.
local environment = getgenv()
local repository = environment.HUTAME_REPOSITORY or "hutamev2/Hutame-libV2"
assert(type(repository) == "string" and repository:match("^[%w_.-]+/[%w_.-]+$"),
    "Set getgenv().HUTAME_REPOSITORY to OWNER/Hutame-libV2")

local token = environment.HUTAME_GITHUB_TOKEN
if not token and type(isfile) == "function" and isfile("hutame/github-token.txt") then
    token = readfile("hutame/github-token.txt"):match("^%s*(.-)%s*$")
end
assert(type(token) == "string" and token ~= "", "Private repository requires a read-only GitHub token supplied locally")
assert(type(request) == "function", "This loader requires Madium request()")

local ok, response = pcall(request, {
    Url = "https://api.github.com/repos/" .. repository .. "/contents/dist/Hutame.lua?ref=main",
    Method = "GET",
    Headers = {
        Authorization = "Bearer " .. token,
        Accept = "application/vnd.github.raw+json",
        ["X-GitHub-Api-Version"] = "2022-11-28",
        ["User-Agent"] = "Hutame-Loader",
    },
})
token = nil
-- Do not include response bodies or request headers in errors: these can contain credentials.
assert(ok and type(response) == "table", "GitHub request failed; check your network")
assert(response.StatusCode == 200,
    "GitHub HTTP " .. tostring(response.StatusCode) .. ": check repository, token access and main branch")
assert(type(response.Body) == "string", "GitHub returned an invalid library response")
local chunk, compileError = loadstring(response.Body, "@Hutame")
assert(chunk, compileError)
return chunk()
