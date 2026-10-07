-- GPO Spooksville Auto Knock Door
-- Hutame-libV2 tabanlı, okunabilir ve yeniden çalıştırılabilir sürüm.

local ENV = getgenv()
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

local PLAYER = Players.LocalPlayer
local CONFIG = {
    WalkSpeed = 16,
    DoorCooldown = 170,
    RetryDelay = 30,
    MaxDistance = 500,
    RouteAttempts = 4,
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
    return ENV.GPODoorRunning and ENV.GPODoorGeneration == generation
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
    if humanoid and root then humanoid:MoveTo(root.Position) end
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

local function waitUntilFree(root)
    local deadline = os.clock() + 25
    while active() and root.Parent and root.Anchored and os.clock() < deadline do
        setStatus("Şeker animasyonu bekleniyor")
        task.wait(0.1)
    end
    return active() and root.Parent and not root.Anchored
end

local function canReachPrompt(root, door)
    return door.frame.Parent and door.prompt.Parent
        and (root.Position - door.frame.Position).Magnitude <= math.max(2, door.prompt.MaxActivationDistance - 1)
end

-- Kapının iki yüzünü dener; geçerli zemini ve en kısa başarılı rotayı seçer.
local function buildRoute(root, model, door)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {model}
    params.RespectCanCollide = true
    local best, bestLength
    local offset = math.clamp(door.prompt.MaxActivationDistance - 3, 3, 7)

    for _, sign in ipairs({1, -1}) do
        local sample = door.frame.Position + door.frame.CFrame.LookVector * offset * sign
        local ground = workspace:Raycast(sample + Vector3.new(0, 5, 0), Vector3.new(0, -18, 0), params)
        if ground and ground.Normal.Y > 0.5 then
            local target = ground.Position + Vector3.new(0, 2, 0)
            local path = PathfindingService:CreatePath({
                AgentRadius = 2.5, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 3,
            })
            local ok = pcall(path.ComputeAsync, path, root.Position, target)
            if ok and path.Status == Enum.PathStatus.Success then
                local points, length, previous = path:GetWaypoints(), 0, root.Position
                for _, point in ipairs(points) do length += (point.Position - previous).Magnitude previous = point.Position end
                if not bestLength or length < bestLength then best, bestLength = {path = path, points = points}, length end
            end
        end
    end
    return best
end

local function walkToDoor(door)
    local model, humanoid, root = character()
    if not model or not humanoid or not root or humanoid.Health <= 0 then return false, "Karakter hazır değil" end
    humanoid.WalkSpeed = CONFIG.WalkSpeed

    for attempt = 1, CONFIG.RouteAttempts do
        if not waitUntilFree(root) then return false, "Durduruldu" end
        if canReachPrompt(root, door) then stopMovement() return true end
        setStatus(attempt == 1 and "Yol hesaplanıyor" or "Rota yeniden hesaplanıyor")
        local route = buildRoute(root, model, door)
        if route then
            local blocked, waypointIndex = false, 1
            local connection = route.path.Blocked:Connect(function(index)
                if index >= waypointIndex then blocked = true end
            end)

            for index, waypoint in ipairs(route.points) do
                waypointIndex = index
                if not active() or blocked or canReachPrompt(root, door) then break end
                if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
                humanoid:MoveTo(waypoint.Position)
                setStatus("Kapıya yürüyor")
                local lastDistance = math.huge
                local lastProgress = os.clock()
                repeat
                    task.wait(0.05)
                    local delta = root.Position - waypoint.Position
                    local distance = Vector2.new(delta.X, delta.Z).Magnitude
                    if distance < lastDistance - 0.4 then lastDistance, lastProgress = distance, os.clock() end
                    if os.clock() - lastProgress > 4 then blocked = true end
                until not active() or blocked or distance <= 2 or canReachPrompt(root, door)
            end
            connection:Disconnect()
            stopMovement()
            if canReachPrompt(root, door) then return true end
        end
        task.wait(0.15)
    end
    return false, "Ulaşılabilir rota bulunamadı"
end

local function knockOnce()
    local model, humanoid, root = character()
    if not model or not humanoid or not root or humanoid.Health <= 0 then setStatus("Karakter bekleniyor") return end
    if root.Anchored then setStatus("Şeker animasyonu bekleniyor") return end

    local door, distance = nearestDoor(root)
    if not door then setStatus("Uygun kapı bekleniyor") return end
    local key = doorKey(door)
    retryAfter[key] = os.clock() + CONFIG.RetryDelay
    targetLabel:SetValue(string.format("%.0f stud", distance))

    local reached, reason = walkToDoor(door)
    if not reached then setStatus(reason) return end
    local equipped, equipError = equipBag()
    if not equipped then setStatus(equipError) return end
    if not active() or not door.prompt.Parent or not door.prompt.Enabled then return end

    setStatus("Kapı çalınıyor")
    local event = door.frame:FindFirstChild("triggerDoor")
    if event and event:IsA("BindableEvent") then event:Fire() task.wait(0.1) end
    fireproximityprompt(door.prompt)
    cooldowns[key] = os.clock() + CONFIG.DoorCooldown
    retryAfter[key] = nil
    completed += 1
    countLabel:SetValue(tostring(completed))

    -- Oyun şekeri verirken karakteri anchor'lar; serbest kalmadan yeni rota başlatma.
    local _, _, currentRoot = character()
    if currentRoot then waitUntilFree(currentRoot) end
end

local function farmLoop()
    while ENV.GPODoorGeneration == generation do
        if active() then
            local ok, err = pcall(knockOnce)
            if not ok then stopMovement() setStatus("Hata atlandı: " .. tostring(err)) end
            task.wait(1)
        else
            task.wait(0.2)
        end
    end
end

Farm:CreateToggle({
    Name = "Auto Knock", Description = "Yakındaki uygun kapılara yürür ve etkinliği tetikler.",
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
    Name = "Yürüme hızı", Min = 6, Max = 30, Increment = 1, Default = CONFIG.WalkSpeed,
    Flag = "WalkSpeed", Callback = function(value) CONFIG.WalkSpeed = value end,
})
Settings:CreateSlider({
    Name = "Maksimum mesafe", Min = 100, Max = 1000, Increment = 50, Default = CONFIG.MaxDistance,
    Flag = "MaxDistance", Callback = function(value) CONFIG.MaxDistance = value end,
})

if ownsWindow then Window:CreateConfigTab() end
setStatus("Hazır — " .. tostring(#scanDoors()) .. " etkin kapı")
task.spawn(farmLoop)

return {loaded = true, generation = generation, doors = #scanDoors()}
