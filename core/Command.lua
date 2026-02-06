SLASH_PUPPETEER1 = "/puppeteer"
SLASH_PUPPETEER2 = "/pt"
if not IsAddOnLoaded("HealersMate") then
    SLASH_PUPPETEER3 = "/hm"
end
SlashCmdList["PUPPETEER"] = function(args)
    if args == "reset" then
        for _, group in pairs(Puppeteer.UnitFrameGroups) do
            local gc = group:GetContainer()
            gc:ClearAllPoints()
            gc:SetPoint(PTUtil.GetCenterScreenPoint(gc:GetWidth(), gc:GetHeight()))
        end
        PTSettingsGui.TabFrame:ClearAllPoints()
        PTSettingsGui.TabFrame:SetPoint("CENTER", 0, 0)
        Puppeteer.Info("Reset all frame positions.")
    elseif args == "check" then
        Puppeteer.CheckGroup()
    elseif args == "update" then
        for _, ui in ipairs(Puppeteer.AllUnitFrames) do
            ui:SizeElements()
            ui:UpdateAll()
        end
        for _, group in pairs(Puppeteer.UnitFrameGroups) do
            group:ApplyProfile()
            group:UpdateUIPositions()
        end
    elseif args == "testui" then
        PTOptions.TestUI = not PTOptions.TestUI
        Puppeteer.TestUI = PTOptions.TestUI
        if PTOptions.TestUI then
            for _, ui in ipairs(Puppeteer.AllUnitFrames) do
                ui.fakeStats = ui.GenerateFakeStats()
                ui:Show()
            end
        end
        Puppeteer.CheckGroup()
        if not PTOptions.TestUI and PTUnitProxy then
            for _, type in ipairs(PTUnitProxy.CustomUnitTypes) do
                PTUnitProxy.UpdateUnitTypeFrames(type)
            end
        end
        Puppeteer.Info("UI Testing is now "..(not PTOptions.TestUI and 
            PTUtil.Colorize("off", 1, 0.6, 0.6) or PTUtil.Colorize("on", 0.6, 1, 0.6))..".")
    elseif args == "toggle" then
        PTOptions.Hidden = not PTOptions.Hidden
        Puppeteer.CheckGroup()
        Puppeteer.Info("The Puppeteer UI is now "..(PTOptions.Hidden and 
            PTUtil.Colorize("hidden", 1, 0.6, 0.6) or PTUtil.Colorize("shown", 0.6, 1, 0.6))..".")
    elseif args == "show" then
        PTOptions.Hidden = false
        Puppeteer.CheckGroup()
        Puppeteer.Info("The Puppeteer UI is now "..(PTOptions.Hidden and 
            PTUtil.Colorize("hidden", 1, 0.6, 0.6) or PTUtil.Colorize("shown", 0.6, 1, 0.6))..".")
    elseif args == "hide" then
        PTOptions.Hidden = true
        Puppeteer.CheckGroup()
        Puppeteer.Info("The Puppeteer UI is now "..(PTOptions.Hidden and 
            PTUtil.Colorize("hidden", 1, 0.6, 0.6) or PTUtil.Colorize("shown", 0.6, 1, 0.6))..".")
    elseif args == "roles" then
        local group = Puppeteer.UnitFrameGroups[Puppeteer.CurrentlyInRaid and "Raid" or "Party"]
        local chatType = Puppeteer.CurrentlyInRaid and "RAID" or "PARTY"
        local tanks = {}
        local healers = {}
        for _, ui in group.uis do
            if UnitIsPlayer(ui:GetUnit()) then
                local role = ui:GetRole()
                local name = UnitName(ui:GetUnit())
                if role == "Tank" then
                    table.insert(tanks, name)
                elseif role == "Healer" then
                    table.insert(healers, name)
                end
            end
        end
        SendChatMessage("Puppeteer -- Assigned Roles", chatType)
        SendChatMessage("Tanks("..table.getn(tanks).."): "..table.concat(tanks, ", "), chatType)
        SendChatMessage("Healers("..table.getn(healers).."): "..table.concat(healers, ", "), chatType)
    elseif args == "silent" then
        PTGlobalOptions.ShowLoadMessage = not PTGlobalOptions.ShowLoadMessage
        Puppeteer.Info("Load message is now "..(PTGlobalOptions.ShowLoadMessage and 
            PTUtil.Colorize("on", 0.6, 1, 0.6) or PTUtil.Colorize("off", 1, 0.6, 0.6))..".")
    elseif args == "help" or args == "?" then
        DEFAULT_CHAT_FRAME:AddMessage(PTUtil.Colorize("/pt", 0, 0.8, 0).." -- Opens the addon configuration")
        DEFAULT_CHAT_FRAME:AddMessage(PTUtil.Colorize("/pt reset", 0, 0.8, 0).." -- Resets all frame positions")
        DEFAULT_CHAT_FRAME:AddMessage(PTUtil.Colorize("/pt testui", 0, 0.8, 0)..
            " -- Toggles fake players to see how the UI would look")
        DEFAULT_CHAT_FRAME:AddMessage(PTUtil.Colorize("/pt toggle", 0, 0.8, 0).." -- Shows/hides the UI")
        DEFAULT_CHAT_FRAME:AddMessage(PTUtil.Colorize("/pt show", 0, 0.8, 0).." -- Shows the UI")
        DEFAULT_CHAT_FRAME:AddMessage(PTUtil.Colorize("/pt hide", 0, 0.8, 0).." -- Hides the UI")
        DEFAULT_CHAT_FRAME:AddMessage(PTUtil.Colorize("/pt roles", 0, 0.8, 0).." -- Broadcast the roles you have assigned to chat")
        DEFAULT_CHAT_FRAME:AddMessage(PTUtil.Colorize("/pt silent", 0, 0.8, 0).." -- Turns off/on message when addon loads")
    elseif args == "importhm" then
        Puppeteer.ImportHealersMateSettings()
        Puppeteer.Info("Imported HealersMate settings")
    elseif args == "" then
        PTSettingsGui.TabFrame:Show()
    else
        Puppeteer.Info("Unknown subcommand. See usage with /pt help")
    end
end