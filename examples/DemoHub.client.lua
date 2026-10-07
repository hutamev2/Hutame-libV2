local Hutame = ...
-- Studio uses require; the generated Madium demo supplies its standalone library.
if not Hutame then
    Hutame = require(game:GetService("ReplicatedStorage"):WaitForChild("Hutame"))
end

local environment = type(getgenv) == "function" and getgenv() or nil
if environment and environment.HutameDemoWindow then environment.HutameDemoWindow:Destroy() end

local Window = Hutame:CreateWindow({
    Title = "Hutame Hub", Subtitle = "Controls, shortcuts and profiles.", HubName = "Hutame Hub",
    ToggleKey = Enum.KeyCode.RightControl,
    Size = Vector2.new(660, 460), MinSize = Vector2.new(520, 340),
    ConfigFolder = "HutameUI/Demo",
})
if environment then environment.HutameDemoWindow = Window end

local Main = Window:CreateTab({ Name = "Main" })
local Actions = Main:CreateSection("Quick actions")
Actions:CreateButton({ Name = "Run demo action", Style = "Primary", Compact = true,
    Tooltip = "This action waits one second to demonstrate automatic loading and repeat-click protection.", Callback = function()
        task.wait(1)
        Window:Notify({ Title = "Completed", Content = "Loading state has finished. No game action was performed." })
    end })
Actions:CreateButton({ Name = "Unavailable action", Compact = true, Disabled = true,
    Tooltip = "Disabled controls cannot run their callback." })
local Section = Main:CreateSection("Trick Or Treat")
local status = nil
Section:CreateToggle({ Name = "Auto Trick Or Treat", Description = "Knock on every door", Flag = "AutoTrickOrTreat", Default = true, Callback = function(value)
    if status then status:SetValue(value and "Auto mode enabled" or "Auto mode disabled") end
end })
Section:CreateToggle({ Name = "Loop Rounds", Description = "Start over when done", Default = true, Flag = "LoopRounds" })
Section:CreateToggle({ Name = "Server Hop When Done", Description = "New server when done", Flag = "ServerHop" })
Section:CreateButton({ Name = "Hop Now", Compact = true, Tooltip = "Connect this secondary action to your own server-hop callback.", Callback = function()
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
Settings:CreateKeybind({ Name = "Notification shortcut", Description = "Click to change; Escape cancels", Default = Enum.KeyCode.F6,
    Flag = "NotificationKey", Tooltip = "Backspace clears the binding. Duplicate keys and the window toggle key are rejected.",
    Callback = function() Window:Notify({ Title = "Shortcut", Content = "Your assigned shortcut is working." }) end })
local Advanced = Settings.Tab:CreateSection({ Name = "Advanced layout", Collapsed = true })
Advanced:CreateButton({ Name = "Compact window", Compact = true, Callback = function() Window:SetSize(Vector2.new(580, 380)) end })
Advanced:CreateButton({ Name = "Default window", Compact = true, Callback = function() Window:SetSize(Vector2.new(660, 460)) end })
Advanced:CreateLabel({ Name = "Resize", Text = "Drag the bottom-right corner. Search works across all tabs." })
Window:CreateConfigTab()
Window:Notify({ Title = "Hutame Hub", Content = "Welcome! All demo controls are ready." })
