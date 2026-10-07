-- Hutame UI: a standalone returnable module for Studio require and Madium loadstring.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local Hutame = { Flags = {}, Version = "1.2.0" }
local defaults = {
    Background = Color3.fromRGB(16, 17, 19),
    Sidebar = Color3.fromRGB(19, 20, 23),
    Surface = Color3.fromRGB(25, 26, 29),
    Hover = Color3.fromRGB(34, 36, 41),
    Border = Color3.fromRGB(43, 45, 51),
    Text = Color3.fromRGB(239, 240, 245),
    Muted = Color3.fromRGB(173, 177, 188),
    Accent = Color3.fromRGB(152, 204, 255),
}

local function make(class, props, parent)
    local object = Instance.new(class)
    for key, value in pairs(props or {}) do object[key] = value end
    object.Parent = parent
    return object
end

local function corner(object, radius)
    make("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, object)
end

local function padding(object, amount)
    make("UIPadding", {
        PaddingLeft = UDim.new(0, amount), PaddingRight = UDim.new(0, amount),
        PaddingTop = UDim.new(0, amount), PaddingBottom = UDim.new(0, amount),
    }, object)
end

local activeTweens = setmetatable({}, { __mode = "k" })
local function cancelTweens(object)
    local animations = activeTweens[object]
    activeTweens[object] = nil
    if animations then for _, animation in pairs(animations) do animation:Cancel() end end
end
local function tween(object, props, duration)
    local animations = activeTweens[object] or {}
    activeTweens[object] = animations
    for property, value in pairs(props) do
        local previous = animations[property]
        local animation = TweenService:Create(object, TweenInfo.new(duration or 0.18, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { [property] = value })
        animations[property] = animation
        if previous then previous:Cancel() end
        animation.Completed:Once(function()
            if animations[property] == animation then animations[property] = nil end
            if next(animations) == nil and activeTweens[object] == animations then activeTweens[object] = nil end
        end)
        animation:Play()
    end
end

local function label(parent, text, size, color, props)
    local options = {
        BackgroundTransparency = 1, Text = text, TextSize = math.max(size, 12), TextColor3 = color,
        Font = Enum.Font.BuilderSans, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, 20),
    }
    for key, value in pairs(props or {}) do options[key] = value end
    return make("TextLabel", options, parent)
end

local function button(parent, text, theme, props)
    local options = {
        BackgroundColor3 = theme.Surface, BorderSizePixel = 0,
        Text = text, TextColor3 = theme.Text, TextSize = 14,
        Font = Enum.Font.BuilderSansMedium, AutoButtonColor = false,
        Size = UDim2.fromOffset(100, 30),
    }
    for key, value in pairs(props or {}) do options[key] = value end
    local result = make("TextButton", options, parent)
    corner(result, 6)
    return result
end

local function connect(owner, signal, callback)
    local connection = signal:Connect(callback)
    table.insert(owner._connections, connection)
    return connection
end

local function disconnect(owner)
    for _, connection in ipairs(owner._connections) do connection:Disconnect() end
    table.clear(owner._connections)
end

local function pressFeedback(owner, target)
    local stroke = make("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = (owner.Window or owner).Theme.Accent, Transparency = 1, Thickness = 1 }, target)
    connect(owner, target.InputBegan, function(input)
        if owner.Disabled or owner.Loading then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            tween(stroke, { Transparency = 0.1 }, 0.1)
        end
    end)
    connect(owner, target.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            tween(stroke, { Transparency = 1 }, 0.18)
        end
    end)
    connect(owner, target.MouseLeave, function() tween(stroke, { Transparency = 1 }, 0.18) end)
end

local function fire(control, value)
    if control._destroyed then return end
    if control.Flag then
        control.Window.Flags[control.Flag] = value
        Hutame.Flags[control.Flag] = value
    end
    local callback = control.Callback
    if control.Kind == "Keybind" then callback = control.Changed end
    if callback then
        task.spawn(function()
            local ok, err = pcall(callback, value)
            if not ok then warn("[Hutame callback] " .. tostring(err)) end
        end)
    end
end

local Control = {}
Control.__index = Control
function Control:GetValue() return self.Value end
function Control:SetText(text)
    self.Name = tostring(text)
    self.Title.Text = self.Name
    if self._refresh then self:_refresh() end
    self.Window:_applySearch(false)
end
function Control:SetVisible(visible) self._userVisible = visible == true; self.Window:_applySearch(false) end
function Control:IsDisabled() return self.Disabled or self.Loading or self._destroyed end
function Control:SetTooltip(text) self.Tooltip = text and tostring(text) or nil end
function Control:_stateChanged()
    tween(self.Root, { GroupTransparency = self:IsDisabled() and 0.42 or 0 }, 0.15)
    if self:IsDisabled() then
        if self._close then self._close() end
        if self.Window._tooltipOwner == self then self.Window:_hideTooltip() end
    end
    if self.Input then
        self.Input.TextEditable = not self:IsDisabled()
        if self:IsDisabled() then self.Input:ReleaseFocus() end
    end
    if self.Window._capturing == self and self:IsDisabled() then self:CancelCapture() end
    if self._refresh then self:_refresh() end
end
function Control:SetDisabled(disabled)
    self.Disabled = disabled == true
    self:_stateChanged()
end
function Control:SetLoading(loading) self.Loading = loading == true; self:_stateChanged() end
function Control:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    if self.Window._capturing == self then self.Window._capturing = nil end
    if self.Window._tooltipOwner == self then self.Window:_hideTooltip() end
    disconnect(self)
    if self.Flag and self.Window._flags[self.Flag] == self then
        self.Window._flags[self.Flag] = nil
        self.Window.Flags[self.Flag] = nil
        Hutame.Flags[self.Flag] = nil
    end
    self.Window._controls[self] = nil
    local index = table.find(self.Section.Controls, self)
    if index then table.remove(self.Section.Controls, index) end
    self.Root:Destroy()
    self.Window:_applySearch(false)
end

local Section = {}
Section.__index = Section
local function row(section, options, height, reserve)
    options = options or {}
    local window = section.Window
    assert(not window._destroyed, "Window has been destroyed")
    if options.Flag then assert(not window._flags[options.Flag], "Duplicate Flag: " .. options.Flag) end
    local root = make("CanvasGroup", {
        Name = options.Name or "Control", BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, height or (options.Description and 50 or 36)),
        LayoutOrder = section._count,
    }, section.Body)
    section._count = section._count + 1
    local title = label(root, options.Name or "", 14, window.Theme.Text, {
        Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, -(reserve or 0), 0, 20),
    })
    if options.Description then
        label(root, options.Description, 11, window.Theme.Muted, {
            Position = UDim2.fromOffset(0, 25), Size = UDim2.new(1, -(reserve or 0), 0, 17),
        })
    end
    local control = setmetatable({
        Root = root, Title = title, Window = window, Callback = options.Callback,
        Flag = options.Flag, Disabled = options.Disabled == true, Loading = false, _connections = {},
        Name = options.Name or "", Description = options.Description or "", Tooltip = options.Tooltip,
        Section = section, _userVisible = true, Default = options.Default, Persist = options.Persist ~= false,
    }, Control)
    table.insert(section.Controls, control)
    window._controls[control] = true
    if options.Flag then window._flags[options.Flag] = control end
    window:_bindTooltip(control)
    task.defer(function() if not control._destroyed then control:_stateChanged(); window:_applySearch(false) end end)
    return control
end

function Section:CreateButton(options)
    local c = row(self, options, options.Description and 78 or 40)
    c.Title.Visible = false
    local b = button(c.Root, options.Name or "Button", self.Window.Theme, {
        Position = UDim2.fromOffset(0, options.Description and 46 or 3),
        Size = options.Compact and UDim2.fromOffset(0, 32) or UDim2.new(1, 0, 0, 32),
        AutomaticSize = options.Compact and Enum.AutomaticSize.X or Enum.AutomaticSize.None,
    })
    make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, b)
    c.Title = b
    c.Kind = "Button"
    local primary = options.Style == "Primary"
    function c:_refresh()
        b.Text = self.Loading and (options.LoadingText or "Working…") or self.Name
        b.TextColor3 = primary and self.Window.Theme.Background or self.Window.Theme.Text
        tween(b, { BackgroundColor3 = primary and self.Window.Theme.Accent or
            ((self._hovered and not self:IsDisabled()) and self.Window.Theme.Hover or self.Window.Theme.Surface) }, 0.14)
    end
    function c:Activate()
        if self:IsDisabled() then return end
        if options.AutoLoading == false then fire(self); return end
        self:SetLoading(true)
        task.spawn(function()
            local ok, err = pcall(function() if self.Callback then self.Callback() end end)
            if not self._destroyed then self:SetLoading(false) end
            if not ok then warn("[Hutame callback] " .. tostring(err)) end
        end)
    end
    pressFeedback(c, b)
    connect(c, b.Activated, function() c:Activate() end)
    connect(c, b.MouseEnter, function() c._hovered = true; c:_refresh() end)
    connect(c, b.MouseLeave, function() c._hovered = false; c:_refresh() end)
    c:_refresh()
    return c
end

function Section:CreateToggle(options)
    local c = row(self, options, nil, 58)
    c.Kind = "Toggle"
    c.Default = options.Default == true
    function c:Validate(value) return type(value) == "boolean" end
    local theme = self.Window.Theme
    local track = button(c.Root, "", theme, {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 9), Size = UDim2.fromOffset(38, 20),
    })
    corner(track, 10)
    local knob = make("Frame", { Size = UDim2.fromOffset(14, 14), BorderSizePixel = 0, BackgroundColor3 = theme.Background }, track)
    corner(knob, 7)
    function c:SetValue(value, silent)
        self.Value = value == true
        tween(track, { BackgroundColor3 = self.Value and theme.Accent or theme.Hover })
        tween(knob, { Position = UDim2.fromOffset(self.Value and 21 or 3, 3), BackgroundColor3 = self.Value and theme.Background or theme.Muted })
        if silent then
            if self.Flag then self.Window.Flags[self.Flag] = self.Value; Hutame.Flags[self.Flag] = self.Value end
        else fire(self, self.Value) end
    end
    connect(c, track.Activated, function() if not c:IsDisabled() then c:SetValue(not c.Value) end end)
    c:SetValue(options.Default == true, true)
    return c
end

function Section:CreateSlider(options)
    local c = row(self, options, options.Description and 82 or 64, 70)
    local theme = self.Window.Theme
    local min, max, increment = options.Min or 0, options.Max or 100, options.Increment or 1
    assert(max > min and increment > 0, "Slider requires Max > Min and Increment > 0")
    c.Kind = "Slider"
    c.Default = options.Default or min
    function c:Validate(value) return type(value) == "number" and value == value and value >= min and value <= max end
    local valueLabel = label(c.Root, "", 12, theme.Accent, { Position = UDim2.new(1, -68, 0, 5), Size = UDim2.fromOffset(68, 20), TextXAlignment = Enum.TextXAlignment.Right })
    local hit = button(c.Root, "", theme, { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -30), Size = UDim2.new(1, 0, 0, 28) })
    local track = make("Frame", { BackgroundColor3 = theme.Hover, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 11), Size = UDim2.new(1, 0, 0, 5) }, hit)
    corner(track, 3)
    local fill = make("Frame", { BackgroundColor3 = theme.Accent, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, track)
    corner(fill, 3)
    local knob = make("Frame", { BackgroundColor3 = theme.Accent, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(12, 12) }, track)
    corner(knob, 6)
    function c:SetValue(value, silent)
        local number = tonumber(value)
        assert(number and number == number and math.abs(number) < math.huge, "Slider value must be finite")
        self.Value = math.clamp(min + math.round((number - min) / increment) * increment, min, max)
        local ratio = (self.Value - min) / (max - min)
        fill.Size = UDim2.fromScale(ratio, 1)
        knob.Position = UDim2.fromScale(ratio, 0.5)
        valueLabel.Text = string.format("%.4f", self.Value):gsub("0+$", ""):gsub("%.$", "")
        if silent then
            if self.Flag then self.Window.Flags[self.Flag] = self.Value; Hutame.Flags[self.Flag] = self.Value end
        else fire(self, self.Value) end
    end
    local active
    local function update(input)
        if c:IsDisabled() or not c.Window._visible or not c.Root.Visible or c.Section.Tab ~= c.Window.SelectedTab or track.AbsoluteSize.X <= 0 then return end
        local value = min + math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1) * (max - min)
        local previous = c.Value
        c:SetValue(value, true)
        if previous ~= c.Value then fire(c, c.Value) end
    end
    connect(c, hit.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then active = input; update(input) end
    end)
    connect(c, UserInputService.InputChanged, function(input)
        if active and (input == active or (active.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)) then update(input) end
    end)
    connect(c, UserInputService.InputEnded, function(input) if input == active then active = nil end end)
    c:SetValue(options.Default or min, true)
    return c
end

function Section:CreateDropdown(options)
    local c = row(self, options, options.Description and 88 or 66)
    c.Kind = "Dropdown"
    local theme = self.Window.Theme
    local baseHeight = c.Root.Size.Y.Offset
    local trigger = button(c.Root, "Select...   v", theme, { Position = UDim2.fromOffset(0, baseHeight - 36), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Left })
    padding(trigger, 8)
    local menu = make("ScrollingFrame", {
        Position = UDim2.fromOffset(0, baseHeight), Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0, Visible = false, ScrollBarThickness = 3, ScrollBarImageColor3 = theme.Accent,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
    }, c.Root)
    corner(menu, 6)
    make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }, menu)
    local items, optionConnections = {}, {}
    function c:Validate(value) return value == nil or table.find(items, value) ~= nil end
    local destroyControl = c.Destroy
    function c:Destroy()
        for _, connection in ipairs(optionConnections) do connection:Disconnect() end
        table.clear(optionConnections)
        destroyControl(self)
    end
    local opened = false
    local function close()
        opened = false
        menu.Visible = false
        tween(c.Root, { Size = UDim2.new(1, 0, 0, baseHeight) }, 0.18)
    end
    c._close = close
    function c:SetValue(value, silent)
        if value ~= nil then assert(table.find(items, value), "Dropdown value is not an option") end
        self.Value = value
        trigger.Text = (value or "Select...") .. "   v"
        close()
        if silent then
            if self.Flag then self.Window.Flags[self.Flag] = value; Hutame.Flags[self.Flag] = value end
        else fire(self, value) end
    end
    function c:SetOptions(values)
        for _, connection in ipairs(optionConnections) do connection:Disconnect() end
        table.clear(optionConnections)
        for _, child in ipairs(menu:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
        items = {}
        for index, value in ipairs(values) do
            assert(type(value) == "string", "Dropdown options must be strings")
            if not table.find(items, value) then
                table.insert(items, value)
                local item = button(menu, value, theme, { Size = UDim2.new(1, -5, 0, 28), LayoutOrder = index })
                table.insert(optionConnections, item.Activated:Connect(function() if not c:IsDisabled() then c:SetValue(value) end end))
            end
        end
        menu.Size = UDim2.new(1, 0, 0, math.min(#items * 31, 155))
        if self.Value and not table.find(items, self.Value) then self:SetValue(nil) end
        close()
    end
    connect(c, trigger.Activated, function()
        if c:IsDisabled() or #items == 0 then return end
        opened = not opened
        if not opened then close(); return end
        menu.Visible = true
        tween(c.Root, { Size = UDim2.new(1, 0, 0, baseHeight + menu.Size.Y.Offset + 6) }, 0.22)
    end)
    c.Root.ClipsDescendants = true
    pressFeedback(c, trigger)
    c:SetOptions(options.Options or {})
    c:SetValue(options.Default, true)
    return c
end

function Section:CreateInput(options)
    local c = row(self, options, options.Description and 88 or 66)
    c.Kind = "Input"
    c.Default = options.Default or ""
    function c:Validate(value) return type(value) == "string" end
    local theme = self.Window.Theme
    local input = make("TextBox", {
        Position = UDim2.new(0, 0, 1, -36), Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = theme.Surface, BorderSizePixel = 0, Font = Enum.Font.BuilderSans,
        TextSize = 14, TextColor3 = theme.Text, PlaceholderColor3 = theme.Muted,
        PlaceholderText = options.Placeholder or "Type here...", Text = "", ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, c.Root)
    c.Input = input
    corner(input, 6); padding(input, 8)
    local outline = make("UIStroke", { Color = theme.Border, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, input)
    connect(c, input.Focused, function() tween(outline, { Color = theme.Accent, Transparency = 0.1 }) end)
    connect(c, input.FocusLost, function() tween(outline, { Color = theme.Border, Transparency = 0.5 }) end)
    function c:SetValue(value, silent)
        self.Value = tostring(value or "")
        input.Text = self.Value
        if silent then
            if self.Flag then self.Window.Flags[self.Flag] = self.Value; Hutame.Flags[self.Flag] = self.Value end
        else fire(self, self.Value) end
    end
    connect(c, input.FocusLost, function()
        if not c:IsDisabled() and input.Text ~= c.Value then c:SetValue(input.Text) end
    end)
    c:SetValue(options.Default or "", true)
    return c
end

function Section:CreateLabel(options)
    local c = row(self, options, options.Text and 48 or 30)
    local text = label(c.Root, options.Text or "", 11, self.Window.Theme.Muted, { Position = UDim2.fromOffset(0, 25) })
    function c:SetValue(value) self.Value = tostring(value or ""); text.Text = self.Value end
    c:SetValue(options.Text)
    return c
end

function Section:CreateDivider()
    local c = row(self, {}, 12)
    make("Frame", { BackgroundColor3 = self.Window.Theme.Border, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 1) }, c.Root)
    return c
end

local function keyCode(value)
    if type(value) == "string" then
        local ok, key = pcall(function() return Enum.KeyCode[value] end)
        return ok and key or nil
    end
    if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then return value end
    return nil
end

function Section:CreateKeybind(options)
    local c = row(self, options, nil, 130)
    c.Kind = "Keybind"
    c.Changed = options.Changed
    c.Default = keyCode(options.Default) or Enum.KeyCode.Unknown
    c.AllowWhenHidden = options.AllowWhenHidden ~= false
    local keyButton = button(c.Root, "", self.Window.Theme, {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.fromOffset(120, 30),
    })
    function c:Validate(value) return keyCode(value) ~= nil end
    function c:_refresh()
        keyButton.Text = self.Window._capturing == self and "Press a key…" or (self.Value == Enum.KeyCode.Unknown and "Unbound" or self.Value.Name)
        keyButton.TextColor3 = self.Window._capturing == self and self.Window.Theme.Accent or self.Window.Theme.Text
    end
    function c:SetValue(value, silent)
        local key = keyCode(value)
        assert(key, "Keybind expects an Enum.KeyCode or its name")
        if key ~= Enum.KeyCode.Unknown then
            assert(key ~= self.Window.ToggleKey, "Key is reserved for the window toggle")
            for control in pairs(self.Window._controls) do
                assert(control == self or control.Kind ~= "Keybind" or control.Value ~= key, "Key is already assigned")
            end
        end
        self.Value = key
        if self.Flag then self.Window.Flags[self.Flag] = key; Hutame.Flags[self.Flag] = key end
        self:_refresh()
        if not silent then fire(self, key) end
    end
    function c:CancelCapture()
        if self.Window._capturing == self then self.Window._capturing = nil end
        self:_refresh()
    end
    function c:Capture()
        if self:IsDisabled() then return end
        if self.Window._capturing then self.Window._capturing:CancelCapture() end
        self.Window._capturing = self
        self:_refresh()
    end
    connect(c, keyButton.Activated, function() c:Capture() end)
    c:SetValue(c.Default, true)
    return c
end

function Section:_resize(instant)
    if self.Window._destroyed then return end
    local expanded = not self.Collapsed or self._searchExpanded
    local height = 32 + (expanded and self.Layout.AbsoluteContentSize.Y + 4 or 0)
    self.Header.Text = (expanded and "−  " or "+  ") .. self.Name
    if instant then self.Root.Size = UDim2.new(1, -4, 0, height)
    else tween(self.Root, { Size = UDim2.new(1, -4, 0, height) }, self.Window.AnimationDuration) end
end
function Section:SetCollapsed(collapsed)
    self.Collapsed = collapsed == true
    self:_resize()
end
function Section:Toggle() self:SetCollapsed(not self.Collapsed) end

local Tab = {}
Tab.__index = Tab
function Tab:CreateSection(name)
    local options = type(name) == "table" and name or { Name = name }
    name = options.Name or "Section"
    local root = make("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.new(1, -4, 0, 32), ClipsDescendants = true, LayoutOrder = self._count }, self.Page)
    self._count = self._count + 1
    local heading = button(root, "−  " .. name, self.Window.Theme, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left })
    make("Frame", { BackgroundColor3 = self.Window.Theme.Border, BackgroundTransparency = 0.45, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 1) }, heading)
    local body = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, root)
    local layout = make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }, body)
    local section = setmetatable({ Root = root, Body = body, Layout = layout, Header = heading,
        Name = name, Tab = self, Window = self.Window, Controls = {}, Collapsed = options.Collapsed == true, _count = 1 }, Section)
    table.insert(self.Sections, section)
    connect(self.Window, heading.Activated, function() section:Toggle() end)
    connect(self.Window, layout:GetPropertyChangedSignal("AbsoluteContentSize"), function() section:_resize() end)
    section:_resize(true)
    return section
end
function Tab:Select() self.Window:SelectTab(self) end

local Window = {}
Window.__index = Window
function Window:_hideTooltip()
    self._tooltipGeneration = (self._tooltipGeneration or 0) + 1
    self._tooltipOwner = nil
    if self.Tooltip then self.Tooltip.Visible = false end
end
function Window:_bindTooltip(control)
    local function show()
        if not control.Tooltip or control._destroyed then return end
        self:_hideTooltip()
        local generation = self._tooltipGeneration
        task.delay(0.4, function()
            if self._destroyed or control._destroyed or generation ~= self._tooltipGeneration or not self._visible or not control.Root.Visible then return end
            if self.SelectedTab ~= control.Section.Tab or (control.Section.Collapsed and not control.Section._searchExpanded) then return end
            self._tooltipOwner = control
            self.TooltipText.Text = control.Tooltip
            local pos = control.Root.AbsolutePosition - self.Viewport.AbsolutePosition
            local size = self.Viewport.AbsoluteSize
            self.Tooltip.Position = UDim2.fromOffset(math.clamp(pos.X, 4, math.max(4, size.X - 264)), math.clamp(pos.Y + control.Root.AbsoluteSize.Y + 6, 4, math.max(4, size.Y - 100)))
            self.Tooltip.Visible = true
            self.Tooltip.GroupTransparency = 1
            tween(self.Tooltip, { GroupTransparency = 0 }, 0.12)
        end)
    end
    connect(control, control.Root.MouseEnter, show)
    connect(control, control.Root.MouseLeave, function() self:_hideTooltip() end)
    connect(control, control.Root.InputBegan, function(input) if input.UserInputType == Enum.UserInputType.Touch then show() end end)
    connect(control, control.Root.InputEnded, function(input) if input.UserInputType == Enum.UserInputType.Touch then self:_hideTooltip() end end)
end
function Window:_applySearch(selectMatch)
    if self._destroyed then return end
    local query = string.lower(self.SearchQuery or "")
    local firstMatch
    for _, tab in ipairs(self.Tabs) do
        local tabMatches = 0
        for _, section in ipairs(tab.Sections) do
            local count = 0
            for _, control in ipairs(section.Controls) do
                if not control._destroyed then
                    local haystack = string.lower(tab.Name .. " " .. section.Name .. " " .. control.Name .. " " .. control.Description)
                    local matches = query == "" or string.find(haystack, query, 1, true) ~= nil
                    control.Root.Visible = control._userVisible and matches
                    if control.Root.Visible then count += 1 end
                end
            end
            section.Root.Visible = query == "" or count > 0
            section._searchExpanded = query ~= "" and count > 0
            section:_resize()
            tabMatches += count
        end
        tab._matches = tabMatches
        if tabMatches > 0 and not firstMatch then firstMatch = tab end
    end
    if selectMatch and query ~= "" and firstMatch and (not self.SelectedTab or self.SelectedTab._matches == 0) then self:SelectTab(firstMatch) end
    if self.EmptySearch then self.EmptySearch.Visible = query ~= "" and (not self.SelectedTab or self.SelectedTab._matches == 0) end
end
function Window:SetSearch(query)
    self.SearchQuery = tostring(query or "")
    if self.SearchBox and self.SearchBox.Text ~= self.SearchQuery then self.SearchBox.Text = self.SearchQuery end
    self:_hideTooltip()
    self:_applySearch(true)
end
function Window:_handleInput(input, processed)
    if self._destroyed or processed or UserInputService:GetFocusedTextBox() then return end
    local key = input.KeyCode
    if key == Enum.KeyCode.Unknown then return end
    local capturing = self._capturing
    if capturing then
        if key == Enum.KeyCode.Escape then capturing:CancelCapture(); return end
        if key == Enum.KeyCode.Backspace or key == Enum.KeyCode.Delete then key = Enum.KeyCode.Unknown end
        local ok = pcall(function() capturing:SetValue(key) end)
        if ok then capturing:CancelCapture()
        else self:Notify({ Title = "Key unavailable", Content = "This key is already assigned. Choose another or press Escape." }) end
        return
    end
    if key == self.ToggleKey then self:Toggle(); return end
    for control in pairs(self._controls) do
        if control.Kind == "Keybind" and control.Value == key and not control:IsDisabled() and (self._visible or control.AllowWhenHidden) and control.Callback then
            task.spawn(function()
                local ok, err = pcall(control.Callback, key)
                if not ok then warn("[Hutame keybind] " .. tostring(err)) end
            end)
        end
    end
end

local function safeName(value)
    return type(value) == "string" and #value > 0 and #value <= 48 and value:match("^[%w_-]+$") ~= nil
end
function Window:ExportConfig()
    local values = {}
    for flag, control in pairs(self._flags) do
        if control.Persist and control.Validate then
            values[flag] = { kind = control.Kind, value = control.Kind == "Keybind" and control.Value.Name or control.Value }
        end
    end
    return HttpService:JSONEncode({ version = 1, values = values })
end
function Window:ImportConfig(json, silent)
    local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
    if not ok or type(data) ~= "table" or data.version ~= 1 or type(data.values) ~= "table" then return false, "Invalid profile format" end
    local pending, desiredKeys = {}, {}
    for flag, control in pairs(self._flags) do
        if control.Persist and control.Validate and data.values[flag] ~= nil then
            local entry = data.values[flag]
            if type(entry) ~= "table" or entry.kind ~= control.Kind or not control:Validate(entry.value) then return false, "Invalid value: " .. flag end
            pending[control] = { value = entry.value, previous = control.Value }
        end
    end
    for control in pairs(self._controls) do
        if control.Kind == "Keybind" then
            local key = pending[control] and keyCode(pending[control].value) or control.Value
            if key ~= Enum.KeyCode.Unknown then
                if key == self.ToggleKey or desiredKeys[key] then return false, "Profile keybind conflict" end
                desiredKeys[key] = true
            end
        end
    end
    -- Clear pending keybinds first so valid swaps do not cause intermediate conflicts.
    for control in pairs(pending) do if control.Kind == "Keybind" then control:SetValue(Enum.KeyCode.Unknown, true) end end
    for control, entry in pairs(pending) do control:SetValue(entry.value, true) end
    if not silent then for control in pairs(pending) do fire(control, control.Value) end end
    return true
end
function Window:ResetConfig(silent)
    local data = { version = 1, values = {} }
    for flag, control in pairs(self._flags) do
        if control.Persist and control.Validate then
            data.values[flag] = { kind = control.Kind, value = control.Kind == "Keybind" and control.Default.Name or control.Default }
        end
    end
    return self:ImportConfig(HttpService:JSONEncode(data), silent)
end
function Window:_profilePath(name)
    assert(safeName(name), "Profile name: use 1–48 letters, digits, _ or -")
    return self.ConfigFolder .. "/" .. name .. ".json"
end
function Window:_ensureConfigFolder()
    assert(type(isfolder) == "function" and type(makefolder) == "function", "File profiles need Madium; use ExportConfig/ImportConfig in Studio")
    local part = ""
    for segment in self.ConfigFolder:gmatch("[^/]+") do
        part = part == "" and segment or part .. "/" .. segment
        if not isfolder(part) then makefolder(part) end
    end
end
function Window:SaveConfig(name, overwrite)
    local ok, result = pcall(function()
        local path = self:_profilePath(name)
        self:_ensureConfigFolder()
        assert(type(writefile) == "function" and type(isfile) == "function", "File profile API unavailable")
        assert(overwrite == true or not isfile(path), "Profile exists; pass overwrite=true to replace it")
        writefile(path, self:ExportConfig())
        return path
    end)
    return ok, result
end
function Window:LoadConfig(name, silent)
    local ok, result = pcall(function()
        local path = self:_profilePath(name)
        assert(type(readfile) == "function" and type(isfile) == "function" and isfile(path), "Profile not found")
        return readfile(path)
    end)
    if not ok then return false, result end
    return self:ImportConfig(result, silent)
end
function Window:ListConfigs()
    local ok, result = pcall(function()
        self:_ensureConfigFolder()
        assert(type(listfiles) == "function", "File profile API unavailable")
        local names = {}
        for _, path in ipairs(listfiles(self.ConfigFolder)) do
            local name = path:gsub("\\", "/"):match("([^/]+)%.json$")
            if name and safeName(name) then table.insert(names, name) end
        end
        table.sort(names)
        return names
    end)
    if ok then return result, nil end
    return {}, result
end
function Window:DeleteConfig(name)
    local ok, result = pcall(function()
        local path = self:_profilePath(name)
        assert(type(delfile) == "function" and type(isfile) == "function" and isfile(path), "Profile not found")
        delfile(path)
    end)
    return ok, result
end
function Window:CreateConfigTab(options)
    options = options or {}
    local tab = self:CreateTab(options.Name or "Profiles")
    local section = tab:CreateSection("Configuration profiles")
    local names, listError = self:ListConfigs()
    local selection = section:CreateDropdown({ Name = "Saved profile", Options = names, Default = names[1], Persist = false,
        Tooltip = "Profiles store controls that have a Flag. Keybind actions are not executed during loading." })
    local nameInput = section:CreateInput({ Name = "New profile name", Default = "Default", Persist = false,
        Tooltip = "Use letters, digits, underscores or hyphens. Existing profiles require the Replace button." })
    local function report(ok, message)
        self:Notify({ Title = ok and "Profiles" or "Profile error", Content = tostring(message), Duration = 4 })
    end
    local function refresh(preferred)
        local updated = self:ListConfigs()
        selection:SetOptions(updated)
        if preferred and table.find(updated, preferred) then selection:SetValue(preferred, true) end
    end
    local create = section:CreateButton({ Name = "Create profile", Style = "Primary", Compact = true, Callback = function()
        local name = nameInput:GetValue()
        local ok, err = self:SaveConfig(name)
        report(ok, ok and ("Saved " .. name) or err)
        if ok then refresh(name) end
    end })
    local load = section:CreateButton({ Name = "Load selected", Compact = true, Callback = function()
        local ok, err = self:LoadConfig(selection:GetValue())
        report(ok, ok and "Profile loaded" or err)
    end })
    local replace = section:CreateButton({ Name = "Replace selected", Compact = true, Tooltip = "Explicitly overwrite the selected profile with current settings.", Callback = function()
        local ok, err = self:SaveConfig(selection:GetValue(), true)
        report(ok, ok and "Profile replaced" or err)
    end })
    local armed, remove
    remove = section:CreateButton({ Name = "Delete selected", Compact = true, Callback = function()
        local name = selection:GetValue()
        if not name then report(false, "Choose a profile first"); return end
        if armed ~= name then
            armed = name; remove:SetText("Confirm delete")
            task.delay(4, function() if not remove._destroyed then armed = nil; remove:SetText("Delete selected") end end)
            return
        end
        armed = nil; remove:SetText("Delete selected")
        local ok, err = self:DeleteConfig(name)
        report(ok, ok and "Profile deleted" or err)
        if ok then refresh() end
    end })
    section:CreateButton({ Name = "Refresh list", Compact = true, Callback = function() refresh(selection:GetValue()) end })
    section:CreateButton({ Name = "Reset to defaults", Tooltip = "Reset flagged controls to their original values. Saved profiles are unchanged.", Callback = function()
        local ok, err = self:ResetConfig()
        report(ok, ok and "Defaults restored" or err)
    end })
    if listError then
        for _, control in ipairs({create, load, replace, remove}) do control:SetDisabled(true) end
        section:CreateLabel({ Name = "File profiles unavailable", Text = "Use ExportConfig / ImportConfig for this environment." })
    end
    return tab
end
function Window:_styleTab(tab)
    local selected = self.SelectedTab == tab
    tween(tab.Button, {
        BackgroundColor3 = (tab._hovered and not selected) and self.Theme.Hover or self.Theme.Surface,
        BackgroundTransparency = selected and 0.08 or (tab._hovered and 0.3 or 1),
        TextColor3 = selected and self.Theme.Accent or (tab._hovered and self.Theme.Text or self.Theme.Muted),
    }, self.AnimationDuration * 0.75)
    tween(tab.Indicator, {
        BackgroundTransparency = selected and 0 or 1,
        Size = UDim2.new(selected and 1 or 0.35, 0, 0, 2),
    }, self.AnimationDuration)
end
function Window:SelectTab(tab)
    assert(tab.Window == self, "Tab belongs to another window")
    if self._destroyed then return end
    if self.SelectedTab == tab then return end
    local previous = self.SelectedTab
    self.SelectedTab = tab
    self:_hideTooltip()
    if self._capturing then self._capturing:CancelCapture() end
    for _, item in ipairs(self.Tabs) do
        local selected = item == tab
        item.Container.Visible = selected
        self:_styleTab(item)
    end
    local direction = previous and tab.Button.LayoutOrder < previous.Button.LayoutOrder and -1 or 1
    tab.Container.GroupTransparency = 0.55
    tab.Container.Position = UDim2.fromOffset(6 * direction, 0)
    tween(tab.Container, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, self.AnimationDuration)
    if self.EmptySearch then self.EmptySearch.Visible = (self.SearchQuery or "") ~= "" and (tab._matches or 0) == 0 end
end
function Window:CreateTab(options)
    if type(options) == "string" then options = { Name = options } end
    local b = button(self.TabBar, options.Name or "Tab", self.Theme, {
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 32), LayoutOrder = #self.Tabs + 1,
        BackgroundTransparency = 1, TextColor3 = self.Theme.Muted,
    })
    -- Only horizontal padding: vertical padding shifts child coordinates into the text.
    make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, b)
    local indicator = make("Frame", { Name = "SelectionIndicator", BackgroundColor3 = self.Theme.Accent, BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 1), BorderSizePixel = 0,
        Position = UDim2.new(0.5, 0, 1, -1), Size = UDim2.new(0.35, 0, 0, 2) }, b)
    corner(indicator, 2)
    local container = make("CanvasGroup", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, self.Content)
    local page = make("ScrollingFrame", {
        Name = options.Name or "Tab", BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3, ScrollBarImageColor3 = self.Theme.Accent, Visible = true,
    }, container)
    padding(page, 16)
    make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12) }, page)
    local tab = setmetatable({ Name = options.Name or "Tab", Sections = {}, Window = self, Page = page, Container = container, Button = b, Indicator = indicator, _count = 1 }, Tab)
    table.insert(self.Tabs, tab)
    connect(self, b.Activated, function() self:SelectTab(tab) end)
    connect(self, b.MouseEnter, function() tab._hovered = true; self:_styleTab(tab) end)
    connect(self, b.MouseLeave, function() tab._hovered = false; self:_styleTab(tab) end)
    if #self.Tabs == 1 then self:SelectTab(tab) end
    return tab
end
function Window:Show()
    if self._destroyed then return end
    self._visible = true
    self._transition = self._transition + 1
    self.Root.Visible = true
    tween(self.Root, { GroupTransparency = 0 }, self.AnimationDuration)
    tween(self.Scale, { Scale = self._targetScale }, self.AnimationDuration)
end
function Window:Hide()
    if self._destroyed then return end
    self._visible = false
    self:_hideTooltip()
    if self._capturing then self._capturing:CancelCapture() end
    self._transition = self._transition + 1
    local generation = self._transition
    tween(self.Root, { GroupTransparency = 1 }, self.AnimationDuration)
    tween(self.Scale, { Scale = self._targetScale * 0.96 }, self.AnimationDuration)
    task.delay(self.AnimationDuration, function()
        if not self._destroyed and not self._visible and self._transition == generation then self.Root.Visible = false end
    end)
end
function Window:Toggle() if self._visible then self:Hide() else self:Show() end end
function Window:SetStatus(text) self.Status.Text = tostring(text) end
local function dimensions(value, fallback)
    if value == nil then return fallback end
    if typeof(value) == "Vector2" then return value end
    assert(typeof(value) == "UDim2" and value.X.Scale == 0 and value.Y.Scale == 0, "Size must be Vector2 or offset-only UDim2")
    return Vector2.new(value.X.Offset, value.Y.Offset)
end
function Window:_clampPosition()
    local view = self.Viewport.AbsoluteSize
    local half = Vector2.new(self.Root.Size.X.Offset, self.Root.Size.Y.Offset) * self._targetScale / 2
    local p = self.Root.Position
    local x, y = view.X * p.X.Scale + p.X.Offset, view.Y * p.Y.Scale + p.Y.Offset
    self.Root.Position = UDim2.fromOffset(math.clamp(x, half.X, math.max(half.X, view.X-half.X)), math.clamp(y, half.Y, math.max(half.Y, view.Y-half.Y-40)))
end
function Window:SetSize(size)
    size = dimensions(size, self.Size)
    assert(size.X == size.X and size.Y == size.Y, "Size must be finite")
    self.Size = Vector2.new(math.clamp(size.X, self.MinSize.X, self.MaxSize.X), math.clamp(size.Y, self.MinSize.Y, self.MaxSize.Y))
    self.Root.Size = UDim2.fromOffset(self.Size.X, self.Size.Y)
    self:_fitViewport()
end
function Window:GetSize() return self.Size end
function Window:Notify(options)
    if self._destroyed then return end
    local slot = make("Frame", { Size = UDim2.new(1, 0, 0, 84), BackgroundTransparency = 1 }, self.Notifications)
    local card = make("CanvasGroup", { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(24, 0), GroupTransparency = 1, BackgroundColor3 = self.Theme.Surface, BorderSizePixel = 0 }, slot)
    tween(card, { Position = UDim2.fromOffset(0, 0), GroupTransparency = 0 }, self.AnimationDuration)
    corner(card, 9)
    make("UIStroke", { Color = self.Theme.Border, Thickness = 1 }, card)
    label(card, options.Title or "Hutame", 13, self.Theme.Accent, { Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 20) })
    label(card, options.Content or "", 12, self.Theme.Text, { Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 40), TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Top })
    local children = self.Notifications:GetChildren()
    local count = 0
    for _, child in ipairs(children) do if child:IsA("Frame") then count = count + 1 end end
    if count > 4 then
        for _, child in ipairs(children) do if child:IsA("Frame") then child:Destroy(); break end end
    end
    task.delay(math.max(0.5, options.Duration or 4), function()
        if not slot.Parent or self._destroyed then return end
        tween(card, { Position = UDim2.fromOffset(24, 0), GroupTransparency = 1 }, self.AnimationDuration)
        task.delay(self.AnimationDuration, function() if slot.Parent then slot:Destroy() end end)
    end)
end
function Window:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    disconnect(self)
    local controls = {}
    for control in pairs(self._controls) do table.insert(controls, control) end
    for _, control in ipairs(controls) do control:Destroy() end
    for object in pairs(activeTweens) do
        if object:IsDescendantOf(self.Gui) then cancelTweens(object) end
    end
    self.Gui:Destroy()
end

function Hutame.CreateWindow(_library, options)
    options = options or {}
    local player = Players.LocalPlayer
    assert(player, "Hutame UI must be required from a LocalScript on the client")
    local theme = table.clone(defaults)
    for key, value in pairs(options.Theme or {}) do theme[key] = value end
    local self = setmetatable({ Theme = theme, Tabs = {}, Flags = {}, _flags = {}, _controls = {}, _connections = {},
        _transition = 0, _visible = false, _targetScale = 1,
        SearchQuery = "", ToggleKey = options.ToggleKey or Enum.KeyCode.RightControl,
        AnimationDuration = math.clamp(tonumber(options.AnimationDuration) or 0.24, 0.05, 1),
    }, Window)
    self.MinSize = dimensions(options.MinSize, Vector2.new(520, 340))
    self.MinSize = Vector2.new(math.max(480, self.MinSize.X), math.max(300, self.MinSize.Y))
    self.MaxSize = dimensions(options.MaxSize, Vector2.new(1280, 900))
    assert(self.MaxSize.X >= self.MinSize.X and self.MaxSize.Y >= self.MinSize.Y, "MaxSize must exceed MinSize")
    self.Size = dimensions(options.Size, Vector2.new(660, 440))
    self.Size = Vector2.new(math.clamp(self.Size.X, self.MinSize.X, self.MaxSize.X), math.clamp(self.Size.Y, self.MinSize.Y, self.MaxSize.Y))
    self.ConfigFolder = options.ConfigFolder or ("HutameUI/" .. tostring(game.GameId))
    assert(type(self.ConfigFolder) == "string" and #self.ConfigFolder > 0 and #self.ConfigFolder <= 160 and not self.ConfigFolder:find("[^%w_/-]") and not self.ConfigFolder:match("^/") and not self.ConfigFolder:match("/$") and not self.ConfigFolder:find("//"), "ConfigFolder must be a relative alphanumeric folder path")
    local parent = options.Parent
    if not parent and type(gethui) == "function" then
        local ok, container = pcall(gethui)
        if ok and typeof(container) == "Instance" then parent = container end
    end
    parent = parent or player:WaitForChild("PlayerGui")
    local gui = make("ScreenGui", { Name = "HutameUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = options.DisplayOrder or 20 }, parent)
    self.Gui = gui
    local function applyFont(object)
        if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
            if object.Font == Enum.Font.BuilderSansBold then object.Font = options.FontBold or Enum.Font.BuilderSansBold
            elseif object.Font == Enum.Font.BuilderSansMedium then object.Font = options.FontMedium or options.Font or Enum.Font.BuilderSansMedium
            else object.Font = options.Font or Enum.Font.BuilderSans end
        end
    end
    connect(self, gui.DescendantAdded, applyFont)
    local viewport = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
    self.Viewport = viewport
    local width, height = self.Size.X, self.Size.Y
    local root = make("CanvasGroup", { Name = "Window", GroupTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(width, height), BackgroundColor3 = theme.Background, BorderSizePixel = 0, ClipsDescendants = true }, viewport)
    self.Root = root
    corner(root, 12)
    make("UIStroke", { Color = theme.Border, Thickness = 1 }, root)
    local scale = make("UIScale", {}, root)
    self.Scale = scale
    function self:_fitViewport()
        local size = viewport.AbsoluteSize
        if size.X <= 0 or size.Y <= 0 then return end
        self._targetScale = math.max(0.1, math.min(1, (size.X - 20) / self.Size.X, (size.Y - 68) / self.Size.Y))
        cancelTweens(scale)
        scale.Scale = self._targetScale * (self._visible and 1 or 0.96)
        self:_clampPosition()
    end
    connect(self, viewport:GetPropertyChangedSignal("AbsoluteSize"), function() self:_fitViewport() end)
    task.defer(function() if not self._destroyed then self:_fitViewport() end end)
    local sidebar = make("Frame", { Name = "Sidebar", BackgroundColor3 = theme.Sidebar, BorderSizePixel = 0, Size = UDim2.new(0, 156, 1, 0) }, root)
    make("Frame", { BackgroundColor3 = theme.Border, BorderSizePixel = 0, Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0) }, sidebar)
    local banner = make("Frame", { Position = UDim2.fromOffset(10, 12), Size = UDim2.fromOffset(136, 60), BackgroundColor3 = theme.Hover, BorderSizePixel = 0 }, sidebar)
    corner(banner, 9)
    make("UIGradient", { Color = ColorSequence.new(theme.Hover, theme.Sidebar), Rotation = 35 }, banner)
    label(banner, "H", 26, theme.Accent, { Position = UDim2.fromOffset(10, 15), Size = UDim2.fromOffset(24, 30), Font = Enum.Font.BuilderSansBold })
    label(banner, options.HubName or "Hutame Hub", 14, theme.Text, { Position = UDim2.fromOffset(40, 13), Size = UDim2.fromOffset(90, 20), Font = Enum.Font.BuilderSansBold })
    label(banner, "UI library", 12, theme.Muted, { Position = UDim2.fromOffset(40, 33), Size = UDim2.fromOffset(90, 16) })
    local profile = make("Frame", { BackgroundColor3 = theme.Background, Position = UDim2.fromOffset(10, 84), Size = UDim2.fromOffset(136, 54), BorderSizePixel = 0 }, sidebar)
    corner(profile, 8)
    local avatar = make("ImageLabel", { BackgroundColor3 = theme.Hover, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 9), Size = UDim2.fromOffset(36, 36) }, profile)
    corner(avatar, 8)
    task.spawn(function()
        local ok, content = pcall(function() return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
        if ok and not self._destroyed then avatar.Image = content end
    end)
    label(profile, player.DisplayName, 13, theme.Text, { Position = UDim2.fromOffset(50, 9), Size = UDim2.fromOffset(80, 18), Font = Enum.Font.BuilderSansMedium })
    label(profile, "@" .. player.Name, 12, theme.Muted, { Position = UDim2.fromOffset(50, 28), Size = UDim2.fromOffset(80, 16) })
    self.SearchBox = make("TextBox", { Name = "Search", Position = UDim2.fromOffset(10, 152), Size = UDim2.fromOffset(136, 32),
        BackgroundColor3 = theme.Surface, BorderSizePixel = 0, Text = "", PlaceholderText = "Search controls…", TextSize = 13,
        Font = Enum.Font.BuilderSans, TextColor3 = theme.Text, PlaceholderColor3 = theme.Muted, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false }, sidebar)
    corner(self.SearchBox, 6)
    make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, self.SearchBox)
    connect(self, self.SearchBox:GetPropertyChangedSignal("Text"), function() self:SetSearch(self.SearchBox.Text) end)
    label(sidebar, "HUTAME  /  " .. Hutame.Version, 12, theme.Muted, { Position = UDim2.new(0, 14, 1, -54), Size = UDim2.new(1, -24, 0, 18) })
    self.Status = label(sidebar, "•  Hutame is ready", 10, theme.Muted, { Position = UDim2.new(0, 14, 1, -29), Size = UDim2.new(1, -24, 0, 18) })
    local body = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(156, 0), Size = UDim2.new(1, -156, 1, 0) }, root)
    local header = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -88, 0, 49), Active = true }, body)
    label(header, options.Title or "Hutame", 19, theme.Text, { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -20, 0, 23), Font = Enum.Font.BuilderSansBold })
    label(header, options.Subtitle or "Welcome to your hub", 11, theme.Muted, { Position = UDim2.fromOffset(20, 31), Size = UDim2.new(1, -20, 0, 15) })
    local hide = button(body, "−", theme, { Position = UDim2.new(1, -82, 0, 6), Size = UDim2.fromOffset(36, 36), TextColor3 = Color3.fromRGB(242, 194, 68), BackgroundTransparency = 1, TextSize = 21 })
    local close = button(body, "×", theme, { Position = UDim2.new(1, -44, 0, 6), Size = UDim2.fromOffset(36, 36), TextColor3 = Color3.fromRGB(235, 97, 110), BackgroundTransparency = 1, TextSize = 21 })
    for _, target in ipairs({hide, close}) do
        connect(self, target.MouseEnter, function() tween(target, { BackgroundTransparency = 0.2 }, 0.12) end)
        connect(self, target.MouseLeave, function() tween(target, { BackgroundTransparency = 1 }, 0.12) end)
    end
    connect(self, hide.Activated, function() self:Hide() end)
    connect(self, close.Activated, function() self:Destroy() end)
    self.TabBar = make("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(16, 55), Size = UDim2.new(1, -32, 0, 34), ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X }, body)
    make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, self.TabBar)
    make("Frame", { BackgroundColor3 = theme.Border, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 93), Size = UDim2.new(1, 0, 0, 1) }, body)
    self.Content = make("Frame", { BackgroundColor3 = theme.Sidebar, BorderSizePixel = 0, Position = UDim2.fromOffset(10, 104), Size = UDim2.new(1, -20, 1, -114), ClipsDescendants = true }, body)
    corner(self.Content, 8)
    self.EmptySearch = label(self.Content, "No matching controls in this tab.", 14, theme.Muted, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Visible = false, ZIndex = 5 })
    self.Tooltip = make("CanvasGroup", { Name = "Tooltip", BackgroundColor3 = theme.Hover, BorderSizePixel = 0,
        Size = UDim2.fromOffset(260, 92), Visible = false, ZIndex = 100 }, viewport)
    corner(self.Tooltip, 8)
    self.TooltipText = label(self.Tooltip, "", 13, theme.Text, { Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 1, -16), TextWrapped = true, TextTruncate = Enum.TextTruncate.None })
    local launcher = button(viewport, "H  ·  " .. (options.Title or "Hutame"), theme, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(150, 32) })
    make("UIStroke", { Color = theme.Border }, launcher)
    pressFeedback(self, launcher)
    connect(self, launcher.Activated, function() self:Toggle() end)
    connect(self, UserInputService.InputBegan, function(input, processed) self:_handleInput(input, processed) end)
    if options.Resizable ~= false then
        local grip = button(root, "◢", theme, { Name = "ResizeHandle", AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1),
            Size = UDim2.fromOffset(28, 28), TextSize = 14, TextColor3 = theme.Muted, BackgroundTransparency = 1, ZIndex = 10 })
        local resizing, resizeOrigin, initialSize, topLeft, resizeScale
        connect(self, grip.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                resizing = input; resizeOrigin = input.Position; initialSize = self.Size
                topLeft = root.AbsolutePosition - viewport.AbsolutePosition; resizeScale = self._targetScale
            end
        end)
        connect(self, UserInputService.InputChanged, function(input)
            if not resizing or not self._visible then return end
            if input ~= resizing and not (resizing.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement) then return end
            local delta = input.Position - resizeOrigin
            local requested = initialSize + Vector2.new(delta.X, delta.Y) / resizeScale
            local bounds = viewport.AbsoluteSize
            requested = Vector2.new(math.min(requested.X, (bounds.X - topLeft.X - 10) / resizeScale), math.min(requested.Y, (bounds.Y - topLeft.Y - 44) / resizeScale))
            self:SetSize(requested)
            root.Position = UDim2.fromOffset(topLeft.X + self.Size.X * self._targetScale / 2, topLeft.Y + self.Size.Y * self._targetScale / 2)
            self:_clampPosition()
        end)
        connect(self, UserInputService.InputEnded, function(input) if input == resizing then resizing = nil end end)
    end
    local drag, origin, start
    connect(self, header.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            drag = input; origin = input.Position; start = root.AbsolutePosition + root.AbsoluteSize / 2
        end
    end)
    connect(self, UserInputService.InputChanged, function(input)
        if not drag or not root.Visible then return end
        if input ~= drag and not (drag.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement) then return end
        local delta = input.Position - origin
        local center = start + Vector2.new(delta.X, delta.Y) - viewport.AbsolutePosition
        local half = root.AbsoluteSize / 2
        local size = viewport.AbsoluteSize
        root.Position = UDim2.fromOffset(math.clamp(center.X, half.X, math.max(half.X, size.X - half.X)), math.clamp(center.Y, half.Y, math.max(half.Y, size.Y - half.Y)))
    end)
    connect(self, UserInputService.InputEnded, function(input) if input == drag then drag = nil end end)
    self.Notifications = make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -48), Size = UDim2.new(0, 280, 1, -70), ZIndex = 5 }, viewport)
    make("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, self.Notifications)
    connect(self, gui.Destroying, function() if not self._destroyed then self:Destroy() end end)
    scale.Scale = 0.96
    self:Show()
    return self
end

return Hutame
