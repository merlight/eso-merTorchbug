local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")
local wm = WINDOW_MANAGER
local strfind = string.find
local strformat = string.format
local strlower = string.lower
local strmatch = string.match

local BasicInspector = tbug.classes.BasicInspector
local GlobalInspector = tbug.classes.GlobalInspector .. BasicInspector
local TextButton = tbug.classes.TextButton

local filterModes = tbug.filterModes

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

local TableInspectorPanel = tbug.classes.TableInspectorPanel
local GlobalInspectorPanel = tbug.classes.GlobalInspectorPanel .. TableInspectorPanel

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
        local filterMode = self.filterModeButton:getId()
        self:updateFilter(editControl, filterMode)
    end)
    self.filterEdit:SetHandler("OnMouseUp", function(editControl, mouseButton, upInside, shift, ctrl, alt, command)
        if mouseButton == MOUSE_BUTTON_INDEX_RIGHT and upInside then
            --Show context menu with the last saved searches (search history)
            --Get the active panel
            local globalInspector = tbug.getGlobalInspector()
            if not globalInspector then return end
            local panels = globalInspector.panels
            if not panels then return end
            local activeTab = self.activeTab
            if not activeTab then return end
            local activeTabKey = activeTab.pKeyStr
            local activeTabName = activeTab.label:GetText()
            --Get the active search mode
            local filterMode = self.filterModeButton:getId()
            local searchHistoryForPanelAndMode = tbug.loadSearchHistoryEntry(activeTabName, filterMode)

            if searchHistoryForPanelAndMode ~= nil and #searchHistoryForPanelAndMode > 0 then
                ClearMenu()
                for _, searchTerm in ipairs(searchHistoryForPanelAndMode) do
                    if searchTerm ~= nil and searchTerm ~= "" then
                        AddCustomMenuItem(searchTerm, function()
                            editControl.doNotRunOnChangeFunc = true
                            editControl:SetText(searchTerm)
                            self:updateFilter(editControl, filterMode)
                        end)
                    end
                end
                ShowMenu(editControl)
            end
        end
    end)

    --The search mode buttons
    local modes = tbug.filterModes
    local mode = 1
    self.filterModeButton = TextButton(control, "FilterModeButton")
    self.filterModeButton:fitText(modes[mode])
    self.filterModeButton:enableMouseButton(MOUSE_BUTTON_INDEX_RIGHT)
    self.filterModeButton:setId(mode)
    self.filterModeButton.onClicked[MOUSE_BUTTON_INDEX_LEFT] = function()
        mode = mode < #modes and mode + 1 or 1
        local filterMode = modes[mode]
        self.filterModeButton:fitText(filterMode, 4)
        self.filterModeButton:setId(filterMode)
        self:updateFilter(self.filterEdit, filterMode)
    end
    self.filterModeButton.onClicked[MOUSE_BUTTON_INDEX_RIGHT] = function()
        mode = mode > 1 and mode - 1 or #modes
        local filterMode = modes[mode]
        self.filterModeButton:fitText(filterMode, 4)
        self.filterModeButton:setId(filterMode)
        self:updateFilter(self.filterEdit, filterMode)
    end

    self.panels = {}
    self:connectPanels(nil, false, false)
    self:selectTab(1)
end

function GlobalInspector:makePanel(title)
    local panel = self:acquirePanel(GlobalInspectorPanel)
    local tabControl = self:insertTab(title, panel, 0)
    return panel
end

function GlobalInspector:connectPanels(panelName, rebuildMasterList, releaseAllTabs)
    rebuildMasterList = rebuildMasterList or false
    releaseAllTabs = releaseAllTabs or false
    if not self.panels then return end
    local panelNames = tbug.panelNames
    if releaseAllTabs == true then
        self:removeAllTabs()
    end
    for _,v in ipairs(panelNames) do
        if releaseAllTabs == true then
            self.panels[v.key]:release()
        end
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
    if rebuildMasterList == true then
        self:refresh()
    end
end

function GlobalInspector:refresh()
    local panels = self.panels
    local classes = panels.classes:clearMasterList(_G)
    local controls = panels.controls:clearMasterList(_G)
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
                push(classes, RT.GENERIC, k, v)
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
    return strlower(tostring(x))
end


local FilterFactory = {}


function FilterFactory.con(expr)
    local func, err = zo_loadstring("return " .. expr)
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


function FilterFactory.pat(expr)
    if not pcall(strfind, "", expr) then
        return nil
    end

    local function patternFilter(data)
        local value = tostring(data.value)
        return strfind(value, expr) ~= nil
    end

    return patternFilter
end


function FilterFactory.str(expr, tostringFunc)
    local tostringFunc = tostring

    if not strfind(expr, "%u") then -- ignore case
        tostringFunc = tolowerstring
    end

    local function findSI(data)
        if data.dataEntry.typeId == RT.LOCAL_STRING then
            local si = rawget(tbug.glookupEnum("SI"), data.key)
            if type(si) == "string" then
                return strfind(tostringFunc(si), expr, 1, true)
            end
        end
    end

    local function stringFilter(data)
        local key = data.key
        if type(key) == "number" and findSI(data) then
            return true
        end
        if strfind(tostringFunc(key), expr, 1, true) then
            return true
        end
        local value = tostringFunc(data.value)
        return strfind(value, expr, 1, true) ~= nil
    end

    return stringFilter
end


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


function GlobalInspector:updateFilter(filterEdit, filterMode)
    filterEdit.doNotRunOnChangeFunc = false
    local expr = strmatch(filterEdit:GetText(), "(%S+.-)%s*$")
    local filterFunc = nil
    local filterModeStr = filterModes[filterMode]

    if expr then
        filterFunc = FilterFactory[filterModeStr](expr)
    else
        filterFunc = false
    end

    if filterFunc ~= nil then
        for _, panel in next, self.panels do
            panel:setFilterFunc(filterFunc)
        end
        filterEdit:SetColor(self.filterColorGood:UnpackRGBA())
    else
        filterEdit:SetColor(self.filterColorBad:UnpackRGBA())
    end

    return filterFunc ~= nil
end
