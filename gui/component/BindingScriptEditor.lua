PTBindingScriptEditor = PTGuiComponent:Extend("puppeteer_binding_script_editor")
local colorize = PTUtil.Colorize

function PTBindingScriptEditor:New()
    local obj = setmetatable({}, self)
    local frame = CreateFrame("Frame", self:GenerateName())
    obj:SetHandle(frame)
    obj:SetSimpleBackground(PTGuiComponent.BACKGROUND_DIALOG)
    local title = PTGuiLib.Get("title", frame)
        :SetSize(192, 36)
        :SetPoint("CENTER", frame, "TOP")
        :SetText("Edit Binding Script")
    obj:AddComponent("Title", title)
    local editbox = PTGuiLib.Get("multi_line_editbox", frame)
        :SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -155)
        :SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 30)
        :SetScript("OnTabPressed", function(self)
            self:GetHandle():Insert("  ")
        end)
    editbox:GetScrollFrame():SetSimpleBackground()
    obj:AddComponent("Editbox", editbox)

    local margin = 130
    local yPos = -30

    local customTextTooltip = "The text shown in the spells tooltip for this binding"
    local name = PTGuiLib.GetText(frame, "Custom Tooltip Text")
        :SetPoint("RIGHT", frame, "TOPLEFT", margin, yPos)
        :ApplyTooltip(customTextTooltip)
    local nameEditbox = PTGuiLib.Get("editbox", frame)
        :SetPoint("LEFT", name, "RIGHT", 5, 0)
        :SetSize(150, 20)
        :ApplyTooltip(customTextTooltip)
        :SetScript("OnTextChanged", function(self)
            if not obj.Binding then
                return
            end
            obj.Binding.Tooltip.Data = self:GetText() ~= "" and self:GetText() or nil
            obj.Binding.Tooltip.Type = obj.Binding.Tooltip.Data and "CUSTOM" or "DEFAULT"
        end)
    obj:AddComponent("TooltipTextEditbox", nameEditbox)

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

    yPos = yPos - 25

    local predefined = PTGuiLib.GetText(frame, "Predefined local variables (hover for more info):")
        :SetPoint("TOPLEFT", frame, "TOPLEFT", 5, yPos)
        :SetJustifyH("LEFT")
    
    local local1 = PTGuiLib.GetText(frame, "local unit")
        :SetTextColor(0.4, 1, 0.4)
        :SetPoint("TOPLEFT", predefined, "BOTTOMLEFT", 0, 0)
        :SetJustifyH("LEFT")
        :ApplyTooltip("The unit being clicked", "This will be resolved to a GUID if clicking on a focus")
    local local2 = PTGuiLib.GetText(frame, "local unresolvedUnit")
        :SetTextColor(0.4, 1, 0.4)
        :SetPoint("TOPLEFT", local1, "BOTTOMLEFT")
        :SetJustifyH("LEFT")
        :ApplyTooltip("The unresolved unit being clicked", 
            "If a focus is being clicked, this will be a phony", "unit, such as 'focus1'")
    local local3 = PTGuiLib.GetText(frame, "local unitData")
        :SetTextColor(0.4, 1, 0.4)
        :SetPoint("TOPLEFT", local2, "BOTTOMLEFT")
        :SetJustifyH("LEFT")
        :ApplyTooltip("Cache stored by Puppeteer about the unit", 
            "Some useful APIs:",
            "unitData:HasBuff(buffName) -- Returns true if the unit has buffName",
            "unitData:HasDebuff(debuffName) -- Returns true if the unit has debuffName",
            "unitData:HasDebuffType(typeName) -- Returns true if the unit has the debuff type(such as \"Magic\")",
            "unitData:GetAuraTimeRemaining(auraName) -- Returns the time remaining on an aura, or nil if unknown(SuperWoW required)")
    local local4 = PTGuiLib.GetText(frame, "local unitFrame")
        :SetTextColor(0.4, 1, 0.4)
        :SetPoint("TOPLEFT", local3, "BOTTOMLEFT")
        :SetJustifyH("LEFT")
        :ApplyTooltip("The PTUnitFrame instance that was clicked")

    local saveButton = PTGuiLib.Get("button", frame)
        :SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)
        :SetSize(150, 20)
        :SetText("Save")
        :OnClick(function()
            obj.Callback(true, editbox:GetText(), nameEditbox:GetText())
        end, true)
    local cancelButton = PTGuiLib.Get("button", frame)
        :SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 5, 5)
        :SetSize(150, 20)
        :SetText("Cancel")
        :OnClick(function()
            obj.Callback(false)
        end, true)
    return obj
end

function PTBindingScriptEditor:OnAcquire()
    self.super.OnAcquire(self)
    self:GetEditbox():SetText("")
    self:GetEditbox():GetScrollFrame():FixNextUpdate()
    self:SetSize(375, 400)
end

function PTBindingScriptEditor:OnDispose()
    self.super.OnDispose(self)
end

PTBindingScriptEditor:CreateGetter("Editbox")
PTBindingScriptEditor:CreateGetter("TooltipTextEditbox")
PTBindingScriptEditor:CreateGetter("TooltipColorCheckbox")
PTBindingScriptEditor:CreateGetter("TooltipColorSelect")

PTBindingScriptEditor.UpdateTooltipTextColor = PTGuiUtil.CreateColorUpdater(
    PTBindingScriptEditor.GetTooltipColorCheckbox,
    PTBindingScriptEditor.GetTooltipColorSelect,
    function(self) return self.Binding and self.Binding.Tooltip.TextColor end)

function PTBindingScriptEditor:SetCallback(func)
    self.Callback = func
    return self
end

function PTBindingScriptEditor:SetBinding(binding)
    self.Binding = binding
    if not binding.Tooltip then
        binding.Tooltip = {}
    end
    self:GetEditbox():SetText(binding.Data or "")
    self:UpdateTooltipTextColor()
    self:GetTooltipTextEditbox():SetText(binding.Tooltip.Type == "CUSTOM" and binding.Tooltip.Data or "")
    return self
end

PTGuiLib.RegisterComponent(PTBindingScriptEditor)