local tbug = SYSTEMS:GetSystem("merTorchbug")
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
