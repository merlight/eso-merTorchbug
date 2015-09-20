local tbug = LibStub:GetLibrary("merTorchbug")
local cm = CALLBACK_MANAGER
local wm = WINDOW_MANAGER
local strformat = string.format
local typeColors = tbug.cache.typeColors

local BasicInspector = tbug.classes.BasicInspector
local ControlInspector = tbug.classes.ControlInspector .. BasicInspector


local function invoke(object, method, ...)
    return object[method](object, ...)
end


function tbug.getControlName(control)
    local ok, name = pcall(invoke, control, "GetName")
    if not ok or name == "" then
        return tostring(control)
    else
        return tostring(name)
    end
end


function tbug.getControlType(control)
    local ok, ct = pcall(invoke, control, "GetType")
    if ok then
        local enum = tbug.glookupEnum("CT")
        return ct, enum[ct]
    end
end


---------------------------------
-- class ControlInspectorPanel --

local BasicInspectorPanel = tbug.classes.BasicInspectorPanel
local ControlInspectorPanel = tbug.classes.ControlInspectorPanel .. BasicInspectorPanel

ControlInspectorPanel.CONTROL_PREFIX = "$(parent)PanelC"
ControlInspectorPanel.TEMPLATE_NAME = "tbugControlInspectorPanel"

local ROW_TYPE_HEADER = 6
local ROW_TYPE_PROPERTY = 7


local function td(prop)
    prop.typ = ROW_TYPE_PROPERTY
    return setmetatable(prop, prop.cls)
end


local function th(prop)
    prop.typ = ROW_TYPE_HEADER
    return setmetatable(prop, prop.cls)
end


local AnchorAttribute = {}
AnchorAttribute.__index = AnchorAttribute


function AnchorAttribute.get(data, control)
    local anchorIndex = math.floor(data.prop.idx / 10)
    local valueIndex = data.prop.idx % 10
    return (select(valueIndex, control:GetAnchor(anchorIndex)))
end


function AnchorAttribute.set(data, control, value)
    local anchor0 = {control:GetAnchor(0)}
    local anchor1 = {control:GetAnchor(1)}

    if data.prop.idx < 10 then
        anchor0[data.prop.idx] = value
    else
        anchor1[data.prop.idx % 10] = value
    end

    control:ClearAnchors()

    if anchor0[2] ~= NONE then
        control:SetAnchor(unpack(anchor0, 2))
    end

    if anchor1[2] ~= NONE then
        control:SetAnchor(unpack(anchor1, 2))
    end
end


local DimensionConstraint = {}
DimensionConstraint.__index = DimensionConstraint


function DimensionConstraint.get(data, control)
    return (select(data.prop.idx, control:GetDimensionConstraints()))
end


function DimensionConstraint.set(data, control, value)
    local constraints = {control:GetDimensionConstraints()}
    constraints[data.prop.idx] = value
    control:SetDimensionConstraints(unpack(constraints))
end


local g_commonProperties =
{
    td{name="name",             get="GetName"},
    td{name="type",             get="GetType", enum="CT"},
    td{name="parent",           get="GetParent", set="SetParent"},
    td{name="owner",            get="GetOwningWindow"},
    td{name="__index",          get=function(data, control)
                                        return getmetatable(control).__index
                                    end},

    th{name="Anchor #0",        get="GetAnchor"},

    td{name="point",            cls=AnchorAttribute, idx=2, enum="AnchorPosition"},
    td{name="relativeTo",       cls=AnchorAttribute, idx=3},
    td{name="relativePoint",    cls=AnchorAttribute, idx=4, enum="AnchorPosition"},
    td{name="offsetX",          cls=AnchorAttribute, idx=5},
    td{name="offsetY",          cls=AnchorAttribute, idx=6},

    th{name="Anchor #1",        get="GetAnchor"},

    td{name="point",            cls=AnchorAttribute, idx=12, enum="AnchorPosition"},
    td{name="relativeTo",       cls=AnchorAttribute, idx=13},
    td{name="relativePoint",    cls=AnchorAttribute, idx=14, enum="AnchorPosition"},
    td{name="offsetX",          cls=AnchorAttribute, idx=15},
    td{name="offsetY",          cls=AnchorAttribute, idx=16},

    th{name="Dimensions",       get="GetDimensions"},

    td{name="width",            get="GetWidth", set="SetWidth"},
    td{name="height",           get="GetHeight", set="SetHeight"},
    td{name="desiredWidth",     get="GetDesiredWidth"},
    td{name="desiredHeight",    get="GetDesiredHeight"},
    td{name="minWidth",         cls=DimensionConstraint, idx=1},
    td{name="minHeight",        cls=DimensionConstraint, idx=2},
    td{name="maxWidth",         cls=DimensionConstraint, idx=3},
    td{name="maxHeight",        cls=DimensionConstraint, idx=4},
}


local g_specialProperties =
{
    [CT_CONTROL] =
    {
        th{name="Control properties"},

        td{name="alpha",                get="GetAlpha", set="SetAlpha"},
        td{name="clampedToScreen",      get="GetClampedToScreen", set="SetClampedToScreen"},
        td{name="controlAlpha",         get="GetControlAlpha"},
        td{name="controlHidden",        get="IsControlHidden"},
        td{name="excludeFromResizeToFitExtents",
                                        get="GetExcludeFromResizeToFitExtents",
                                        set="SetExcludeFromResizeToFitExtents"},
        td{name="hidden",               get="IsHidden", set="SetHidden"},
        td{name="inheritAlpha",         get="GetInheritsAlpha", set="SetInheritAlpha"},
        td{name="inheritScale",         get="GetInheritsScale", set="SetInheritScale"},
        td{name="keyboardEnabled",      get="IsKeyboardEnabled", set="SetKeyboardEnabled"},
        td{name="layer", enum="DL",     get="GetDrawLayer", set="SetDrawLayer"},
        td{name="level",                get="GetDrawLevel", set="SetDrawLevel"},
        td{name="mouseEnabled",         get="IsMouseEnabled", set="SetMouseEnabled"},
        td{name="resizeToFitDescendents",
                                        get="GetResizeToFitDescendents",
                                        set="SetResizeToFitDescendents"},
        td{name="scale",                get="GetScale", set="SetScale"},
        td{name="tier",  enum="DT",     get="GetDrawTier", set="SetDrawTier"},

        th{name="Children",             get="GetNumChildren"},
    },
    [CT_BUTTON] =
    {
        th{name="Button properties"},

        td{name="label",                get="GetLabelControl"},
        td{name="state", enum="BSTATE", get="GetState", set="SetState"},
    },
    [CT_LABEL] =
    {
        th{name="Label properties"},

        td{name="didLineWrap",          get="DidLineWrap"},
        td{name="fontHeight",           get="GetFontHeight"},
        td{name="horizontalAlignment",  get="GetHorizontalAlignment",
           enum="TEXT_ALIGN",           set="SetHorizontalAlignment"},
        td{name="modifyTextType",       get="GetModifyTextType",
           enum="MODIFY_TEXT_TYPE",     set="SetModifyTextType"},
        td{name="numLines",             get="GetNumLines"},
        td{name="text",                 get="GetText", set="SetText"},
        td{name="textHeight",           get="GetTextHeight"},
        td{name="textWidth",            get="GetTextWidth"},
        td{name="verticalAlignment",    get="GetVerticalAlignment",
           enum="TEXT_ALIGN",           set="SetVerticalAlignment"},
        td{name="wasTruncated",         get="WasTruncated"},
    },
}


function ControlInspectorPanel:__init__(control, ...)
    BasicInspectorPanel.__init__(self, control, ...)
    self:initScrollList(control)

    cm:RegisterCallback("tbugChanged:typeColor", function() self:refreshVisible() end)
end


local function createPropEntry(data)
    return ZO_ScrollList_CreateDataEntry(data.prop.typ, data)
end


local function getControlChild(data, control)
    return control:GetChild(data.childIndex)
end


function ControlInspectorPanel:buildMasterList()
    local masterList, n = self.masterList, 0
    local subject = self.subject
    local _, controlType = pcall(invoke, subject, "GetType")
    local _, numChildren = pcall(invoke, subject, "GetNumChildren")

    for _, prop in ipairs(g_commonProperties) do
        n = n + 1
        masterList[n] = createPropEntry{prop = prop}
    end

    local controlProps = g_specialProperties[controlType]
    if controlProps then
        for _, prop in ipairs(controlProps) do
            n = n + 1
            masterList[n] = createPropEntry{prop = prop}
        end
    end

    if controlType ~= CT_CONTROL then
        for _, prop in ipairs(g_specialProperties[CT_CONTROL]) do
            n = n + 1
            masterList[n] = createPropEntry{prop = prop}
        end
    end

    for i = 1, tonumber(numChildren) or 0 do
        local childProp = td{name = tostring(i), get = getControlChild}
        n = n + 1
        masterList[n] = createPropEntry{prop = childProp, childIndex = i}
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
        local tk = (k == "__index" and "function" or type(k))
        local ck = typeColors[tk]

        self:setupRow(row, data)

        row.cKeyLeft:SetColor(ck:UnpackRGBA())
        row.cKeyLeft:SetText(tostring(k))
        row.cKeyRight:SetText("")

        return k, tk
    end

    local function setupHeader(row, data, list)
        row.label:SetText(data.prop.name)
    end

    local function setupSimple(row, data, list)
        local getter = data.prop.get
        local ok, v

        if type(getter) == "function" then
            ok, v = pcall(getter, data, self.subject)
        else
            ok, v = pcall(invoke, self.subject, getter)
        end

        local tv = type(v)
        data.value = v
        setupCommon(row, data, list)

        if tv == "string" then
            setupValue(row.cVal, tv, strformat("%q", v))
        elseif tv == "number" then
            local enum = data.prop.enum
            if enum then
                local nv = tbug.glookupEnum(enum)[v]
                if v ~= nv then
                    setupValue(row.cKeyRight, tv, nv)
                end
            end
            setupValue(row.cVal, tv, v)
        elseif tv == "userdata" then
            local ct, ctName = tbug.getControlType(v)
            if ct then
                setupValue(row.cKeyRight, type(ct), ctName)
                setupValue(row.cVal, tv, tbug.getControlName(v))
                return
            end
            setupValueLookup(row.cVal, tv, v)
        else
            setupValueLookup(row.cVal, tv, v)
        end
    end

    self:addDataType(ROW_TYPE_HEADER, "tbugTableInspectorHeaderRow", 24, setupHeader)
    self:addDataType(ROW_TYPE_PROPERTY, "tbugTableInspectorRow", 24, setupSimple)
end


function ControlInspectorPanel:onRowClicked(row, data, mouseButton)
    if mouseButton == 1 then
        local tv = type(data.value)
        if tv == "table" or tv == "userdata" then
            local title = tbug.getControlName(data.value)
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
        local title = tbug.getControlName(subject)
        local ctlPanel = self:acquirePanel(ControlInspectorPanel)
        local ctlTab = self:insertTab(title, ctlPanel, 0)
        ctlPanel.subject = subject
        ctlPanel:refreshData()
    end

    self:selectTab(1)
end
