PTMultiEditor = PTGuiComponent:Extend("puppeteer_multi_editor")

function PTMultiEditor:New()
    local obj = setmetatable({}, self)
    local frame = CreateFrame("Frame", self:GenerateName())
    obj:SetHandle(frame)
    obj:SetSimpleBackground(PTGuiComponent.BACKGROUND_DIALOG)

    local title = PTGuiLib.Get("title", frame)
        :SetSize(192, 36)
        :SetPoint("CENTER", frame, "TOP")
        :SetText("Edit Multi Binding")
    obj:AddComponent("title", title)

    local interface = PTGuiLib.Get("puppeteer_spell_bind_interface", frame)
        :SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -75)
        :SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 60)
        :SetLeftLabel("Controls")
    obj:AddComponent("BindInterface", interface)

    local margin = 120
    local yPos = -30

    local titleTooltip = {"The title of the Multi-menu, leave blank for no title", 
        "If there's no custom tooltip text set, this title will be", "used in the spells tooltip"}
    local titleLabel = PTGuiLib.GetText(frame, "Menu Title")
        :SetPoint("RIGHT", frame, "TOPLEFT", margin, yPos)
        :ApplyTooltip(titleTooltip)
    local titleEditbox = PTGuiLib.Get("editbox", frame)
        :SetPoint("LEFT", titleLabel, "RIGHT", 5, 0)
        :SetSize(140, 20)
        :ApplyTooltip(titleTooltip)
        :SetScript("OnTextChanged", function(self)
            obj.Binding.Data.Title = self:GetText() ~= "" and self:GetText() or nil
        end)
    obj:AddComponent("TitleEditbox", titleEditbox)

    yPos = yPos - 25

    local titleColorTooltip = "Use a custom color for the title"
    local titleColorLabel = PTGuiLib.GetText(frame, "Title Color")
        :SetPoint("RIGHT", frame, "TOPLEFT", margin, yPos)
        :ApplyTooltip(titleColorTooltip)
    local titleColorCheckbox = PTGuiLib.Get("checkbox", frame)
        :SetPoint("LEFT", titleColorLabel, "RIGHT", 5, 0)
        :SetSize(20, 20)
        :ApplyTooltip(titleColorTooltip)
        :OnClick(function(self)
            if self:GetChecked() then
                local color = Puppeteer.BindTypeTooltipColors[obj.Binding.Type]
                obj:GetTitleColorSelect():SetColorRGB(color[1], color[2], color[3])
                obj.Binding.Data.TitleColor = {color[1], color[2], color[3]}
            else
                obj.Binding.Data.TitleColor = nil
            end
            obj:UpdateTitleTextColor()
        end)
    obj:AddComponent("TitleColorCheckbox", titleColorCheckbox)
    local titleColorSelect = PTGuiLib.Get("color_select", frame)
        :SetPoint("LEFT", titleColorCheckbox, "RIGHT", 5, 0)
        :SetSize(30, 20)
        :SetColorSelectHandler(function(self)
            obj.Binding.Data.TitleColor = self:GetColor()
        end)
    obj:AddComponent("TitleColorSelect", titleColorSelect)




    local multiKeepOpenTooltip = {"If enabled, the Multi-menu will stay open after clicking a binding",
        "It will still close if a different menu is triggered"}
    local multiKeepOpenLabel = PTGuiLib.GetText(frame, "Keep Open")
        :SetPoint("LEFT", titleEditbox, "RIGHT", 30, 0)
        :ApplyTooltip(multiKeepOpenTooltip)
    local multiKeepOpenCheckbox = PTGuiLib.Get("checkbox", frame)
        :SetPoint("LEFT", multiKeepOpenLabel, "RIGHT", 5, 0)
        :SetSize(20, 20)
        :ApplyTooltip(multiKeepOpenTooltip)
        :OnClick(function(self)
            if self:GetChecked() then
                obj.Binding.Data.KeepOpen = true
            else
                obj.Binding.Data.KeepOpen = nil
            end
        end)
    obj:AddComponent("KeepOpenCheckbox", multiKeepOpenCheckbox)
    

    local done = PTGuiLib.Get("button", frame)
        :SetPoint("BOTTOM", frame, "BOTTOM", 0, 5)
        :SetSize(200, 20)
        :SetText("Done")
        :OnClick(function()
            obj:Dispose()
        end)

    local add = PTGuiLib.Get("button", frame)
        :SetPoint("BOTTOM", done, "TOP", 0, 5)
        :SetSize(200, 20)
        :SetText("Add Binding")
        :OnClick(function()
            if table.getn(interface.Bindings) >= 20 then
                Puppeteer.Info("Cannot add any more bindings!")
                return
            end
            local binding = {}
            table.insert(interface.Bindings, binding)
            local line = interface:AddSpellLine()
            line:SetMode(PTSpellLine.MODE_ORDERED)
            line:SetBinding(binding)
            interface:UpdateLinePositions()
        end)
    return obj
end

function PTMultiEditor:OnAcquire()
    self.super.OnAcquire(self)
    self:SetSize(425, 360)
    self:GetBindInterface():GetScrollFrame():FixNextUpdate()
end

function PTMultiEditor:OnDispose()
    self.super.OnDispose(self)
    self:GetBindInterface():ClearSpellLines()
end

PTMultiEditor:CreateGetter("BindInterface")
PTMultiEditor:CreateGetter("TitleEditbox")
PTMultiEditor:CreateGetter("TitleColorCheckbox")
PTMultiEditor:CreateGetter("TitleColorSelect")
PTMultiEditor:CreateGetter("KeepOpenCheckbox")

PTMultiEditor.UpdateTitleTextColor = PTGuiUtil.CreateColorUpdater(
    PTMultiEditor.GetTitleColorCheckbox,
    PTMultiEditor.GetTitleColorSelect,
    function(self) return self.Binding.Data.TitleColor end)

function PTMultiEditor:SetBinding(multiBinding)
    self.Binding = multiBinding
    local interface = self:GetBindInterface()
    if not multiBinding.Data then
        multiBinding.Data = {Bindings = {}}
    end
    interface:SetBindings(multiBinding.Data.Bindings)
    for i, binding in ipairs(multiBinding.Data.Bindings) do
        local line = interface:AddSpellLine(i, "")
        line:SetMode(PTSpellLine.MODE_ORDERED)
        line:SetBinding(binding)
    end
    self:GetTitleEditbox():SetText(multiBinding.Data.Title or "")
    self:UpdateTitleTextColor()
    self:GetKeepOpenCheckbox():SetChecked(multiBinding.Data.KeepOpen)
end

PTGuiLib.RegisterComponent(PTMultiEditor)