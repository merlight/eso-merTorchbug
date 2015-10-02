local tbug = LibStub:GetLibrary("merTorchbug")
local strformat = string.format
local typeColors = tbug.cache.typeColors


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


function tbug.isControl(object)
    return type(object) == "userdata" and
           type(object.IsControlHidden) == "function"
end


---------------------------------
-- class ControlInspectorPanel --

local ObjectInspectorPanel = tbug.classes.ObjectInspectorPanel
local ControlInspectorPanel = tbug.classes.ControlInspectorPanel .. ObjectInspectorPanel

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
    ObjectInspectorPanel.__init__(self, control, ...)
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


function ControlInspectorPanel:canEditValue(data)
    return data.prop.set ~= nil
end


function ControlInspectorPanel:initScrollList(control)
    ObjectInspectorPanel.initScrollList(self, control)

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

        local k = data.prop.name
        local tk = (k == "__index" and "function" or type(k))
        local tv = type(v)
        data.value = v

        self:setupRow(row, data)
        setupValue(row.cKeyLeft, tk, k)
        setupValue(row.cKeyRight, tk, "")

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

    local function hideCallback(row, data)
        if self.editData == data then
            self.editBox:ClearAnchors()
            self.editBox:SetAnchor(BOTTOMRIGHT, nil, TOPRIGHT, 0, -20)
        end
    end

    self:addDataType(ROW_TYPE_HEADER, "tbugTableInspectorHeaderRow", 24, setupHeader, hideCallback)
    self:addDataType(ROW_TYPE_PROPERTY, "tbugTableInspectorRow", 24, setupSimple, hideCallback)
end


function ControlInspectorPanel:onRowClicked(row, data, mouseButton, ctrl, alt, shift)
    if mouseButton == MOUSE_BUTTON_INDEX_LEFT then
        self.editBox:LoseFocus()
        if shift then
            local inspector = tbug.inspect(data.value, data.prop.name, nil, false)
            if inspector then
                inspector.control:BringWindowToTop()
            end
        else
            self.inspector:openTabFor(data.value, data.prop.name)
        end
    elseif mouseButton == MOUSE_BUTTON_INDEX_RIGHT then
        if MouseIsOver(row.cVal) and self:canEditValue(data) then
            self:valueEditStart(self.editBox, row, data)
        else
            self.editBox:LoseFocus()
        end
    end
end


function ControlInspectorPanel:valueEditConfirmed(editBox, evalResult)
    local editData = self.editData
    if editData then
        local setter = editData.prop.set
        local ok, setResult
        if type(setter) == "function" then
            ok, setResult = pcall(setter, editData, self.subject, evalResult)
        else
            ok, setResult = pcall(invoke, self.subject, setter, evalResult)
        end
        if not ok then
            return setResult
        end
        self.editData = nil
        -- the modified value might affect multiple related properties,
        -- so we have to refresh all visible rows, not just editData
        ZO_ScrollList_RefreshVisible(self.list)
    end
    editBox:LoseFocus()
end
