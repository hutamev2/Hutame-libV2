-- GPO Spooksville Auto Knock Door
-- Hutame-libV2 tabanlı, okunabilir ve yeniden çalıştırılabilir sürüm.

local ENV = getgenv()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PLAYER = Players.LocalPlayer
local CONFIG = {
    TravelSpeed = 32,
    MaxStep = 0.5,
    HoverHeight = 4,
    DoorCooldown = 170,
    RetryDelay = 30,
    MaxDistance = 500,
}

ENV.GPODoorGeneration = (ENV.GPODoorGeneration or 0) + 1
local generation = ENV.GPODoorGeneration
ENV.GPODoorRunning = false
if ENV.GPODoorWindow then pcall(function() ENV.GPODoorWindow:Destroy() end) end

local sharedWindow = ENV.GPOAutofarmSharedWindow
local sharedTab = ENV.GPOAutofarmSharedTab
local ownsWindow = sharedWindow == nil
local Window = sharedWindow
if ownsWindow then
    local Hutame = loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/hutamev2/Hutame-libV2/main/dist/Hutame.lua"
    ))()
    Window = Hutame:CreateWindow({
        Title = "Spooksville",
        Subtitle = "Auto Knock Door",
        HubName = "Hutame",
        ToggleKey = Enum.KeyCode.End,
        ConfigFolder = "HutameUI/GPOAutoKnock",
    })
end
ENV.GPODoorWindow = Window

local Main = sharedTab or Window:CreateTab("Door Farm")
local Farm = Main:CreateSection("Auto Knock Door")
local Settings = Main:CreateSection("Door Ayarları")
local Status = Main:CreateSection("Door Durumu")
local statusLabel = Status:CreateLabel({Name = "Durum", Text = "Hazır"})
local targetLabel = Status:CreateLabel({Name = "Hedef", Text = "-"})
local countLabel = Status:CreateLabel({Name = "Başarılı kapı", Text = "0"})

local cooldowns = {}
local retryAfter = {}
local completed = 0

local function active()
    return ENV.GPODoorRunning and ENV.GPODoorGeneration == generation and not Window._destroyed
end

local function setStatus(text)
    statusLabel:SetValue(text)
    Window:SetStatus(text)
end

local function character()
    local model = PLAYER.Character
    return model, model and model:FindFirstChildOfClass("Humanoid"), model and model:FindFirstChild("HumanoidRootPart")
end

local function stopMovement()
    local _, humanoid, root = character()
    if root then
        root.Anchored = false
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    if humanoid then
        humanoid.AutoRotate = true
        if root then humanoid:MoveTo(root.Position) end
    end
end

local function findBag(container)
    local tool = container and container:FindFirstChild("Candy Corn Basket")
    return tool and tool:IsA("Tool") and tool or nil
end

local function equipBag()
    local model, humanoid = character()
    if not model or not humanoid then return false, "Karakter hazır değil" end
    if findBag(model) then return true end
    local backpack = PLAYER:FindFirstChild("Backpack")
    local tool = findBag(backpack) or findBag(backpack and backpack:FindFirstChild("Unequiped"))
    if not tool then return false, "Candy Corn Basket bulunamadı" end
    if tool.Parent ~= backpack then tool.Parent = backpack task.wait(0.1) end
    humanoid:EquipTool(tool)
    task.wait(0.2)
    return findBag(model) ~= nil, "Çanta kuşanılamadı"
end

-- Kapıları her döngüde yeniden tarar; stream edilen/yeni oluşan evler otomatik katılır.
local function scanDoors()
    local islands = workspace:FindFirstChild("Islands")
    local town = islands and islands:FindFirstChild("Spooksville")
    local buildings = town and town:FindFirstChild("Building")
    local result = {}
    if not buildings then return result end
    for _, house in ipairs(buildings:GetChildren()) do
        local door = house:FindFirstChild("eventDoor")
        local frame = door and door:FindFirstChild("Frame")
        local prompt = frame and frame:FindFirstChildOfClass("ProximityPrompt")
        if frame and frame:IsA("BasePart") and prompt and prompt.Enabled then
            table.insert(result, {house = house, frame = frame, prompt = prompt})
        end
    end
    return result
end

local function doorKey(door)
    local p = door.frame.Position
    return string.format("%d:%d:%d", math.floor(p.X + 0.5), math.floor(p.Y + 0.5), math.floor(p.Z + 0.5))
end

local function nearestDoor(root)
    local best, bestDistance
    for _, door in ipairs(scanDoors()) do
        local key = doorKey(door)
        local now = os.clock()
        if (retryAfter[key] or 0) <= now and (cooldowns[key] or 0) <= now then
            local distance = (root.Position - door.frame.Position).Magnitude
            if distance <= CONFIG.MaxDistance and (not bestDistance or distance < bestDistance) then
                best, bestDistance = door, distance
            end
        end
    end
    return best, bestDistance
end

local function canReachPrompt(root, door)
    return door.frame.Parent and door.prompt.Parent
        and (root.Position - door.frame.Position).Magnitude <= door.prompt.MaxActivationDistance
end

-- Her Heartbeat'te küçük bir CFrame adımı; gecikmede büyük sıçrama yapılmaz.
-- Hedef kapının biraz üstüdür; varınca karakter anchor ile havada tutulur.
local function stepToDoor(door)
    local model, humanoid, root = character()
    if not model or not humanoid or not root or humanoid.Health <= 0 then return false, "Karakter hazır değil" end
    local targetPosition = door.frame.Position + Vector3.new(0, CONFIG.HoverHeight, 0)
    local facing = CFrame.lookAt(targetPosition, door.frame.Position)
    root.Anchored = true
    humanoid.AutoRotate = false
    setStatus("Kapıya küçük adımlarla ilerliyor")
    local deadline = os.clock() + math.max(45,
        (targetPosition - root.Position).Magnitude / 4 + 15)

    while active() and root.Parent and door.frame.Parent do
        local dt = RunService.Heartbeat:Wait()
        if not active() or PLAYER.Character ~= model or not root.Parent
            or humanoid.Health <= 0 or not door.frame.Parent then break end
        if os.clock() >= deadline then
            stopMovement()
            return false, "Kapıya ulaşma süresi doldu"
        end
        targetPosition = door.frame.Position + Vector3.new(0, CONFIG.HoverHeight, 0)
        facing = CFrame.lookAt(targetPosition, door.frame.Position)
        local offset = targetPosition - root.Position
        local distance = offset.Magnitude
        if distance <= 0.001 then
            root.CFrame = facing
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            return true
        end

        -- Eski profiller yüksek değer taşısa da hareket sınırlarını burada uygula.
        -- Uzun karede geçen süreyi telafi etmek için daha büyük sıçrama yapılmaz.
        local speed = math.clamp(CONFIG.TravelSpeed, 8, 32)
        local stepSize = math.clamp(CONFIG.MaxStep, 0.25, 0.5)
        local step = math.min(distance, stepSize, speed * math.min(dt, 1 / 30))
        local nextPosition = root.Position + offset.Unit * step
        root.CFrame = CFrame.lookAt(nextPosition, door.frame.Position)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    stopMovement()
    return false, "Hedef kapı kayboldu veya farm durduruldu"
end

local function knockOnce()
    local model, humanoid, root = character()
    if not model or not humanoid or not root or humanoid.Health <= 0 then setStatus("Karakter bekleniyor") return end
    local door, distance = nearestDoor(root)
    if not door then setStatus("Uygun kapı bekleniyor") return end
    local key = doorKey(door)
    retryAfter[key] = os.clock() + CONFIG.RetryDelay
    targetLabel:SetValue(string.format("%.0f stud", distance))

    local reached, reason = stepToDoor(door)
    if not reached then setStatus(reason) return end
    local equipped, equipError = equipBag()
    if not equipped then stopMovement() setStatus(equipError) return end
    if not active() or not door.prompt.Parent or not door.prompt.Enabled then stopMovement() return end
    if not canReachPrompt(root, door) then stopMovement() setStatus("Kapı etkileşim mesafesi dışında") return end

    setStatus("Kapı çalınıyor")
    local event = door.frame:FindFirstChild("triggerDoor")
    if event and event:IsA("BindableEvent") then event:Fire() task.wait(0.1) end
    fireproximityprompt(door.prompt)
    cooldowns[key] = os.clock() + CONFIG.DoorCooldown
    retryAfter[key] = nil
    completed += 1
    countLabel:SetValue(tostring(completed))

    -- Kapının üstünde kısa süre sabit kal; sonraki hedefe yine kademeli hareket et.
    task.wait(1.5)
end

local function farmLoop()
    while ENV.GPODoorGeneration == generation do
        if active() then
            local ok, err = pcall(knockOnce)
            if not ok then stopMovement() setStatus("Hata atlandı: " .. tostring(err)) end
            task.wait(1)
        else
            stopMovement()
            task.wait(0.2)
        end
    end
end

Farm:CreateToggle({
    Name = "Auto Knock", Description = "Kapılara küçük CFrame adımlarıyla gider ve etkinliği tetikler.",
    Default = false, Flag = "AutoKnock",
    Callback = function(value)
        ENV.GPODoorRunning = value
        if not value then stopMovement() end
        setStatus(value and "Sürekli farm açık" or "Durduruldu")
    end,
})
Farm:CreateButton({
    Name = "Kapıları yeniden tara", Style = "Secondary",
    Callback = function()
        Window:Notify({Title = "Spooksville", Content = tostring(#scanDoors()) .. " etkin kapı bulundu."})
    end,
})
Settings:CreateSlider({
    Name = "Hareket hızı", Min = 8, Max = 32, Increment = 2, Default = CONFIG.TravelSpeed,
    Flag = "TravelSpeed", Callback = function(value) CONFIG.TravelSpeed = math.clamp(value, 8, 32) end,
})
Settings:CreateSlider({
    Name = "CFrame adım mesafesi", Min = 0.25, Max = 0.5, Increment = 0.25, Default = CONFIG.MaxStep,
    Flag = "DoorStepSize", Callback = function(value) CONFIG.MaxStep = math.clamp(value, 0.25, 0.5) end,
})
Settings:CreateSlider({
    Name = "Kapı üstü yükseklik", Min = 2, Max = 7, Increment = 0.5, Default = CONFIG.HoverHeight,
    Flag = "HoverHeight", Callback = function(value) CONFIG.HoverHeight = value end,
})
Settings:CreateSlider({
    Name = "Maksimum mesafe", Min = 100, Max = 1000, Increment = 50, Default = CONFIG.MaxDistance,
    Flag = "MaxDistance", Callback = function(value) CONFIG.MaxDistance = value end,
})

if ownsWindow then Window:CreateConfigTab() end
setStatus("Hazır — " .. tostring(#scanDoors()) .. " etkin kapı")
task.spawn(farmLoop)

return {loaded = true, generation = generation, doors = #scanDoors()}
