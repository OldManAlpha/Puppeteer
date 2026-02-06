PTSpellLine = PTGuiComponent:Extend("puppeteer_spell_line")
local compost = AceLibrary("Compost-2.0")
local util = PTUtil
local RotateTexture = util.RotateTexture
local colorize = util.Colorize
local SearchSpells = util.SearchSpells
local SearchMacros = util.SearchMacros
local SearchItems = util.SearchItems

local bindHelper = PTGuiLib.Get("dropdown", UIParent)

function PTSpellLine:New()
    local obj = setmetatable({}, self)
    local frame = CreateFrame("Frame", self:GenerateName())
    obj:SetHandle(frame)

    local initFunc = function(self, gui)
        self.checked = self.text == gui:GetText()
    end
    local func = function(self, gui)
        gui:SetText(self.text)
        obj:SetBindType(self.type)
    end
    local createTypeEntry = function(type, text, tooltip)
        return {
            type = type,
            text = text,
            tooltipTitle = text,
            tooltipText = tooltip,
            initFunc = initFunc,
            func = func
        }
    end
    local typeDropdown = PTGuiLib.Get("dropdown", frame)
        :SetShowShadow(false)
        :SetPoint("LEFT", frame, "LEFT", 70, 0)
        :SetWidth(70)
        :SetText("Spell")
        :SetOptions({
            createTypeEntry("SPELL", "Spell", "Bind a spell from your spellbook"),
            createTypeEntry("ACTION", "Action", "Bind a special action"),
            createTypeEntry("ITEM", "Item", "Bind an item from your inventory"),
            createTypeEntry("MACRO", "Macro", "Bind one of your macros"),
            createTypeEntry("SCRIPT", "Script", "Run a custom Lua script"),
            createTypeEntry("MULTI", "Multi", "Open an interface with multiple bindings")
        })

    local buttonText = PTGuiLib.Get("text", frame)
        :SetPoint("RIGHT", typeDropdown, "LEFT", -5, 0)
        :SetText("Left")
        :SetWidth(65)
        :SetHeight(30)
        :SetJustifyH("RIGHT")
        :SetNonSpaceWrap(true)

    buttonText:Hide()
    
    local down = PTGuiLib.Get("button", frame)
        :SetPoint("RIGHT", typeDropdown, "LEFT", -3, 0)
        :SetSize(20, 20)
        :ApplyTooltip("Move this binding down", "Hold shift to move to bottom")
        :OnClick(function()
            if obj.ControlHandler then
                obj.ControlHandler:OnLineDown(obj)
            end
        end)
    down.NormalTexture:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    RotateTexture(down.NormalTexture, 90, 0.75)
    down.PushedTexture:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    RotateTexture(down.PushedTexture, 90, 0.75)
    down.HighlightTexture:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    down.HighlightTexture:SetTexCoord(0, 1, 0, 1)
    down:SetUseDefaultTextures(true)

    local up = PTGuiLib.Get("button", frame)
        :SetPoint("RIGHT", down, "LEFT", -1, 0)
        :SetSize(20, 20)
        :ApplyTooltip("Move this binding up", "Hold shift to move to top")
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

    local delete = PTGuiLib.Get("button", frame)
        :SetPoint("RIGHT", up, "LEFT", -6, 0)
        :SetSize(20, 20)
        :ApplyTooltip("Delete this binding")
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

    local options = PTGuiLib.Get("button", frame)
        :SetPoint("RIGHT", frame, "RIGHT")
        :SetSize(20, 20)
        :ApplyTooltip("More options for this binding")
        :OnClick(function()
            local TabFrame = PTSettingsGui.TabFrame
            local editor = PTGuiLib.Get("puppeteer_binding_options", TabFrame)
                :SetPoint("CENTER", TabFrame, "CENTER")
            editor:SetBinding(obj.Binding)
            PTSettingsGui.AddOverlayFrame(editor)
            editor:SetDisposeHandler(function()
                PTSettingsGui.PopOverlayFrame()
                PTSettingsGui.UpdateUnsavedChanges()
                obj:Update()
            end)
        end)
    options:SetClickSound(PlaySound, "igMainMenuOption")
    options.NormalTexture:SetTexture("Interface\\ICONS\\INV_Misc_Gear_01")
    options.NormalTexture:SetTexCoord(0, 1, 0, 1)
    options.PushedTexture:SetTexture("Interface\\ICONS\\INV_Misc_Gear_01")
    options.PushedTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    options.HighlightTexture:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    RotateTexture(options.HighlightTexture, 0, 0.5)
    options:SetUseDefaultTextures(true)

    -- Depending on the selected type, one of these three components is displayed
    local editbox = PTGuiLib.Get("editbox", frame)
        :SetJustifyH("CENTER")
        :SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
        end)
    local dropdown = PTGuiLib.Get("dropdown", frame)
        :SetShowShadow(false)
    local t = getglobal(dropdown:GetName().."Text")
    t:ClearAllPoints()
    t:SetPoint("CENTER", dropdown:GetHandle(), "CENTER")
    t:SetJustifyH("CENTER")
    t:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    local button = PTGuiLib.Get("button", frame)
    for _, f in ipairs({editbox, dropdown, button}) do
        f:SetPoint("LEFT", typeDropdown, "RIGHT", 5, 0)
        f:SetPoint("RIGHT", options, "LEFT", -5, 0)
        f:SetHeight(20)
        f:Hide()
    end

    obj:AddComponent("Label", buttonText)
    obj:AddComponent("UpButton", up)
    obj:AddComponent("DownButton", down)
    obj:AddComponent("DeleteButton", delete)
    obj:AddComponent("TypeDropdown", typeDropdown)
    obj:AddComponent("OptionsButton", options)
    obj:AddComponent("ContentEditbox", editbox)
    obj:AddComponent("ContentDropdown", dropdown)
    obj:AddComponent("ContentButton", button)
    return obj
end

function PTSpellLine:OnAcquire()
    self.super.OnAcquire(self)

    self:SetMode(PTSpellLine.MODE_LABELED)
end

function PTSpellLine:OnDispose()
    self.super.OnDispose(self)

    self.ControlHandler = nil
end

PTSpellLine:CreateGetter("Label")
PTSpellLine:CreateGetter("UpButton")
PTSpellLine:CreateGetter("DownButton")
PTSpellLine:CreateGetter("DeleteButton")
PTSpellLine:CreateGetter("TypeDropdown")
PTSpellLine:CreateGetter("OptionsButton")
PTSpellLine:CreateGetter("ContentEditbox")
PTSpellLine:CreateGetter("ContentDropdown")
PTSpellLine:CreateGetter("ContentButton")

function PTSpellLine:SetLabel(text)
    self:GetLabel():SetText(text):ApplyTooltip(text)
    return self
end

PTSpellLine.MODE_LABELED = 1
PTSpellLine.MODE_ORDERED = 2
function PTSpellLine:SetMode(mode)
    if mode == PTSpellLine.MODE_LABELED then
        self:GetLabel():Show()
        self:GetUpButton():Hide()
        self:GetDownButton():Hide()
        self:GetDeleteButton():Hide()
    elseif mode == PTSpellLine.MODE_ORDERED then
        self:GetLabel():Hide()
        self:GetUpButton():Show()
        self:GetDownButton():Show()
        self:GetDeleteButton():Show()
    end
    return self
end

function PTSpellLine:SetBindType(bindType)
    self:GetTypeDropdown():SetText(bindType)
    util.ClearTable(self.Binding)
    self.Binding.Type = bindType
    PTSettingsGui.UpdateUnsavedChanges()
    self:Update()
    return self
end

function PTSpellLine:SetBinding(binding)
    self.Binding = binding
    Puppeteer.ExpandBinding(binding)
    self:Update()
    return self
end

-- The handler is expected to have functions OnLineDelete, OnLineUp, OnLineDown
function PTSpellLine:SetControlHandler(handler)
    self.ControlHandler = handler
    return self
end

function PTSpellLine:SetEnabledContent(contentType)
    self:GetContentEditbox():Hide()
    self:GetContentDropdown():Hide()
    self:GetContentButton():Hide()
    if contentType == "editbox" then
        self:GetContentEditbox():Show()
    elseif contentType == "dropdown" then
        self:GetContentDropdown():Show()
    elseif contentType == "button" then
        self:GetContentButton():Show()
    end
end

function PTSpellLine:ApplySearchableEditbox(bindType, searchFunc, searchAtLength)
    local binding = self.Binding
    self:GetContentEditbox():SetScript("OnTextChanged", function(editbox)
        if not editbox.hasFocus then
            return
        end
        binding.Data = self:GetContentEditbox():GetText()
        PTSettingsGui.UpdateUnsavedChanges()
        if not binding.Type then
            binding.Type = bindType
        end
        if string.len(binding.Data) < (searchAtLength or 2) then
            return
        end
        local searchResults = searchFunc(binding.Data)
        if table.getn(searchResults) == 1 and searchResults[1] == binding.Data then
            bindHelper:SetToggleState(false)
            return
        end
        bindHelper:SetSimpleOptions(searchResults, function(option)
            return {
                text = option,
                notCheckable = true,
                func = function(option)
                    binding.Data = option.text
                    PTSettingsGui.UpdateUnsavedChanges()
                    self:Update()
                end
            }
        end)
        bindHelper:SetToggleState(false)
        bindHelper:SetToggleState(true, self:GetContentEditbox():GetHandle(), 0, 0)
        bindHelper:SetKeepOpen(true)
    end)
    self:GetContentEditbox():SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
        self.hasFocus = true
    end)
    self:GetContentEditbox():SetScript("OnEditFocusLost", function(self)
        bindHelper:SetToggleState(false)
        self:HighlightText(0, 0)
        self.hasFocus = nil
    end)
    self:GetContentEditbox():SetScript("OnTabPressed", function(editbox)
        if string.len(binding.Data) < (searchAtLength or 2) then
            return
        end
        local searchResults = searchFunc(binding.Data)
        if table.getn(searchResults) > 0 then
            editbox:SetText(searchResults[1])
            PTSettingsGui.UpdateUnsavedChanges()
        end
    end)
end

function PTSpellLine:Update()
    local binding = self.Binding
    if binding.Type == "SPELL" or not binding.Type then
        self:SetEnabledContent("editbox")
        self:GetTypeDropdown():SetText("Spell")
        self:GetContentEditbox():SetText(binding.Data or "")
        self:GetContentEditbox():ApplyTooltip("Enter the name of a spell", "To downrank, suffix '("..RANK.." #)'", "For example, 'Heal("..RANK.." 2)'")
        self:ApplySearchableEditbox("SPELL", SearchSpells, 2)
    elseif binding.Type == "ACTION" then
        self:SetEnabledContent("dropdown")
        self:GetTypeDropdown():SetText("Action")
        self:GetContentDropdown():ApplyTooltip("Choose from a list of special actions")
        self:GetContentDropdown():SetText(binding.Data or "")

        self:GetContentDropdown():SetDynamicOptions(function(addOption, level, args)
            for _, action in ipairs(Puppeteer.ActionBinds) do
                addOption("text", action.Name,
                    "checked", binding.Data == action.Name,
                    "func", args.func,
                    "tooltipTitle", action.Name,
                    "tooltipText", action.Description)
            end
        end, {
            func = function(self, gui)
                binding.Data = self.text
                gui:SetText(self.text)
                PTSettingsGui.UpdateUnsavedChanges()
            end
        })
    elseif binding.Type == "MACRO" then
        self:SetEnabledContent("editbox")
        self:GetTypeDropdown():SetText("Macro")
        self:GetContentEditbox():SetText(binding.Data or "")
        self:GetContentEditbox():ApplyTooltip("Enter the name of one of your macros", 
            "Note that macro binds won't target unless you enable", "\"Target While Casting\" in this binding's settings or globally")
        self:ApplySearchableEditbox("MACRO", SearchMacros, 1)
    elseif binding.Type == "ITEM" then
        self:SetEnabledContent("editbox")
        self:GetTypeDropdown():SetText("Item")
        self:GetContentEditbox():SetText(binding.Data or "")
        self:GetContentEditbox():ApplyTooltip("Enter the name of an item in your bags")
        self:ApplySearchableEditbox("ITEM", SearchItems, 1)
    elseif binding.Type == "SCRIPT" then
        self:SetEnabledContent("button")
        self:GetTypeDropdown():SetText("Script")
        local script = binding.Data or ""
        local info
        local _, lines = nil, 0
        if script ~= "" then
            _, lines = string.gsub(script, "\n", "")
            lines = lines + 1
            info = lines.." Line"..(lines ~= 1 and "s" or "")
        else
            info = "Empty"
        end
        self:GetContentButton():SetText("Edit Script ("..info..")")
        local maxLines = 16
        if lines > maxLines then
            local lineCount = 0
            local pos = 0
            local nl
            while lineCount < maxLines do
                nl = string.find(script, "\n", pos, true)
                if not nl then
                    break
                end
                pos = nl + 1
                lineCount = lineCount + 1
            end
            script = string.sub(script, 1, nl - 1).."\n"..colorize((lines - maxLines).." More...", 0.7, 0.7, 0.7)
        end
        if lines > 0 then
            self:GetContentButton():ApplyTooltip("Script Preview", script)
        else
            self:GetContentButton():ApplyTooltip("Blank Script")
        end
        self:GetContentButton():OnClick(function()
            local TabFrame = PTSettingsGui.TabFrame
            local editor
            editor = PTGuiLib.Get("puppeteer_binding_script_editor", TabFrame)
                :SetPoint("CENTER", TabFrame, "CENTER")
                :SetBinding(binding)
                :SetCallback(function(save, scriptData, nameData)
                    if save then
                        binding.Data = scriptData
                        PTSettingsGui.UpdateUnsavedChanges()
                    end
                    editor:Dispose()

                    self:Update()
                end)
            PTSettingsGui.AddOverlayFrame(editor)
            editor:SetDisposeHandler(PTSettingsGui.PopOverlayFrame)

            editor:GetEditbox():SetFocus()
        end, true)
    elseif binding.Type == "MULTI" then
        self:SetEnabledContent("button")
        self:GetTypeDropdown():SetText("Multi")
        local count = (binding.Data and binding.Data.Bindings and table.getn(binding.Data.Bindings)) or 0
        self:GetContentButton():SetText("Edit Bindings ("..count..")")
        local tooltip = {}
        for i = 1, count do
            local subBinding = binding.Data.Bindings[i]
            tooltip[i] = subBinding.Type
            if subBinding.Type ~= "SCRIPT" and subBinding.Type ~= "MULTI" and subBinding.Data then
                tooltip[i] = tooltip[i].." - "..subBinding.Data
            end
        end
        self:GetContentButton():ApplyTooltip("Contents", tooltip)
        self:GetContentButton():OnClick(function()
            local TabFrame = PTSettingsGui.TabFrame
            local editor = PTGuiLib.Get("puppeteer_multi_editor", TabFrame)
                :SetPoint("CENTER", TabFrame, "CENTER")
            editor:SetBinding(binding)
            PTSettingsGui.AddOverlayFrame(editor)
            editor:SetDisposeHandler(function()
                PTSettingsGui.PopOverlayFrame()
                PTSettingsGui.UpdateUnsavedChanges()
                self:Update()
            end)
        end, true)
    end
end

PTGuiLib.RegisterComponent(PTSpellLine)