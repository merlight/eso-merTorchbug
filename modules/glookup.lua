local tbug = LibStub:GetLibrary("merTorchbug")
local strfind = string.find
local strmatch = string.match
local strsub = string.sub

local DEBUG = 1

local mtEnum = {__index = function(_, v) return v end}
local g_enums = setmetatable({}, tbug.autovivify(mtEnum))
local g_needRefresh = true
local g_objects = {}
local g_tmpGroups = setmetatable({}, tbug.autovivify(nil))
local g_tmpKeys = {}

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


local function makeEnum2(group, k1, v1, prefix)
    if DEBUG >= 2 then
        if type(k1) == "string" then
            df("tbug: enum %q, %s, %q", k1, v1, prefix)
        else
            df("tbug: enum %s, %s, %q", tostring(k1), v1, prefix)
        end
    end

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

    if k1 ~= nil then
        prefix = longestCommonPrefix(g_tmpKeys, "^(.*[^_]_).")
        if DEBUG >= 2 then
            if type(prefix) == "string" then
                df(".. lcp %q", prefix)
            else
                df(".. lcp %s", prefix)
            end
        end
    end

    if not prefix or numKeys < 2 then
        return nil
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
    if prefix then
        g_tmpGroups[prefix][k] = v
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
    tbug.foreachValue(g_enums, ZO_ClearTable)
    tbug.foreachValue(g_tmpGroups, ZO_ClearTable)

    for k, v in zo_insecureNext, _G do
        if type(k) == "string" then
            local mapFunc = typeMappings[type(v)]
            if mapFunc then
                mapFunc(k, v)
            end
        end
    end

    doRefreshLib("LibStub", LibStub)
    for libName, lib in next, LibStub.libs do
        doRefreshLib(libName, lib)
    end

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

    makeEnum2(g_tmpGroups["ABILITY_"],  nil, 1, "ABILITY_SLOT_TYPE_")
    makeEnum2(g_tmpGroups["ACTION_"],   nil, 1, "ACTION_RESULT_")
    makeEnum2(g_tmpGroups["ACTIVE_"],   nil, 1, "ACTIVE_COMBAT_TIP_COLOR_")
    makeEnum2(g_tmpGroups["ACTIVE_"],   nil, 1, "ACTIVE_COMBAT_TIP_RESULT_")
    makeEnum2(g_tmpGroups["CHAT_"],     nil, 1, "CHAT_CATEGORY_HEADER_")
    makeEnum2(g_tmpGroups["EVENT_"],    nil, 1, "EVENT_REASON_")
    makeEnum2(g_tmpGroups["MOUSE_"],    nil, 1, "MOUSE_CONTENT_")
    makeEnum2(g_tmpGroups["MOUSE_"],    nil, 1, "MOUSE_CURSOR_")
    makeEnum2(g_tmpGroups["STAT_"],     nil, 1, "STAT_BONUS_OPTION_")
    makeEnum2(g_tmpGroups["STAT_"],     nil, 1, "STAT_SOFT_CAP_OPTION_")
    makeEnum2(g_tmpGroups["STAT_"],     nil, 1, "STAT_VALUE_COLOR_")
    makeEnum2(g_tmpGroups["TRADE_"],    nil, 1, "TRADE_ACTION_RESULT_")

    for prefix, group in next, g_tmpGroups do
        repeat
            local final = true
            for k, v in next, group do
                -- find the shortest prefix that yields distinct values
                local p, f = prefix, false
                while not makeEnum2(group, k, v, p) do
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
