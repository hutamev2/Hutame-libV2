-- GPO Fish Autofarm
-- Hutame-libV2 tabanlı, yeniden çalıştırılabilir sade sürüm.

local ENV = getgenv()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local PLAYER = Players.LocalPlayer
local CONFIG = {
    BaitName = "Common Fish Bait",
    BaitPrice = 45,
    MaxBait = 300,
    BuyThreshold = 10,
    BuyTarget = 30,
    BiteTimeout = 45,
}

-- Yeni çalıştırma eski worker'ı geçersiz kılar ve eski pencereyi kapatır.
ENV.GPOFishGeneration = (ENV.GPOFishGeneration or 0) + 1
local generation = ENV.GPOFishGeneration
ENV.GPOFishRunning = false
if ENV.GPOFishWindow then pcall(function() ENV.GPOFishWindow:Destroy() end) end

local sharedWindow = ENV.GPOAutofarmSharedWindow
local sharedTab = ENV.GPOAutofarmSharedTab
local ownsWindow = sharedWindow == nil
local Window = sharedWindow
if ownsWindow then
    local Hutame = loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/hutamev2/Hutame-libV2/main/dist/Hutame.lua"
    ))()
    Window = Hutame:CreateWindow({
        Title = "GPO Fishing",
        Subtitle = "Fish Autofarm",
        HubName = "Hutame",
        ToggleKey = Enum.KeyCode.End,
        ConfigFolder = "HutameUI/GPOFishing",
    })
end
ENV.GPOFishWindow = Window

local Main = sharedTab or Window:CreateTab("Fishing")
local Farm = Main:CreateSection("Fish Autofarm")
local Bait = Main:CreateSection("Fish Ayarları")
local Status = Main:CreateSection("Fish Durumu")

local statusLabel = Status:CreateLabel({Name = "Durum", Text = "Hazır"})
local statsLabel = Status:CreateLabel({Name = "Sayaç", Text = "Başarılı: 0 | Başarısız: 0"})
local baitLabel = Status:CreateLabel({Name = "Common Bait", Text = "0"})

local state = {success = 0, failure = 0, error = nil}
local function active()
    return ENV.GPOFishRunning and ENV.GPOFishGeneration == generation
end

local function setStatus(text)
    statusLabel:SetValue(text)
    Window:SetStatus(text)
end

local stats = ReplicatedStorage:WaitForChild("Stats" .. PLAYER.Name)
local inventoryValue = stats:WaitForChild("Inventory"):WaitForChild("Inventory")
local peliValue = stats:WaitForChild("Stats"):WaitForChild("Peli")
local shopRemote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Shop")

local function baitCount()
    local ok, inventory = pcall(HttpService.JSONDecode, HttpService, inventoryValue.Value)
    return ok and type(inventory) == "table" and (tonumber(inventory[CONFIG.BaitName]) or 0) or 0
end

local function findRod()
    local character = PLAYER.Character
    if not character then return nil end
    for _, tool in ipairs(character:GetChildren()) do
        if tool:IsA("Tool") and tool:FindFirstChild("Client") and tool:FindFirstChild("BobbleSpawn", true) then
            return tool
        end
    end
end

local function fishingUI()
    return PLAYER.PlayerGui:FindFirstChild("FishingUIBill")
end

-- Oyun kendi minigame takip sistemini kurduğunda ilgili boolean upvalue'ı açar.
local function enableNativeAssist()
    for _, connection in ipairs(getconnections(RunService.RenderStepped)) do
        local fn = connection.Function
        if type(fn) == "function" then
            local values = debug.getupvalues(fn)
            local controller
            for _, value in pairs(values) do
                if type(value) == "table" and rawget(value, "FishTime") ~= nil and rawget(value, "Tool") ~= nil then
                    controller = value
                    break
                end
            end
            if controller and typeof(values[14]) == "Instance" and values[14].Name == "Goal"
                and type(values[16]) == "boolean" then
                debug.setupvalue(fn, 16, true)
                return true
            end
        end
    end
    return false
end

local function buyBait(amount)
    local model = workspace:FindFirstChild("BuyableItems")
    model = model and model:FindFirstChild(CONFIG.BaitName)
    if not model then return false, "Bait mağaza modeli bulunamadı" end

    local wanted = math.min(amount, CONFIG.MaxBait - baitCount(), math.floor(peliValue.Value / CONFIG.BaitPrice))
    for _ = 1, math.max(0, wanted) do
        if not active() then return false, "Durduruldu" end
        local before = baitCount()
        local ok, accepted = pcall(shopRemote.InvokeServer, shopRemote, model, 1)
        if not ok or accepted ~= true then return false, "Bait alımı sunucu tarafından reddedildi" end
        local deadline = os.clock() + 2
        repeat task.wait(0.1) until baitCount() > before or os.clock() >= deadline
        if baitCount() <= before then return false, "Envanter güncellenmedi" end
    end
    return baitCount() > 0
end

local function ensureBait()
    local count = baitCount()
    baitLabel:SetValue(string.format("%d | Peli: %s", count, tostring(peliValue.Value)))
    if count > CONFIG.BuyThreshold then return true end
    setStatus("Bait alınıyor")
    return buyBait(CONFIG.BuyTarget - count)
end

local function cast(rod)
    rod:Activate()
    task.wait(1.5)
    rod:Deactivate()
end

local function updateStats()
    statsLabel:SetValue(string.format("Başarılı: %d | Başarısız: %d", state.success, state.failure))
    baitLabel:SetValue(string.format("%d | Peli: %s", baitCount(), tostring(peliValue.Value)))
end

local function farmLoop()
    while ENV.GPOFishGeneration == generation do
        if not active() then task.wait(0.2) continue end

        local ok, err = pcall(function()
            local rod = findRod()
            if not rod then setStatus("Oltayı kuşanmanı bekliyor") task.wait(0.5) return end
            if not ensureBait() then setStatus("Bait yok") task.wait(2) return end

            local ui = fishingUI()
            if not ui then
                setStatus("Olta atılıyor")
                cast(rod)
                local deadline = os.clock() + CONFIG.BiteTimeout
                repeat task.wait(0.05) ui = fishingUI() until not active() or ui or os.clock() >= deadline
                if not ui then setStatus("Vuruş gelmedi, yeniden deneniyor") return end
            end

            setStatus("Minigame oynanıyor")
            local assistDeadline = os.clock() + 2
            repeat
                if enableNativeAssist() then break end
                task.wait()
            until not active() or os.clock() >= assistDeadline

            local bestFill = 0
            while active() and ui and ui.Parent do
                local frame = ui:FindFirstChild("Frame")
                local time = frame and frame:FindFirstChild("Time")
                local fill = time and time:FindFirstChild("Fill")
                if fill then bestFill = math.max(bestFill, fill.Size.Y.Scale) end
                task.wait()
                ui = fishingUI()
            end
            if not active() then return end
            if bestFill >= 0.95 then state.success += 1 else state.failure += 1 end
            updateStats()
            task.wait(2)
        end)

        if not ok then
            state.error = tostring(err)
            setStatus("Hata: " .. state.error)
            task.wait(1)
        end
    end
end

Farm:CreateToggle({
    Name = "Auto Fish", Description = "Atış ve minigame akışını otomatik yönetir.",
    Default = false, Flag = "AutoFish",
    Callback = function(value)
        ENV.GPOFishRunning = value
        setStatus(value and "Auto Fish açık" or "Durduruldu")
    end,
})

Bait:CreateSlider({
    Name = "Alım eşiği", Min = 1, Max = 200, Increment = 1, Default = CONFIG.BuyThreshold,
    Flag = "BaitThreshold", Callback = function(value) CONFIG.BuyThreshold = value end,
})
Bait:CreateSlider({
    Name = "Hedef stok", Min = 5, Max = 300, Increment = 1, Default = CONFIG.BuyTarget,
    Flag = "BaitTarget", Callback = function(value) CONFIG.BuyTarget = math.max(value, CONFIG.BuyThreshold + 1) end,
})
Bait:CreateButton({
    Name = "Şimdi 10 bait al", Style = "Secondary",
    Callback = function()
        local wasRunning = ENV.GPOFishRunning
        ENV.GPOFishRunning = true
        local ok, err = buyBait(10)
        ENV.GPOFishRunning = wasRunning
        Window:Notify({Title = "Bait", Content = ok and "Alım tamamlandı." or tostring(err)})
        updateStats()
    end,
})

if ownsWindow then Window:CreateConfigTab() end
updateStats()
task.spawn(farmLoop)
if ownsWindow then
    Window:Notify({Title = "GPO Fishing", Content = "Hazır. Oltayı ve bait'i kuşan."})
end

return {loaded = true, generation = generation}
