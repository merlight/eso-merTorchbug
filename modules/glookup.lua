local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")
local strfind = string.find
local strmatch = string.match
local strsub = string.sub
local EsoStrings = EsoStrings

local DEBUG = 1
local SI_LAST = SI_NONSTR_INGAMESHAREDSTRINGS_LAST_ENTRY

local g_nonEnumPrefixes =
{
    ["ABILITY_"] = true,
    ["ACTION_"] = true,
    ["ACTIVE_"] = "_SETTING_ID$",
    ["COLLECTIBLE_"] = true,
    ["GAMEPAD_"] = true,
    ["GROUP_"] = true,
    ["INFAMY_"] = true,
    ["MAIL_"] = true,
    ["QUEST_"] = true,
    ["RAID_"] = true,
    ["STAT_"] = "^STAT_STATE_",
    ["TRADE_"] = true,
    ["TUTORIAL_"] = true,
    ["UI_"] = true,
    ["VOICE_"] = "^VOICE_CHAT_REQUEST_DELAY$",
}

local mtEnum = {__index = function(_, v) return v end}
local g_enums = setmetatable({}, tbug.autovivify(mtEnum))
tbug.g_enums = g_enums
local g_needRefresh = true
local g_objects = {}
local g_tmpGroups = setmetatable({}, tbug.autovivify(nil))
local g_tmpKeys = {}
local g_tmpStringIds = {}

tbug.enums = g_enums


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


local function makeEnum(group, prefix, minKeys)
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

    local enum = g_enums[strsub(prefix, 1, -2)]
    for v2, k2 in next, g_tmpKeys do
        enum[v2] = k2
        group[k2] = nil
        g_tmpKeys[v2] = nil
    end
    return enum
end


local function mapEnum(k, v)
    local prefix = strmatch(k, "^([A-Z][A-Z0-9]*_)[_A-Z0-9]*$")
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
    ["number"] = mapEnum,
    ["table"] = mapObject,
    ["userdata"] = mapObject,
    ["function"] = mapObject,
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

    local enumControlTypes = g_enums["CT_names"]
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

    local enumAnchorPosition = g_enums["AnchorPosition"]
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

    local enumTradeParticipant = g_enums["TradeParticipant"]
    enumTradeParticipant[TRADE_ME] = "TRADE_ME"
    enumTradeParticipant[TRADE_THEM] = "TRADE_THEM"

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

    for prefix, group in next, g_tmpGroups do
        repeat
            local final = true
            for k, v in next, group do
                -- find the shortest prefix that yields distinct values
                local p, f = prefix, false
                while not makeEnum(group, p, 2) do
                    local ms, me = strfind(k, "[^_]_", #p + 1)
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

    local enumStringId = g_enums["SI"]
    for v, k in next, g_tmpStringIds do
        if k then
            enumStringId[v] = k
        end
    end

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
