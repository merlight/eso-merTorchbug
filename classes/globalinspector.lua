local tbug = LibStub:GetLibrary("merTorchbug")
local wm = WINDOW_MANAGER
local strfind = string.find
local strformat = string.format
local strlower = string.lower
local strmatch = string.match

local BasicInspector = tbug.classes.BasicInspector
local GlobalInspector = tbug.classes.GlobalInspector .. BasicInspector
local TextButton = tbug.classes.TextButton


function tbug.getGlobalInspector()
    local inspector = tbug.globalInspector
    if not inspector then
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

local RT = tbug.subtable(TableInspectorPanel, "ROW_TYPES")


function GlobalInspectorPanel:buildMasterList()
    self:buildMasterListSpecial()
end


function GlobalInspectorPanel:onRowClicked(row, data, mouseButton)
    if mouseButton == 1 then
        local tv = type(data.value)
        if tv == "string" then
            if data.dataEntry.typeId == RT.SOUND_STRING then
                PlaySound(data.value)
            end
        elseif tv == "table" or tv == "userdata" then
            local inspector = tbug.inspect(data.value, tostring(data.key))
            if inspector then
                inspector.control:BringWindowToTop()
            end
        end
    end
end


---------------------------
-- class GlobalInspector --


function GlobalInspector:__init__(id, control)
    BasicInspector.__init__(self, id, control)

    self.conf = tbug.savedTable("globalInspector" .. id)
    self:configure(self.conf)

    self.title:SetText("GLOBALS")

    self.filterColorGood = ZO_ColorDef:New(118/255, 188/255, 195/255)
    self.filterColorBad = ZO_ColorDef:New(255/255, 153/255, 136/255)

    self.filterButton = control:GetNamedChild("FilterButton")
    self.filterEdit = control:GetNamedChild("FilterEdit")
    self.filterEdit:SetColor(self.filterColorGood:UnpackRGBA())

    self.filterEdit:SetHandler("OnTextChanged", function(editControl)
        local filterMode = self.filterModeButton:getText()
        self:updateFilter(editControl, filterMode)
    end)

    local modes = {"str", "pat", "val", "con"}
    local mode = 1
    self.filterModeButton = TextButton(control, "FilterModeButton")
    self.filterModeButton:fitText(modes[mode])
    self.filterModeButton:enableMouseButton(2)
    self.filterModeButton.onClicked[1] = function()
        mode = mode < #modes and mode + 1 or 1
        local filterMode = modes[mode]
        self.filterModeButton:fitText(filterMode, 4)
        self:updateFilter(self.filterEdit, filterMode)
    end
    self.filterModeButton.onClicked[2] = function()
        mode = mode > 1 and mode - 1 or #modes
        local filterMode = modes[mode]
        self.filterModeButton:fitText(filterMode, 4)
        self:updateFilter(self.filterEdit, filterMode)
    end

    local function makePanel(title)
        local panel = self:acquirePanel(GlobalInspectorPanel)
        local tabControl = self:insertTab(title, panel, 0)
        return panel
    end

    self.panels = {
        classes = makePanel("Classes"),
        objects = makePanel("Objects"),
        controls = makePanel("Controls"),
        fonts = makePanel("Fonts"),
        functions = makePanel("Functions"),
        constants = makePanel("Constants"),
        strings = makePanel("Strings"),
        sounds = makePanel("Sounds"),
        dialogs = makePanel("Dialogs"),
        libs = makePanel("Libs"),
    }

    self:selectTab(1)
end


function GlobalInspector:refreshGlobals()
    local classes = self.panels.classes:clearMasterList(_G)
    local controls = self.panels.controls:clearMasterList(_G)
    local fonts = self.panels.fonts:clearMasterList(_G)
    local functions = self.panels.functions:clearMasterList(_G)
    local objects = self.panels.objects:clearMasterList(_G)
    local constants = self.panels.constants:clearMasterList(_G)

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

    self.panels.strings:bindMasterList(_G.EsoStrings)
    self.panels.sounds:bindMasterList(_G.SOUNDS)
    self.panels.dialogs:bindMasterList(_G.ESO_Dialogs)
    self.panels.libs:bindMasterList(LibStub.libs)

    for _, panel in next, self.panels do
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

    function conditionFilter(data)
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
    local expr = strmatch(filterEdit:GetText(), "(%S+.-)%s*$")
    local filterFunc = nil

    if expr then
        filterFunc = FilterFactory[filterMode](expr)
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
