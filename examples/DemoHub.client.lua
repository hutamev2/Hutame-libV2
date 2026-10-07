local Hutame = ...
-- Studio uses require; the generated Madium demo supplies its standalone library.
if not Hutame then
    Hutame = require(game:GetService("ReplicatedStorage"):WaitForChild("Hutame"))
end

local environment = type(getgenv) == "function" and getgenv() or nil
if environment and environment.HutameDemoWindow then environment.HutameDemoWindow:Destroy() end

local Window = Hutame:CreateWindow({
    Title = "Halloween", Subtitle = "Trick or treat.", HubName = "Hutame Hub",
    ToggleKey = Enum.KeyCode.RightControl,
})
if environment then environment.HutameDemoWindow = Window end

local Main = Window:CreateTab({ Name = "Trick Or Treat" })
local Section = Main:CreateSection("Trick Or Treat")
local status = nil
Section:CreateToggle({ Name = "Auto Trick Or Treat", Description = "Knock on every door", Flag = "AutoTrickOrTreat", Default = true, Callback = function(value)
    if status then status:SetValue(value and "Auto mode enabled" or "Auto mode disabled") end
end })
Section:CreateToggle({ Name = "Loop Rounds", Description = "Start over when done", Default = true, Flag = "LoopRounds" })
Section:CreateToggle({ Name = "Server Hop When Done", Description = "New server when done", Flag = "ServerHop" })
Section:CreateButton({ Name = "Hop Now", Callback = function()
    Window:Notify({ Title = "Demo action", Content = "Connect your server-hop function here." })
end })
Section:CreateToggle({ Name = "Hold Basket", Description = "Hold your best basket", Default = true, Flag = "HoldBasket" })
Section:CreateToggle({ Name = "Auto Set Spawn", Description = "Spawn at Spooksville", Default = true, Flag = "AutoSpawn" })
status = Section:CreateLabel({ Name = "Status", Text = "Ready — UI demo loaded" })
Section:CreateDropdown({ Name = "Spawn Point", Options = { "Spooksville", "Graveyard", "Town" }, Default = "Spooksville", Flag = "SpawnPoint" })

local Shop = Window:CreateTab("Shop"):CreateSection("Basket Shop")
Shop:CreateDropdown({ Name = "Basket", Options = { "Classic", "Pumpkin", "Ghost" }, Default = "Pumpkin", Flag = "Basket" })
Shop:CreateButton({ Name = "Preview Basket", Callback = function()
    Window:Notify({ Title = "Selected basket", Content = Window.Flags.Basket })
end })

local Settings = Window:CreateTab("Settings"):CreateSection("Preferences")
Settings:CreateSlider({ Name = "Volume", Description = "Example slider with decimal steps", Min = 0, Max = 1, Increment = 0.05, Default = 0.5, Flag = "Volume" })
Settings:CreateSlider({ Name = "Speed", Min = 16, Max = 100, Default = 24, Flag = "Speed" })
Settings:CreateInput({ Name = "Profile Name", Placeholder = "Enter a name", Default = "Default", Flag = "ProfileName", Callback = function(value)
    Window:SetStatus("•  Profile: " .. value)
end })
Settings:CreateDivider()
Settings:CreateLabel({ Name = "Hutame UI v" .. Hutame.Version, Text = "RightControl or the bottom button toggles the window." })
Settings:CreateButton({ Name = "Show Notification", Callback = function()
    Window:Notify({ Title = "Hutame Hub", Content = "Your interface is ready.", Duration = 4 })
end })
Window:Notify({ Title = "Hutame Hub", Content = "Welcome! All demo controls are ready." })
