PTSettingsGui = {}
PTUtil.SetEnvironment(PTSettingsGui, PuppeteerSettings)
local util = PTUtil
local colorize = util.Colorize
local compost = AceLibrary("Compost-2.0")
local GetOption = PuppeteerSettings.GetOption
local SetOption = PuppeteerSettings.SetOption

TabFrame = PTGuiLib.Get("tab_frame"):Hide()

function Init()
    TabFrame:SetPoint("CENTER")
        :SetSize(425, 475)
        :SetSimpleBackground(PTGuiComponent.BACKGROUND_DIALOG)
        :SetSpecial()
    
    local origHide = TabFrame:GetHandle().Hide
    TabFrame:GetHandle().Hide = function(self)
        origHide(self)
        if EditedBindings then
            if Puppeteer.GetNumLoadoutChanges(Puppeteer.GetBindings(), EditedBindings) > 0 then
                Puppeteer.Info("You have unsaved changes to your bindings")
            end
        end
    end

    if PTOptions.Debug2 then
        TabFrame:Show()
    end

    local title = PTGuiLib.Get("title", TabFrame)
    title:SetPoint("TOP", TabFrame, "TOP", 0, 22)
    title:SetHeight(38)
    title:SetWidth(170)
    title:SetText("Puppeteer Settings")

    local closeButton = CreateFrame("Button", nil, TabFrame:GetHandle(), "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", TabFrame:GetHandle(), "TOPRIGHT", 0, 0)
    closeButton:SetScript("OnClick", function() TabFrame:Hide() end)

    CreateTab_Bindings()
    CreateTab_Options()
    CreateTab_Customize()
    CreateTab_About()
end

OverlayStack = {}
OverlayBlockInputs = {}
function AddOverlayFrame(overlayFrame)
    table.insert(OverlayStack, overlayFrame)
    local block = PTGuiLib.Get("puppeteer_input_block", TabFrame)
    block:SetScript("OnMouseDown", TabFrame:GetScript("OnMouseDown"), true)
    block:SetScript("OnMouseUp", TabFrame:GetScript("OnMouseUp"), true)
    table.insert(OverlayBlockInputs, block)
    block:SetFrameLevel(overlayFrame:GetFrameLevel() + (table.getn(OverlayStack) * 200) - 100)
    overlayFrame:SetFrameLevel(overlayFrame:GetFrameLevel() + (table.getn(OverlayStack) * 200))
    PTUtil.FixFrameLevels(overlayFrame:GetHandle())
end

function PopOverlayFrame()
    local index = table.getn(OverlayStack)
    table.remove(OverlayStack, index)
    local block = table.remove(OverlayBlockInputs, index)
    block:Dispose()
end

EditedBindings = {}
BindingsContext = {Target = "Friendly", Modifier = "None"}
function CreateTab_Bindings()
    local container = TabFrame:CreateTab("Bindings")

    local selectLoadoutLabel = CreateLabel(container, "Select Loadout")
        :SetPoint("TOPLEFT", container, "TOPLEFT", 30, -40)
    local selectLoadoutDropdown = CreateDropdown(container, 130)
        :SetPoint("LEFT", selectLoadoutLabel, "RIGHT", 5, 0)
        :SetDynamicOptions(function(addOption, level, args)
            for _, name in ipairs(Puppeteer.GetBindingLoadoutNames()) do
                addOption("text", name,
                    "checked", Puppeteer.GetSelectedBindingsLoadoutName() == name,
                    "func", args.func)
            end
        end, {
            func = function(self)
                local loadoutName = self.text
                if Puppeteer.LoadoutEquals(Puppeteer.GetBindings(), EditedBindings) then
                    Puppeteer.SetSelectedBindingsLoadout(loadoutName)
                else
                    local dialog
                    dialog = PTGuiLib.Get("simple_dialog", TabFrame)
                        :SetPoint("CENTER", TabFrame, "CENTER")
                        :SetTitle("Unsaved Changes")
                        :SetText("You have unsaved changes to your bindings. What would you like to do?")
                        :AddButton("Save changes & switch", function()
                            SaveBindings()
                            Puppeteer.SetSelectedBindingsLoadout(loadoutName)
                            PopOverlayFrame()
                            dialog:Dispose()
                        end)
                        :AddButton("Discard changes & switch", function()
                            Puppeteer.SetSelectedBindingsLoadout(loadoutName)
                            PopOverlayFrame()
                            dialog:Dispose()
                        end)
                        :AddButton("Carry changes over", function()
                            local editedBindings = EditedBindings
                            Puppeteer.SetSelectedBindingsLoadout(loadoutName)
                            EditedBindings = editedBindings
                            UpdateBindingsInterface()
                            UpdateUnsavedChanges()
                            PopOverlayFrame()
                            dialog:Dispose()
                        end)
                        :AddButton("Cancel", function()
                            PopOverlayFrame()
                            dialog:Dispose()
                        end)
                    AddOverlayFrame(dialog)
                    PlaySound("igMainMenuOpen")
                end
            end
        })
        :SetTextUpdater(function(self)
            self:SetText(Puppeteer.GetSelectedBindingsLoadoutName())
        end)
    LoadoutsDropdown = selectLoadoutDropdown
    local newLoadout = PTGuiLib.Get("button", container)
        :SetPoint("LEFT", selectLoadoutDropdown, "RIGHT", 5, 0)
        :SetSize(60, 22)
        :SetText("New")
        :OnClick(function(self)
            if util.GetTableSize(Puppeteer.GetBindingLoadouts()) >= 20 then
                Puppeteer.Info("You cannot create any more loadouts!")
                return
            end

            if Puppeteer.LoadoutEquals(Puppeteer.GetBindings(), EditedBindings) then
                PromptNewLoadout()
            else
                local dialog
                dialog = PTGuiLib.Get("simple_dialog", TabFrame)
                    :SetPoint("CENTER", TabFrame, "CENTER")
                    :SetTitle("Unsaved Changes")
                    :SetText("You have unsaved changes to your bindings. What would you like to do?")
                    :AddButton("Save changes", function()
                        SaveBindings()
                        PopOverlayFrame()
                        dialog:Dispose()
                        PromptNewLoadout()
                    end)
                    :AddButton("Discard changes", function()
                        LoadBindings()
                        PopOverlayFrame()
                        dialog:Dispose()
                        PromptNewLoadout()
                    end)
                    :AddButton("Cancel", function()
                        PopOverlayFrame()
                        dialog:Dispose()
                    end)
                AddOverlayFrame(dialog)
                PlaySound("igMainMenuOpen")
            end
        end)
    local deleteLoadout = PTGuiLib.Get("button", container)
        :SetPoint("LEFT", newLoadout, "RIGHT", 5, 0)
        :SetSize(60, 22)
        :SetText("Delete")
        :OnClick(function()
            local loadouts = Puppeteer.GetBindingLoadouts()
            local currentLoadoutName = Puppeteer.GetSelectedBindingsLoadoutName()
            local anotherLoadoutName
            for k, v in pairs(loadouts) do
                if k ~= Puppeteer.GetSelectedBindingsLoadoutName() then
                    anotherLoadoutName = k
                    break
                end
            end
            if not anotherLoadoutName then
                Puppeteer.Info("Cannot delete the only loadout")
                return
            end
            local dialog = PTGuiLib.Get("simple_dialog", TabFrame)
                :SetPoint("CENTER", TabFrame, "CENTER", 0, 40)
            dialog:SetTitle("Confirm Delete")
            dialog:SetText("Are you sure you want to delete binding loadout '"..currentLoadoutName.."'?")
            dialog:AddButton("Yes, delete loadout", function()
                dialog:Dispose()
                PopOverlayFrame()
                Puppeteer.SetSelectedBindingsLoadout(anotherLoadoutName)
                loadouts[currentLoadoutName] = nil
            end)
            dialog:AddButton("No, keep loadout", function()
                dialog:Dispose()
                PopOverlayFrame()
            end)
            dialog:PlayOpenSound()
            AddOverlayFrame(dialog)
        end)

    local bindingsForLabel = CreateLabel(container, "Bindings For")
        :SetPoint("TOPLEFT", container, "TOPLEFT", 40, -95)

    local bindingsForDropdown = CreateDropdown(container, 100)
        :SetPoint("LEFT", bindingsForLabel, "RIGHT", 5, 0)
        :SetDynamicOptions(function(addOption, level, args)
            if not EditedBindings.UseFriendlyForHostile then
                for _, option in ipairs(args.options) do
                    addOption("text", option,
                        "dropdownText", option,
                        "initFunc", args.initFunc,
                        "func", args.func)
                end
            end
        end, {
            options = {"Friendly", "Hostile"},
            initFunc = function(self, gui)
                self.checked = self.text == gui:GetText()
            end,
            func = function(self)
                SetTargetContext(self.text)
                UpdateBindingsInterface()
            end
        })
        :SetTextUpdater(function(self)
            self:SetText(EditedBindings.UseFriendlyForHostile and "All Targets" or BindingsContext.Target)
        end)
    BindingsForDropdown = bindingsForDropdown

    local useSame = CreateLabel(container, "Universal Bindings")
        :SetPoint("LEFT", bindingsForDropdown, "RIGHT", 10, 0)
        :ApplyTooltip("Use the same bindings for both friendly and hostile targets")
    local universalBindingsCheckbox = CreateCheckbox(container, 20, 20)
        :SetPoint("LEFT", useSame, "RIGHT", 5, 0)
        :ApplyTooltip("Use the same bindings for both friendly and hostile targets")
        :OnClick(function(self)
            EditedBindings.UseFriendlyForHostile = self:GetChecked() == 1
            SetTargetContext("Friendly")
            UpdateBindingsInterface()
            UpdateUnsavedChanges()
        end)
    UniversalBindingsCheckbox = universalBindingsCheckbox

    local keyLabel = CreateLabel(container, "Key Modifier")
        :SetPoint("TOPLEFT", container, "TOPLEFT", 95, -125)
    
    local keyDropdown = CreateDropdown(container, 150)
        :SetPoint("LEFT", keyLabel, "RIGHT", 5, 0)
        :SetSimpleOptions(util.GetKeyModifiers(), function(modifier)
            return {
                text = modifier,
                initFunc = function(self, gui)
                    self.checked = self.text == gui:GetText()
                end,
                func = function(self, gui)
                    gui:SetText(self.text)
                    SetModifierContext(self.text)
                    UpdateBindingsInterface()
                end
            }
        end, "None")

    local interface = PTGuiLib.Get("puppeteer_spell_bind_interface", container)
        :SetPoint("TOPLEFT", container, "TOPLEFT", 5, -160)
        :SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -5, 80)

    SpellBindInterface = interface

    UnsavedChangesText = PTGuiLib.GetText(container, "", 12)
        :SetPoint("TOP", interface, "BOTTOM", 0, -3)
        --:SetTextColor(1, 0.2, 0.2)
    

    DiscardButton = PTGuiLib.Get("button", container)
        :SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 10, 35)
        :SetSize(125, 25)
        :SetText("Discard Changes")
        :OnClick(function()
            LoadBindings()
        end)
    SaveAndCloseButton = PTGuiLib.Get("button", container)
        :SetPoint("BOTTOM", container, "BOTTOM", 0, 35)
        :SetSize(125, 25)
        :SetText("Save & Close")
        :OnClick(function()
            SaveBindings()
            TabFrame:Hide()
        end)
    SaveButton = PTGuiLib.Get("button", container)
        :SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -10, 35)
        :SetSize(125, 25)
        :SetText("Save Changes")
        :OnClick(function()
            SaveBindings()
        end)

    local addButton = PTGuiLib.Get("button", container)
        :SetPoint("TOP", container, "TOP", 0, -445)
        :SetSize(200, 25)
        :SetText("Add or Remove Buttons")
        :ApplyTooltip("Edit what buttons you can bind spells to")
        :OnClick(function()
            local editor = PTGuiLib.Get("puppeteer_button_editor", TabFrame)
                :SetPoint("CENTER", TabFrame, "CENTER")
            AddOverlayFrame(editor)
        end)

    LoadBindings()
end

function PromptNewLoadout()
    local newLoadout = PTGuiLib.Get("puppeteer_new_loadout", TabFrame)
        :SetPoint("CENTER", TabFrame, "CENTER")
    AddOverlayFrame(newLoadout)
    PlaySound("igMainMenuOpen")
end

function SetTargetContext(friendlyOrHostile)
    BindingsContext.Target = friendlyOrHostile
    BindingsForDropdown:UpdateText()
end

function SetModifierContext(modifier)
    BindingsContext.Modifier = modifier

end

function SetBindingsContext(friendlyOrHostile, modifier)
    SetTargetContext(friendlyOrHostile)
    SetModifierContext(modifier)
end

function GetBindingsContext()
    local targetBindings = EditedBindings.Bindings[BindingsContext.Target]
    if not targetBindings then
        targetBindings = {}
        EditedBindings.Bindings[BindingsContext.Target] = targetBindings
    end
    local bindings = EditedBindings.Bindings[BindingsContext.Target][BindingsContext.Modifier]
    if not bindings then
        bindings = {}
        EditedBindings.Bindings[BindingsContext.Target][BindingsContext.Modifier] = bindings
    end
    return bindings
end

function UpdateBindingsInterface()
    local bindings = GetBindingsContext()
    for _, button in ipairs(PTOptions.Buttons) do
        if not bindings[button] then
            bindings[button] = {}
        end
    end
    SpellBindInterface:SetBindings(bindings)
end

function ReloadBindingLines()
    SpellBindInterface:ClearSpellLines()
    for _, button in ipairs(PTOptions.Buttons) do
        SpellBindInterface:AddSpellLine(button, PTOptions.ButtonInfo[button].Name or button)
    end
end

function LoadBindings()
    ReloadBindingLines()
    LoadoutsDropdown:UpdateText()
    EditedBindings = util.CloneTable(Puppeteer.GetBindings(), true)
    UniversalBindingsCheckbox:SetChecked(EditedBindings.UseFriendlyForHostile)
    if EditedBindings.UseFriendlyForHostile then
        SetTargetContext("Friendly")
    end
    BindingsForDropdown:UpdateText()
    UpdateBindingsInterface()
    UpdateUnsavedChanges()
end

function SaveBindings()
    Puppeteer.GetBindingLoadouts()[Puppeteer.GetSelectedBindingsLoadoutName()] = Puppeteer.PruneLoadout(EditedBindings)
    LoadBindings()
end

function UpdateUnsavedChanges()
    local ok, changes = pcall(Puppeteer.GetNumLoadoutChanges, Puppeteer.GetBindings(), EditedBindings)
    if not ok then
        Puppeteer.print(changes)
        changes = "ERROR"
    end
    if changes == 0 then
        UnsavedChangesText:Hide()
        DiscardButton:SetEnabled(false)
        SaveAndCloseButton:SetEnabled(false)
        SaveButton:SetEnabled(false)
    else
        UnsavedChangesText:Show()
        UnsavedChangesText:SetText("You have "..changes.." unsaved change"..(changes ~= 1 and "s" or "").." to your bindings")
        DiscardButton:SetEnabled(true)
        SaveAndCloseButton:SetEnabled(true)
        SaveButton:SetEnabled(true)
    end
end

function CreateTab_Options()
    local container = TabFrame:CreateTab("Options")

    local tabPanel = PTGuiLib.Get("tab_panel", container)
    tabPanel:SetPoint("TOPLEFT", container, "TOPLEFT", 5, -28 - 50)
    tabPanel:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -5, 5)
    tabPanel:SetSimpleBackground()
    container.TabPanel = tabPanel

    CreateTab_Options_Casting(tabPanel)
    CreateTab_Options_SpellsTooltip(tabPanel)
    CreateTab_Options_Other(tabPanel)
    CreateTab_Options_Advanced(tabPanel)
    CreateTab_Options_Mods(tabPanel)
end

function CreateTab_Options_Casting(panel)
    local container = panel:CreateTab("Casting")
    local layout = NewLabeledColumnLayout(container, {150, 310}, -20, 10)
    local factory = NewComponentFactory(container, layout)
    container.factory = factory

    factory:dropdown("Cast When (Mouse)", "What mouse button state to start casting spells at", "CastWhen", {"Mouse Up", "Mouse Down"}, function()
        for _, ui in ipairs(Puppeteer.AllUnitFrames) do
            ui:RegisterClicks()
        end
    end)
    factory:dropdown("Cast When (Keys)", "What key state to start casting spells at", "CastWhenKey", {"Key Up", "Key Down"})
    local resSpell = util.ResurrectionSpells[util.GetClass("player")]
    local autoResInfo = not resSpell and "This does nothing for your class" or {"Replaces your bound spells with "..resSpell..
        " when clicking on a dead ally", "All other types of binds, such as Actions, will not be replaced"}
    factory:checkbox("Auto Resurrect", autoResInfo, "AutoResurrect")
    factory:checkbox("PVP Flag Protection", {"Stops you from casting spells on PVP flagged players if you're not flagged",
        "Attempting to cast will prompt you to make an exception",
        "Only stops you from using Spell bindings"}, "PVPFlagProtection")
    factory:checkbox("Target While Casting", {"Target the unit while most bindings run",
        "Note that these binding types override this rule:",
        "Spell - Always targets unless using SuperWoW",
        "Action - Never targets unless specified by action",
        "Item - Always targets",
        "Multi - Never targets"}, "TargetWhileCasting")
    factory:checkbox("Target After Casting", {"Target the unit after most bindings run",
        "Note that these binding types override this rule:",
        "Multi - Never targets"}, "TargetAfterCasting")
end

function CreateTab_Options_SpellsTooltip(panel)
    local container = panel:CreateTab("Spells Tooltip")
    local layout = NewLabeledColumnLayout(container, {150, 310}, -20, 10)
    local factory = NewComponentFactory(container, layout)
    container.factory = factory
    factory:checkbox("Enable Spells Tooltip", {"Show the spells tooltip when hovering over unit frames"}, "SpellsTooltip.Enabled")
    factory:checkbox("Show % Mana Cost", {"Show the percent mana cost in the spells tooltip", 
        "Does nothing for non-mana users"}, "SpellsTooltip.ShowManaPercentCost")
    layout:column(2):levelAt(1)
    factory:checkbox("Show # Mana Cost", {"Show the number mana cost in the spells tooltip", 
        "Does nothing for non-mana users"}, "SpellsTooltip.ShowManaCost")
    layout:column(1)
    factory:slider("Hide Casts Above", "Hide cast count if above this threshold", "SpellsTooltip.HideCastsAbove", 0, 50)
    factory:slider("Critical Casts Level", "Show yellow text at this threshold", "SpellsTooltip.CriticalCastsLevel", 0, 50)
    factory:checkbox("Shortened Keys", "Shortens keys to 1 letter", "SpellsTooltip.AbbreviatedKeys")
    layout:column(2):levelAt(1)
    factory:checkbox("Colored Keys", "Color code the keys as opposed to all being white", "SpellsTooltip.ColoredKeys")
    layout:column(1)
    factory:checkbox("Show Power Bar", "Show a power bar in the spells tooltip", "SpellsTooltip.ShowPowerBar", function()
        if PTOptions.SpellsTooltip.ShowPowerBar then
            Puppeteer.SpellsTooltipPowerBar:Show()
        else
            Puppeteer.SpellsTooltipPowerBar:Hide()
        end
    end)
    factory:dropdown("Show Power As", "What type of information to show for power amounts", "SpellsTooltip.ShowPowerAs", 
        {"Power", "Power/Max Power", "Power %"})
    factory:dropdown("Attach To", "What the tooltip should be attached to", "SpellsTooltip.AttachTo", 
        {"Button", "Frame", "Group", "Screen"})
    layout:offset(0, 10)
    factory:dropdown("Anchor", "Where the tooltip should be anchored", "SpellsTooltip.Anchor", 
        {"Top Left", "Top Right", "Bottom Left", "Bottom Right"})
    factory:checkbox("Show Item Count", {"Show the amount of your bound items", colorize("Warning: This causes lag!", 1, 0.4, 0.4)}, 
        "SpellsTooltip.ShowItemCount")
end

function CreateTab_Options_Other(panel)
    local container = panel:CreateTab("Other")
    local layout = NewLabeledColumnLayout(container, {150, 220, 300}, -20, 10)
    local factory = NewComponentFactory(container, layout)
    container.factory = factory
    factory:checkbox("Always Show Target", "Always show the target frame, regardless of whether you have a target or not",
        "AlwaysShowTargetFrame", function() Puppeteer.CheckTarget() end)
    layout:offset(0, 10)
    factory:label("Show Targets:")
    layout:column(2):levelAt(1)
    factory:checkbox("Friendly", {"Show the Target frame when targeting friendlies", "No effect if Always Show Target is checked"},
        "ShowTargets.Friendly", function() Puppeteer.CheckTarget() end)
    layout:column(3):levelAt(2)
    factory:checkbox("Hostile", {"Show the Target frame when targeting hostiles", "No effect if Always Show Target is checked"},
        "ShowTargets.Hostile", function() Puppeteer.CheckTarget() end)
    layout:column(1)
    factory:label("Hide Party Frames:")
    layout:column(2):levelAt(1)
    factory:checkbox("In Party", {"Hide default party frames while in party", "This may cause issues with other addons"},
        "DisablePartyFrames.InParty", function() Puppeteer.CheckPartyFramesEnabled() end)
    layout:column(3):levelAt(2)
    factory:checkbox("In Raid", {"Hide default party frames while in raid", "This may cause issues with other addons"},
        "DisablePartyFrames.InRaid", function() Puppeteer.CheckPartyFramesEnabled() end)
    layout:column(1)
    factory:checkbox("Hide While Solo", "If enabled, all Puppeteer frames will be hidden when not in a party or raid", 
        "HideWhileSolo", function() Puppeteer.CheckGroup() end)
    local dragAllCheckbox = factory:checkbox("Drag All Frames", {"If enabled, all frames will be moved when dragging", 
        "Use the inverse key to move a single frame; Opposite effect if disabled"}, "FrameDrag.MoveAll")
    layout:ignoreNext()
    local inverseDropdown = factory:dropdown("Inverse Key", {"This key will be used to do the opposite of the default drag operation"}, 
        "FrameDrag.AltMoveKey", {"Shift", "Control", "Alt"})
    inverseDropdown:SetWidth(80)
    inverseDropdown:SetPoint("LEFT", dragAllCheckbox, "RIGHT", 90, 0)
    factory:checkbox("Show Heal Predictions", {"See predictions on incoming healing", "Improved predictions if using SuperWoW"},
        "UseHealPredictions", function() Puppeteer.UpdateAllIncomingHealing() end)

    factory:checkbox("(TWoW) LFT Auto Role", {"Automatically assign roles when joining LFT groups", 
            "This functionality was tested for 1.18.0 and may break in future updates"}, "LFTAutoRole",
            function() Puppeteer.SetLFTAutoRoleEnabled(PTOptions.LFTAutoRole) end)
end

function CreateTab_Options_Advanced(panel)
    local container = panel:CreateTab("Advanced")
    local layout = NewLabeledColumnLayout(container, {150, 220, 300}, 0, 10)
    local factory = NewComponentFactory(container, layout)
    container.factory = factory

    local TEXT_WIDTH = 370

    local experimentsLabel = CreateLabel(container, "Experiments")
        :SetPoint("TOP", container, "TOP", 0, -20)
        :SetFontSize(14)
    local experimentsInfo = CreateLabel(container, "Features which are not complete and/or need more testing. Use at your own risk.")
        :SetWidth(TEXT_WIDTH)
        :SetPoint("TOP", experimentsLabel, "BOTTOM", 0, -5)
    layout:offset(0, -70)
    factory:checkbox("(TWoW)\nAuto Role", {"If enabled, the Role Action menu shows auto role detection options", "Enabled Account-Wide"}, 
        "Global.Experiments.AutoRole",
        Puppeteer.InitRoleDropdown)
    factory:checkbox("(SuperWoW & UnitXP)\nEnemy Frames", 
        {"If enabled, you will see an additional frame group with in-combat enemies", "Requires SuperWoW and UnitXP SP3", 
        "Enabled Per-Character"},
        "Experiments.Enemy",
        function()
            Puppeteer.SetEnemyTrackingEnabled(PuppeteerSettings.IsExperimentEnabled("Enemy"))
        end)
    factory:checkbox("(SuperWoW)\nCast Icons", {"If enabled, you will see incoming casts over unit frames", 
            "This feature is highly subject to changes", "Requires SuperWoW!", "Enabled Per-Character"},
        "Experiments.CastIcons",
        function()
            if PTHealPredict then
                PTHealPredict.RemoveAllCastIcons()
            end
        end)

    local scriptsLabel = CreateLabel(container, "Load & Postload Scripts")
        :SetPoint("TOP", container, "TOP", 0, -160)
        :SetFontSize(14)

    local loadScriptInfo = CreateLabel(container, "The Load Script runs after profiles are initialized, but before UIs are created, "..
            "making it good for editing profile attributes. GetProfile and CreateProfile are defined locals.")
        :SetWidth(TEXT_WIDTH)
        :SetPoint("TOP", scriptsLabel, "BOTTOM", 0, -10)
    local loadScriptButton = PTGuiLib.Get("button", container)
        :SetPoint("TOP", loadScriptInfo, "BOTTOM", 0, -5)
        :SetSize(150, 20)
        :SetText("Edit Load Script")
        :OnClick(function()
            local editor
            editor = PTGuiLib.Get("puppeteer_load_script_editor", TabFrame)
                :SetPoint("CENTER", TabFrame, "CENTER")
                :SetTitle("Edit Load Script")
            editor:GetEditbox():SetText(PTOptions.Scripts.OnLoad or "")
            editor:SetCallback(function(save, data)
                if save then
                    PTOptions.Scripts.OnLoad = data
                end
                editor:Dispose()
                PopOverlayFrame()
            end)
            editor:GetEditbox():SetFocus()
            AddOverlayFrame(editor)
        end)
    local postLoadScriptInfo = CreateLabel(container, "The Postload Script runs after everything is initialized. "..
        "GetProfile and CreateProfile are defined locals.")
        :SetWidth(TEXT_WIDTH)
        :SetPoint("TOP", loadScriptButton, "BOTTOM", 0, -10)
    local postLoadScriptButton = PTGuiLib.Get("button", container)
        :SetPoint("TOP", postLoadScriptInfo, "BOTTOM", 0, -5)
        :SetSize(150, 20)
        :SetText("Edit Postload Script")
        :OnClick(function()
            local editor
            editor = PTGuiLib.Get("puppeteer_load_script_editor", TabFrame)
                :SetPoint("CENTER", TabFrame, "CENTER")
                :SetTitle("Edit Postload Script")
            editor:GetEditbox():SetText(PTOptions.Scripts.OnPostLoad or "")
            editor:SetCallback(function(save, data)
                if save then
                    PTOptions.Scripts.OnPostLoad = data
                end
                editor:Dispose()
                PopOverlayFrame()
            end)
            editor:GetEditbox():SetFocus()
            AddOverlayFrame(editor)
        end)
    local reloadInfo = CreateLabel(container, "A reload or relog is required for any script changes to take effect.")
        :SetWidth(TEXT_WIDTH)
        :SetPoint("TOP", postLoadScriptButton, "BOTTOM", 0, -20)
    local reloadButton = PTGuiLib.Get("button", container)
        :SetPoint("TOP", reloadInfo, "BOTTOM", 0, -5)
        :SetSize(120, 20)
        :SetText("Reload UI")
        :OnClick(function()
            ReloadUI()
        end)
end

function CreateTab_Options_Mods(panel)
    local container, scrollFrame = panel:CreateTab("Mods", true)
    local layout = NewLabeledColumnLayout(container, {150, 310}, -20, 10)
    local factory = NewComponentFactory(container, layout)
    container.factory = factory

    local TEXT_WIDTH = 370

    local generalInfo = CreateLabel(container, "Some client mods enhance your experience with Puppeteer by enabling additional functionality.")
        :SetWidth(TEXT_WIDTH)
        :SetPoint("TOP", container, "TOP", 0, -10)

    local superWowDetected = util.IsSuperWowPresent()
    local unitXPDetected = util.IsUnitXPSP3Present()
    local nampowerDetected = util.IsNampowerPresent()

    local detectedTexts = {
        [true] = colorize("Mod Detected", 0.2, 1, 0.2),
        [false] = colorize("Mod Not Detected", 1, 0.2, 0.2)
    }
    local superWowLabel = CreateLabel(container, "SuperWoW")
        :SetPoint("TOP", generalInfo, "BOTTOM", 0, -20)
        :SetFontSize(14)
    local superWowDetectedLabel = CreateLabel(container, detectedTexts[superWowDetected])
        :SetPoint("TOP", superWowLabel, "BOTTOM", 0, -5)
        :SetFontSize(10)
        :SetFontFlags("OUTLINE")
    local superWowInfo = CreateLabel(container, "SuperWoW provides the following enhancements:\n\n"..
        "• Enables tracking of many class buff and debuff timers\n"..
        "• Enhances spell casting by directly casting on targets rather than split-second target switching tricks\n"..
        "• Allows you to see accurate distance to other friendly players and NPCs\n"..
        "• Mousing over unit frames properly sets your mouseover target\n"..
        "• Shows incoming healing from players that do not have HealComm and predicts more accurate numbers\n"..
        "• Add players/mobs to a separate Focus frame (By using the Focus action bind)")
        :SetJustifyH("LEFT")
        :SetWidth(TEXT_WIDTH)
        :SetPoint("TOP", superWowDetectedLabel, "BOTTOM", 0, -10)
    local superWowLink = CreateLinkEditbox(container, "https://github.com/balakethelock/SuperWoW")
        :SetPoint("TOP", superWowInfo, "BOTTOM", 0, -5)
        :SetSize(300, 20)
    local superWowLinkLabel = CreateLabel(container, "Link:")
        :SetPoint("RIGHT", superWowLink, "LEFT", -5, 0)

    layout:ignoreNext()
    local setMouseoverCheckbox = factory:checkbox("Set Mouseover", {"Requires SuperWoW Mod To Work", 
        "If enabled, hovering over frames will set your mouseover target"}, "SetMouseover")
        :SetPoint("TOP", superWowLink, "BOTTOM", 0, -10)
    if not superWowDetected then
        setMouseoverCheckbox:Disable()
    end

    -- UnitXP SP3

    local unitXPLabel = CreateLabel(container, "UnitXP SP3")
        :SetPoint("TOP", setMouseoverCheckbox, "BOTTOM", 0, -20)
        :SetFontSize(14)
    local unitXPDetectedLabel = CreateLabel(container, detectedTexts[unitXPDetected])
        :SetPoint("TOP", unitXPLabel, "BOTTOM", 0, -5)
        :SetFontSize(10)
        :SetFontFlags("OUTLINE")
    
    local unitXPInfo = CreateLabel(container, "UnitXP SP3 provides the following enhancements:\n\n"..
        "• Displays when units are out of line-of-sight\n"..
        "• Allows you to see more accurate distance than SuperWoW and also see distance to enemies")
        :SetJustifyH("LEFT")
        :SetWidth(TEXT_WIDTH)
        :SetPoint("TOP", unitXPDetectedLabel, "BOTTOM", 0, -10)
    local unitXPLink = CreateLinkEditbox(container, "https://codeberg.org/konaka/UnitXP_SP3/wiki")
        :SetPoint("TOP", unitXPInfo, "BOTTOM", 0, -5)
        :SetSize(300, 20)
    local unitXPLinkLabel = CreateLabel(container, "Link:")
        :SetPoint("RIGHT", unitXPLink, "LEFT", -5, 0)

    -- Nampower

    local nampowerLabel = CreateLabel(container, "Nampower")
        :SetPoint("TOP", unitXPLink, "BOTTOM", 0, -20)
        :SetFontSize(14)
    local nampowerDetectedLabel = CreateLabel(container, detectedTexts[nampowerDetected])
        :SetPoint("TOP", nampowerLabel, "BOTTOM", 0, -5)
        :SetFontSize(10)
        :SetFontFlags("OUTLINE")
    
    local nampowerInfo = CreateLabel(container, "Nampower provides the following enhancements:\n\n"..
        "• Allows you to queue spell casts like in modern versions of WoW, drastically increasing casting efficiency")
        :SetJustifyH("LEFT")
        :SetWidth(TEXT_WIDTH)
        :SetPoint("TOP", nampowerDetectedLabel, "BOTTOM", 0, -10)
    local nampowerLink = CreateLinkEditbox(container, "https://github.com/pepopo978/nampower")
        :SetPoint("TOP", nampowerInfo, "BOTTOM", 0, -5)
        :SetSize(300, 20)
    local nampowerLinkLabel = CreateLabel(container, "Link:")
        :SetPoint("RIGHT", nampowerLink, "LEFT", -5, 0)
    

    
    scrollFrame:UpdateScrollRange()
end

function CreateTab_Customize()
    local container = TabFrame:CreateTab("Customize")

    local frameStyleContainer = PTGuiLib.Get("container", container)
        :SetSimpleBackground()
        :SetPoint("TOPLEFT", container, "TOPLEFT", 5, -26)
        :SetPoint("BOTTOMRIGHT", container, "TOPRIGHT", -5, -155)
    local layout = NewLabeledColumnLayout(frameStyleContainer, {100, 340, 175}, -25, 5)

    local frameSettingsText = CreateLabel(frameStyleContainer, "Frame Group Settings")
        :SetPoint("TOP", frameStyleContainer, "TOP", 0, -5)
        :SetFontSize(14)
    

    local preferredFrameOrder = {"Party", "Pets", "Raid", "Raid Pets", "Target", "Focus"}
    local frameDropdown = CreateLabeledDropdown(frameStyleContainer, "Configure Frame", "The frame to edit the attributes of")
        :SetWidth(150)
        :SetDynamicOptions(function(addOption, level, args)
            for _, name in ipairs(preferredFrameOrder) do
                if Puppeteer.UnitFrameGroups[name] then
                    addOption("text", name,
                        "dropdownText", name,
                        "initFunc", args.initFunc,
                        "func", args.func)
                end
            end
            for name, group in pairs(Puppeteer.UnitFrameGroups) do
                if not util.ArrayContains(preferredFrameOrder, name) then
                    addOption("text", name,
                        "dropdownText", name,
                        "initFunc", args.initFunc,
                        "func", args.func)
                end
            end
        end, {
            initFunc = function(self, gui)
                self.checked = self.text == gui:GetText()
            end,
            func = function(self, gui)
                StyleDropdown:UpdateText()
                AnchorDropdown:UpdateText()
                UpdateFrameOptions()
            end
        })
        :SetText("Party")
    FrameDropdown = frameDropdown
    layout:column(3):layoutComponent(frameDropdown)
    local GetSelectedProfileName = PuppeteerSettings.GetSelectedProfileName
    local styleDropdown = CreateLabeledDropdown(frameStyleContainer, "Choose Style", "The style of the frame")
        :SetWidth(150)
        :SetDynamicOptions(function(addOption, level, args)
            local profiles = PTProfileManager.GetProfileNames()
            for _, profile in ipairs(profiles) do
                addOption("text", profile,
                    "checked", GetSelectedProfileName(frameDropdown:GetText()) == profile,
                    "func", args.func)
            end
        end, {
            func = function(self, gui)
                local selectedFrame = frameDropdown:GetText()
                PTOptions.ChosenProfiles[selectedFrame] = self.text

                if selectedFrame == "Focus" and not util.IsSuperWowPresent() then
                    return
                end

                -- Here's some probably buggy profile hotswapping
                local group = Puppeteer.UnitFrameGroups[selectedFrame]
                group.profile = GetSelectedProfile(selectedFrame)
                local oldUIs = group.uis
                group.uis = {}
                group:ResetFrameLevel() -- Need to lower frame or the added UIs are somehow under it
                for unit, ui in pairs(oldUIs) do
                    ui:GetRootContainer():SetParent(nil)
                    -- Forget about the old UI, and cause a fat memory leak why not
                    ui:GetRootContainer():Hide()
                    local newUI = PTUnitFrame:New(unit, ui.isCustomUnit)
                    util.RemoveElement(Puppeteer.AllUnitFrames, ui)
                    table.insert(Puppeteer.AllUnitFrames, newUI)
                    local unitUIs = Puppeteer.GetUnitFrames(unit)
                    util.RemoveElement(unitUIs, ui)
                    table.insert(unitUIs, newUI)
                    group:AddUI(newUI, true)
                    if ui.guidUnit then
                        newUI.guidUnit = ui.guidUnit
                    elseif unit ~= "target" then
                        newUI:Hide()
                    end
                end
                Puppeteer.CheckGroup()
                group:UpdateUIPositions()
                group:ApplyProfile()

                gui:UpdateText()
            end
        })
        :SetTextUpdater(function(self)
            self:SetText(GetSelectedProfileName(frameDropdown:GetText()))
        end)
    StyleDropdown = styleDropdown
    layout:column(1):offset(0, -30):layoutComponent(styleDropdown)

    local anchors = {"TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT"}
    local readableAnchorMap = {
        TOPLEFT = "Top Left",
        TOP = "Top",
        TOPRIGHT = "Top Right",
        LEFT = "Left",
        CENTER = "Center",
        RIGHT = "Right",
        BOTTOMLEFT = "Bottom Left",
        BOTTOM = "Bottom",
        BOTTOMRIGHT = "Bottom Right"
    }
    local anchorDropdown = CreateLabeledDropdown(frameStyleContainer, "Anchor", 
            {"The point the frame is anchored to, affecting the direction it expands/retracts",
            "Top Left: Expands right and down",
            "Top: Expands equally left & right and down",
            "Top Right: Expands left and down",
            "Left: Expands right and equally up & down",
            "Center: Expands equally in all directions",
            "Right: Expands left and equally up & down",
            "Bottom Left: Expands right and up",
            "Bottom: Expands equally left & right and up",
            "Bottom Right: Expands left and up",})
        :SetWidth(150)
        :SetSimpleOptions(anchors, function(option)
            return {
                initFunc = function(self)
                    self.checked = PuppeteerSettings.GetFramePosition(frameDropdown:GetText()) == option
                end,
                func = function(self, gui)
                    local group = Puppeteer.UnitFrameGroups[frameDropdown:GetText()]
                    util.ConvertAnchor(group:GetContainer(), option)
                    PuppeteerSettings.SaveFramePositions()
                    gui:UpdateText()
                end,
                text = readableAnchorMap[option]
            }
        end)
        :SetTextUpdater(function(self)
            self:SetText(readableAnchorMap[PuppeteerSettings.GetFramePosition(frameDropdown:GetText())])
        end)
    layout:layoutComponent(anchorDropdown)
    AnchorDropdown = anchorDropdown

    local lockFrameCheckbox = CreateLabeledCheckbox(frameStyleContainer, "Lock Frame", {"If checked, this frame will not be movable", 
        "Note: This setting is also accessible by right-clicking the group title bar"})
        :OnClick(function(self)
            local frameName = frameDropdown:GetText()
            PuppeteerSettings.SetFrameLocked(frameName, self:GetChecked() == 1)
        end)
    layout:column(2):offset(0, -30):layoutComponent(lockFrameCheckbox)
    LockFrameCheckbox = lockFrameCheckbox

    local hideTitleCheckbox = CreateLabeledCheckbox(frameStyleContainer, "Hide Title", {"If checked, the title of this frame will be hidden", 
        colorize("Note: When you want to move the frame, you need to enable the title!", 1, 0.4, 0.4)})
        :OnClick(function(self)
            local frameName = frameDropdown:GetText()
            PuppeteerSettings.SetTitleHidden(frameName, self:GetChecked() == 1)
        end)
    layout:layoutComponent(hideTitleCheckbox)
    HideTitleCheckbox = hideTitleCheckbox

    local hideFrameCheckbox = CreateLabeledCheckbox(frameStyleContainer, "Hide Frame", "If checked, this frame will not be visible")
        :OnClick(function(self)
            local frameName = frameDropdown:GetText()
            PuppeteerSettings.SetFrameHidden(frameName, self:GetChecked() == 1)
            Puppeteer.CheckGroup()
        end)
    layout:layoutComponent(hideFrameCheckbox)
    HideFrameCheckbox = hideFrameCheckbox

    UpdateFrameOptions()

    local overrideContainer = PTGuiLib.Get("scroll_frame", container)
        :SetPoint("TOPLEFT", frameStyleContainer, "BOTTOMLEFT", 0, -5)
        :SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -5, 5)
        :SetSimpleBackground()
    StyleOverrideContainer = overrideContainer

    local container = overrideContainer

    local styleOverridesText = PTGuiLib.GetText(container, "Style Overrides")
        :SetFontSize(14)
        :SetPoint("TOP", container, "TOP", 0, -5)
    local explainer = PTGuiLib.GetText(container, "Style Overrides are an inelegant, temporary measure to enable customization "..
            "of commonly requested unit frame edits. Some settings may be visually incompatible with one another. "..
            "This will be replaced in a future date with a system that is much more robust.\n\n"..
            colorize("You must reload or relog for any changes to take effect!", 1, 0.5, 0.5))
        :SetPoint("TOP", styleOverridesText, "TOP", 0, -20)
        :SetWidth(360)

    local layout = NewLabeledColumnLayout(container, {160}, -120, 5)

    local styleDropdown = CreateLabeledDropdown(container, "Edit Style", "The style to edit the overrides of")
        :SetWidth(160)
        :SetText("Default")
        :SetDynamicOptions(function(addOption, level, args)
            local profiles = PTProfileManager.GetProfileNames()
            for _, profile in ipairs(profiles) do
                addOption("text", profile,
                    "initFunc", args.initFunc,
                    "func", args.func)
            end
        end, {
            initFunc = function(self, gui)
                self.checked = gui:GetText() == self.text
            end,
            func = function(self)
                SetSelectedStyleOverride(self.text)
            end
        })
    layout:offset(-65, 0):layoutComponent(styleDropdown)
    layout:offset(65, 0)
    StyleOverrideDropdown = styleDropdown
    SetSelectedStyleOverride(PTProfileManager.DEFAULT_PROFILE_NAME)

    local reloadUI = PTGuiLib.Get("button", container)
        :SetPoint("LEFT", styleDropdown, "RIGHT", 10, 0)
        :SetSize(100, 20)
        :SetText("Reload UI")
        :OnClick(ReloadUI)

    local function add(component, offsetY)
        if component:Type() == "checkbox" then
            offsetY = (offsetY or 0) - 12
        end
        layout:offset(0, offsetY or 0):layoutComponent(component)
    end
    local createDropdown = CreateStyleOverrideDropdown
    local createSlider = CreateStyleOverrideSlider

    local barStyles = util.ToArray(Puppeteer.BarStyles)
    table.sort(barStyles)

    add(createDropdown("Health Bar Color", nil, "HealthBarColor", {"Green To Red", "Green", "Class"}), -10)
    add(createDropdown("Health Bar Texture", nil, "HealthBarStyle", barStyles))
    add(createDropdown("Health Display", "What kind of text is displayed as health", "HealthDisplay", {"Health", "Health/Max Health", "% Health", "Hidden"}))
    add(createDropdown("Missing Health Display", "What kind of text is displayed as missing health", "MissingHealthDisplay", {"-Health", "-% Health", "Hidden"}))
    add(createDropdown("Incoming Heal Display", nil, "IncomingHealDisplay", {"Overheal", "Heal", "Hidden"}))
    add(createDropdown("Power Bar Texture", nil, "PowerBarStyle", barStyles))
    add(createDropdown("Power Display", "What kind of text is displayed as power", "PowerDisplay", {"Power", "Power/Max Power", "% Power", "Hidden"}))
    add(createDropdown("Name Text Color", "'Default' is default Blizzard yellow text", "NameText.Color", {"Class", "Default"}))
    add(createDropdown("Show Debuff Colors On", nil, "ShowDebuffColorsOn", {"Health Bar", "Name", "Health", "Hidden"}))
    add(createDropdown("Sort Units By", "The sorting algorithm for units in a group", "SortUnitsBy", {"ID", "Name", "Class Name"}))
    add(createDropdown("Growth Orientation", "Vertical grows units up and down, Horizontal grows units left and right", "Orientation", {"Vertical", "Horizontal"}))
    add(createDropdown("Split Raid Into Groups", "If enabled, raids will be split based on the groups", "SplitRaidIntoGroups", {true, false}))
    add(createDropdown("Border Style", "The border of the group", "BorderStyle", {"Tooltip", "Dialog Box", "Borderless"}))
    add(createSlider("Background Opacity", "How opaque the background of the frame group is in %", "BackgroundOpacity", 0, 100))
    add(createSlider("Max Units In Axis", "The maximum number of units in the growth axis until it must shift down", "MaxUnitsInAxis", 1, 20))
    add(createSlider("Min Units X", "The minimum amount of unit space to take on the X-axis", "MinUnitsX", 0, 20))
    add(createSlider("Min Units Y", "The minimum amount of unit space to take on the Y-axis", "MinUnitsY", 0, 20))
    add(createSlider("Horizontal Spacing", "The number of pixels between units", "HorizontalSpacing", 0, 20))
    add(createSlider("Vertical Spacing", "The number of pixels between units", "VerticalSpacing", 0, 20))
    add(createSlider("Show Distance At\n(Friendly)", "How many yards to start showing friendly distance at", "ShowDistanceThreshold.Friendly", 0, 100))
    add(createSlider("Show Distance At\n(Hostile)", "How many yards to start showing hostile distance at", "ShowDistanceThreshold.Hostile", 0, 100))
    add(createSlider("Out of Range At\n(Friendly)", "How many yards to fade out friendly units", "OutOfRangeThreshold.Friendly", 0, 100))
    add(createSlider("Out of Range At\n(Hostile)", "How many yards to fade out hostile units", "OutOfRangeThreshold.Hostile", 0, 100))
    add(createSlider("Out of Range Opacity", "How opaque out of range players appear in %", "OutOfRangeOpacity", 0, 100))
    local visualIssues = colorize("Adjusting this value may cause visual issues!", 1, 0.4, 0.4)
    add(createSlider("Unit Frame Width", {"The width of each unit frame", visualIssues}, "Width", 20, 250))
    add(createSlider("Health Bar Height", {"The height of the health bar", visualIssues}, "HealthBarHeight", 1, 100))
    add(createSlider("Power Bar Height", {"The height of the power bar", visualIssues}, "PowerBarHeight", 1, 100))
    add(createSlider("Aura Tracker Height", {"The height of tracked auras", visualIssues}, "AuraTracker.Height", 0, 50))
    PopulateStyleOverrides()
end

function UpdateFrameOptions()
    LockFrameCheckbox:SetChecked(PuppeteerSettings.IsFrameLocked(FrameDropdown:GetText()))
    HideTitleCheckbox:SetChecked(PuppeteerSettings.IsTitleHidden(FrameDropdown:GetText()))
    HideFrameCheckbox:SetChecked(PuppeteerSettings.IsFrameHidden(FrameDropdown:GetText()))
end

StyleOverrideComponents = {}

CurrentStyleOverride = nil

function CreateStyleOverrideDropdown(text, tooltip, optionLoc, options)
    local dropdown, label = CreateLabeledDropdown(StyleOverrideContainer, text, tooltip)
    dropdown:SetWidth(200)
    dropdown:SetDynamicOptions(function(addOption, level, args)
        addOption("text", "Use Style Default",
            "initFunc", args.initFunc,
            "func", args.func)
        for _, option in ipairs(options) do
            addOption("text", tostring(option),
                "option", option,
                "initFunc", args.initFunc,
                "func", args.func)
        end
    end, {
        initFunc = function(self, gui)
            self.checked = gui:GetText() == self.text
        end,
        func = function(self, gui)
            SetStyleOverride(GetSelectedStyleOverride(), optionLoc, self.option)
            gui:UpdateText()
        end
    })
    :SetTextUpdater(function(gui)
        local value = GetStyleOverride(GetSelectedStyleOverride(), optionLoc)
        gui:SetText(value ~= nil and tostring(value) or "Use Style Default")
    end)
    StyleOverrideComponents[optionLoc] = {Updater = function()
        dropdown:UpdateText()
    end}
    return dropdown
end

function CreateStyleOverrideSlider(text, tooltip, optionLoc, min, max)
    local checkbox = CreateLabeledCheckbox(StyleOverrideContainer, text, tooltip)
    checkbox:ApplyTooltip(tooltip, colorize("Check to override style default", 1, 0.4, 1))
    local slider = CreateSlider(StyleOverrideContainer)
    slider:SetMinMaxValues(min, max)
    slider:GetSlider():SetNumberedText()
    slider:GetSlider():HookScript("OnValueChanged", function()
        SetStyleOverride(GetSelectedStyleOverride(), optionLoc, slider:GetSlider():GetValue())
    end)
    slider:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
    slider:ApplyTooltip(tooltip)
    local function Checkbox_OnClick()
        local value = GetStyleOverride(GetSelectedStyleOverride(), optionLoc)
        if checkbox:GetChecked() then
            slider:Show()
            if value == nil then
                value = GetStyleOverride(PTProfileManager.GetDefaultProfile(CurrentStyleOverride), optionLoc)
                SetStyleOverride(GetSelectedStyleOverride(), optionLoc, value)
            end
            slider:SetValue(value)
        else
            slider:Hide()
            SetStyleOverride(GetSelectedStyleOverride(), optionLoc, nil)
        end
    end
    checkbox:SetScript("OnClick", Checkbox_OnClick)
    StyleOverrideComponents[optionLoc] = {Updater = function()
        local hasOverride = GetStyleOverride(GetSelectedStyleOverride(), optionLoc) ~= nil
        checkbox:SetChecked(hasOverride)
        Checkbox_OnClick()
    end}
    return checkbox
end

function GetSelectedStyleOverride()
    return PTOptions.StyleOverrides[CurrentStyleOverride]
end

function SetSelectedStyleOverride(style)
    CurrentStyleOverride = style
    if not PTOptions.StyleOverrides[CurrentStyleOverride] then
        PTOptions.StyleOverrides[CurrentStyleOverride] = {}
    end
    StyleOverrideDropdown:SetText(style)
    PopulateStyleOverrides()
end

function PopulateStyleOverrides()
    for _, component in pairs(StyleOverrideComponents) do
        component.Updater()
    end
end

function TraverseOverride(style, location)
    local path = util.SplitString(location, ".")
    local currentTable = style
    for i = 1, table.getn(path) - 1 do
        if not currentTable[path[i]] then
            currentTable[path[i]] = {}
        end
        currentTable = currentTable[path[i]]
    end
    return currentTable, path[table.getn(path)]
end

function GetStyleOverride(style, location)
    local optionTable, location = TraverseOverride(style, location)
    return optionTable[location]
end

function SetStyleOverride(style, location, value)
    local optionTable, location = TraverseOverride(style, location)
    optionTable[location] = value
end

function CreateTab_About()
    local container = TabFrame:CreateTab("About")

    local text = PTGuiLib.GetText(container, 
            "Puppeteer Version "..Puppeteer.VERSION..
            "\n\n\nPuppeteer Author: OldManAlpha\nTurtle Nordanaar IGN: Oldmana, Lowall, Jmdruid"..
            "\n\nHealersMate Original Author: i2ichardt\nEmail: rj299@yahoo.com"..
            "\n\nAdditional Contributors"..
            "\nTurtle WoW Community: Answers to addon development questions"..
            "\nShagu: Utility functions & providing a wealth of research material"..
            "\nChatGPT: Utility functions"..
            "\n\n\nCheck For Updates, Report Issues, Make Suggestions:\n",
            12)
        :SetPoint("TOP", container, "TOP", 0, -80)

    CreateLinkEditbox(container, "https://github.com/OldManAlpha/Puppeteer")
        :SetPoint("TOP", text, "BOTTOM", 0, -10)
        :SetSize(300, 20)
end


-- Factory-related functions

function NewLabeledColumnLayout(container, columns, startY, spacing)
    local layout = {}
    layout.lastAdded = {}
    layout.params = {}
    layout.selectedColumn = 1
    function layout:getNextPoint(columnIndex)
        local offsetX, offsetY = self.params.offsetX or 0, self.params.offsetY or 0
        if self.lastAdded[columnIndex] then
            return "TOPLEFT", self.lastAdded[columnIndex], "BOTTOMLEFT", offsetX, -spacing + offsetY
        end
        return "TOPLEFT", container, "TOPLEFT", columns[columnIndex] + offsetX, startY + offsetY
    end
    function layout:layoutComponent(component)
        if not self.params.ignoreNext then
            local columnIndex = self.selectedColumn or 1
            component:SetPoint(self:getNextPoint(columnIndex))
            self.lastAdded[columnIndex] = component
        end
        util.ClearTable(self.params)
    end
    function layout:column(columnIndex)
        self.selectedColumn = columnIndex
        return self
    end
    function layout:offset(offsetX, offsetY)
        self.params.offsetX = (self.params.offsetX or 0) + offsetX
        self.params.offsetY = (self.params.offsetY or 0) + offsetY
        return self
    end
    function layout:levelAt(columnIndex)
        local lastAdded = self.lastAdded[columnIndex]
        self.lastAdded[self.selectedColumn] = lastAdded
        self:offset(columns[self.selectedColumn] - columns[columnIndex], spacing + lastAdded:GetHeight())
        return self
    end
    function layout:setLastAdded(columnIndex, component)
        self.lastAdded[columnIndex] = component
        return self
    end
    function layout:ignoreNext()
        self.params.ignoreNext = true
        return self
    end
    return layout
end

function NewComponentFactory(container, layout)
    return {
        ["layout"] = layout,
        ["doLayout"] = function(self, component)
            if self.layout then
                self.layout:layoutComponent(component)
            end
        end,
        ["checkbox"] = function(self, text, tooltipText, optionLoc, clickFunc)
            local checkbox, label = CreateLabeledCheckbox(container, text, tooltipText)
            self:doLayout(checkbox)
            checkbox:SetScript("OnClick", function(self)
                SetOption(optionLoc, this:GetChecked() == 1)
                if clickFunc then
                    clickFunc(self)
                end
            end)
            checkbox:SetChecked(GetOption(optionLoc))
            return checkbox, label
        end,
        ["dropdown"] = function(self, text, tooltipText, optionLoc, options, selectFunc)
            local dropdown, label = CreateLabeledDropdown(container, text, tooltipText)
            self:doLayout(dropdown)
            dropdown:SetSimpleOptions(options, function(option)
                return {
                    text = option,
                    dropdownText = option,
                    initFunc = function(self)
                        self.checked = GetOption(optionLoc) == self.text
                    end,
                    func = function(self)
                        SetOption(optionLoc, self.text)
                        if selectFunc then
                            selectFunc(self)
                        end
                    end
                }
            end, GetOption(optionLoc))
            return dropdown, label
        end,
        ["slider"] = function(self, text, tooltipText, optionLoc, minValue, maxValue)
            local slider, label = CreateLabeledSlider(container, text, tooltipText)
            slider:SetMinMaxValues(minValue, maxValue)
            slider:SetValue(GetOption(optionLoc))
            slider:GetSlider():SetNumberedText()
            local script = slider:GetSlider():GetScript("OnValueChanged")
            slider:GetSlider():SetScript("OnValueChanged", function(self)
                script()
                SetOption(optionLoc, self:GetValue())
            end)
            self:doLayout(slider)
            return slider, label
        end,
        ["label"] = function(self, text, tooltipText)
            -- Dummy frame
            local frame = PTGuiLib.Get("container", container)
                :SetSize(20, 20)
            local label = CreateLabel(container, text)
                :SetPoint(GetLabelPoint(frame))
            self:doLayout(frame)
            return label, frame
        end
    }
end

function GetLabelPoint(relative)
    return "RIGHT", relative, "LEFT", -5, 0
end

function CreateLabeledCheckbox(parent, text, tooltipText)
    local checkbox = CreateCheckbox(parent)
    local label = CreateLabel(parent, text)
    label:SetPoint(GetLabelPoint(checkbox))
    checkbox:ApplyTooltip(tooltipText)
    label:ApplyTooltip(tooltipText)
    return checkbox, label
end

function CreateLabeledDropdown(parent, text, tooltipText)
    local dropdown = CreateDropdown(parent)
    local label = CreateLabel(parent, text)
    label:SetPoint(GetLabelPoint(dropdown))
    dropdown:ApplyTooltip(tooltipText)
    label:ApplyTooltip(tooltipText)
    return dropdown, label
end

function CreateLabeledSlider(parent, text, tooltipText)
    local slider = CreateSlider(parent)
    local label = CreateLabel(parent, text)
    label:SetPoint(GetLabelPoint(slider))
    slider:ApplyTooltip(tooltipText)
    label:ApplyTooltip(tooltipText)
    return slider, label
end

function CreateLinkEditbox(parent, site)
    return PTGuiLib.Get("editbox", parent)
        :SetText(site)
        :SetJustifyH("CENTER")
        :SetScript("OnTextChanged", function(self)
            self:SetText(site)
        end)
end

function CreateDropdown(parent, width)
    return PTGuiLib.Get("dropdown", parent)
        :SetSize(width or 140, 25)
end

function CreateSlider(parent, width, height)
    return PTGuiLib.Get("editbox_slider", parent)
        :SetSize(width or 160, height or 36)
end

function CreateCheckbox(parent, width, height)
    return PTGuiLib.Get("checkbox", parent)
        :SetSize(width or 20, height or 20)
end

function CreateLabel(parent, text)
    return PTGuiLib.GetText(parent, text)
end