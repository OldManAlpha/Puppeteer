PTLocale = {}
PTUtil.SetEnvironment(PTLocale)
local compost = AceLibrary("Compost-2.0")

Translations = nil

-- Set to true to enable the ability to dump all things that need translations
local EXPORT_MODE = false

function SetTranslations(translations)
    Translations = translations

    if not EXPORT_MODE then
        -- Non-English version
        function Translate(str)
            return Translations[str] or str
        end
        T = Translate
    end
end

function IsUsingTranslations()
    return Translations ~= nil or EXPORT_MODE
end

-- English version
function Translate(str)
    return str
end

if EXPORT_MODE then
    NeedsTranslation = {}

    function Translate(str)
        if not PTUtil.ArrayContains(NeedsTranslation, str) then
            table.insert(NeedsTranslation, str)
        end
        return Translations and Translations[str] or str
    end

    -- /run PTLocale.ExportNeedsTranslate()
    function ExportNeedsTranslate()
        local needsTranslate = table.concat(NeedsTranslation, "\n")
        ExportFile("NeedsTranslate", needsTranslate)
    end
end

T = Translate

function Keys(set)
    if not IsUsingTranslations() then
        return
    end
    local toInsert = compost:GetTable()
    for key, value in pairs(set) do
        local translated = Translate(key)
        if translated then
            set[key] = nil
            toInsert[Translate(key)] = value
        end
    end
    for key, value in pairs(toInsert) do
        set[key] = value
    end
    compost:Reclaim(toInsert)
end

function Values(table)
    if not IsUsingTranslations() then
        return
    end
    for key, value in pairs(table) do
        table[key] = Translate(value)
    end
end

function KeysValues(table)
    if not IsUsingTranslations() then
        return
    end
    local toInsert = compost:GetTable()
    for key, value in pairs(table) do
        local translated = Translate(key)
        if translated then
            table[key] = nil
            toInsert[translated] = Translate(value)
        end
    end
    for key, value in pairs(toInsert) do
        table[key] = value
    end
    compost:Reclaim(toInsert)
end

function Array(array)
    if not IsUsingTranslations() then
        return
    end
    for i, value in ipairs(array) do
        array[i] = Translate(value)
    end
end