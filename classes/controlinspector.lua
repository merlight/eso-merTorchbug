local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")
local strformat = string.format
local typeColors = tbug.cache.typeColors

local prepareItemLink = tbug.prepareItemLink


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


function tbug.getControlType(control, enumType)
    local ok, ct = pcall(invoke, control, "GetType")
    if ok then
        enumType = enumType or "CT"
        local enum = tbug.glookupEnum(enumType)
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

------------------------------------------------------------------------------------------------------------------------
local ColorProperty = {}

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

local function td(prop)
    local getFuncName = prop.gets
    if getFuncName then
        local arg = prop.arg
        local idx = prop.idx
        local setFuncName = prop.sets
        if arg ~= nil then
            function prop.get(data, control)
                return (select(idx, control[getFuncName](control, arg)))
            end
            if setFuncName then
                function prop.set(data, control, value)
                    local values = {control[getFuncName](control, arg)}
                    values[idx] = value
                    control[setFuncName](control, arg, unpack(values))
                end
            end
        else
            function prop.get(data, control)
                return (select(idx, control[getFuncName](control)))
            end
            if setFuncName then
                function prop.set(data, control, value)
                    local values = {control[getFuncName](control)}
                    values[idx] = value
                    control[setFuncName](control, unpack(values))
                end
            end
        end
    end
    prop.typ = ROW_TYPE_PROPERTY
    if prop.cls then
        if prop.cls == ColorProperty then
            prop.isColor = true
        end
    end
    return setmetatable(prop, prop.cls)
end


local function th(prop)
    prop.typ = ROW_TYPE_HEADER
    return setmetatable(prop, prop.cls)
end

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

ColorProperty.__index = ColorProperty


function ColorProperty.getRGBA(data, control)
    local getFuncName = data.prop.getFuncName
    if not getFuncName then
        getFuncName = "Get" .. data.prop.name:gsub("^%l", string.upper, 1)
        data.prop.getFuncName = getFuncName
    end

    local r, g, b, a = control[getFuncName](control)
    return r, g, b, a
end

function ColorProperty.getFormatedRGBA(data, r, g, b, a)
    local s = data.prop.scale or 255
    if a then
        return strformat("rgba(%.0f, %.0f, %.0f, %.2f)",
                         r * s, g * s, b * s, a * s / 255)
    else
        return strformat("rgb(%.0f, %.0f, %.0f)",
                         r * s, g * s, b * s)
    end
end

function ColorProperty.get(data, control)
    local r, g, b, a = ColorProperty.getRGBA(data, control)
    return ColorProperty.getFormatedRGBA(data, r, g, b, a)
end

function ColorProperty.set(data, control, value)
    local setFuncName = data.prop.setFuncName
    if not setFuncName then
        setFuncName = "Set" .. data.prop.name:gsub("^%l", string.upper, 1)
        data.prop.setFuncName = setFuncName
    end

    local color = tbug.parseColorDef(value)
    control[setFuncName](control, color:UnpackRGBA())
end

------------------------------------------------------------------------------------------------------------------------
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

------------------------------------------------------------------------------------------------------------------------
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
------------------------------------------------------------------------------------------------------------------------


local g_commonProperties = {
    td { name = "name", get = "GetName" },
    td { name = "type", get = "GetType", enum = "CT_names" },
    td { name = "parent", get = "GetParent", set = "SetParent", enum = "CT_names"},
    td { name = "owningWindow", get = "GetOwningWindow", enum = "CT_names"},
    td { name = "hidden", checkFunc = function(control) return tbug.isControl(control)  end, get = "IsHidden", set = "SetHidden" },
    td { name = "__index", get = function(data, control)
        return getmetatable(control).__index
    end },
}

local  g_controlPropListRow =
{
    [CT_BUTTON] =
    {
        th{name="Button properties"},
        td{name="bagId",        get=function(data, control)
                return control.bagId or control.bag
            end,
        isSpecial = true},
        td{name="slotIndex",    get=function(data, control)
                return control.slotIndex
            end,
        isSpecial = true},
        td{name="itemLink",    get=function(data, control)
                return prepareItemLink(control, false)
            end,
        isSpecial = true},
        td{name="itemLink plain text",    get=function(data, control)
                return prepareItemLink(control, true)
            end,
        isSpecial = true},
    },
    [CT_CONTROL] =
    {
        th{name="List row data properties"},
        td{name="dataEntry.data",  get=function(data, control)
            return control.dataEntry.data or control.dataEntry or control
        end},
        td{name="bagId",        get=function(data, control)
                return control.dataEntry.data.bagId or control.dataEntry.data.bag or control.dataEntry.bagId or control.dataEntry.bag or control.bagId or control.bag
            end,
        isSpecial = true},
        td{name="slotIndex",    get=function(data, control)
                return control.dataEntry.data.slotIndex or control.dataEntry.data.index or control.dataEntry.slotIndex or control.dataEntry.index or control.slotIndex
            end,
        isSpecial = true},
        td{name="itemLink",    get=function(data, control)
                return prepareItemLink(control, false)
            end,
        isSpecial = true},
        td{name="itemLink plain text",    get=function(data, control)
                return prepareItemLink(control, true)
            end,
        isSpecial = true},
    },
}

local g_commonProperties2 = {
    th{name="Anchor #0",        get="GetAnchor"},

    td{name="point",            cls=AnchorAttribute, idx=2, enum="AnchorPosition"},
    td{name="relativeTo",       cls=AnchorAttribute, idx=3, enum = "CT_names"},
    td{name="relativePoint",    cls=AnchorAttribute, idx=4, enum="AnchorPosition"},
    td{name="offsetX",          cls=AnchorAttribute, idx=5},
    td{name="offsetY",          cls=AnchorAttribute, idx=6},

    th{name="Anchor #1",        get="GetAnchor"},

    td{name="point",            cls=AnchorAttribute, idx=12, enum="AnchorPosition"},
    td{name="relativeTo",       cls=AnchorAttribute, idx=13, enum = "CT_names"},
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
        td{name="layer", enum="DL_names",     get="GetDrawLayer", set="SetDrawLayer"},
        td{name="level",                get="GetDrawLevel", set="SetDrawLevel"},
        td{name="mouseEnabled",         get="IsMouseEnabled", set="SetMouseEnabled"},
        td{name="resizeToFitDescendents",
                                        get="GetResizeToFitDescendents",
                                        set="SetResizeToFitDescendents"},
        td{name="scale",                get="GetScale", set="SetScale"},
        td{name="tier",  enum="DT_names",     get="GetDrawTier", set="SetDrawTier"},

        th{name="Children",             get="GetNumChildren"},
    },
    [CT_BACKDROP] =
    {
        th{name="Backdrop properties"},

        td{name="centerColor",          cls=ColorProperty},
        td{name="pixelRoundingEnabled", get="IsPixelRoundingEnabled",
                                        set="SetPixelRoundingEnabled"},
    },
    [CT_BUTTON] =
    {
        th{name="Button properties"},

        td{name="label",                get="GetLabelControl", enum = "CT_names"},
        td{name="pixelRoundingEnabled", get="IsPixelRoundingEnabled",
                                        set="SetPixelRoundingEnabled"},
        td{name="state", enum="BSTATE", get="GetState", set="SetState"},
    },
    [CT_COLORSELECT] =
    {
        th{name="ColorSelect properties"},

        td{name="colorAsRGB",               cls=ColorProperty},
        td{name="colorWheelTexture",        get="GetColorWheelTextureControl",
                                            set="SetColorWheelTextureControl"},
        td{name="colorWheelThumbTexture",   get="GetColorWheelThumbTextureControl",
                                            set="SetColorWheelThumbTextureControl"},
        td{name="fullValuedColorAsRGB",     get=ColorProperty.get},
        td{name="value",                    get="GetValue", set="SetValue"},
    },
    [CT_COMPASS] =
    {
        th{name="Compass properties"},

        td{name="numCenterOveredPins",  get="GetNumCenterOveredPins"},
    },
    [CT_COOLDOWN] =
    {
        th{name="Cooldown properties"},

        td{name="duration",             get="GetDuration"},
        td{name="percentCompleteFixed", get="GetPercentCompleteFixed",
                                        set="SetPercentCompleteFixed"},
        td{name="timeLeft",             get="GetTimeLeft"},
    },
    [CT_EDITBOX] =
    {
        th{name="Edit properties"},

        td{name="copyEnabled",          get="GetCopyEnabled", set="SetCopyEnabled"},
        td{name="cursorPosition",       get="GetCursorPosition", set="SetCursorPosition"},
        td{name="editEnabled",          get="GetEditEnabled", set="SetEditEnabled"},
        td{name="fontHeight",           get="GetFontHeight"},
        td{name="multiLine",            get="IsMultiLine", set="SetMultiLine"},
        td{name="newLineEnabled",       get="GetNewLineEnabled", set="SetNewLineEnabled"},
        td{name="pasteEnabled",         get="GetPasteEnabled", set="SetPasteEnabled"},
        td{name="scrollExtents",        get="GetScrollExtents"},
        td{name="text",                 get="GetText", set="SetText"},
        td{name="topLineIndex",         get="GetTopLineIndex", set="SetTopLineIndex"},
    },
    [CT_LABEL] =
    {
        th{name="Label properties"},

        td{name="color",                cls=ColorProperty},
        td{name="didLineWrap",          get="DidLineWrap"},
        td{name="fontHeight",           get="GetFontHeight"},
        td{name="horizontalAlignment",  get="GetHorizontalAlignment",
           enum="TEXT_ALIGN",           set="SetHorizontalAlignment"},
        td{name="modifyTextType",       get="GetModifyTextType",
           enum="MODIFY_TEXT_TYPE",     set="SetModifyTextType"},
        td{name="numLines",             get="GetNumLines"},
        td{name="styleColor",           cls=ColorProperty, scale=1},
        td{name="text",                 get="GetText", set="SetText"},
        td{name="textHeight",           get="GetTextHeight"},
        td{name="textWidth",            get="GetTextWidth"},
        td{name="verticalAlignment",    get="GetVerticalAlignment",
           enum="TEXT_ALIGN",           set="SetVerticalAlignment"},
        td{name="wasTruncated",         get="WasTruncated"},
    },
    [CT_LINE] =
    {
        th{name="Line properties"},

        td{name="blendMode",            get="GetBlendMode",
           enum="TEX_BLEND_MODE",       set="SetBlendMode"},
        td{name="color",                cls=ColorProperty},
        td{name="desaturation",         get="GetDesaturation",
                                        set="SetDesaturation"},
        td{name="pixelRoundingEnabled", get="IsPixelRoundingEnabled",
                                        set="SetPixelRoundingEnabled"},
        td{name="textureCoords.left",   gets="GetTextureCoords", idx=1,
                                        sets="SetTextureCoords"},
        td{name="textureCoords.right",  gets="GetTextureCoords", idx=2,
                                        sets="SetTextureCoords"},
        td{name="textureCoords.top",    gets="GetTextureCoords", idx=3,
                                        sets="SetTextureCoords"},
        td{name="textureCoords.bottom", gets="GetTextureCoords", idx=4,
                                        sets="SetTextureCoords"},
        td{name="textureFileName",      get="GetTextureFileName",
                                        set="SetTexture"},
        td{name="textureFileWidth",     gets="GetTextureFileDimensions", idx=1},
        td{name="textureFileHeight",    gets="GetTextureFileDimensions", idx=2},
        td{name="textureLoaded",        get="IsTextureLoaded"},
    },
    [CT_MAPDISPLAY] =
    {
        th{name="MapDisplay properties"},

        td{name="zoom",                 get="GetZoom", set="SetZoom"},
    },
    [CT_SCROLL] =
    {
        th{name="Scroll properties"},

        td{name="extents.horizontal",   gets="GetScrollExtents", idx=1},
        td{name="extents.vertical",     gets="GetScrollExtents", idx=2},
        td{name="offsets.horizontal",   gets="GetScrollOffsets", idx=1,
                                        set="SetHorizontalScroll"},
        td{name="offsets.vertical",     gets="GetScrollOffsets", idx=2,
                                        set="SetVerticalScroll"},
    },
    [CT_SLIDER] =
    {
        th{name="Slider properties"},

        td{name="allowDraggingFromThumb",   get="DoesAllowDraggingFromThumb",
                                            set="SetAllowDraggingFromThumb"},
        td{name="enabled",                  get="GetEnabled", set="SetEnabled"},
        td{name="orientation",              get="GetOrientation",
           enum="ORIENTATION",              set="SetOrientation"},
        td{name="thumbTexture",             get="GetThumbTextureControl"},
        td{name="valueMin",          idx=1, gets="GetMinMax", sets="SetMinMax"},
        td{name="value",                    get="GetValue", set="SetValue"},
        td{name="valueMax",          idx=2, gets="GetMinMax", sets="SetMinMax"},
        td{name="valueStep",                get="GetValueStep", set="SetValueStep"},
        td{name="thumbFlushWithExtents",    get="IsThumbFlushWithExtents",
                                            set="SetThumbFlushWithExtents"},
    },
    [CT_STATUSBAR] =
    {
        th{name="StatusBar properties"},

        td{name="valueMin",          idx=1, gets="GetMinMax", sets="SetMinMax"},
        td{name="value",                    get="GetValue", set="SetValue"},
        td{name="valueMax",          idx=2, gets="GetMinMax", sets="SetMinMax"},
    },
    [CT_TEXTBUFFER] =
    {
        th{name="TextBuffer properties"},

        td{name="drawLastEntryIfOutOfRoom", get="GetDrawLastEntryIfOutOfRoom",
                                            set="SetDrawLastEntryIfOutOfRoom"},
        td{name="linkEnabled",              get="GetLinkEnabled",
                                            set="SetLinkEnabled"},
        td{name="maxHistoryLines",          get="GetMaxHistoryLines",
                                            set="SetMaxHistoryLines"},
        td{name="numHistoryLines",          get="GetNumHistoryLines"},
        td{name="numVisibleLines",          get="GetNumVisibleLines"},
        td{name="scrollPosition",           get="GetScrollPosition",
                                            set="SetScrollPosition"},
        td{name="splitLongMessages",        get="IsSplittingLongMessages",
                                            set="SetSplitLongMessages"},
        td{name="timeBeforeLineFadeBegins", gets="GetLineFade", idx=1,
                                            sets="SetLineFade"},
        td{name="timeForLineToFade",        gets="GetLineFade", idx=2,
                                            sets="SetLineFade"},
    },
    [CT_TEXTURE] =
    {
        th{name="Texture properties"},

        td{name="addressMode",          get="GetAddressMode",
           enum="TEX_MODE",             set="SetAddressMode"},
        td{name="blendMode",            get="GetBlendMode",
           enum="TEX_BLEND_MODE",       set="SetBlendMode"},
        td{name="color",                cls=ColorProperty},
        td{name="desaturation",         get="GetDesaturation",
                                        set="SetDesaturation"},
        td{name="pixelRoundingEnabled", get="IsPixelRoundingEnabled",
                                        set="SetPixelRoundingEnabled"},
        td{name="resizeToFitFile",      get="GetResizeToFitFile",
                                        set="SetResizeToFitFile"},
        td{name="textureCoords.left",   gets="GetTextureCoords", idx=1,
                                        sets="SetTextureCoords"},
        td{name="textureCoords.right",  gets="GetTextureCoords", idx=2,
                                        sets="SetTextureCoords"},
        td{name="textureCoords.top",    gets="GetTextureCoords", idx=3,
                                        sets="SetTextureCoords"},
        td{name="textureCoords.bottom", gets="GetTextureCoords", idx=4,
                                        sets="SetTextureCoords"},
        td{name="textureFileName",      get="GetTextureFileName",
                                        set="SetTexture"},
        td{name="textureFileWidth",     gets="GetTextureFileDimensions", idx=1},
        td{name="textureFileHeight",    gets="GetTextureFileDimensions", idx=2},
        td{name="textureLoaded",        get="IsTextureLoaded"},

        td{name="VERTEX_POINTS_BOTTOMLEFT.U",   gets="GetVertexUV", idx=1,
           arg=VERTEX_POINTS_BOTTOMLEFT,        sets="SetVertexUV"},
        td{name="VERTEX_POINTS_BOTTOMLEFT.V",   gets="GetVertexUV", idx=2,
           arg=VERTEX_POINTS_BOTTOMLEFT,        sets="SetVertexUV"},
        td{name="VERTEX_POINTS_BOTTOMRIGHT.U",  gets="GetVertexUV", idx=1,
           arg=VERTEX_POINTS_BOTTOMRIGHT,       sets="SetVertexUV"},
        td{name="VERTEX_POINTS_BOTTOMRIGHT.V",  gets="GetVertexUV", idx=2,
           arg=VERTEX_POINTS_BOTTOMRIGHT,       sets="SetVertexUV"},
        td{name="VERTEX_POINTS_TOPLEFT.U",      gets="GetVertexUV", idx=1,
           arg=VERTEX_POINTS_TOPLEFT,           sets="SetVertexUV"},
        td{name="VERTEX_POINTS_TOPLEFT.V",      gets="GetVertexUV", idx=2,
           arg=VERTEX_POINTS_TOPLEFT,           sets="SetVertexUV"},
        td{name="VERTEX_POINTS_TOPRIGHT.U",     gets="GetVertexUV", idx=1,
           arg=VERTEX_POINTS_TOPRIGHT,          sets="SetVertexUV"},
        td{name="VERTEX_POINTS_TOPRIGHT.V",     gets="GetVertexUV", idx=2,
           arg=VERTEX_POINTS_TOPRIGHT,          sets="SetVertexUV"},
    },
    [CT_TEXTURECOMPOSITE] =
    {
        th{name="TextureComposite properties"},

        td{name="blendMode",            get="GetBlendMode",
           enum="TEX_BLEND_MODE",       set="SetBlendMode"},
        td{name="desaturation",         get="GetDesaturation",
                                        set="SetDesaturation"},
        td{name="numSurfaces",          get="GetNumSurfaces"},
        td{name="pixelRoundingEnabled", get="IsPixelRoundingEnabled",
                                        set="SetPixelRoundingEnabled"},
        td{name="textureFileName",      get="GetTextureFileName",
                                        set="SetTexture"},
        td{name="textureFileWidth",     gets="GetTextureFileDimensions", idx=1},
        td{name="textureFileHeight",    gets="GetTextureFileDimensions", idx=2},
        td{name="textureLoaded",        get="IsTextureLoaded"},
    },
    [CT_TOOLTIP] =
    {
        th{name="Tooltip properties"},

        td{name="owner",                get="GetOwner", enum = "CT_names"},
    },
    [CT_TOPLEVELCONTROL] =
    {
        th{name="TopLevelControl properties"},

        td{name="allowBringToTop",      get="AllowBringToTop",
                                        set="SetAllowBringToTop", enum = "CT_names"},
    },
}


function ControlInspectorPanel:__init__(control, ...)
    ObjectInspectorPanel.__init__(self, control, ...)
end


local function createPropEntry(data)
    -->Created within "ControlInspectorPanel:initScrollList" for the list
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
        local doAdd = true
        if prop.checkFunc then
            doAdd = prop.checkFunc(subject)
        end
        if doAdd == true then
            n = n + 1
            masterList[n] = createPropEntry{prop = prop}
        end
    end

    local controlPropsListRows = g_controlPropListRow[controlType]
    if controlPropsListRows then
        local _, controlName = pcall(invoke, subject, "GetName")
        if controlName and controlName ~= "" then
            if tbug.isSupportedInventoryRowPattern(controlName) == true then
                for _, prop in ipairs(controlPropsListRows) do
                    n = n + 1
                    masterList[n] = createPropEntry{prop = prop}
                end
            else
            end
        end
    end

    for _, prop in ipairs(g_commonProperties2) do
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
        local childProp = td{name = tostring(i), get = getControlChild, enum = "CT_names"}
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
        if typ ~= nil then
            cell:SetColor(typeColors[typ]:UnpackRGBA())
        end
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
        local prop = data.prop
        local getter = prop.get
        local ok, v

        if type(getter) == "function" then
            ok, v = pcall(getter, data, self.subject)
        else
            ok, v = pcall(invoke, self.subject, getter)
        end
        local k = prop.name
        local tk = (k == "__index" and "event" or type(k))
        local tv = type(v)
        data.value = v

        self:setupRow(row, data)
        setupValue(row.cKeyLeft, tk, k)
        setupValue(row.cKeyRight, tk, "")

        if tv == "string" then
            setupValue(row.cVal, tv, strformat("%q", v))
            if prop.isColor and prop.isColor == true then
                setupValue(row.cKeyRight, nil, "[COLOR EXAMPLE, click to change]")
                local currentColor = tbug.parseColorDef(v)
                row.cKeyRight:SetColor(currentColor:UnpackRGBA())
            end
        elseif tv == "number" then
            local enum = prop.enum
            if enum then
                local nv = tbug.glookupEnum(enum)[v]
                if v ~= nv then
                    setupValue(row.cKeyRight, tv, nv)
                end
            end
            setupValue(row.cVal, tv, v)
        elseif tv == "userdata" then
            local ct, ctName = tbug.getControlType(v, prop.enum)
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

    self:addDataType(ROW_TYPE_HEADER,   "tbugTableInspectorHeaderRow",  24, setupHeader, hideCallback)
    self:addDataType(ROW_TYPE_PROPERTY, "tbugTableInspectorRow",        24, setupSimple, hideCallback)
end

function ControlInspectorPanel:onRowClicked(row, data, mouseButton, ctrl, alt, shift)
    ClearMenu()
    if mouseButton == MOUSE_BUTTON_INDEX_LEFT then
        self.editBox:LoseFocus()
        if MouseIsOver(row.cKeyRight) then
            local prop = data.prop
            if prop and prop.isColor and prop.isColor == true then
                tbug.showColorPickerAtRow(self, row, data)
            end
        else
            local title = data.prop.name
            if data.childIndex then
                -- data.prop.name is just the string form of data.childIndex,
                -- it's better to use the child's name for title in this case
                local ok, name = pcall(invoke, data.value, "GetName")
                if ok then
                    local parentName = tbug.getControlName(self.subject)
                    local ms, me = name:find(parentName, 1, true)
                    if ms == 1 and me < #name then
                        -- take only the part after the parent's name
                        title = name:sub(me + 1)
                    else
                        title = name
                    end
                end
            end
            if shift then
                local inspector = tbug.inspect(data.value, title, nil, false)
                if inspector then
                    inspector.control:BringWindowToTop()
                end
            else
                self.inspector:openTabFor(data.value, title)
            end
        end
    elseif mouseButton == MOUSE_BUTTON_INDEX_RIGHT then
        if MouseIsOver(row.cVal) then
            if self:canEditValue(data) then
                self:valueEditStart(self.editBox, row, data)
            end
            tbug.buildRowContextMenuData(self, row, data)
        elseif MouseIsOver(row.cKeyLeft) or MouseIsOver(row.cKeyRight) then
            self.editBox:LoseFocus()
            tbug.buildRowContextMenuData(self, row, data, true)
        else
            self.editBox:LoseFocus()
        end
    end
end

function ControlInspectorPanel:onRowDoubleClicked(row, data, mouseButton, ctrl, alt, shift)
--df("tbug:ControlInspectorPanel:onRowDoubleClicked")
    ClearMenu()
    if mouseButton == MOUSE_BUTTON_INDEX_LEFT then
        if MouseIsOver(row.cVal) then
            if self:canEditValue(data) then
                if type(data.value) == "boolean" then
                    local oldValue = data.value
                    if oldValue == true then
                        data.value = false
                    else
                        data.value = true
                    end
                    tbug.setEditValueFromContextMenu(self, row, data, oldValue)
                else
                    local prop = data.prop
                    if prop and prop.isColor and prop.isColor == true then
                        tbug.showColorPickerAtRow(self, row, data)
                    end
                end
            end
        end
    end
end

function ControlInspectorPanel:valueEditConfirmed(editBox, evalResult)
--d("[tbug]ControlInspectorPanel:valueEditConfirmed")
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