-- DEPRECATION NOTICE
-- UI Profiles as they currently stand will be retired in a future update for a more modular system

PTProfileManager = {}

PTUtil.SetEnvironment(PTProfileManager)
local _G = getfenv(0)

local util = PTUtil

-- The profile name used for fallback
DEFAULT_PROFILE_NAME = "Default"

-- Profiles that have not had style overrides applied
DefaultProfiles = {}
-- Profiles that have had style overrides applied
Profiles = {}

DefaultProfileOrder = {
    "Default", "Default (Short Bar)", "Small", "Very Small", "Very Small (Horizontal)", "Long", "Long (Small)", 
    "Long (Integrated)", "Enemy", "Enemy (Small)", "Legacy"
}
DefaultProfileOrder = util.ToSet(DefaultProfileOrder, true)

-- Tries to get profile with overrides applied, or the default one if none is found
function GetProfile(name)
    return Profiles[name or DEFAULT_PROFILE_NAME] or DefaultProfiles[name or DEFAULT_PROFILE_NAME]
end

function GetDefaultProfile(name)
    return DefaultProfiles[name or DEFAULT_PROFILE_NAME]
end

function GetProfileNames()
    local names = util.ToArray(DefaultProfiles)
    table.sort(names, function(a, b)
        return (DefaultProfileOrder[a] or 1000) < (DefaultProfileOrder[b] or 1000)
    end)
    return names
end

function CreateProfile(name, baseName, diff, useDefault)
    local profileGetter = (useDefault ~= false) and GetDefaultProfile or GetProfile
    DefaultProfiles[name] = PTUIProfile:New(profileGetter(baseName or DEFAULT_PROFILE_NAME), diff)
    if useDefault ~= false then
        ApplyOverrides(name)
    end
    return DefaultProfiles[name]
end

function ApplyOverrides(profileName)
    local overrides = PTOptions.StyleOverrides[profileName]
    local profile = GetDefaultProfile(profileName)

    if overrides and profile then
        profile = PTUIProfile:New(profile, overrides)
        Profiles[profileName] = profile
    end
end

function InitializeDefaultProfiles()
    DefaultProfiles["Default"] = PTUIProfile:New({
        ["HorizontalSpacing"] = 1,
        ["AlertPercent"] = 100,
        ["PVPIcon"] = {
            ["PaddingH"] = 0,
            ["Opacity"] = 100,
            ["OffsetX"] = -6,
            ["Anchor"] = "Container",
            ["PaddingV"] = 0,
            ["AlignmentH"] = "LEFT",
            ["Width"] = 14,
            ["ObjectType"] = "Sized",
            ["Height"] = 14,
            ["OffsetY"] = 2,
            ["AlignmentV"] = "TOP",
        },
        ["Flash"] = {
            ["PaddingH"] = 4,
            ["Opacity"] = 100,
            ["OffsetX"] = 0,
            ["Anchor"] = "Health Bar",
            ["PaddingV"] = 4,
            ["AlignmentH"] = "CENTER",
            ["Width"] = "Anchor",
            ["ObjectType"] = "Sized",
            ["Height"] = "Anchor",
            ["OffsetY"] = 0,
            ["AlignmentV"] = "CENTER",
        },
        ["FlashOpacity"] = 70,
        ["OutOfRangeOpacity"] = 50,
        ["AuraTracker"] = {
            ["PaddingH"] = 0,
            ["Opacity"] = 100,
            ["OffsetX"] = 0,
            ["Anchor"] = "Health Bar",
            ["PaddingV"] = 0,
            ["AlignmentH"] = "LEFT",
            ["Width"] = "Anchor",
            ["ObjectType"] = "Sized",
            ["Height"] = 14,
            ["OffsetY"] = 0,
            ["AlignmentV"] = "BOTTOM",
        },
        ["AlwaysShowMissingHealth"] = false,
        ["PowerText"] = {
            ["FontSize"] = 8,
            ["PaddingH"] = 4,
            ["Opacity"] = 100,
            ["OffsetX"] = 0,
            ["Anchor"] = "Power Bar",
            ["PaddingV"] = 4,
            ["AlignmentH"] = "CENTER",
            ["ObjectType"] = "Text",
            ["OffsetY"] = 0,
            ["AlignmentV"] = "CENTER",
        },
        ["RoleIcon"] = {
            ["PaddingH"] = 1,
            ["Opacity"] = 100,
            ["OffsetX"] = 0,
            ["Anchor"] = "Container",
            ["PaddingV"] = 1,
            ["AlignmentH"] = "LEFT",
            ["Width"] = 14,
            ["ObjectType"] = "Sized",
            ["Height"] = 14,
            ["OffsetY"] = 0,
            ["AlignmentV"] = "TOP",
        },
        ["SortUnitsBy"] = "ID", -- "ID", "Name", "Class Name"
        ["IncomingHealText"] = {
            ["Outline"] = true,
            ["FontSize"] = 9,
            ["PaddingH"] = 2,
            ["Color"] = {
                0.5,
                1,
                0.5,
            },
            ["Opacity"] = 100,
            ["OffsetX"] = 0,
            ["Anchor"] = "Health Bar",
            ["PaddingV"] = 4,
            ["AlignmentH"] = "LEFT",
            ["IndirectColor"] = {
                0.3,
                0.8,
                0.3,
            },
            ["ObjectType"] = "Text",
            ["OffsetY"] = 2,
            ["AlignmentV"] = "CENTER",
        },
        ["NameText"] = {
            ["FontSize"] = 11,
            ["PaddingH"] = 4,
            ["Color"] = "Class",
            ["Opacity"] = 100,
            ["OffsetX"] = 0,
            ["Anchor"] = "Health Bar",
            ["PaddingV"] = 1,
            ["AlignmentH"] = "CENTER",
            ["MaxWidth"] = 80,
            ["ObjectType"] = "Text",
            ["OffsetY"] = 0,
            ["AlignmentV"] = "TOP",
        },
        ["HealthBarColor"] = "Green To Red", -- "Class", "Green", "Green To Red"
        ["Width"] = 100,
        ["HealthDisplay"] = "Health", -- "Health", "Health/Max Health", "% Health", "Hidden"
        ["ShowDistanceThreshold"] = {
            ["Friendly"] = 30,
            ["Hostile"] = 30,
        },
        ["MissingHealthDisplay"] = "-Health", -- "Hidden", "-Health", "-% Health"
        ["IncomingHealDisplay"] = "Overheal", -- "Overheal", "Heal", "Hidden"
        ["PowerDisplay"] = "Power", -- "Power", "Power/Max Power", "% Power", "Hidden"
        ["ShowEnemyMissingHealth"] = false,
        ["RangeText"] = {
            ["FontSize"] = 9,
            ["PaddingH"] = 4,
            ["Opacity"] = 100,
            ["OffsetX"] = 0,
            ["Anchor"] = "Health Bar",
            ["PaddingV"] = 0,
            ["AlignmentH"] = "CENTER",
            ["ObjectType"] = "Text",
            ["OffsetY"] = -7,
            ["AlignmentV"] = "CENTER",
        },
        ["RangeDirectionThreshold"] = 20,
        ["RangeDirectionIcon"] = {
            ["PaddingH"] = 0,
            ["Opacity"] = 100,
            ["OffsetX"] = 0,
            ["Anchor"] = "Container",
            ["PaddingV"] = 0,
            ["AlignmentH"] = "LEFT",
            ["Width"] = 6,
            ["ObjectType"] = "Sized",
            ["Height"] = 6,
            ["OffsetY"] = 0,
            ["AlignmentV"] = "CENTER",
        },
        ["NameDisplay"] = "Name", -- Unimplemented
        ["TargetOutline"] = {
            ["PaddingH"] = 4,
            ["Opacity"] = 100,
            ["OffsetX"] = 0,
            ["Anchor"] = "Button",
            ["PaddingV"] = 4,
            ["AlignmentH"] = "CENTER",
            ["Height2"] = 2,
            ["Width"] = "Anchor",
            ["Thickness"] = 2,
            ["ObjectType"] = "Sized",
            ["Height"] = "Anchor",
            ["Width2"] = 2,
            ["OffsetY"] = 0,
            ["AlignmentV"] = "CENTER",
        },
        ["HealthTexts"] = {
            ["Normal"] = {
                ["FontSize"] = 11,
                ["PaddingH"] = 4,
                ["Opacity"] = 100,
                ["OffsetX"] = 0,
                ["Anchor"] = "Health Bar",
                ["PaddingV"] = 4,
                ["AlignmentH"] = "CENTER",
                ["ObjectType"] = "Text",
                ["OffsetY"] = 2,
                ["AlignmentV"] = "CENTER",
            },
            ["Missing"] = {
                ["FontSize"] = 11,
                ["PaddingH"] = 2,
                ["Color"] = {
                    1,
                    0.4,
                    0.4,
                },
                ["Opacity"] = 100,
                ["OffsetX"] = 0,
                ["Anchor"] = "Health Bar",
                ["PaddingV"] = 0,
                ["AlignmentH"] = "RIGHT",
                ["ObjectType"] = "Text",
                ["OffsetY"] = 2,
                ["AlignmentV"] = "CENTER",
            },
            ["WithMissing"] = {
                ["FontSize"] = 11,
                ["PaddingH"] = 8,
                ["Opacity"] = 100,
                ["OffsetX"] = 0,
                ["Anchor"] = "Health Bar",
                ["PaddingV"] = 0,
                ["AlignmentH"] = "CENTER",
                ["ObjectType"] = "Text",
                ["OffsetY"] = 2,
                ["AlignmentV"] = "CENTER",
            },
        },
        ["OutOfRangeThreshold"] = {
            ["Friendly"] = 41,
            ["Hostile"] = 41,
        },
        ["HealthBarStyle"] = "Puppeteer", -- "Blizzard", "Blizzard Raid", "Puppeteer"
        ["Orientation"] = "Vertical", --"Vertical", "Horizontal"
        ["NotAlertedOpacity"] = 60,
        ["MinUnitsX"] = 0,
        ["PaddingBottom"] = 0,
        ["TrackedAurasSpacing"] = 1,
        ["HealthBarHeight"] = 36,
        ["EnemyHealthBarColor"] = "Green",
        ["BorderStyle"] = "Tooltip", -- "Tooltip", "Dialog Box", "Borderless"
        ["PaddingTop"] = 0,
        ["PowerBarHeight"] = 9,
        ["SplitRaidIntoGroups"] = true,
        ["MaxUnitsInAxis"] = 5,
        ["PowerBarStyle"] = "Puppeteer Borderless",
        ["FlashThreshold"] = 25,
        ["TrackAuras"] = true,
        ["TrackedAurasAlignment"] = "BOTTOM",
        ["ShowDebuffColorsOn"] = "Health Bar", -- "Health Bar", "Name", "Health", "Hidden"
        ["MinUnitsY"] = 0,
        ["MissingHealthInline"] = false,
        ["BarsOffsetY"] = 0,
        ["VerticalSpacing"] = 0,
        ["BackgroundOpacity"] = 25,
        ["LineOfSightIcon"] = {
            ["PaddingH"] = 4,
            ["Opacity"] = 80,
            ["OffsetX"] = 0,
            ["Anchor"] = "Health Bar",
            ["PaddingV"] = 4,
            ["AlignmentH"] = "CENTER",
            ["Width"] = 20,
            ["ObjectType"] = "Sized",
            ["Height"] = 20,
            ["OffsetY"] = 0,
            ["AlignmentV"] = "CENTER",
        },
        ["RaidMarkIcon"] = {
            ["PaddingH"] = 1,
            ["Opacity"] = 100,
            ["OffsetX"] = 0,
            ["Anchor"] = "Container",
            ["PaddingV"] = 1,
            ["AlignmentH"] = "RIGHT",
            ["Width"] = 12,
            ["ObjectType"] = "Sized",
            ["Height"] = 12,
            ["OffsetY"] = 0,
            ["AlignmentV"] = "TOP",
        },
    })
    ApplyOverrides("Default")

    CreateProfile("Default (Short Bar)", "Default", {
        ["AuraTracker"] = {
            ["Height"] = 13,
        },
        ["IncomingHealText"] = {
            ["PaddingV"] = 2,
            ["OffsetY"] = 0,
            ["AlignmentV"] = "TOP",
        },
        ["NameText"] = {
            ["Anchor"] = "Container",
            ["PaddingV"] = 0,
        },
        ["RangeText"] = {
            ["OffsetY"] = -4,
        },
        ["HealthTexts"] = {
            ["Missing"] = {
                ["OffsetY"] = 0,
                ["AlignmentV"] = "TOP",
            },
            ["Normal"] = {
                ["OffsetY"] = 0,
                ["PaddingV"] = 0,
                ["AlignmentV"] = "TOP",
            },
            ["WithMissing"] = {
                ["OffsetY"] = 0,
                ["AlignmentV"] = "TOP",
            },
        },
        ["PaddingTop"] = 12,
        ["HealthBarHeight"] = 24,
    })

    CreateProfile("Small", "Default", {
        ["AuraTracker"] = {
            ["Height"] = 12,
        },
        ["PowerText"] = {
            ["AlignmentH"] = "RIGHT",
        },
        ["RoleIcon"] = {
            ["Width"] = 12,
            ["Height"] = 12,
        },
        ["IncomingHealText"] = {
            ["FontSize"] = 7,
            ["AlignmentH"] = "RIGHT",
            ["OffsetY"] = -6,
        },
        ["NameText"] = {
            ["MaxWidth"] = 47,
        },
        ["Width"] = 67,
        ["PowerDisplay"] = "Hidden",
        ["RangeText"] = {
            ["FontSize"] = 8,
            ["OffsetY"] = -6,
        },
        ["HealthTexts"] = {
            ["Normal"] = {
                ["FontSize"] = 9,
            },
            ["Missing"] = {
                ["FontSize"] = 9,
                ["PaddingH"] = 4,
            },
            ["WithMissing"] = {
                ["FontSize"] = 9,
                ["PaddingH"] = 4,
                ["AlignmentH"] = "LEFT",
            },
        },
        ["PowerBarHeight"] = 6,
        ["LineOfSightIcon"] = {
            ["Opacity"] = 70,
        },
        ["RaidMarkIcon"] = {
            ["PaddingV"] = 0,
        },
    })

    CreateProfile("Very Small", "Default", {
        ["PVPIcon"] = {
            ["Width"] = 12,
            ["Height"] = 12,
        },
        ["AuraTracker"] = {
            ["Height"] = 11,
        },
        ["PowerText"] = {
            ["AlignmentH"] = "RIGHT",
        },
        ["RoleIcon"] = {
            ["Width"] = 10,
            ["Height"] = 10,
        },
        ["IncomingHealText"] = {
            ["FontSize"] = 7,
            ["AlignmentH"] = "RIGHT",
            ["OffsetY"] = -6,
        },
        ["NameText"] = {
            ["FontSize"] = 9,
            ["OffsetX"] = 6,
            ["AlignmentH"] = "LEFT",
            ["MaxWidth"] = 34,
        },
        ["Width"] = 50,
        ["MissingHealthDisplay"] = "Hidden",
        ["IncomingHealDisplay"] = "Hidden",
        ["PowerDisplay"] = "Hidden",
        ["RangeText"] = {
            ["FontSize"] = 7,
            ["OffsetY"] = -6,
        },
        ["HealthTexts"] = {
            ["Normal"] = {
                ["FontSize"] = 8,
                ["OffsetY"] = 1,
            },
            ["Missing"] = {
                ["FontSize"] = 13,
                ["PaddingH"] = 4,
                ["OffsetY"] = 0,
                ["AlignmentV"] = "BOTTOM",
            },
            ["WithMissing"] = {
                ["PaddingH"] = 4,
                ["AlignmentH"] = "RIGHT",
                ["OffsetY"] = 0,
                ["AlignmentV"] = "TOP",
            },
        },
        ["HealthBarHeight"] = 29,
        ["PowerBarHeight"] = 5,
        ["LineOfSightIcon"] = {
            ["Opacity"] = 70,
            ["Width"] = 16,
            ["Height"] = 16,
        },
        ["RaidMarkIcon"] = {
            ["PaddingV"] = 0,
            ["AlignmentH"] = "CENTER",
            ["Width"] = 10,
            ["Height"] = 10,
            ["OffsetY"] = 4,
        },
    })

    CreateProfile("Very Small (Horizontal)", "Very Small", {
        ["Orientation"] = "Horizontal"
    })

    do 
		local profile = CreateProfile("Less Small (Horizontal)", "Very Small")
		profile.Orientation = "Horizontal"
		profile.PowerBarHeight = 8
		profile.VerticalSpacing = 3
		profile.HorizontalSpacing = 3
		profile.Width = 65
		profile.HealthBarHeight = 25
		profile.HealthBarColor = "Class"
		profile.HealthBarStyle = "Blizzard Smooth"
		profile.PowerBarStyle = "Blizzard Smooth"
		profile.ShowDebuffColorsOn = "Hidden"
		profile.AuraTracker.Anchor = "Power Bar"
		profile.AuraTracker.OffsetY = 3
		
		profile.RoleIcon.Opacity = 0
		
		profile.RangeDirectionIcon.Anchor = "Health Bar"
		profile.RangeDirectionIcon.AlignmentH = "LEFT"
		profile.RangeDirectionIcon.AlignmentV = "CENTER"
		profile.RangeDirectionIcon.Opacity = 100
		profile.RangeDirectionIcon.OffsetX = 3
		profile.RangeDirectionIcon.OffsetY = 3
		profile.RangeDirectionIcon.Width = 6
		profile.RangeDirectionIcon.Height = 6
		
		profile.NameText.FontSize = 9
        profile.NameText.AlignmentH = "LEFT"
        profile.NameText.AlignmentV = "TOP"
        profile.NameText.PaddingV = 1
        profile.NameText.OffsetX = 6
		profile.NameText.OffsetY = 2
        profile.NameText.MaxWidth = 54
		profile.NameText.Color = "Default"
		
		local healthTexts = profile.HealthTexts
        healthTexts.Normal.FontSize = 9
        healthTexts.Normal.AlignmentH = "CENTER"
        healthTexts.Normal.AlignmentV = "CENTER"
        healthTexts.Normal.OffsetY = -2
        healthTexts.WithMissing.FontSize = 9
        healthTexts.WithMissing.AlignmentH = "LEFT"
        healthTexts.WithMissing.AlignmentV = "CENTER"
        healthTexts.WithMissing.OffsetY = -2
        healthTexts.Missing.FontSize = 9
        healthTexts.Missing.AlignmentH = "RIGHT"
        healthTexts.Missing.AlignmentV = "CENTER"
        healthTexts.Missing.OffsetY = -2
	end
	
	do 
		local profile = CreateProfile("Less Small (Vertical)", "Less Small (Horizontal)")
		profile.Orientation = "Vertical"
		profile.MaxUnitsInAxis = 4

		profile.PowerBarHeight = 8
		profile.VerticalSpacing = 3
		profile.HorizontalSpacing = 3
		profile.Width = 65
		profile.HealthBarHeight = 25
		profile.HealthBarColor = "Class"
		profile.HealthBarStyle = "Blizzard Smooth"
		profile.PowerBarStyle = "Blizzard Smooth"
		profile.ShowDebuffColorsOn = "Hidden"
		
		profile.NameText.FontSize = 9
        profile.NameText.AlignmentH = "LEFT"
        profile.NameText.AlignmentV = "TOP"
        profile.NameText.PaddingV = 1
        profile.NameText.OffsetX = 6
		profile.NameText.OffsetY = 2
        profile.NameText.MaxWidth = 54
		profile.NameText.Color = "Default"
		
		local healthTexts = profile.HealthTexts
        healthTexts.Normal.FontSize = 9
        healthTexts.Normal.AlignmentH = "CENTER"
        healthTexts.Normal.AlignmentV = "CENTER"
        healthTexts.Normal.OffsetY = -2
        healthTexts.WithMissing.FontSize = 9
        healthTexts.WithMissing.AlignmentH = "LEFT"
        healthTexts.WithMissing.AlignmentV = "CENTER"
        healthTexts.WithMissing.OffsetY = -2
        healthTexts.Missing.FontSize = 9
        healthTexts.Missing.AlignmentH = "RIGHT"
        healthTexts.Missing.AlignmentV = "CENTER"
        healthTexts.Missing.OffsetY = -2
	end

    CreateProfile("Long", "Default", {
        ["PVPIcon"] = {
            ["OffsetY"] = -5,
        },
        ["AuraTracker"] = {
            ["Anchor"] = "Container",
            ["AlignmentH"] = "CENTER",
            ["Height"] = 20,
        },
        ["PowerText"] = {
            ["FontSize"] = 10,
            ["AlignmentH"] = "RIGHT",
        },
        ["RoleIcon"] = {
            ["OffsetX"] = -5,
            ["PaddingV"] = 0,
            ["OffsetY"] = 5,
        },
        ["IncomingHealText"] = {
            ["PaddingH"] = 4,
            ["AlignmentH"] = "RIGHT",
            ["OffsetY"] = 0,
            ["AlignmentV"] = "BOTTOM",
        },
        ["NameText"] = {
            ["FontSize"] = 12,
            ["PaddingV"] = 4,
            ["AlignmentH"] = "LEFT",
            ["MaxWidth"] = 105,
            ["AlignmentV"] = "CENTER",
        },
        ["Width"] = 150,
        ["IncomingHealDisplay"] = "Hidden",
        ["RangeText"] = {
            ["OffsetY"] = 0,
            ["AlignmentV"] = "TOP",
        },
        ["HealthTexts"] = {
            ["Normal"] = {
                ["FontSize"] = 12,
                ["AlignmentH"] = "RIGHT",
                ["OffsetY"] = 0,
            },
            ["Missing"] = {
                ["FontSize"] = 13,
                ["PaddingH"] = 4,
                ["OffsetY"] = 0,
                ["AlignmentV"] = "BOTTOM",
            },
            ["WithMissing"] = {
                ["PaddingH"] = 4,
                ["AlignmentH"] = "RIGHT",
                ["OffsetY"] = 0,
                ["AlignmentV"] = "TOP",
            },
        },
        ["PaddingBottom"] = 20,
        ["TrackedAurasSpacing"] = 2,
        ["HealthBarHeight"] = 24,
        ["PowerBarHeight"] = 10,
        ["TrackedAurasAlignment"] = "TOP",
        ["LineOfSightIcon"] = {
            ["Anchor"] = "Button",
            ["Width"] = 24,
            ["Height"] = 24,
        },
        ["RaidMarkIcon"] = {
            ["PaddingV"] = 0,
            ["AlignmentH"] = "CENTER",
            ["Width"] = 14,
            ["Height"] = 14,
            ["OffsetY"] = 5,
        },
    })

    CreateProfile("Long (Small)", "Long", {
        ["AuraTracker"] = {
            ["Height"] = 16,
        },
        ["PowerText"] = {
            ["FontSize"] = 8,
        },
        ["RoleIcon"] = {
            ["OffsetX"] = -4,
            ["Width"] = 12,
            ["Height"] = 12,
        },
        ["NameText"] = {
            ["FontSize"] = 10,
            ["MaxWidth"] = 80,
        },
        ["Width"] = 120,
        ["HealthTexts"] = {
            ["Missing"] = {
                ["FontSize"] = 9,
            },
            ["Normal"] = {
                ["FontSize"] = 10,
            },
            ["WithMissing"] = {
                ["FontSize"] = 8,
            },
        },
        ["PaddingBottom"] = 16,
        ["PowerBarHeight"] = 8,
        ["HealthBarHeight"] = 16,
        ["RaidMarkIcon"] = {
            ["Width"] = 12,
            ["Height"] = 12,
        },
    })

    CreateProfile("Long (Integrated)", "Long", {
        ["AuraTracker"] = {
            ["Anchor"] = "Health Bar",
            ["AlignmentH"] = "LEFT",
            ["Width"] = 105,
            ["Height"] = 17,
        },
        ["RoleIcon"] = {
            ["OffsetY"] = 6,
        },
        ["NameText"] = {
            ["AlignmentV"] = "TOP",
        },
        ["HealthTexts"] = {
            ["Missing"] = {
                ["PaddingV"] = 4,
            },
            ["Normal"] = {
                ["AlignmentV"] = "TOP",
            },
            ["WithMissing"] = {
                ["FontSize"] = 12,
                ["PaddingV"] = 4,
            },
        },
        ["PaddingBottom"] = 0,
        ["TrackedAurasAlignment"] = "BOTTOM",
        ["HealthBarHeight"] = 35,
    })

    CreateProfile("Enemy", "Default", {
        ["PVPIcon"] = {
            ["OffsetX"] = -8,
            ["OffsetY"] = -4,
        },
        ["OutOfRangeThreshold"] = {
            ["Hostile"] = 31,
        },
        ["AuraTracker"] = {
            ["Height"] = 13,
        },
        ["RoleIcon"] = {
            ["OffsetX"] = -5,
            ["Width"] = 10,
            ["Height"] = 10,
            ["OffsetY"] = 5,
        },
        ["IncomingHealText"] = {
            ["FontSize"] = 7,
            ["AlignmentH"] = "RIGHT",
            ["OffsetY"] = -6,
        },
        ["NameText"] = {
            ["PaddingH"] = 1,
            ["AlignmentH"] = "LEFT",
            ["MaxWidth"] = 75,
            ["PaddingV"] = 2,
        },
        ["Width"] = 120,
        ["ShowDistanceThreshold"] = {
            ["Hostile"] = 20,
        },
        ["MissingHealthDisplay"] = "Hidden",
        ["PowerDisplay"] = "Hidden",
        ["RangeText"] = {
            ["FontSize"] = 10,
            ["OffsetY"] = 2,
            ["AlignmentV"] = "BOTTOM",
        },
        ["HealthTexts"] = {
            ["Missing"] = {
                ["FontSize"] = 9,
                ["PaddingH"] = 4,
            },
            ["Normal"] = {
                ["PaddingH"] = 1,
                ["AlignmentH"] = "RIGHT",
                ["OffsetY"] = 0,
                ["PaddingV"] = 2,
                ["AlignmentV"] = "TOP",
            },
            ["WithMissing"] = {
                ["FontSize"] = 9,
                ["PaddingH"] = 4,
                ["AlignmentH"] = "LEFT",
            },
        },
        ["PowerText"] = {
            ["AlignmentH"] = "RIGHT",
        },
        ["LineOfSightIcon"] = {
            ["Opacity"] = 70,
        },
        ["MaxUnitsInAxis"] = 10,
        ["PowerBarHeight"] = 0,
        ["HealthBarHeight"] = 29,
        ["RaidMarkIcon"] = {
            ["AlignmentH"] = "CENTER",
            ["OffsetY"] = 2,
            ["PaddingV"] = 0,
        },
    })

    CreateProfile("Enemy (Small)", "Enemy", {
        ["AuraTracker"] = {
            ["Height"] = 12,
        },
        ["NameText"] = {
            ["FontSize"] = 9,
            ["MaxWidth"] = 60,
        },
        ["Width"] = 100,
        ["HealthTexts"] = {
            ["Normal"] = {
                ["FontSize"] = 9,
            },
        },
        ["HealthBarHeight"] = 24,
    })

    CreateProfile("Legacy", "Default", {
        ["PVPIcon"] = {
            ["OffsetY"] = -4,
        },
        ["AuraTracker"] = {
            ["Anchor"] = "Container",
            ["AlignmentH"] = "CENTER",
            ["Height"] = 20,
        },
        ["PowerText"] = {
            ["FontSize"] = 10,
            ["AlignmentH"] = "RIGHT",
        },
        ["RoleIcon"] = {
            ["AlignmentH"] = "RIGHT",
            ["Width"] = 16,
            ["Height"] = 16,
        },
        ["IncomingHealText"] = {
            ["PaddingH"] = 4,
            ["OffsetY"] = 0,
        },
        ["NameText"] = {
            ["FontSize"] = 12,
            ["Anchor"] = "Container",
            ["PaddingV"] = 4,
            ["AlignmentH"] = "LEFT",
            ["MaxWidth"] = 200,
        },
        ["Width"] = 200,
        ["HealthDisplay"] = "Health/Max Health",
        ["PowerDisplay"] = "Hidden",
        ["RangeText"] = {
            ["OffsetY"] = 0,
            ["AlignmentV"] = "TOP",
        },
        ["HealthTexts"] = {
            ["Normal"] = {
                ["FontSize"] = 12,
                ["OffsetY"] = 0,
            },
            ["Missing"] = {
                ["FontSize"] = 13,
                ["PaddingH"] = 4,
                ["OffsetY"] = 0,
                ["AlignmentV"] = "BOTTOM",
            },
            ["WithMissing"] = {
                ["PaddingH"] = 4,
                ["AlignmentH"] = "RIGHT",
                ["OffsetY"] = 0,
                ["AlignmentV"] = "TOP",
            },
        },
        ["HealthBarStyle"] = "Blizzard",
        ["PaddingBottom"] = 20,
        ["TrackedAurasSpacing"] = 2,
        ["HealthBarHeight"] = 25,
        ["BorderStyle"] = "Hidden",
        ["PaddingTop"] = 20,
        ["PowerBarHeight"] = 5,
        ["PowerBarStyle"] = "Blizzard",
        ["TrackedAurasAlignment"] = "TOP",
        ["MissingHealthInline"] = true,
        ["LineOfSightIcon"] = {
            ["Anchor"] = "Button",
            ["Width"] = 24,
            ["Height"] = 24,
        },
        ["RaidMarkIcon"] = {
            ["OffsetX"] = -18,
            ["Width"] = 16,
            ["Height"] = 16,
        },
    })
end