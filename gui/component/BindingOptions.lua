PTBindingOptions = PTGuiComponent:Extend("puppeteer_binding_options")

function PTBindingOptions:New()
    local obj = setmetatable({}, self)
    local frame = CreateFrame("Frame", self:GenerateName())
    obj:SetHandle(frame)
    obj:SetSimpleBackground(PTGuiComponent.BACKGROUND_DIALOG)

    local title = PTGuiLib.Get("title", frame)
        :SetSize(192, 36)
        :SetPoint("CENTER", frame, "TOP")
        :SetText("Binding Options")
    obj:AddComponent("title", title)


    local margin = 150
    local yPos = -40

    local tooltipTypeTooltip = "What type of text to show in the tooltip"
    local tooltipTypeLabel = PTGuiLib.GetText(frame, "Tooltip Text")
        :SetPoint("RIGHT", frame, "TOPLEFT", margin, yPos)
        :ApplyTooltip(tooltipTypeTooltip)
    local tooltipTypeDropdown = PTGuiLib.Get("dropdown", frame)
        :SetPoint("LEFT", tooltipTypeLabel, "RIGHT", 5, 0)
        :SetWidth(120)
        :ApplyTooltip(tooltipTypeTooltip)
    obj:AddComponent("TooltipTypeDropdown", tooltipTypeDropdown)
    local initFunc = function(self, gui)
        self.checked = self.text == gui:GetText()
    end
    local func = function(self)
        obj.Binding.Tooltip.Type = self.type
        obj.Binding.Tooltip.Data = nil
        obj:UpdateTooltipType()
    end
    tooltipTypeDropdown:SetOptions({
        {
            text = "Default",
            type = "DEFAULT",
            initFunc = initFunc,
            func = func
        },
        {
            text = "Custom Text",
            type = "CUSTOM",
            initFunc = initFunc,
            func = func
        }
    })

    yPos = yPos - 30

    local tooltipCustomTextTooltip = "The text shown in the tooltip"
    local tooltipTextLabel = PTGuiLib.GetText(frame, "Custom Text")
        :SetPoint("RIGHT", frame, "TOPLEFT", margin, yPos)
        :ApplyTooltip(tooltipCustomTextTooltip)
    obj:AddComponent("TooltipTextLabel", tooltipTextLabel)
    local tooltipTextEditbox = PTGuiLib.Get("editbox", frame)
        :SetPoint("LEFT", tooltipTextLabel, "RIGHT", 5, 0)
        :SetSize(150, 20)
        :ApplyTooltip(tooltipCustomTextTooltip)
        :SetScript("OnTextChanged", function(self)
            if not obj.Binding then
                return
            end
            obj.Binding.Tooltip.Data = self:GetText() ~= "" and self:GetText() or nil
        end)
    obj:AddComponent("TooltipTextEditbox", tooltipTextEditbox)

    yPos = yPos - 30

    local textColorTooltip = "Use a custom color for this binding in the tooltip"
    local tooltipColorLabel = PTGuiLib.GetText(frame, "Custom Text Color")
        :SetPoint("RIGHT", frame, "TOPLEFT", margin, yPos)
        :ApplyTooltip(textColorTooltip)
    local tooltipColorCheckbox = PTGuiLib.Get("checkbox", frame)
        :SetPoint("LEFT", tooltipColorLabel, "RIGHT", 5, 0)
        :SetSize(20, 20)
        :ApplyTooltip(textColorTooltip)
        :OnClick(function(self)
            if self:GetChecked() then
                local color = Puppeteer.BindTypeTooltipColors[obj.Binding.Type]
                obj:GetTooltipColorSelect():SetColorRGB(color[1], color[2], color[3])
                obj.Binding.Tooltip.TextColor = {color[1], color[2], color[3]}
            else
                obj.Binding.Tooltip.TextColor = nil
            end
            obj:UpdateTooltipTextColor()
        end)
    obj:AddComponent("TooltipColorCheckbox", tooltipColorCheckbox)

    local colorSelect = PTGuiLib.Get("color_select", frame)
        :SetPoint("LEFT", tooltipColorCheckbox, "RIGHT", 5, 0)
        :SetSize(30, 20)
        :SetColorSelectHandler(function(colorSelect)
            local r, g, b = colorSelect:GetColorRGB()
            obj.Binding.Tooltip.TextColor = {r, g, b}
        end)
    obj:AddComponent("TooltipColorSelect", colorSelect)

    yPos = yPos - 30

    local targetWhileCastingTooltip = {"Target the unit while this binding runs", 
            "Note that these binding types override this rule:",
            "Spell - Always targets unless using SuperWoW",
            "Action - Never targets unless specified by action",
            "Item - Always targets",
            "Multi - Never targets"}
    local targetWhileCastingLabel = PTGuiLib.GetText(frame, "Target While Casting")
        :SetPoint("RIGHT", frame, "TOPLEFT", margin, yPos)
        :ApplyTooltip(targetWhileCastingTooltip)
    local targetWhileCastingDropdown = PTGuiLib.Get("dropdown", frame)
        :SetPoint("LEFT", targetWhileCastingLabel, "RIGHT", 5, 0)
        :SetWidth(120)
        :ApplyTooltip(targetWhileCastingTooltip)
    obj:AddComponent("TargetWhileCastingDropdown", targetWhileCastingDropdown)

    yPos = yPos - 30

    local targetAfterCastingTooltip = "Target the unit after this binding runs"
    local targetAfterCastingLabel = PTGuiLib.GetText(frame, "Target After Casting")
        :SetPoint("RIGHT", frame, "TOPLEFT", margin, yPos)
        :ApplyTooltip(targetAfterCastingTooltip)
    local targetAfterCastingDropdown = PTGuiLib.Get("dropdown", frame)
        :SetPoint("LEFT", targetAfterCastingLabel, "RIGHT", 5, 0)
        :SetWidth(120)
        :ApplyTooltip(targetAfterCastingTooltip)
    obj:AddComponent("TargetAfterCastingDropdown", targetAfterCastingDropdown)

    local copy = PTGuiLib.Get("button", frame)
        :SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 30, 40)
        :SetSize(120, 20)
        :SetText("Copy")
        :ApplyTooltip("Copy this binding in its current state to the clipboard")
        :OnClick(function()
            Puppeteer.SetBindingClipboard(obj.Binding)
            obj:GetPasteButton():SetEnabled(true)
            PlaySound("igSpellBookOpen")
        end)
    self:AddComponent("CopyButton", copy)
    local paste = PTGuiLib.Get("button", frame)
        :SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 40)
        :SetSize(120, 20)
        :SetText("Paste")
        :ApplyTooltip("Overwrite this binding with your clipboard")
        :SetEnabled(false)
        :OnClick(function()
            local binding = obj.Binding
            PTUtil.ClearTable(binding)
            for k, v in pairs(Puppeteer.GetBindingClipboard()) do
                binding[k] = v
            end
            PlaySound("igSpellBookClose")
            obj:Dispose()
        end)
    obj:AddComponent("PasteButton", paste)

    local done = PTGuiLib.Get("button", frame)
        :SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 5, 5)
        :SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)
        :SetHeight(20)
        :SetText("Done")
        :OnClick(function()
            Puppeteer.PruneBinding(obj.Binding)
            obj:Dispose()
        end)
    return obj
end

function PTBindingOptions:OnAcquire()
    self.super.OnAcquire(self)
    self:SetSize(350, 300)
    local populateDropdown = function(dropdown, settingName)
        local initFunc = function(option)
            option.checked = self.Binding[settingName] == option.setting
        end
        local func = function(option, gui)
            gui:SetText(option.text)
            self.Binding[settingName] = option.setting
        end
        dropdown:SetTextUpdater(function(gui)
            gui:SetTextBy("setting", self.Binding[settingName])
        end, true)
        dropdown:SetOptions({
            {
                text = "Use Default ("..(PTOptions[settingName] and "Yes" or "No")..")",
                setting = nil,
                initFunc = initFunc,
                func = func
            },
            {
                text = "Yes",
                setting = true,
                initFunc = initFunc,
                func = func
            },
            {
                text = "No",
                setting = false,
                initFunc = initFunc,
                func = func
            }
        })
    end
    populateDropdown(self:GetTargetWhileCastingDropdown(), "TargetWhileCasting")
    populateDropdown(self:GetTargetAfterCastingDropdown(), "TargetAfterCasting")

    self:GetPasteButton():SetEnabled(Puppeteer.HasBindingClipboard())
end

function PTBindingOptions:OnDispose()
    self.super.OnDispose(self)
    self.Binding = nil
end

PTBindingOptions:CreateGetter("TooltipTypeDropdown")
PTBindingOptions:CreateGetter("TooltipTextLabel")
PTBindingOptions:CreateGetter("TooltipTextEditbox")
PTBindingOptions:CreateGetter("TooltipColorCheckbox")
PTBindingOptions:CreateGetter("TooltipColorSelect")
PTBindingOptions:CreateGetter("TargetWhileCastingDropdown")
PTBindingOptions:CreateGetter("TargetAfterCastingDropdown")
PTBindingOptions:CreateGetter("CopyButton")
PTBindingOptions:CreateGetter("PasteButton")

function PTBindingOptions:UpdateTooltipType()
    local type = self.Binding and self.Binding.Tooltip.Type or "DEFAULT"
    if type == "DEFAULT" then
        self:GetTooltipTextLabel():Hide()
        self:GetTooltipTextEditbox():Hide()
    elseif type == "CUSTOM" then
        self:GetTooltipTextLabel():Show()
        self:GetTooltipTextEditbox():Show()
        self:GetTooltipTextEditbox():SetText(self.Binding.Tooltip.Data or "")
    end
    self:GetTooltipTypeDropdown():SetTextBy("type", type)
end

PTBindingOptions.UpdateTooltipTextColor = PTGuiUtil.CreateColorUpdater(
    PTBindingOptions.GetTooltipColorCheckbox,
    PTBindingOptions.GetTooltipColorSelect,
    function(self) return self.Binding and self.Binding.Tooltip.TextColor end)

function PTBindingOptions:SetBinding(binding)
    self.Binding = binding
    if not binding.Tooltip then
        binding.Tooltip = {}
    end
    self:GetTargetWhileCastingDropdown():UpdateText()
    self:GetTargetAfterCastingDropdown():UpdateText()
    self:UpdateTooltipType()
    self:UpdateTooltipTextColor()
end

PTGuiLib.RegisterComponent(PTBindingOptions)