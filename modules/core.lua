local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")

--Track merTorchbug load time and session time
local startTimeTimeStamp = GetTimeStamp()
TBUG.startTimeTimeStamp = startTimeTimeStamp
local startTime = startTimeTimeStamp * 1000
TBUG.sessionStartTime = startTime - GetGameTimeMilliseconds()
TBUG.startTime = startTime

local EM = EVENT_MANAGER

local getmetatable = getmetatable
local next = next
local rawget = rawget
local rawset = rawset
local select = select
local setmetatable = setmetatable
local tostring = tostring
local type = type

local rtSpecialReturnValues = tbug.RTSpecialReturnValues

------------------------------------------------------------------------------------------------------------------------
local function throttledCall(callbackName, timer, callback, ...)
    if not callbackName or callbackName == "" or not callback then return end
    local args
    if ... ~= nil then
        args = {...}
    end
    local function Update()
        EM:UnregisterForUpdate(callbackName)
        if args then
            callback(unpack(args))
        else
            callback()
        end
    end
    EM:UnregisterForUpdate(callbackName)
    EM:RegisterForUpdate(callbackName, timer, Update)
end
tbug.throttledCall = throttledCall

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
local function inherit(class, base)
    getmetatable(class).__index = base
    return class
end


local function new(class, ...)
    local instance = setmetatable({}, class)
    return instance, instance:__init__(...)
end


local function newClass(dict, name)
    local classMT = {__call = new, __concat = inherit}
    local class = {}
    rawset(class, "__index", class)
    rawset(dict, name, class)
    return setmetatable(class, classMT)
end


tbug.classes = setmetatable({}, {__index = newClass})


function tbug.autovivify(mt)
    local function setdefault(self, key)
        local sub = setmetatable({}, mt)
        rawset(self, key, sub)
        return sub
    end
    return {__index = setdefault}
end


tbug.cache = setmetatable({}, tbug.autovivify(nil))


function tbug.bind1(func, arg1)
    return function(...)
        return func(arg1, ...)
    end
end


function tbug.bind2(func, arg1, arg2)
    return function(...)
        return func(arg1, arg2, ...)
    end
end


function tbug.foreach(tab, func)
    for key, val in next, tab do
        func(key, val)
    end
end


function tbug.foreachValue(tab, func)
    for key, val in next, tab do
        func(val)
    end
end


function tbug.gettype(tab, key)
    local mt = getmetatable(tab)
    if mt then
        local gettype = mt._tbug_gettype
        if gettype then
            return gettype(tab, key)
        end
    end
    return type(rawget(tab, key))
end


function tbug.setindex(tab, key, val)
    local mt = getmetatable(tab)
    if mt then
        local setindex = mt._tbug_setindex
        if setindex then
            setindex(tab, key, val)
            return rawget(tab, key)
        end
    end
    rawset(tab, key, val)
    return val
end


function tbug.subtable(tab, ...)
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        local sub = tab[key]
        if type(sub) ~= "table" then
            sub = {}
            tab[key] = sub
        end
        tab = sub
    end
    return tab
end


do
    local function tail(name, t1, ...)
        local t2 = GetGameTimeMilliseconds()
        df("%s took %.3fms", name, t2 - t1)
        return ...
    end

    function tbug.timed(name, func)
        return function(...)
            local t1 = GetGameTimeMilliseconds()
            return tail(name, t1, func(...))
        end
    end
end


function tbug.truncate(tab, len)
    for i = #tab, len + 1, -1 do
        tab[i] = nil
    end
    return tab
end

local typeOrder =
{
    ["nil"] = 0,
    ["boolean"] = 1,
    ["number"] = 2,
    ["string"] = 3,
    ["table"] = 4,
    ["userdata"] = 5,
    ["function"] = 6,
}

setmetatable(typeOrder,
{
    __index = function(t, k)
        df("tbug: typeOrder[%q] undefined", tostring(k))
        return -1
    end
})

local typeCompare =
{
    ["nil"] = function(a, b) return false end,
    ["boolean"] = function(a, b) return not a and b end,
    ["number"] = function(a, b) return a < b end,
    ["string"] = function(a, b)
        local _, na = a:find("^_*")
        local _, nb = b:find("^_*")
        if na ~= nb then
            return na > nb
        else
            return a < b
        end
    end,
    ["table"] = function(a, b) return tostring(a) < tostring(b) end,
    ["userdata"] = function(a, b) return tostring(a) < tostring(b) end,
    ["function"] = function(a, b) return tostring(a) < tostring(b) end,
}

function tbug.typeSafeLess(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then
        return typeOrder[ta] < typeOrder[tb]
    else
        return typeCompare[ta](a, b)
    end
end

function tbug.firstToUpper(str)
    return (str:gsub("^%l", string.upper))
end

function tbug.startsWith(str, start)
    if str == nil or start == nil or start  == "" then return false end
    return str:sub(1, #start) == start
end

function tbug.endsWith(str, ending)
    if str == nil or ending == nil or ending  == "" then return false end
    return ending == "" or str:sub(-#ending) == ending
end

local getStringKeys = tbug.getStringKeys
local function isGetStringKey(key)
    return getStringKeys[key] or false
end
tbug.isGetStringKey = isGetStringKey



--Get a property of a control in the TorchBugControlInspector list, at index indexInList, and the name should be propName
function tbug.getPropOfControlAtIndex(listWithProps, indexInList, propName, searchWholeList)
    if not listWithProps or not indexInList or not propName or propName == "" then return end
    searchWholeList = searchWholeList or false
    local listEntryAtIndex = listWithProps[indexInList]
    if listEntryAtIndex then
        local listEntryAtIndexData = listEntryAtIndex.data
        if listEntryAtIndexData then
            if (listEntryAtIndexData.prop and listEntryAtIndexData.prop.name and listEntryAtIndexData.prop.name == propName) or
             (listEntryAtIndexData.data and listEntryAtIndexData.data.key and listEntryAtIndexData.data.key == propName) then
                return listEntryAtIndexData.value
            else
                --The list is not control inspector and thus the e.g. bagId and slotIndex are not next to each other, so we
                --need to search the whole list for the propName
                if searchWholeList == true then
                    for _, propData in ipairs(listWithProps) do
                        if (propData.prop and propData.prop.name and propData.prop.name == propName) or
                            (propData.data and propData.data.key and propData.data.key == propName) then
                            return propData.data and propData.data.value
                        end
                    end
                end
            end
        end
    end
    return nil
end

local specialEntriesAtInspectorLists = tbug.specialEntriesAtInspectorLists
local function isSpecialEntryAtInspectorList(entry)
    local specialKeys = specialEntriesAtInspectorLists
    return specialKeys[entry] or false
end

--Check if the number at the currently clicked row at the controlInspectorList is a special number
--like a pair of bagid and slotIndex
function tbug.isSpecialEntryAtInspectorList(p_self, p_row, p_data)
    if not p_self or not p_row or not p_data then return end
    local props = p_data.prop
    if not props then

        --Check if it's not a control but another type having only a key
        if p_data.key then
            props = {}
            props.isSpecial = isSpecialEntryAtInspectorList(p_data.key)
        end
    end
    if not props then return end
    return props.isSpecial or false
end

local function returnTextAfterLastDot(str)
    local strAfterLastDot = str:match("[^%.]+$")
    return strAfterLastDot
end

--Try to get the key of the object (the string behind the last .)
function tbug.getKeyOfObject(objectStr)
    if objectStr and objectStr ~= "" then
        return returnTextAfterLastDot(objectStr)
    end
    return nil
end

--Clean the key of a key String (remove trailing () or [])
function tbug.cleanKey(keyStr)
    if keyStr == nil or keyStr == "" then return end
    if not tbug.endsWith(keyStr, "()") and not tbug.endsWith(keyStr, "[]") then return keyStr end
    local retStr = keyStr:sub(1, (keyStr:len()-2))
    return retStr
end

local inventoryRowPatterns = tbug.inventoryRowPatterns
--Is the control an inventory list row? Check by it's name pattern
function tbug.isSupportedInventoryRowPattern(controlName)
    if not controlName then return false, nil end
    if not inventoryRowPatterns then return false, nil end
    for _, patternToCheck in ipairs(inventoryRowPatterns) do
        if controlName:find(patternToCheck) ~= nil then
            return true, patternToCheck
        end
    end
    return false, nil
end

function tbug.formatTime(timeStamp)
    return os.date("%F %T.%%03.0f %z", timeStamp / 1000):format(timeStamp % 1000)
end

--Get the zone and subZone string from the given map's tile texture (or the current's map's tile texture name)
function tbug.getZoneInfo(mapTileTextureName, patternToUse)
--[[
    Possible texture names are e.g.
    /art/maps/southernelsweyr/els_dragonguard_island05_base_8.dds
    /art/maps/murkmire/tsofeercavern01_1.dds
    /art/maps/housing/blackreachcrypts.base_0.dds
    /art/maps/housing/blackreachcrypts.base_1.dds
    Art/maps/skyrim/blackreach_base_0.dds
    Textures/maps/summerset/alinor_base.dds
]]
    mapTileTextureName = mapTileTextureName or GetMapTileTexture()
    if not mapTileTextureName or mapTileTextureName == "" then return end
    local mapTileTextureNameLower = mapTileTextureName:lower()
    mapTileTextureNameLower = mapTileTextureNameLower:gsub("ui_map_", "")
    --mapTileTextureNameLower = mapTileTextureNameLower:gsub(".base", "_base")
    --mapTileTextureNameLower = mapTileTextureNameLower:gsub("[_+%d]*%.dds$", "") -> Will remove the 01_1 at the end of tsofeercavern01_1
    mapTileTextureNameLower = mapTileTextureNameLower:gsub("%.dds$", "")
    mapTileTextureNameLower = mapTileTextureNameLower:gsub("_%d*$", "")
    local regexData = {}
    if not patternToUse or patternToUse == "" then patternToUse = "([%/]?.*%/maps%/)(%w+)%/(.*)" end
    regexData = {mapTileTextureNameLower:find(patternToUse)} --maps/([%w%-]+/[%w%-]+[%._][%w%-]+(_%d)?)
    local zoneName, subzoneName = regexData[4], regexData[5]
    local zoneId = GetZoneId(GetCurrentMapZoneIndex())
    local parentZoneId = GetParentZoneId(zoneId)
    d("========================================\n[TBUG.getZoneInfo]\nzone: " ..tostring(zoneName) .. ", subZone: " .. tostring(subzoneName) .. "\nmapTileTexture: " .. tostring(mapTileTextureNameLower).."\nzoneId: " ..tostring(zoneId).. ", parentZoneId: " ..tostring(parentZoneId))
    return zoneName, subzoneName, mapTileTextureNameLower, zoneId, parentZoneId
end

--Check if not the normal data.key should be returned (and used for e.g. a string search or the RAW string copy context
-- menu) but any other of the data entries (e.g. data.value._eventName for the "Events" tab)
local function checkForSpecialDataEntryAsKey(data)
    local key = data.key
    local dataEntry = data.dataEntry
    local typeId = dataEntry.typeId
    local specialPlaceWhereTheStringsIsFound = rtSpecialReturnValues[typeId]
    if specialPlaceWhereTheStringsIsFound ~= nil then
        local funcToGetStr, err = zo_loadstring("return data." .. specialPlaceWhereTheStringsIsFound)
        if err ~= nil or not funcToGetStr then
            return key
        else
            local filterEnv = setmetatable({}, {__index = tbug.env})
            setfenv(funcToGetStr, filterEnv)
            filterEnv.data = data
            local isOkay
            isOkay, key = pcall(funcToGetStr)
            if not isOkay then return key end
        end
    end
    return key
end
tbug.checkForSpecialDataEntryAsKey = checkForSpecialDataEntryAsKey

------------------------------------------------------------------------------------------------------------------------



--Create list of TopLevelControls (boolean parameter onlyVisible: only add visible, or all TLCs)
function ListTLC(onlyVisible)
    onlyVisible = onlyVisible or false
    local res = {}
    if GuiRoot then
        for i = 1, GuiRoot:GetNumChildren() do
            local doAdd = false
            local c = GuiRoot:GetChild(i)
            if c then
                if onlyVisible then
                    if not c.IsHidden or (c.IsHidden and not c:IsHidden()) then
                        doAdd = true
                    end
                else
                    doAdd = true
                end
                if doAdd then
                    res[i] = c
                end
            end
        end
    end
    return res
end