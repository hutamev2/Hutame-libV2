-- GPO Autofarm Hub
-- Fish Autofarm ve Auto Knock Door'u tek Autofarm sekmesinde birleştirir.

local ENV = getgenv()
-- Sabit commit adresi GitHub raw önbelleğinin eski alt dosyaları döndürmesini engeller.
local BASE_URL = "https://raw.githubusercontent.com/hutamev2/Hutame-libV2/7386c6e9c435aa388adc8967a76926dff5d8c35f/"

-- Yeniden çalıştırıldığında eski otomasyonları ve pencereyi güvenli biçimde kapat.
ENV.GPOFishRunning = false
ENV.GPODoorRunning = false
if ENV.GPOAutofarmWindow then
    pcall(function() ENV.GPOAutofarmWindow:Destroy() end)
end

local Hutame = loadstring(game:HttpGet(BASE_URL .. "dist/Hutame.lua"))()
local Window = Hutame:CreateWindow({
    Title = "GPO Autofarm",
    Subtitle = "Fish & Spooksville",
    HubName = "Hutame",
    ToggleKey = Enum.KeyCode.End,
    ConfigFolder = "HutameUI/GPOAutofarm",
})
local Autofarm = Window:CreateTab("Autofarm")

ENV.GPOAutofarmWindow = Window
ENV.GPOAutofarmSharedWindow = Window
ENV.GPOAutofarmSharedTab = Autofarm

-- Alt sistemler ortak pencere ve sekmeyi ENV üzerinden alır.
local function install(path, name)
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(BASE_URL .. path))()
    end)
    if not ok then
        Window:Notify({
            Title = name .. " yüklenemedi",
            Content = tostring(result),
            Duration = 8,
        })
    end
    return ok, result
end

local fishLoaded = install("examples/GPOFishHub.lua", "Fish Autofarm")
local doorLoaded = install("examples/GPOAutoKnockDoor.lua", "Auto Knock Door")

-- Sonradan tekil script çalıştırılırsa yeni pencere açabilmesi için geçici paylaşımı temizle.
ENV.GPOAutofarmSharedWindow = nil
ENV.GPOAutofarmSharedTab = nil

Window:CreateConfigTab()
Window:Notify({
    Title = "GPO Autofarm",
    Content = "Fish Autofarm ve Auto Knock Door hazır.",
})

return {
    loaded = fishLoaded and doorLoaded,
    fish = fishLoaded,
    door = doorLoaded,
}
