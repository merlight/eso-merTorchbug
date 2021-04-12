local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")
local cm = CALLBACK_MANAGER

local firstToUpper = tbug.firstToUpper

------------------------------------------------------------------------------------------------------------------------
local defaults =
{
    interfaceColors =
    {
        tabWindowBackground                  = "hsla(60, 10, 20, 0.5)",
        tabWindowPanelBackground             = "rgba(0, 0, 0, 0.6)",
        tabWindowTitleBackground_TOPLEFT     = "rgba(0, 0, 0, 0.3)",
        tabWindowTitleBackground_TOPRIGHT    = "rgba(0, 0, 0, 0.2)",
        tabWindowTitleBackground_BOTTOMLEFT  = "rgba(0, 0, 0, 0.6)",
        tabWindowTitleBackground_BOTTOMRIGHT = "rgba(0, 0, 0, 0.5)",
    },
    typeColors =
    {
        ["nil"]      = "hsl(120, 50, 70)",
        ["boolean"]  = "hsl(120, 50, 70)",
        ["event"]    = "hsl(60, 90, 70)",
        ["number"]   = "hsl(120, 50, 70)",
        ["string"]   = "hsl(30, 90, 70)",
        ["function"] = "hsl(270, 90, 80)",
        ["table"]    = "hsl(210, 90, 75)",
        ["userdata"] = "hsl(0, 0, 75)",
        ["obsolete"] = "hsl(0, 100, 50)", --red
        ["comment"]  = "hsl(0, 0, 100)" --white
    },
    scriptHistory = {},
    scriptHistoryComments = {},
    searchHistory = {}
}
tbug.svDefaults = defaults

local function copyDefaults(dst, src)
    for k, v in next, src do
        local dk = dst[k]
        local tv = type(v)
        if tv == "table" then
            if type(dk) == "table" then
                copyDefaults(dk, v)
            else
                dst[k] = copyDefaults({}, v)
            end
        elseif type(dk) ~= tv then
            dst[k] = v
        end
    end
    return dst
end


------------------------------------------------------------------------------------------------------------------------
tbug.savedVars = tbug.savedVars or {}

function tbug.savedTable(...)
    return tbug.subtable(tbug.savedVars, ...)
end

function tbug.initSavedVars()
    local allowedSlashCommandsForPanels = {
        ["-all-"] = true,
    }
    local allowedSlashCommandsForPanelsLookup = {}
    for idx, panelData in ipairs(tbug.panelNames) do
        allowedSlashCommandsForPanels[panelData.slashCommand] = true
        if panelData.lookup ~= nil then
            allowedSlashCommandsForPanelsLookup[panelData.lookup] = idx
        else
            allowedSlashCommandsForPanelsLookup[firstToUpper(panelData.slashCommand)] = idx
        end

        --Search history in SV
        defaults.searchHistory[panelData.key] = {}
        for searchIdx, _ in ipairs(tbug.filterModes) do
            defaults.searchHistory[panelData.key][searchIdx] = {}
        end
    end
    tbug.allowedSlashCommandsForPanels = allowedSlashCommandsForPanels
    tbug.allowedSlashCommandsForPanelsLookup = allowedSlashCommandsForPanelsLookup

    if merTorchbugSavedVars then
        tbug.savedVars = merTorchbugSavedVars
    else
        merTorchbugSavedVars = tbug.savedVars
    end

    copyDefaults(tbug.savedVars, defaults)
    tbug.initColorTable("interfaceColors",  "tbugChanged:interfaceColor")
    tbug.initColorTable("typeColors",       "tbugChanged:typeColor")

    cm:RegisterCallback("tbugChanged:interfaceColor", function(key, color)
        tbug.interfaceColorChanges:FireCallbacks(key, color)
    end)
end

------------------------------------------------------------------------------------------------------------------------
function tbug.saveSearchHistoryEntry(panelKey, searchMode, value)
    if not panelKey or not searchMode then return end
    tbug.savedVars.searchHistory = tbug.savedVars.searchHistory or {}
    tbug.savedVars.searchHistory[panelKey] = tbug.savedVars.searchHistory[panelKey] or {}
    tbug.savedVars.searchHistory[panelKey][searchMode] = tbug.savedVars.searchHistory[panelKey][searchMode] or {}
    --Check if the value is already in the history
    for _,v in ipairs(tbug.savedVars.searchHistory[panelKey][searchMode]) do
        if v == value then return end
    end
    table.insert(tbug.savedVars.searchHistory[panelKey][searchMode], 1, value)
    if #tbug.savedVars.searchHistory[panelKey][searchMode] > 20 then
        table.remove(tbug.savedVars.searchHistory[panelKey][searchMode], 20)
    end
end

function tbug.loadSearchHistoryEntry(panelKey, searchMode)
    if not panelKey or not searchMode then return end
    if tbug.savedVars.searchHistory and tbug.savedVars.searchHistory[panelKey] then
        return tbug.savedVars.searchHistory[panelKey][searchMode]
    end
    return nil
end

function tbug.clearSearchHistory(panelKey, searchMode, idx)
    if not panelKey or not searchMode then return end
    if tbug.savedVars.searchHistory and tbug.savedVars.searchHistory[panelKey] and
        tbug.savedVars.searchHistory[panelKey][searchMode] then
        if idx == nil then
            tbug.savedVars.searchHistory[panelKey][searchMode] = {}
        elseif tbug.savedVars.searchHistory[panelKey][searchMode][idx] ~= nil then
            tbug.savedVars.searchHistory[panelKey][searchMode][idx] = nil
        end
    end
    return nil
end