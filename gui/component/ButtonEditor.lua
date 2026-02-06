PTButtonEditor = PTGuiComponent:Extend("puppeteer_button_editor")
local util = PTUtil
local RotateTexture = util.RotateTexture

function PTButtonEditor:New()
    local obj = setmetatable({}, self)
    local frame = CreateFrame("Frame", self:GenerateName())
    obj:SetHandle(frame)
    obj:SetSimpleBackground(PTGuiComponent.BACKGROUND_DIALOG)

    local title = PTGuiLib.Get("title", frame)
        :SetSize(192, 36)
        :SetPoint("CENTER", frame, "TOP")
        :SetText("Edit Buttons")
    obj:AddComponent("Title", title)

    local scrollFrame = PTGuiLib.Get("scroll_frame", frame)
        :SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -50)
        :SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 100)
        :SetSimpleBackground()
    obj:AddComponent("ScrollFrame", scrollFrame)

    local controlsLabel = PTGuiLib.Get("text", frame)
        :SetText("Controls")
        :SetWidth(66)
        :SetHeight(30)
        :SetPoint("TOPLEFT", scrollFrame:GetHandle(), "TOPLEFT", 5, 33)
        :SetFontSize(14)
        :SetFontFlags("OUTLINE")
        :SetJustifyV("BOTTOM")
    local buttonIDLabel = PTGuiLib.Get("text", frame)
        :SetText("Button ID")
        :SetWidth(100)
        :SetHeight(30)
        :SetPoint("LEFT", controlsLabel, "RIGHT", 0, 0)
        :SetFontSize(14)
        :SetFontFlags("OUTLINE")
        :SetJustifyV("BOTTOM")
    local customNameLabel = PTGuiLib.Get("text", frame)
        :SetText("Custom Name")
        :SetWidth(130)
        :SetHeight(30)
        :SetPoint("LEFT", buttonIDLabel, "RIGHT", 0, 0)
        :SetFontSize(14)
        :SetFontFlags("OUTLINE")
        :SetJustifyV("BOTTOM")
    local showUnboundLabel = PTGuiLib.Get("text", frame)
        :SetText("Show Unbound")
        :SetWidth(82)
        :SetHeight(30)
        :SetPoint("LEFT", customNameLabel, "RIGHT", 0, 0)
        :SetFontSize(14)
        :SetFontFlags("OUTLINE")
        :SetJustifyV("BOTTOM")

    local done = PTGuiLib.Get("button", frame)
        :SetPoint("BOTTOM", frame, "BOTTOM", 0, 5)
        :SetText("Done")
        :SetSize(200, 20)
        :OnClick(function()
            local Buttons = PTOptions.Buttons
            local buttonInfo = PTOptions.ButtonInfo
            PTUtil.ClearTable(Buttons)
            for _, line in ipairs(obj.Lines) do
                local button = line.Button
                table.insert(Buttons, button)
                if not buttonInfo[button] then
                    buttonInfo[button] = {}
                end
                local info = buttonInfo[button]
                info.Name = line:GetCustomButtonName()
                info.ShowUnbound = line:IsUnboundShown()
            end
            PTSettingsGui.ReloadBindingLines()
            PTSettingsGui.UpdateBindingsInterface()
            Puppeteer.InitBindingDisplayCache()
            Puppeteer.InitOverrideBindingsMapping()
            obj:Dispose()
            PTSettingsGui.PopOverlayFrame()
        end)

    local addButton = PTGuiLib.Get("button", frame)
        :SetPoint("BOTTOM", done, "TOP", 0, 10)
        :SetSize(200, 50)
        :SetText("Add a Button")
        :OnClick(function(self)
            if not obj.AddMode then
                obj:SetAddMode(true)
            end
        end)

    addButton:HookScript("OnMouseUp", function(self)
        if not obj.AddMode then
            return
        end
        if not obj:ContainsButton(arg1) then
            obj:AddButtonLine(arg1, arg1)
            PlaySound("igSpellBookOpen")
        end
        obj:SetAddMode(false)
        local onClick = addButton:GetScript("OnClick")
        addButton:SetScript("OnClick", nil)
        PTUtil.RunLater(function()
            addButton:SetScript("OnClick", onClick, true)
        end)
    end)
    addButton:SetScript("OnKeyUp", function(self)
        if not obj.AddMode then
            return
        end
        if arg1 == "ESCAPE" then
            obj:SetAddMode(false)
            return
        end
        if not obj:ContainsButton(arg1) then
            if not obj:AreBindingsFull() then
                obj:AddButtonLine(arg1, arg1)
                PlaySound("igSpellBookOpen")
            else
                Puppeteer.Info("You cannot add any more non-mouse buttons!")
            end
        end
        obj:SetAddMode(false)
    end)
    addButton:SetScript("OnMouseWheel", function(self)
        if not obj.AddMode then
            return
        end
        if arg1 > 0 then
            if not obj:ContainsButton("MOUSEWHEELUP") then
                if not obj:AreBindingsFull() then
                    obj:AddButtonLine("MOUSEWHEELUP", "MOUSEWHEELUP")
                    PlaySound("igSpellBookOpen")
                else
                    Puppeteer.Info("You cannot add any more non-mouse buttons!")
                end
            end
        elseif arg1 < 0 then
            if not obj:ContainsButton("MOUSEWHEELDOWN") then
                if not obj:AreBindingsFull() then
                    obj:AddButtonLine("MOUSEWHEELDOWN", "MOUSEWHEELDOWN")
                    PlaySound("igSpellBookOpen")
                else
                    Puppeteer.Info("You cannot add any more non-mouse buttons!")
                end
            end
        end
        obj:SetAddMode(false)
    end)
    obj:AddComponent("AddButton", addButton)
    obj:SetAddMode(false)

    obj.Lines = {}
    obj.LineMap = {}
    return obj
end

function PTButtonEditor:OnAcquire()
    self.super.OnAcquire(self)
    self:SetSize(425, 400)
    self:GetScrollFrame():FixNextUpdate()
    for _, button in ipairs(PTOptions.Buttons) do
        self:AddButtonLine(button, button)
    end
end

function PTButtonEditor:OnDispose()
    self.super.OnDispose(self)
    self:ClearButtonLines()
    self:SetAddMode(false)
end

PTButtonEditor:CreateGetter("ScrollFrame")
PTButtonEditor:CreateGetter("AddButton")

function PTButtonEditor:SetAddMode(addMode)
    self.AddMode = addMode
    self:GetAddButton():GetHandle():EnableKeyboard(self.AddMode)
    self:GetAddButton():GetHandle():EnableMouseWheel(self.AddMode)
    self:GetAddButton():SetText(self.AddMode and "Press any button, key,\nor mouse wheel to bind\nPress Esc to Cancel" 
        or "Left click to start\nbinding a button")
end

function PTButtonEditor:ContainsButton(button)
    return self.LineMap[button] ~= nil
end

function PTButtonEditor:GetNumUsedBindings()
    local nonBindingButtons = util.GetAllButtonsSet()
    local used = 0
    for button, _ in pairs(self.LineMap) do
        if not nonBindingButtons[button] then
            used = used + 1
        end
    end
    return used
end

function PTButtonEditor:AreBindingsFull()
    return self:GetNumUsedBindings() >= 24
end

function PTButtonEditor:SwapIndexes(index1, index2)
    self.Lines[index1], self.Lines[index2] = self.Lines[index2], self.Lines[index1]
    self:UpdateLinePositions()
end

function PTButtonEditor:AddButtonLine(id, button)
    local line = PTGuiLib.Get("puppeteer_button_line", self:GetScrollFrame())
            :SetSize(380, 25)
            :SetButton(button)
            :SetControlHandler(self)

    table.insert(self.Lines, line)
    if id then
        self.LineMap[id] = line
    end

    self:UpdateLinePositions()
    return line
end

function PTButtonEditor:RemoveButtonLine(line)
    for id, l in pairs(self.LineMap) do
        if line == l then
            self.LineMap[id] = nil
        end
    end
    PTUtil.RemoveElement(self.Lines, line)
    line:Dispose()

    self:UpdateLinePositions()
end

function PTButtonEditor:ClearButtonLines()
    for _, line in ipairs(self.Lines) do
        line:Dispose()
    end
    PTUtil.ClearTable(self.Lines)
    PTUtil.ClearTable(self.LineMap)
end

function PTButtonEditor:UpdateLinePositions()
    local INTERVAL = 26
    for i, line in ipairs(self.Lines) do
        line:SetPoint("TOPLEFT", self:GetScrollFrame(), "TOPLEFT", 5, -5 - (INTERVAL * (i - 1)))
    end
    self:GetScrollFrame():UpdateScrollChildRect()
end

-- Control handler functions

function PTButtonEditor:OnLineDelete(line)
    self:RemoveButtonLine(line)
end

function PTButtonEditor:OnLineUp(line)
    local index = PTUtil.IndexOf(self.Lines, line)
    if IsShiftKeyDown() then
        for i = index, 2, -1 do
            self:SwapIndexes(i, i - 1)
        end
    elseif index > 1 and table.getn(self.Lines) > 1 then
        self:SwapIndexes(index, index - 1)
    end
end

function PTButtonEditor:OnLineDown(line)
    local index = PTUtil.IndexOf(self.Lines, line)
    local lineCount = table.getn(self.Lines)
    if IsShiftKeyDown() then
        for i = index, lineCount - 1 do
            self:SwapIndexes(i, i + 1)
        end
    elseif index < table.getn(self.Lines) then
        self:SwapIndexes(index, index + 1)
    end
end

-- End of control handler functions

PTGuiLib.RegisterComponent(PTButtonEditor)

-- Button line component

PTButtonLine = PTGuiComponent:Extend("puppeteer_button_line")

function PTButtonLine:New()
    local obj = setmetatable({}, self)
    local frame = CreateFrame("Frame", self:GenerateName())
    obj:SetHandle(frame)

    local delete = PTGuiLib.Get("button", frame)
        :SetPoint("LEFT", frame, "LEFT", 0, 0)
        :SetSize(20, 20)
        :ApplyTooltip("Delete this button")
        :OnClick(function()
            if obj.ControlHandler then
                obj.ControlHandler:OnLineDelete(obj)
            end
        end)
    delete.NormalTexture:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    RotateTexture(delete.NormalTexture, 180, 0.7)
    delete.PushedTexture:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    RotateTexture(delete.PushedTexture, 180, 0.7)
    delete:SetUseDefaultTextures(true)

    local up = PTGuiLib.Get("button", frame)
        :SetPoint("LEFT", delete, "RIGHT", 6, 0)
        :SetSize(20, 20)
        :ApplyTooltip("Move this button up", "Hold shift to move to top")
        :OnClick(function()
            if obj.ControlHandler then
                obj.ControlHandler:OnLineUp(obj)
            end
        end)
    up.NormalTexture:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    RotateTexture(up.NormalTexture, -90, 0.75)
    up.PushedTexture:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    RotateTexture(up.PushedTexture, -90, 0.75)
    up.HighlightTexture:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    up.HighlightTexture:SetTexCoord(0, 1, 0, 1)
    up:SetUseDefaultTextures(true)
    
    local down = PTGuiLib.Get("button", frame)
        :SetPoint("LEFT", up, "RIGHT", 1, 0)
        :SetSize(20, 20)
        :ApplyTooltip("Move this button down", "Hold shift to move to bottom")
        :OnClick(function()
            if obj.ControlHandler then
                obj.ControlHandler:OnLineDown(obj)
            end
        end, true)
    down.NormalTexture:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    RotateTexture(down.NormalTexture, 90, 0.75)
    down.PushedTexture:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    RotateTexture(down.PushedTexture, 90, 0.75)
    down.HighlightTexture:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    down.HighlightTexture:SetTexCoord(0, 1, 0, 1)
    down:SetUseDefaultTextures(true)


    local buttonNameLabel = PTGuiLib.Get("text", frame)
        :SetPoint("LEFT", down, "RIGHT", 5, 0)
        :SetText("Left")
        :SetWidth(90)
        :SetHeight(30)
        :SetJustifyH("RIGHT")
        :SetNonSpaceWrap(true)
    obj:AddComponent("ButtonNameLabel", buttonNameLabel)

    local nameEditbox = PTGuiLib.Get("editbox", frame)
        :SetPoint("LEFT", buttonNameLabel, "RIGHT", 5, 0)
        :SetSize(130, 20)
        :SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
        end)
        :ApplyTooltip("This name will be shown on the binding tooltip")
    obj:AddComponent("NameEditbox", nameEditbox)
    
    local showUnboundCheckbox = PTGuiLib.Get("checkbox", frame)
        :SetPoint("LEFT", nameEditbox, "RIGHT", 30, 0)
        :SetSize(20, 20)
        :ApplyTooltip("If enabled, the binding tooltip will show this key when unbound")
    obj:AddComponent("ShowUnboundCheckbox", showUnboundCheckbox)


    return obj
end

function PTButtonLine:OnAcquire()
    self.super.OnAcquire(self)
    self:SetSize(380, 25)
end

function PTButtonLine:OnDispose()
    self.super.OnDispose(self)
    self.Button = nil
end

PTButtonLine:CreateGetter("ButtonNameLabel")
PTButtonLine:CreateGetter("NameEditbox")
PTButtonLine:CreateGetter("ShowUnboundCheckbox")

function PTButtonLine:SetButton(button)
    self.Button = button
    self:GetButtonNameLabel():SetText(util.GetButtonName(button))
    local buttonInfo = PTOptions.ButtonInfo
    if not buttonInfo[button] then
        buttonInfo[button] = {Name = util.GetButtonName(button), ShowUnbound = true}
    end
    self:GetNameEditbox():SetText(buttonInfo[button].Name or util.GetButtonName(button))
    self:GetShowUnboundCheckbox():SetChecked(buttonInfo[button].ShowUnbound)
    return self
end

-- The handler is expected to have functions OnLineDelete, OnLineUp, OnLineDown
function PTButtonLine:SetControlHandler(handler)
    self.ControlHandler = handler
    return self
end

function PTButtonLine:GetCustomButtonName()
    local text = self:GetNameEditbox():GetText()
    if text == "" then
        text = util.GetButtonName(self.Button)
    end
    return text
end

function PTButtonLine:IsUnboundShown()
    return self:GetShowUnboundCheckbox():GetChecked() == 1
end

PTGuiLib.RegisterComponent(PTButtonLine)