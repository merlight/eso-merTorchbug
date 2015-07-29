local tbug = LibStub:GetLibrary("merTorchbug")
local wm = WINDOW_MANAGER
local strformat = string.format
local typeColors = tbug.typeColors

local BasicInspector = tbug.classes.BasicInspector
local ControlInspector = tbug.classes.ControlInspector .. BasicInspector


local function getControlInfo(control)
    local controlTypes = tbug.glookupEnum("CT")
    local ct = control:GetType()
    return ct, controlTypes[ct], control:GetName()
end


local function invoke(object, method, ...)
    return object[method](object, ...)
end


---------------------------------
-- class ControlInspectorPanel --

local BasicInspectorPanel = tbug.classes.BasicInspectorPanel
local TableInspectorPanel = tbug.classes.TableInspectorPanel
local ControlInspectorPanel = tbug.classes.ControlInspectorPanel .. BasicInspectorPanel

ControlInspectorPanel.CONTROL_PREFIX = "$(parent)PanelC"
ControlInspectorPanel.TEMPLATE_NAME = "tbugControlInspectorPanel"

local PROP_SIMPLE = 1
local PROP_ANCHOR = 2

local g_properties = {
    {typ=PROP_SIMPLE, name="owner",         get="GetOwningWindow"},
    {typ=PROP_SIMPLE, name="parent",        get="GetParent",
                                            set="SetParent"},
    {typ=PROP_SIMPLE, name="name",          get="GetName"},
    {typ=PROP_SIMPLE, name="type",          get="GetType",
                      enum="CT"},
    {typ=PROP_SIMPLE, name="numChildren",   get="GetNumChildren"},
    {typ=PROP_SIMPLE, name="state",         get="GetState",
                                            set="SetState"},
    {typ=PROP_SIMPLE, name="text",          get="GetText",
                                            set="SetText"},
    {typ=PROP_SIMPLE, name="hidden",        get="IsHidden",
                                            set="SetHidden"},
    {typ=PROP_SIMPLE, name="controlHidden", get="IsControlHidden"},
    {typ=PROP_SIMPLE, name="alpha",         get="GetAlpha",
                                            set="SetAlpha"},
    {typ=PROP_SIMPLE, name="controlAlpha",  get="GetControlAlpha"},
    {typ=PROP_SIMPLE, name="width",         get="GetWidth",
                                            set="SetWidth"},
    {typ=PROP_SIMPLE, name="desiredWidth",  get="GetDesiredWidth",
                                            set="SetDesiredWidth"},
    {typ=PROP_SIMPLE, name="height",        get="GetHeight",
                                            set="SetHeight"},
    {typ=PROP_SIMPLE, name="desiredHeight", get="GetDesiredHeight",
                                            set="SetDesiredHeight"},
    {typ=PROP_SIMPLE, name="clampedToScreen",   get="GetClampedToScreen",
                                                set="SetClampedToScreen"},
    {typ=PROP_SIMPLE, name="mouseEnabled",      get="GetMouseEnabled",
                                                set="SetMouseEnabled"},
    {typ=PROP_SIMPLE, name="keyboardEnabled",   get="GetKeyboardEnabled",
                                                set="SetKeyboardEnabled"},
    {typ=PROP_SIMPLE, name="layer",     get="GetDrawLayer",
                      enum="DL",        set="SetDrawLayer"},
    {typ=PROP_SIMPLE, name="level",     get="GetDrawLevel",
                                        set="SetDrawLevel"},
    {typ=PROP_SIMPLE, name="tier",      get="GetDrawTier",
                      enum="DT",        set="SetDrawTier"},
    {typ=PROP_SIMPLE, name="inheritAlpha",      get="GetInheritAlpha",
                                                set="SetInheritAlpha"},
    {typ=PROP_SIMPLE, name="inheritScale",      get="GetInheritScale",
                                                set="SetInheritScale"},
    {typ=PROP_SIMPLE, name="scale",     get="GetScale",
                                        set="SetScale"},
    {typ=PROP_SIMPLE, name="excludeFromResizeToFitExtents",
                      get="GetExcludeFromResizeToFitExtents",
                      set="SetExcludeFromResizeToFitExtents"},
    {typ=PROP_SIMPLE, name="resizeToFitDescendents",
                      get="GetResizeToFitDescendents",
                      set="SetResizeToFitDescendents"},
}


function ControlInspectorPanel:__init__(control, ...)
    BasicInspectorPanel.__init__(self, control, ...)
    self:initScrollList(control)
end


function ControlInspectorPanel:buildMasterList()
    local masterList, n = self.masterList, 0
    local subject = self.subject

    if type(subject) == "userdata" then
        for _, prop in ipairs(g_properties) do
            if type(subject[prop.get]) == "function" then
                local data = {
                    enum = prop.enum and tbug.glookupEnum(prop.enum),
                    prop = prop,
                }
                n = n + 1
                masterList[n] = ZO_ScrollList_CreateDataEntry(prop.typ, data)
            end
        end
    end

    tbug.truncate(masterList, n)
end


function ControlInspectorPanel:initScrollList(control)
    BasicInspectorPanel.initScrollList(self, control)

    local function setupValue(cell, typ, val)
        cell:SetColor(typeColors[typ]:UnpackRGBA())
        cell:SetText(tostring(val))
    end

    local function setupValueLookup(cell, typ, val)
        cell:SetColor(typeColors[typ]:UnpackRGBA())
        local name = tbug.glookup(val)
        if name then
            cell:SetText(strformat("%s: %s", typ, name))
        else
            cell:SetText(tostring(val))
        end
    end

    local function setupCommon(row, data, list)
        local k = data.prop.name
        local tk = type(k)
        local ck = typeColors[tk]

        self:setupRow(row, data)

        row.cKeyLeft:SetColor(ck:UnpackRGBA())
        row.cKeyLeft:SetText(tostring(k))
        row.cKeyRight:SetText("")

        return k, tk
    end

    local function setupSimple(row, data, list)
        local ok, v = pcall(invoke, self.subject, data.prop.get)
        local tv = type(v)

        data.value = v
        setupCommon(row, data, list)

        if tv == "string" then
            setupValue(row.cVal, tv, strformat("%q", v))
        elseif tv == "number" then
            if data.enum then
                v = data.enum[v]
            end
            setupValue(row.cVal, tv, v)
        elseif tv == "userdata" then
            local ok, ct, cts, name = pcall(getControlInfo, v)
            if ok then
                setupValue(row.cKeyRight, type(ct), cts)
                setupValue(row.cVal, tv, name)
                return
            end
            setupValueLookup(row.cVal, tv, v)
        else
            setupValueLookup(row.cVal, tv, v)
        end
    end

    self:addDataType(PROP_SIMPLE, "tbugTableInspectorRow", 24, setupSimple)
end


function ControlInspectorPanel:onRowClicked(row, data, mouseButton)
    if mouseButton == 1 then
        local tv = type(data.value)
        if tv == "table" or tv == "userdata" then
            local ok, title = pcall(invoke, data.value, "GetName")
            if not ok then
                title = tostring(data.value)
            end
            local inspector = tbug.inspect(data.value, title)
            if inspector then
                inspector.control:BringWindowToTop()
            end
        end
    end
end


function ControlInspectorPanel:onRowMouseUp(row, data, mouseButton, upInside, ...)
    if upInside then
        if mouseButton == 2 and MouseIsOver(row.cVal) then
            df("tbug: TODO edit property")
        end
        self:onRowClicked(row, data, mouseButton)
    end
end


function ControlInspectorPanel:reset()
    tbug.truncate(self.masterList, 0)
    ZO_ScrollList_Clear(self.list)
    self:commitScrollList()
    self.control:SetHidden(true)
    self.control:ClearAnchors()
    self.subject = nil
end


----------------------------
-- class ControlInspector --


ControlInspector._activeObjects = {}
ControlInspector._inactiveObjects = {}
ControlInspector._nextObjectId = 1
ControlInspector._templateName = "tbugControlInspector"


function ControlInspector:__init__(id, control)
    BasicInspector.__init__(self, id, control)

    self.conf = tbug.savedTable("controlInspector" .. id)
    self:configure(self.conf)
end


function ControlInspector:refresh()
    local subject = self.subject

    df("tbug: refreshing %s", tostring(subject))

    self:removeAllTabs()

    if type(subject) == "userdata" then
        local _, title = pcall(subject.GetName, subject)
        if title == "" then
            title = "<NoName>"
        end
        local ctlPanel = self:acquirePanel(ControlInspectorPanel)
        local ctlTab = self:insertTab(title, ctlPanel, 0)
        ctlPanel.subject = subject
        ctlPanel:refreshData()
    end

    local mt = getmetatable(subject)

    while type(mt) == "table" do
        local mtPanel = self:acquirePanel(TableInspectorPanel)
        local mtTab = self:insertTab("metatable", mtPanel, 0)
        mtPanel.editTable = mt
        mtPanel:refreshData()
        mt = getmetatable(mt)
    end

    self:selectTab(1)
end
