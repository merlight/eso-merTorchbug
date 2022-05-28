local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")

local strfind = string.find
local strformat = string.format
local strlower = string.lower
local strmatch = string.match
local tos = tostring

local throttledCall = tbug.throttledCall
local strsplit = tbug.strSplit

local classes = tbug.classes
local BasicInspector = classes.BasicInspector
local GlobalInspector = classes.GlobalInspector .. BasicInspector
local TextButton = classes.TextButton

local checkForSpecialDataEntryAsKey = tbug.checkForSpecialDataEntryAsKey
local isAControlOfType = tbug.isAControlOfType
local filterModes = tbug.filterModes

--------------------------------
local function getFilterMode(selfVar)
    --Get the active search mode
    return selfVar.filterModeButton:getId()
end

local function getActiveTabName(selfVar)
    --Get the globalInspectorObject and the active tab name
    local globalInspectorObject = selfVar or tbug.getGlobalInspector()
    if not globalInspectorObject then return end
    local panels = globalInspectorObject.panels
    if not panels then return end
    local activeTab = globalInspectorObject.activeTab
    if not activeTab then return end
    local activeTabName = activeTab.label:GetText()
    return activeTabName, globalInspectorObject
end

local function getSearchHistoryData(globalInspectorObject)
    --Get the active search mode
    local activeTabName
    activeTabName, globalInspectorObject = getActiveTabName(globalInspectorObject)
    local filterMode = getFilterMode(globalInspectorObject)
    return globalInspectorObject, filterMode, activeTabName
end


local function updateSearchHistoryContextMenu(editControl, globalInspectorObject)
    local filterMode, activeTabName
    globalInspectorObject, filterMode, activeTabName = getSearchHistoryData(globalInspectorObject)
    if not activeTabName or not filterMode then return end
    local searchHistoryForPanelAndMode = tbug.loadSearchHistoryEntry(activeTabName, filterMode)
    --local isSHNil = (searchHistoryForPanelAndMode == nil) or false
    if searchHistoryForPanelAndMode ~= nil and #searchHistoryForPanelAndMode > 0 then
        --Clear the context menu
        ClearMenu()
        --Search history
        local filterModeStr = filterModes[filterMode]
        if MENU_ADD_OPTION_HEADER ~= nil then
            AddCustomMenuItem(strformat("- Search history \'%s\' -", tos(filterModeStr)), function() end, MENU_ADD_OPTION_HEADER)
        else
            AddCustomMenuItem("-", function() end)
        end
        for _, searchTerm in ipairs(searchHistoryForPanelAndMode) do
            if searchTerm ~= nil and searchTerm ~= "" then
                AddCustomMenuItem(searchTerm, function()
                    editControl.doNotRunOnChangeFunc = true
                    editControl:SetText(searchTerm)
                    globalInspectorObject:updateFilter(editControl, filterMode)
                end)
            end
        end
        --Actions
        AddCustomMenuItem("-", function() end)
        if MENU_ADD_OPTION_HEADER ~= nil then
            AddCustomMenuItem(strformat("Actions", tos(filterModeStr)), function() end, MENU_ADD_OPTION_HEADER)
        end
        --Delete entry
        local subMenuEntriesForDeletion = {}
        for searchEntryIdx, searchTerm in ipairs(searchHistoryForPanelAndMode) do
            local entryForDeletion =
            {
                label = strformat("Delete \'%s\'", tos(searchTerm)),
                callback = function()
                    tbug.clearSearchHistory(activeTabName, filterMode, searchEntryIdx)
                end,
            }
            table.insert(subMenuEntriesForDeletion, entryForDeletion)
        end
        AddCustomSubMenuItem("Delete entry", subMenuEntriesForDeletion)
        --Clear whole search history
        AddCustomMenuItem("Clear whole history", function() tbug.clearSearchHistory(activeTabName, filterMode) end)
        --Show the context menu
        ShowMenu(editControl)
    end
end

local function saveNewSearchHistoryContextMenuEntry(editControl, globalInspectorObject)
    if not editControl then return end
    local searchText = editControl:GetText()
    if not searchText or searchText == "" then return end
    local filterMode, activeTabName
    globalInspectorObject, filterMode, activeTabName = getSearchHistoryData(globalInspectorObject)
    if not activeTabName or not filterMode then return end
    tbug.saveSearchHistoryEntry(activeTabName, filterMode, searchText)
end

--------------------------------

function tbug.getGlobalInspector(doNotCreate)
    doNotCreate = doNotCreate or false
    local inspector = tbug.globalInspector
    if not inspector and doNotCreate == false then
        inspector = GlobalInspector(1, tbugGlobalInspector)
        tbug.globalInspector = inspector
    end
    return inspector
end

--------------------------------
-- class GlobalInspectorPanel --
local TableInspectorPanel = classes.TableInspectorPanel
local GlobalInspectorPanel = classes.GlobalInspectorPanel .. TableInspectorPanel

GlobalInspectorPanel.CONTROL_PREFIX = "$(parent)PanelG"
GlobalInspectorPanel.TEMPLATE_NAME = "tbugTableInspectorPanel"

local RT = tbug.RT


function GlobalInspectorPanel:buildMasterList()
    self:buildMasterListSpecial()
end

---------------------------
-- class GlobalInspector --

function GlobalInspector:__init__(id, control)
    control.isGlobalInspector = true
    BasicInspector.__init__(self, id, control)

    self.conf = tbug.savedTable("globalInspector" .. id)
    self:configure(self.conf)

    self.title:SetText("GLOBALS")

    self.filterColorGood = ZO_ColorDef:New(118/255, 188/255, 195/255)
    self.filterColorBad = ZO_ColorDef:New(255/255, 153/255, 136/255)

    self.filterButton = control:GetNamedChild("FilterButton")
    self.filterEdit = control:GetNamedChild("FilterEdit")
    self.filterEdit:SetColor(self.filterColorGood:UnpackRGBA())

    self.filterEdit.doNotRunOnChangeFunc = false
    self.filterEdit:SetHandler("OnTextChanged", function(editControl)
        --local filterMode = self.filterModeButton:getText()
        if editControl.doNotRunOnChangeFunc == true then return end
        local mode = self.filterModeButton:getId()
        self:updateFilter(editControl, mode, nil)
    end)

    self.filterEdit:SetHandler("OnMouseUp", function(editControl, mouseButton, upInside, shift, ctrl, alt, command)
        if mouseButton == MOUSE_BUTTON_INDEX_RIGHT and upInside then
            --Show context menu with the last saved searches (search history)
            updateSearchHistoryContextMenu(editControl, self)
        end
    end)

    --The search mode buttons
    local mode = 1
    self.filterModeButton = TextButton(control, "FilterModeButton")
    self.filterModeButton:fitText(filterModes[mode])
    self.filterModeButton:enableMouseButton(MOUSE_BUTTON_INDEX_RIGHT)
    self.filterModeButton:setId(mode)
    self.filterModeButton.onClicked[MOUSE_BUTTON_INDEX_LEFT] = function()
        mode = mode < #filterModes and mode + 1 or 1
        local filterModeStr = filterModes[mode]
        self.filterModeButton:fitText(filterModeStr, 4)
        self.filterModeButton:setId(mode)
        self:updateFilter(self.filterEdit, mode, filterModeStr)
    end
    self.filterModeButton.onClicked[MOUSE_BUTTON_INDEX_RIGHT] = function()
        mode = mode > 1 and mode - 1 or #filterModes
        local filterModeStr = filterModes[mode]
        self.filterModeButton:fitText(filterModeStr, 4)
        self.filterModeButton:setId(mode)
        self:updateFilter(self.filterEdit, mode, filterModeStr)
    end

    self.panels = {}
    self:connectPanels(nil, false, false)
    self:selectTab(1)
end

function GlobalInspector:makePanel(title)
--d("[TB]makePanel-title: " ..tos(title))
    local panel = self:acquirePanel(GlobalInspectorPanel)
    --local tabControl = self:insertTab(title, panel, 0)
    self:insertTab(title, panel, 0, nil, nil, true)
    return panel
end

function GlobalInspector:connectPanels(panelName, rebuildMasterList, releaseAllTabs, tabIndex)
    rebuildMasterList = rebuildMasterList or false
    releaseAllTabs = releaseAllTabs or false
    if not self.panels then return end
    local panelNames = tbug.panelNames
    if releaseAllTabs == true then
        self:removeAllTabs()
    end
    for idx,v in ipairs(panelNames) do
        if releaseAllTabs == true then
            self.panels[v.key]:release()
        end
        --Use the fixed tabIndex instead of the name? For e.g. tabs where the text on the tab does not match the key (sv <-> SV, or Sv entered as slash command /tbug sv to re-create the tab)
        if tabIndex ~= nil and idx == tabIndex then
            --d(">connectPanels-panelName: " ..tos(panelName) .. ", tabIndex: " ..tos(tabIndex))
            --d(">>make panel for v.key: " ..tos(v.key) .. ", v.name: " ..tos(v.name))
            self.panels[v.key] = self:makePanel(v.name)
            if rebuildMasterList == true then
                self:refresh()
            end
        --Use the tab's name
        else
            if panelName and panelName ~= "" then
                if v.name == panelName then
                    self.panels[v.key] = self:makePanel(v.name)
                    if rebuildMasterList == true then
                        self:refresh()
                    end
                    return
                end
            else
                self.panels[v.key] = self:makePanel(v.name)
            end
        end
    end
    if rebuildMasterList == true then
        self:refresh()
    end
end

function GlobalInspector:refresh()
    local panels       = self.panels
    local panelClasses = panels.classes:clearMasterList(_G)
    local controls     = panels.controls:clearMasterList(_G)
    local fonts = panels.fonts:clearMasterList(_G)
    local functions = panels.functions:clearMasterList(_G)
    local objects = panels.objects:clearMasterList(_G)
    local constants = panels.constants:clearMasterList(_G)

    local function push(masterList, dataType, key, value)
        local data = {key = key, value = value}
        local n = #masterList + 1
        masterList[n] = ZO_ScrollList_CreateDataEntry(dataType, data)
    end

    for k, v in zo_insecureNext, _G do
        local tv = type(v)
        if tv == "userdata" then
            if v.IsControlHidden then
                push(controls, RT.GENERIC, k, v)
            elseif v.GetFontInfo then
                push(fonts, RT.FONT_OBJECT, k, v)
            else
                push(objects, RT.GENERIC, k, v)
            end
        elseif tv == "table" then
            if rawget(v, "__index") then
                push(panelClasses, RT.GENERIC, k, v)
            else
                push(objects, RT.GENERIC, k, v)
            end
        elseif tv == "function" then
            push(functions, RT.GENERIC, k, v)
        elseif tv ~= "string" or type(k) ~= "string" then
            push(constants, RT.GENERIC, k, v)
        elseif IsPrivateFunction(k) then
            push(functions, RT.GENERIC, k, "function: private")
        elseif IsProtectedFunction(k) then
            push(functions, RT.GENERIC, k, "function: protected")
        else
            push(constants, RT.GENERIC, k, v)
        end
    end

    panels.dialogs:bindMasterList(_G.ESO_Dialogs, RT.GENERIC)
    panels.strings:bindMasterList(_G.EsoStrings, RT.LOCAL_STRING)
    panels.sounds:bindMasterList(_G.SOUNDS, RT.SOUND_STRING)
    panels.scenes:bindMasterList(_G.SCENE_MANAGER.scenes, RT.GENERIC)

    panels.libs:bindMasterList(tbug.LibrariesOutput, RT.LIB_TABLE)
    panels.addons:bindMasterList(tbug.AddOnsOutput, RT.ADDONS_TABLE)
    tbug.refreshScripts()
    panels.scriptHistory:bindMasterList(tbug.ScriptsData, RT.SCRIPTHISTORY_TABLE)
    tbug.RefreshTrackedEventsList()
    panels.events:bindMasterList(tbug.Events.eventsTable, RT.EVENTS_TABLE)
    panels.sv:bindMasterList(tbug.SavedVariablesOutput, RT.SAVEDVARIABLES_TABLE)


    for _, panel in next, panels do
        panel:refreshData()
    end
end


function GlobalInspector:release()
    -- do not release anything
    self.control:SetHidden(true)
end


local function tolowerstring(x)
    return strlower(tos(x))
end


local FilterFactory = {}

--Search for condition
--[[
    The expression is evaluated for each list item, with environment containing 'k' and 'v' as the list item key and value. Items for which the result is truthy pass the filter.
    For example, this is how you can search the Constants tab for items whose key starts with "B" and whose value is an even number:
    k:find("^B") and v % 2 == 0
]]
function FilterFactory.con(expr)
    local func, _ = zo_loadstring("return " .. expr)
    if not func then
        return nil
    end

    local filterEnv = setmetatable({}, {__index = tbug.env})
    setfenv(func, filterEnv)

    local function conditionFilter(data)
        filterEnv.k = data.key
        filterEnv.v = data.value
        local ok, res = pcall(func)
        return ok and res
    end

    return conditionFilter
end

--Search for patern
function FilterFactory.pat(expr)
    if not pcall(strfind, "", expr) then
        return nil
    end

    local function patternFilter(data)
        local value = tos(data.value)
        return strfind(value, expr) ~= nil
    end

    return patternFilter
end

--Search for string
function FilterFactory.str(expr, data) --2nd param data is only passed in if called locally!
    local tosFunc = tos
    expr = tolowerstring(expr)

    if not strfind(expr, "%u") then -- ignore case
        tosFunc = tolowerstring
    end

    local function findSI(data)
        if data.dataEntry.typeId == RT.LOCAL_STRING then
            --local si = rawget(tbug.glookupEnum("SI"), data.key)
            local si = data.keyText
            if si == nil then si = rawget(tbug.glookupEnum("SI"), data.key) end
            if type(si) == "string" then
                return strfind(tosFunc(si), expr, 1, true)
            end
        end
    end

    local function stringFilter(data)
        local key = data.key
        if type(key) == "number" then
            if findSI(data) then
                return true
            else
                --local value = data.value
                --[[
                if typeId == RT.ADDONS_TABLE then
                    key = value.name
                elseif typeId == RT.EVENTS_TABLE then
                    key = value._eventName
                end
                ]]
                key = checkForSpecialDataEntryAsKey(data)
            end
        end
        if strfind(tosFunc(key), expr, 1, true) then
            return true
        end
        local value = tosFunc(data.value)
        return strfind(value, expr, 1, true) ~= nil
    end

    return stringFilter
end
local filterFactoryStr = FilterFactory.str

--Search for value
function FilterFactory.val(expr)
    local ok, result = pcall(zo_loadstring("return " .. expr))
    if not ok then
        return nil
    end

    local function valueFilter(data)
        return rawequal(data.value, result)
    end

    return valueFilter
end

--Search for the control type if the row contains a control at the key, or the key2
--[[
    The expression needs 2 params seperated with a space. 1st param is the name of the control to search. 2nd OPTIONAL param is the number control type (e.g. CT_CONTROL = 0).
    If 2nd param is left empty all types of CT_* will be found
    For example: ZO_toplevel CT_TOPLEVELCONTROL
    ->will find all CT_TOPLEVELCONTROLs with the name ZO_TOPLEVEL
]]
function FilterFactory.ctrl(expr)
    local tosFunc = tos
    local ctrlName, ctrlType
    local searchParams = strsplit(expr, " ")
    if searchParams == nil or #searchParams < 1 then return end
    ctrlName = searchParams[1]
    if #searchParams == 2 then
        ctrlType = searchParams[2]
    end

    local function ctrlFilter(data)
        local retVar = false
        local key = data.key
        if type(key) == "string" then
            if filterFactoryStr(ctrlName, data) == true then
d(">found control name: " ..tos(ctrlName))
                --Check if the value is a control and if the control type matches
                retVar = isAControlOfType(data, ctrlType)
            end
        end
        return retVar
    end

    return ctrlFilter
end


function GlobalInspector:updateFilter(filterEdit, mode, filterModeStr)
    local function addToSearchHistory(p_self, p_filterEdit)
        saveNewSearchHistoryContextMenuEntry(p_filterEdit, p_self)
    end

    local function filterEditBoxContentsNow(p_self, p_filterEdit, p_mode, p_filterModeStr)
        p_filterEdit.doNotRunOnChangeFunc = false
        local expr = strmatch(p_filterEdit:GetText(), "(%S+.-)%s*$")
        local filterFunc
        p_filterModeStr = p_filterModeStr or filterModes[p_mode]
--d(strformat("[filterEditBoxContentsNow]expr: %s, mode: %s, modeStr: %s", tos(expr), tos(p_mode), tos(p_filterModeStr)))
        if expr then
            filterFunc = FilterFactory[p_filterModeStr](expr)
        else
            filterFunc = false
        end
        if filterFunc ~= nil then
            for _, panel in next, p_self.panels do
                panel:setFilterFunc(filterFunc)
            end
            p_filterEdit:SetColor(p_self.filterColorGood:UnpackRGBA())
        else
            p_filterEdit:SetColor(p_self.filterColorBad:UnpackRGBA())
        end
        return filterFunc ~= nil
    end

    throttledCall("merTorchbugSearchEditChanged", 500,
                    filterEditBoxContentsNow, self, filterEdit, mode, filterModeStr
    )

    throttledCall("merTorchbugSearchEditAddToSearchHistory", 2000,
                    addToSearchHistory, self, filterEdit
    )
end
