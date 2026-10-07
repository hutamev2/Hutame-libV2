-- Run in Madium after copying dist/Hutame.lua to hutame/Hutame.lua.
local Hutame = ...
if not Hutame then Hutame = assert(loadstring(readfile("hutame/Hutame.lua"), "@Hutame"))() end
local window = Hutame:CreateWindow({ Title = "Hutame smoke test", AnimationDuration = 0.08 })
local ok, result = pcall(function()
    local first = window:CreateTab("First")
    local second = window:CreateTab("Second")
    local section = first:CreateSection("Checks")
    local calls = 0
    local toggle = section:CreateToggle({ Name = "Toggle", Flag = "TestToggle", Callback = function() calls += 1 end })
    assert(calls == 0, "Initialization must not call callbacks")
    toggle:SetValue(true, true)
    assert(window.Flags.TestToggle == true and calls == 0)
    toggle:SetValue(false)
    task.wait()
    assert(calls == 1 and window.Flags.TestToggle == false)
    local slider = section:CreateSlider({ Name = "Slider", Min = 0, Max = 1, Increment = 0.05 })
    slider:SetValue(0.43)
    assert(math.abs(slider:GetValue() - 0.45) < 0.00001)
    slider:SetValue(12)
    assert(slider:GetValue() == 1)
    local dropdown = section:CreateDropdown({ Name = "Dropdown", Options = {"A", "B"}, Default = "A" })
    firesignal(dropdown.Root:FindFirstChildWhichIsA("TextButton").Activated)
    task.wait(0.3)
    assert(dropdown.Root.Size.Y.Offset > 66, "Dropdown must expand")
    dropdown:SetOptions({"C"})
    task.wait(0.3)
    assert(dropdown:GetValue() == nil and dropdown.Root.Size.Y.Offset == 66)
    dropdown:SetValue("C")
    local input = section:CreateInput({ Name = "Input", Default = "Test" })
    input:SetDisabled(true)
    assert(not input.Root:FindFirstChildWhichIsA("TextBox").TextEditable)
    window:Hide(); window:Show(); window:Hide(); window:Show()
    task.wait(0.2)
    assert(window.Root.Visible and window.Root.GroupTransparency < 0.01, "Window transition race")
    first:Select(); second:Select(); first:Select()
    task.wait(0.2)
    assert(first.Container.Visible and not second.Container.Visible and first.Container.GroupTransparency < 0.01)
    window:Notify({ Title = "Test", Duration = 0.5 })
    task.wait(0.8)
    for _, child in window.Notifications:GetChildren() do assert(not child:IsA("Frame"), "Notification did not expire") end
    for _, child in window.Gui:GetDescendants() do
        if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
            assert(child.Font.Name:find("BuilderSans"), "Unexpected font")
        end
    end
    toggle:Destroy()
    assert(window.Flags.TestToggle == nil)
    window:Destroy()
    window:Destroy()
    assert(#window._connections == 0 and next(window._controls) == nil)
    return "PASS: callbacks, flags, slider, dropdown, disabled input, transition races, notifications, fonts, cleanup"
end)
window:Destroy()
assert(ok, result)
return result
