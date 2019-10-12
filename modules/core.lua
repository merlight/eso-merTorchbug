TBUG = {}
local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")
local getmetatable = getmetatable
local next = next
local rawget = rawget
local rawset = rawset
local select = select
local setmetatable = setmetatable
local tostring = tostring
local type = type

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

--LibCustomMenu custom context menu "OnClick" handling function for inspector row context menu entries
function tbug.setEditValueFromContextMenu(p_self, p_row, p_data, p_oldValue)
--df("tbug:setEditValueFromContextMenu")
    if p_self and p_row and p_data and p_oldValue ~= nil and p_oldValue ~= p_data.value then
        p_self.editData = p_data
        local editBox = p_self.editBox
        if editBox then
            local newVal
            if p_data.value == nil then
                newVal = ""
            else
                newVal = tostring(p_data.value)
            end
            if editBox then
                editBox:SetText(newVal)
                p_row.cVal:SetText(newVal)
                if editBox.panel and editBox.panel.valueEditConfirm then
                    editBox.panel:valueEditConfirm(editBox)
                end
            end
        end
    end
    ClearMenu()
end

--LibCustomMenu custom context menu entry creation for inspector rows
function tbug.buildRowContextMenuData(p_self, p_row, p_data)
    if LibCustomMenu ~= nil and p_self and p_row and p_data then
        if p_data.value ~= nil then
            local valType = type(p_data.value)
            if valType == "boolean" then
                local oldValue = p_data.value
                ClearMenu()
                AddCustomMenuItem("- false", function() p_data.value = false tbug.setEditValueFromContextMenu(p_self, p_row, p_data, oldValue) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                AddCustomMenuItem("+ true",  function() p_data.value = true  tbug.setEditValueFromContextMenu(p_self, p_row, p_data, oldValue) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                AddCustomMenuItem("   NIL",  function() p_data.value = nil  tbug.setEditValueFromContextMenu(p_self, p_row, p_data, oldValue) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                ShowMenu(p_row)
            end
        end
    end
end

