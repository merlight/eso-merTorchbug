local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")

local strfor = string.format
local tos= tostring

-- Watchpoints: Inspect variable changes -> Only works for table variables via set- and getmetatable
--found here
--https://stackoverflow.com/questions/59492946/change-update-value-of-a-local-variable-lua-upvalue
--->Enhanded by IsJustAGhost 2022-02-08 in esoui gitter. With his permission "go ahead" using his code example and enhancing it to the needs

--The stored table references where watchpoints are added
local watchpointTables = {}
tbug.watchpointTables = watchpointTables
--The watchpoints (variable names) per table
local watchpoints = {}
tbug.watchpoints = watchpoints

--Ignore these table keys inside the callback funtion of setmetatable index
local ignoreTableKeysForMetatables = {
   ["RegisterCallback"] =                   true,
   ["UnregisterCallback"] =                 true,
   ["_tbugWatchpoint_callbackFunctions"] =  true,
   ["_tbugWatchpoint_onChangeOnly"] =       true,
   ["_tbugWatchpoint_tableRef"] =           true
}

--Metatable index check table: Calling the updateFunction if any value changes in that table's key
local function onNewTableIndex(tabRef, key, value)
    if not ignoreTableKeysForMetatables[key] then
d("[TBUG]onNewTableIndex - key: " ..tos(key) .. ", value: " ..tos(value))
        --Do not fire the callback if no value was changed?
        if tabRef._tbugWatchpoint_onChangeOnly[key] == true and tabRef[key] == value then return end
        --Get the callack function for the value
        local updateFunction = tabRef._tbugWatchpoint_callbackFunctions[key]
        if updateFunction ~= nil then
            updateFunction(key, value, tabRef)
        end
    end
    --Call the original index function of the table, via the getmetatable
    getmetatable(tabRef).__index[key] = value
end

local function variableChangedOutput(key, value, tableRef)
    d(strfor("[TBUG]Watchpoint on {%s}: %q=%s", tos(tableRef), tos(key), tos(value)))
end

local function addWatchpointCallbackHandler(tableRef)
    --Do not add another reference for the callback register/unregister to the same table
    if watchpointTables[tableRef] ~= nil then
d("<existing watchpoint table handler was found")
        return watchpointTables[tableRef]
    end
    if getmetatable(tableRef) ~= nil then
d(">the table already uses a metatable! Aborting")
        return false
    end
d(">adding new watchpoint table handler now")

    --Add function "onNewIndex" that fires each time as any index in tableRef changes and store that into a reference to the metatable of the table to watch
    local callbackHandlerForWatchedTableVariable = setmetatable({}, { __newindex = onNewTableIndex, __index = tableRef}) --use the entries of passed in table, at same index. Call onNewTableIndex if an inde get's added
    if callbackHandlerForWatchedTableVariable == nil then return end
    watchpointTables[tableRef] = callbackHandlerForWatchedTableVariable
    watchpoints[tableRef] = watchpoints[tableRef] or {}

    --Add callback register and unregister functions to that
    function callbackHandlerForWatchedTableVariable:RegisterCallback(name, callbackFunction, onChangeOnly)
d(">>>ADD Callback on table watchpoint: Register on variable: " ..tos(name))
        self._tbugWatchpoint_tableRef = self._tbugWatchpoint_tableRef or tableRef
        if self._tbugWatchpoint_tableRef[name] == nil then return false end

        self._tbugWatchpoint_callbackFunctions = self._tbugWatchpoint_callbackFunctions or {}
        self._tbugWatchpoint_callbackFunctions[name] = callbackFunction
        watchpoints[tableRef][name] = { onChangeOnly = onChangeOnly, callbackFunc = callbackFunction }

        --Remember which variable of the table should only fire a changed callback if the value really changed
        self._tbugWatchpoint_onChangeOnly = self._tbugWatchpoint_onChangeOnly or {}
        self._tbugWatchpoint_onChangeOnly[name] = onChangeOnly or false
    end

    function callbackHandlerForWatchedTableVariable:UnregisterCallback(name)
d(">>>REM Callback on table watchpoint: Register on variable: " ..tos(name))
        local lTableRef = self._tbugWatchpoint_tableRef
        if lTableRef ~= nil and self._tbugWatchpoint_callbackFunctions ~= nil and self._tbugWatchpoint_callbackFunctions[name] ~= nil then
            self._tbugWatchpoint_callbackFunctions[name] = nil
            watchpoints[lTableRef][name] = nil

            --Check how many variables are still tracked at the table and remove the metatable again if 0
            if NonContiguousCount(watchpoints[lTableRef]) == 0 then
                --The metatable is not at the lTableRef but it is at callbackHandlerForWatchedTableVariable -> self
                if getmetatable(self) ~= nil then
                    setmetatable(self, nil)
                end
                watchpoints[lTableRef] = nil
                --Nil "callbackHandlerForWatchedTableVariable but delayed so that it will not error as we are in one
                --of it's own functions!
                zo_callLater(function() watchpointTables[lTableRef] = nil end, 10)
            end
            return true
        end
        return false
    end
    return callbackHandlerForWatchedTableVariable
end

local function removeWatchpointFrom(tableRef, variableName)
d("[TBUG]removeWatchpointFrom]tab: " ..tos(tableRef)..", var: " ..tos(variableName))
    local callbackHandlerForTableRef = watchpointTables[tableRef]
    if not callbackHandlerForTableRef then return false end
    return callbackHandlerForTableRef:UnregisterCallback(variableName)
end
tbug.RemoveTableVariableWatchpoint = removeWatchpointFrom

local function addWatchpointTo(tableRef, variableName, onChangeOnly, callbackFunction)
d("[TBUG]addWatchpointTo]tab: " ..tos(tableRef)..", var: " ..tos(variableName) .. ", onChangeOnly: " ..tos(onChangeOnly))
    if onChangeOnly == nil then onChangeOnly = true end
    if callbackFunction == nil then callbackFunction = variableChangedOutput end
    if (tableRef == nil and _G[tableRef] == nil) or variableName == nil then return end
    local tableRefType = type(tableRef)
    local isTableRefString = tableRefType == "string"
    if not isTableRefString and tableRef ~= nil then
d(">1")
        if tableRefType ~= "table" and tableRefType ~= "userdata" then return end
        if tableRef[variableName] == nil then return end
    elseif isTableRefString == true and _G[tableRef] ~= nil then
d(">2")
        tableRefType = type(_G[tableRef])
        if tableRefType ~= "table" and tableRefType ~= "userdata" then return end
        if _G[tableRef][variableName] == nil then return end
d(">3")
        tableRef = _G[tableRef]
    end
    if tableRef == nil then return false end
    --Watchpoint was already added?
    if watchpoints[tableRef] ~= nil then
d(">>4")
        --Remove it again
        if watchpoints[tableRef][variableName] ~= nil then
d("<<<5")
            return removeWatchpointFrom(tableRef, variableName)
        end
    end
d(">6")
    --Add new callbackHandler to the table, via setmetatable
    local callbackHandlerForTableRef = addWatchpointCallbackHandler(tableRef)
    if not callbackHandlerForTableRef then return end
    --Register a new callback handler to the table's variable change
    return callbackHandlerForTableRef:RegisterCallback(variableName, callbackFunction, onChangeOnly)
end
tbug.AddTableVariableWatchpoint = addWatchpointTo



--CallbackVariable:RegisterCallback('foo', callbackFunction, UpdateIfValuesDifferOnly)
--CallbackVariable:RegisterCallback('bar', callbackFunction)
--CallbackVariable.foo = 'bar' -- fires callback
--CallbackVariable.foo = 'bar' -- does not fire callback
--CallbackVariable.foo = 'change' -- fires callback
--CallbackVariable.bar = 'foo'-- fires callback

--CallbackVariable:UnregisterCallback('bar')

--CallbackVariable.bar = 'foo' -- does not fire callback
------------------------------------------------------------------------------------------------------------------------