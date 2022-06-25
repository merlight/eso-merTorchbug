local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")

local tos = tostring
local strfind = string.find
local strmatch = string.match
local strsub = string.sub
local EsoStrings = EsoStrings

local DEBUG = 1
local SI_LAST = SI_NONSTR_INGAMESHAREDSTRINGS_LAST_ENTRY

local g_nonEnumPrefixes = tbug.nonEnumPrefixes

local mtEnum = {__index = function(_, v) return v end}
local g_enums = setmetatable({}, tbug.autovivify(mtEnum))
tbug.enums = g_enums
local g_needRefresh = true
local g_objects = {}
local g_tmpGroups = setmetatable({}, tbug.autovivify(nil))
local g_tmpKeys = {}
local g_tmpStringIds = {}
tbug.tmpGroups = g_tmpGroups

local keyToEnums = {
    ["point"]                   = "AnchorPosition",
    ["relativePoint"]           = "AnchorPosition",
    ["type"]                    = "CT_names",
    ["parent"]                  = "CT_names",
    ["relativeTo"]              = "CT_names",
    ["layer"]                   = "DL_names",
    ["tier"]                    = "DT_names",
    ["bagId"]                   = "Bags",
    ["bag"]                     = "Bags",
}
tbug.keyToEnums = keyToEnums

local keyToSpecialEnumTmpGroupKey = {
    ["bagId"]                   = "BAG_",
    ["functionalQuality"]       = "ITEM_",
    ["displayQuality"]          = "ITEM_",
    ["equipType"]               = "EQUIP_",
    ["itemType"]                = "ITEMTYPE_",
    ["quality"]                 = "ITEM_",
    ["specializedItemType"]     = "SPECIALIZED_",
    ["traitInformation"]        = "ITEM_",
}
local keyToSpecialEnumExclude = {
    ["traitInformation"]        = {"ITEM_TRAIT_TYPE_CATEGORY_"},
}

--These entries will "record" all created subTables in function makeEnum so that one can combine them later on in
--g_enums["SPECIALIZED_ITEMTYPE"] again for 1 consistent table with all entries
local keyToSpecialEnumNoSubtablesInEnum = {
    ["SPECIALIZED_ITEMTYPE_"]        = true,
}
local specialEnumNoSubtables_subTables = {}
--tbug._specialEnumNoSubtables_subTables = specialEnumNoSubtables_subTables

local keyToSpecialEnum = {
    --Special key entries at tableInspector
    ["bagId"]                   = "BAG_",
    ["functionalQuality"]       = "ITEM_FUNCTIONAL_QUALITY_",
    ["displayQuality"]          = "ITEM_DISPLAY_QUALITY_",
    ["equipType"]               = "EQUIP_TYPE_",
    ["itemType"]                = "ITEMTYPE_",
    ["quality"]                 = "ITEM_QUALITY_",
    ["specializedItemType"]     = "SPECIALIZED_ITEMTYPE_",
    ["traitInformation"]        = "ITEM_TRAIT_TYPE_",
}
tbug.keyToSpecialEnum = keyToSpecialEnum

local isSpecialInspectorKey = {}
for k,_ in pairs(keyToSpecialEnum) do
    isSpecialInspectorKey[k] = true
end
tbug.isSpecialInspectorKey = isSpecialInspectorKey


local function isIterationOrMinMaxConstant(stringToSearch)
    local stringsToFind = {
        ["_MIN_VALUE"]          = -11,
        ["_MAX_VALUE"]          = -11,
        ["_ITERATION_BEGIN"]    = -17,
        ["_ITERATION_END"]      = -15,
    }
    for searchStr, offsetFromEnd in pairs(stringsToFind) do
        if strfind(stringToSearch, searchStr, offsetFromEnd, true) ~= nil then
            return true
        end
    end
    return false
end

local function longestCommonPrefix(tab, pat)
    local key, val = next(tab)
    local lcp = val and strmatch(val, pat)

    if not lcp then
        return nil
    end

    if DEBUG >= 2 then
        df("... lcp start %q => %q", val, lcp)
    end

    for key, val in next, tab, key do
        while strfind(val, lcp, 1, true) ~= 1 do
            lcp = strmatch(lcp, pat)
            if not lcp then
                return nil
            end
            if DEBUG >= 2 then
                df("... lcp cut %q", lcp)
            end
        end
    end
    return lcp
end

local function getPrefix(k)
    return strmatch(k, "^([A-Z][A-Z0-9]*_)[_A-Z0-9]*$")
end
tbug.getPrefix = getPrefix

local function makeEnum(group, prefix, minKeys, calledFromTmpGroupsLoop)
    ZO_ClearTable(g_tmpKeys)

    local numKeys = 0
    for k2, v2 in next, group do
        if strfind(k2, prefix, 1, true) == 1 then
            if g_tmpKeys[v2] == nil then
                g_tmpKeys[v2] = k2
                numKeys = numKeys + 1
            else
                -- duplicate value
                return nil
            end
        end
    end

    if minKeys then
        if numKeys < minKeys then
            return nil
        end
        prefix = longestCommonPrefix(g_tmpKeys, "^(.*[^_]_).")
        if not prefix then
            return nil
        end
    end

    local prefixWithoutLastUnderscore = strsub(prefix, 1, -2)
    local enum = g_enums[prefixWithoutLastUnderscore]
    for v2, k2 in next, g_tmpKeys do
        enum[v2] = k2
        g_tmpKeys[v2] = nil
        --IMPORTANT: remove g_tmpGroups constant entry (set = nil) here -> to prevent endless loop in calling while . do
        group[k2] = nil
    end

    --Is the while not makeEnum(group, p, 2, true) do run on tmpGroups actually active?
    if calledFromTmpGroupsLoop then
        --Is the current prefix a speical one which could be split into multiple subTables at g_enums?
        --And should these split subTables be combined again to one in the end, afer tthe while ... do loop was finished?
        for prefixRecordAllSubtables, isActivated in pairs(keyToSpecialEnumNoSubtablesInEnum) do
            if isActivated and strfind(prefix, prefixRecordAllSubtables, 1) == 1 then
--d(">anti-split into subtables found: " ..tos(prefix))
                specialEnumNoSubtables_subTables[prefixRecordAllSubtables] = specialEnumNoSubtables_subTables[prefixRecordAllSubtables] or {}
                table.insert(specialEnumNoSubtables_subTables[prefixRecordAllSubtables], prefixWithoutLastUnderscore)
            end
        end
    end

    return enum
end

local function makeEnumWithMinMaxAndIterationExclusion(group, prefix, key)
--d("==========================================")
--d("[TBUG]makeEnumWithMinMaxAndIterationExclusion - prefix: " ..tos(prefix) .. ", group: " ..tos(group) .. ", key: " ..tos(key))
    ZO_ClearTable(g_tmpKeys)

    local keyToSpecialEnumExcludeEntries = keyToSpecialEnumExclude[key]

    local goOn = true
    for k2, v2 in next, group do
        local strFoundPos = strfind(k2, prefix, 1, true)
--d(">k: " ..tos(k2) .. ", v: " ..tos(v2) .. ", pos: " ..tos(strFoundPos))
        if strFoundPos ~= nil then
            --Exclude _MIN_VALUE and _MAX_VALUE
            if isIterationOrMinMaxConstant(k2) == false then
                if keyToSpecialEnumExcludeEntries ~= nil then
                    for _, vExclude in ipairs(keyToSpecialEnumExcludeEntries) do
                        if strfind(k2, vExclude, 1, true) == 1 then
--d("<<excluded: " ..tos(k2))
                            goOn = false
                            break
                        end
                    end
                end
                if goOn then
                    if g_tmpKeys[v2] == nil then
--d(">added value: " ..tos(v2) .. ", key: " ..tos(k2))
                        g_tmpKeys[v2] = k2
                    else
--d("<<<<<<<<<duplicate value: " ..tos(v2))
                        -- duplicate value
                        return nil
                    end
                end
            --else
--d("<<<<<--------------------------")
--d("<<iterationOrMinMax")
            end
        end
    end

    if goOn then
--d("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")

        local prefixWithoutLastUnderscore = strsub(prefix, 1, -2)
        local enum = g_enums[prefixWithoutLastUnderscore]
        for v2, k2 in next, g_tmpKeys do
--d(">prefix w/o last _: " .. tos(prefixWithoutLastUnderscore)  ..", added v2: " .. tos(v2) .. " with key: " ..tos(k2) .." to enum"  )
            enum[v2] = k2
            group[k2] = nil
            g_tmpKeys[v2] = nil
        end
        return enum
    end
end

local function mapEnum(k, v)
    local prefix = getPrefix(k)
    local skip = g_nonEnumPrefixes[prefix]

    if skip ~= nil then
        if skip == true then
            prefix = strmatch(k, "^([A-Z][A-Z0-9]*_[A-Z0-9]+_)")
        elseif strfind(k, skip) then
            return
        end
    end

    if prefix then
        g_tmpGroups[prefix][k] = v
        if v > SI_LAST and EsoStrings[v] then
            if g_tmpStringIds[v] ~= nil then
                g_tmpStringIds[v] = false
            else
                g_tmpStringIds[v] = k
            end
        end
    end
end


local function mapObject(k, v)
    if g_objects[v] == nil then
        g_objects[v] = k
    else
        g_objects[v] = false
    end
end


local typeMappings = {
    ["number"]      = mapEnum,
    ["table"]       = mapObject,
    ["userdata"]    = mapObject,
    ["function"]    = mapObject,
}


local function doRefreshLib(lname, ltab)
    for k, v in next, ltab do
        if type(k) == "string" then
            local mapFunc = typeMappings[type(v)]
            if mapFunc then
                mapFunc(lname .. "." .. k, v)
            end
        end
    end
end

local function doRefresh()
--d("[TBUG]doRefresh")
    ZO_ClearTable(g_objects)
    ZO_ClearTable(g_tmpStringIds)
    tbug.foreachValue(g_enums, ZO_ClearTable)
    tbug.foreachValue(g_tmpGroups, ZO_ClearTable)

    for k, v in zo_insecureNext, _G do
        if type(k) == "string" then
            --TODO: Libraries without LibStub: Check for global variables starting with "Lib" or "LIB"


            local mapFunc = typeMappings[type(v)]
            if mapFunc then
                mapFunc(k, v)
            end
        end
    end

    --Libraries: With deprecated LibStub
    if LibStub and LibStub.libs then
        doRefreshLib("LibStub", LibStub)
        for libName, lib in next, LibStub.libs do
            doRefreshLib(libName, lib)
        end
    end

    local enumAnchorPosition = g_enums[keyToEnums["point"]]
    enumAnchorPosition[BOTTOM] = "BOTTOM"
    enumAnchorPosition[BOTTOMLEFT] = "BOTTOMLEFT"
    enumAnchorPosition[BOTTOMRIGHT] = "BOTTOMRIGHT"
    enumAnchorPosition[CENTER] = "CENTER"
    enumAnchorPosition[LEFT] = "LEFT"
    enumAnchorPosition[NONE] = "NONE"
    enumAnchorPosition[RIGHT] = "RIGHT"
    enumAnchorPosition[TOP] = "TOP"
    enumAnchorPosition[TOPLEFT] = "TOPLEFT"
    enumAnchorPosition[TOPRIGHT] = "TOPRIGHT"

    local enumControlTypes = g_enums[keyToEnums["type"]]
    enumControlTypes[CT_INVALID_TYPE] = "CT_INVALID_TYPE"
    enumControlTypes[CT_CONTROL] = "CT_CONTROL"
    enumControlTypes[CT_LABEL] = "CT_LABEL"
    enumControlTypes[CT_DEBUGTEXT] = "CT_DEBUGTEXT"
    enumControlTypes[CT_TEXTURE] = "CT_TEXTURE"
    enumControlTypes[CT_TOPLEVELCONTROL] = "CT_TOPLEVELCONTROL"
    enumControlTypes[CT_ROOT_WINDOW] = "CT_ROOT_WINDOW"
    enumControlTypes[CT_TEXTBUFFER] = "CT_TEXTBUFFER"
    enumControlTypes[CT_BUTTON] = "CT_BUTTON"
    enumControlTypes[CT_STATUSBAR] = "CT_STATUSBAR"
    enumControlTypes[CT_EDITBOX] = "CT_EDITBOX"
    enumControlTypes[CT_COOLDOWN] = "CT_COOLDOWN"
    enumControlTypes[CT_TOOLTIP] = "CT_TOOLTIP"
    enumControlTypes[CT_SCROLL] = "CT_SCROLL"
    enumControlTypes[CT_SLIDER] = "CT_SLIDER"
    enumControlTypes[CT_BACKDROP] = "CT_BACKDROP"
    enumControlTypes[CT_MAPDISPLAY] = "CT_MAPDISPLAY"
    enumControlTypes[CT_COLORSELECT] = "CT_COLORSELECT"
    enumControlTypes[CT_LINE] = "CT_LINE"
    enumControlTypes[CT_COMPASS] = "CT_COMPASS"
    enumControlTypes[CT_TEXTURECOMPOSITE] = "CT_TEXTURECOMPOSITE"
    enumControlTypes[CT_POLYGON] = "CT_POLYGON"

    local enumDrawLayer = g_enums[keyToEnums["layer"]]
    enumDrawLayer[DL_BACKGROUND]    = "DL_BACKGROUND"
    enumDrawLayer[DL_CONTROLS]      = "DL_CONTROLS"
    enumDrawLayer[DL_OVERLAY]       = "DL_OVERLAY"
    enumDrawLayer[DL_TEXT]          = "DL_TEXT"

    local enumDrawTier = g_enums[keyToEnums["tier"]]
    enumDrawTier[DT_LOW]    = "DT_LOW"
    enumDrawTier[DT_MEDIUM] = "DT_MEDIUM"
    enumDrawTier[DT_HIGH]   = "DT_HIGH"
    enumDrawTier[DT_PARENT] = "DT_PARENT"


    local enumTradeParticipant = g_enums["TradeParticipant"]
    enumTradeParticipant[TRADE_ME]      = "TRADE_ME"
    enumTradeParticipant[TRADE_THEM]    = "TRADE_THEM"

    local enumBags = g_enums[keyToEnums["bagId"]]
    enumBags[BAG_WORN]              = "BAG_WORN"
    enumBags[BAG_BACKPACK]          = "BAG_BACKPACK"
    enumBags[BAG_BANK]              = "BAG_BANK"
    enumBags[BAG_GUILDBANK]         = "BAG_GUILDBANK"
    enumBags[BAG_BUYBACK]           = "BAG_BUYBACK"
    enumBags[BAG_VIRTUAL]           = "BAG_VIRTUAL"
    enumBags[BAG_SUBSCRIBER_BANK]   = "BAG_SUBSCRIBER_BANK"
    enumBags[BAG_HOUSE_BANK_ONE]    = "BAG_HOUSE_BANK_ONE"
    enumBags[BAG_HOUSE_BANK_TWO]    = "BAG_HOUSE_BANK_TWO"
    enumBags[BAG_HOUSE_BANK_THREE]  = "BAG_HOUSE_BANK_THREE"
    enumBags[BAG_HOUSE_BANK_FOUR]   = "BAG_HOUSE_BANK_FOUR"
    enumBags[BAG_HOUSE_BANK_FIVE]   = "BAG_HOUSE_BANK_FIVE"
    enumBags[BAG_HOUSE_BANK_SIX]    = "BAG_HOUSE_BANK_SIX"
    enumBags[BAG_HOUSE_BANK_SEVEN]  = "BAG_HOUSE_BANK_SEVEN"
    enumBags[BAG_HOUSE_BANK_EIGHT]  = "BAG_HOUSE_BANK_EIGHT"
    enumBags[BAG_HOUSE_BANK_NINE]   = "BAG_HOUSE_BANK_NINE"
    enumBags[BAG_HOUSE_BANK_TEN]    = "BAG_HOUSE_BANK_TEN"
    enumBags[BAG_COMPANION_WORN]    = "BAG_COMPANION_WORN"


    -- some enumerations share prefix with other unrelated constants,
    -- making them difficult to isolate;
    -- extract these known trouble-makers explicitly
    makeEnum(g_tmpGroups["ANIMATION_"],     "ANIMATION_PLAYBACK_")
    makeEnum(g_tmpGroups["ATTRIBUTE_"],     "ATTRIBUTE_BAR_STATE_")
    makeEnum(g_tmpGroups["ATTRIBUTE_"],     "ATTRIBUTE_TOOLTIP_COLOR_")
    makeEnum(g_tmpGroups["ATTRIBUTE_"],     "ATTRIBUTE_VISUAL_")
    makeEnum(g_tmpGroups["BUFF_"],          "BUFF_TYPE_COLOR_")
    makeEnum(g_tmpGroups["CD_"],            "CD_TIME_TYPE_")
    makeEnum(g_tmpGroups["CHAT_"],          "CHAT_CATEGORY_HEADER_")
    makeEnum(g_tmpGroups["EVENT_"],         "EVENT_REASON_")
    makeEnum(g_tmpGroups["GAME_"],          "GAME_CREDITS_ENTRY_TYPE_")
    makeEnum(g_tmpGroups["GAME_"],          "GAME_NAVIGATION_TYPE_")
    makeEnum(g_tmpGroups["GUILD_"],         "GUILD_HISTORY_ALLIANCE_WAR_")
    makeEnum(g_tmpGroups["INVENTORY_"],     "INVENTORY_UPDATE_REASON_")
    makeEnum(g_tmpGroups["JUSTICE_"],       "JUSTICE_SKILL_")
    makeEnum(g_tmpGroups["MOVEMENT_"],      "MOVEMENT_CONTROLLER_DIRECTION_")
    makeEnum(g_tmpGroups["NOTIFICATIONS_"], "NOTIFICATIONS_MENU_OPENED_FROM_")
    makeEnum(g_tmpGroups["OBJECTIVE_"],     "OBJECTIVE_CONTROL_EVENT_")
    makeEnum(g_tmpGroups["OBJECTIVE_"],     "OBJECTIVE_CONTROL_STATE_")
    makeEnum(g_tmpGroups["OPTIONS_"],       "OPTIONS_CUSTOM_SETTING_")
    makeEnum(g_tmpGroups["PPB_"],           "PPB_CLASS_")
    makeEnum(g_tmpGroups["RIDING_"],        "RIDING_TRAIN_SOURCE_")
    makeEnum(g_tmpGroups["STAT_"],          "STAT_BONUS_OPTION_")
    makeEnum(g_tmpGroups["STAT_"],          "STAT_SOFT_CAP_OPTION_")
    makeEnum(g_tmpGroups["STAT_"],          "STAT_VALUE_COLOR_")
    makeEnum(g_tmpGroups["TRADING_"],       "TRADING_HOUSE_SORT_LISTING_")


    --Transfer the tmpGroups of constants to the enumerations table, using the tmpGroups prefix e.g. SPECIALIZED_ and
    --checking for + creating subTables like SPECIALIZED_ITEMTYPE etc.
    --Enum entries at least need 2 constants entries in the g_tmpKeys or it will fail to create a new subTable
    for prefix, group in next, g_tmpGroups do
        repeat
            local final = true
            for k, _ in next, group do
                -- find the shortest prefix that yields distinct values
                local p, f = prefix, false
                --Make the enum entry now and remove g_tmpGroups constant entry (set = nil) -> to prevent endless loop!
                while not makeEnum(group, p, 2, true) do
                    --Creates subTables at "_", e.g. SPECIALIZED_ITEMTYPE, SPECIALIZED_ITEMTYP_ARMOR, ...
                    local _, me = strfind(k, "[^_]_", #p + 1)
                    if not me then
                        f = final
                        break
                    end
                    p = strsub(k, 1, me)
                end
                final = f
            end
        until final
    end

    --Create the 1table for splitUp sbtables like SPECIALIZED_ITEMTYPE_ again now, from all of the relevant subTables
    if specialEnumNoSubtables_subTables and not ZO_IsTableEmpty(specialEnumNoSubtables_subTables) then
        for prefixWhichGotSubtables, subtableNames in pairs(specialEnumNoSubtables_subTables) do
            local prefixWithoutLastUnderscore = strsub(prefixWhichGotSubtables, 1, -2)
--d(">>combining subtables to 1 table: " ..tos(prefixWithoutLastUnderscore))
            g_enums[prefixWithoutLastUnderscore] = g_enums[prefixWithoutLastUnderscore] or {}
            for _, subTablePrefixWithoutUnderscore in ipairs(subtableNames) do
--d(">>>subtable name: " ..tos(subTablePrefixWithoutUnderscore))
                local subTableData = g_enums[subTablePrefixWithoutUnderscore]
                if subTableData ~= nil then
                    for constantValue, constantName in pairs(subTableData) do
--d(">>>>copied constant from subtable: " ..tos(constantName) .. " (" .. tos(constantValue) ..")")
                        if type(constantName) == "string" then
                            g_enums[prefixWithoutLastUnderscore][constantValue] = constantName
                        end
                    end
                end
            end
        end
    end

    --For the Special cRightKey entries at tableInspector
    local alreadyCheckedValues = {}
    for k, v in pairs(keyToSpecialEnum) do
        if not alreadyCheckedValues[v] then
            alreadyCheckedValues[v] = true
            local tmpGroupEntry = keyToSpecialEnumTmpGroupKey[k]
            local selectedTmpGroupTable = g_tmpGroups[tmpGroupEntry]
            if selectedTmpGroupTable ~= nil then
                makeEnumWithMinMaxAndIterationExclusion(selectedTmpGroupTable, v, k)
            end
        end
    end

    local enumStringId = g_enums["SI"]
    for v, k in next, g_tmpStringIds do
        if k then
            enumStringId[v] = k
        end
    end


    --Prepare the entries for the filterCombobox at the global inspector
    tbug.filterComboboxFilterTypesPerPanel = {}
    local filterComboboxFilterTypesPerPanel = tbug.filterComboboxFilterTypesPerPanel
    --"AddOns" panel
    filterComboboxFilterTypesPerPanel[1] = nil
    --"Classes" panel
    filterComboboxFilterTypesPerPanel[2] = nil
    --"Objects" panel
    filterComboboxFilterTypesPerPanel[3] = nil
    --"Controls" panel
    filterComboboxFilterTypesPerPanel[4] = ZO_ShallowTableCopy(g_enums[keyToEnums["type"]]) --CT_CONTROL, at "controls" tab
    --"Fonts" panel
    filterComboboxFilterTypesPerPanel[5] = nil
    --"Functions" panel
    filterComboboxFilterTypesPerPanel[6] = nil
    --"Constants" panel
    filterComboboxFilterTypesPerPanel[7] = nil
    --"Strings" panel
    filterComboboxFilterTypesPerPanel[8] = nil
    --"Sounds" panel
    filterComboboxFilterTypesPerPanel[9] = nil
    --"Dialogs" panel
    filterComboboxFilterTypesPerPanel[10] = nil
    --"Scenes" panel
    filterComboboxFilterTypesPerPanel[11] = nil
    --"Libs" panel
    filterComboboxFilterTypesPerPanel[12] = nil
    --"Scripts" panel
    filterComboboxFilterTypesPerPanel[13] = nil
    --"SV" panel
    filterComboboxFilterTypesPerPanel[14] = nil

    g_needRefresh = false
end


if DEBUG >= 1 then
    doRefresh = tbug.timed("tbug: glookupRefresh", doRefresh)
end


function tbug.glookup(obj)
    if g_needRefresh then
        doRefresh()
    end
    return g_objects[obj]
end


function tbug.glookupEnum(prefix)
    if g_needRefresh then
        doRefresh()
    end
    return g_enums[prefix]
end


function tbug.glookupRefresh(now)
    if now then
        doRefresh()
    else
        g_needRefresh = true
    end
end
