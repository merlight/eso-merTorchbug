local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")
local strformat = string.format
local typeColors = tbug.cache.typeColors
local typeSafeLess = tbug.typeSafeLess


local function invoke(object, method, ...)
    return object[method](object, ...)
end


-------------------------------
-- class TableInspectorPanel --

local ObjectInspectorPanel = tbug.classes.ObjectInspectorPanel
local TableInspectorPanel = tbug.classes.TableInspectorPanel .. ObjectInspectorPanel

TableInspectorPanel.CONTROL_PREFIX = "$(parent)PanelT"
TableInspectorPanel.TEMPLATE_NAME = "tbugTableInspectorPanel"

local RT = tbug.subtable(TableInspectorPanel, "ROW_TYPES")

RT.GENERIC = 1
RT.FONT_OBJECT = 2
RT.LOCAL_STRING = 3
RT.SOUND_STRING = 4
RT.LIB_TABLE = 5


function TableInspectorPanel:__init__(control, ...)
    ObjectInspectorPanel.__init__(self, control, ...)

    self.compareFunc = function(a, b)
        local aa, bb = a.data, b.data
        if not aa.meta then
            if bb.meta then
                return false
            end
        elseif not bb.meta then
            return true
        end
        return typeSafeLess(aa.key, bb.key)
    end
end


function TableInspectorPanel:bindMasterList(editTable)
    self.subject = editTable
end


function TableInspectorPanel:buildMasterList()
    if self:buildMasterListSpecial() then
        return
    end

    local masterList = self.masterList
    local n = 0

    for k, v in next, self.subject do
        local tv = type(v)
        local rt = RT.GENERIC

        if tv == "userdata" and pcall(invoke, v, "GetFontInfo") then
            rt = RT.FONT_OBJECT
        end

        local data = {key = k, value = v}
        n = n + 1
        masterList[n] = ZO_ScrollList_CreateDataEntry(rt, data)
    end

    local mt = getmetatable(self.subject)
    if mt then
        local rt = RT.GENERIC
        if rawequal(mt, rawget(mt, "__index")) then
            -- metatable refers to itself, which is typical for class
            -- tables containing methods => only insert the __index
            local data = {key = "__index", value = mt, meta = mt}
            n = n + 1
            masterList[n] = ZO_ScrollList_CreateDataEntry(rt, data)
        else
            -- insert the whole metatable contents
            for k, v in next, mt do
                local data = {key = k, value = v, meta = mt}
                n = n + 1
                masterList[n] = ZO_ScrollList_CreateDataEntry(rt, data)
            end
        end
    end

    tbug.truncate(masterList, n)
end


function TableInspectorPanel:buildMasterListSpecial()
    local editTable = self.subject
    if rawequal(editTable, nil) then
        return true
    elseif rawequal(editTable, _G.ESO_Dialogs) then
        self:populateMasterList(editTable, RT.GENERIC)
    elseif rawequal(editTable, _G.EsoStrings) then
        self:populateMasterList(editTable, RT.LOCAL_STRING)
    elseif rawequal(editTable, _G.SOUNDS) then
        self:populateMasterList(editTable, RT.SOUND_STRING)
    elseif rawequal(editTable, LibStub.libs) then
        self:populateMasterList(editTable, RT.LIB_TABLE)
    else
        return false
    end
    return true
end


function TableInspectorPanel:canEditValue(data)
    local typeId = data.dataEntry.typeId
    return typeId == RT.GENERIC
        or typeId == RT.LOCAL_STRING
        or typeId == RT.SOUND_STRING
end


function TableInspectorPanel:clearMasterList(editTable)
    local masterList = self.masterList
    tbug.truncate(masterList, 0)
    self.subject = editTable
    return masterList
end


function TableInspectorPanel:initScrollList(control)
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

    local function setupCommon(row, data, list)
        local k = data.key
        local tk = data.meta and "event" or type(k)

        self:setupRow(row, data)
        setupValue(row.cKeyLeft, tk, k)
        setupValue(row.cKeyRight, tk, "")

        return k, tk
    end

    local function setupGeneric(row, data, list)
        local k, tk = setupCommon(row, data, list)
        local v = data.value
        local tv = type(v)

        if v == nil or tv == "boolean" or tv == "number" then
            setupValue(row.cVal, tv, v)
        elseif tv == "string" then
            setupValue(row.cVal, tv, strformat("%q", v))
        elseif tv == "table" and next(v) == nil then
            setupValue(row.cVal, tv, "{}")
        elseif tv == "userdata" then
            local ct, ctName = tbug.getControlType(v)
            if ct then
                setupValue(row.cKeyRight, type(ct), ctName)
                setupValue(row.cVal, tv, tbug.getControlName(v))
            else
                setupValueLookup(row.cVal, tv, v)
            end
        else
            setupValueLookup(row.cVal, tv, v)
            if rawequal(v, self.subject) then
                setupValue(row.cKeyRight, tv, "self")
            end
        end
    end

    local function setupFontObject(row, data, list)
        local k, tk = setupCommon(row, data, list)
        local v = data.value
        local tv = type(v)

        local ok, face, size, option = pcall(invoke, v, "GetFontInfo")
        if ok then
            v = strformat("%s||%s||%s",
                          typeColors[type(face)]:Colorize(face),
                          typeColors[type(size)]:Colorize(size),
                          typeColors[type(option)]:Colorize(option))
        end

        setupValue(row.cVal, tv, v)
    end

    local function setupLibTable(row, data, list)
        local k, tk = setupCommon(row, data, list)
        local v = data.value

        if type(LibStub.minors) == "table" then
            local m = LibStub.minors[k]
            setupValue(row.cKeyRight, type(m), m)
        end

        setupValue(row.cVal, type(v), v)
    end

    local function setupLocalString(row, data, list)
        local k, tk = setupCommon(row, data, list)
        local v = data.value
        local tv = type(v)

        if tk == "number" then
            local si = rawget(tbug.glookupEnum("SI"), k)
            row.cKeyLeft:SetText(si or "")
            row.cKeyRight:SetText(tostring(k))
        end

        if tv == "string" then
            setupValue(row.cVal, tv, strformat("%q", v))
        else
            setupValue(row.cVal, tv, v)
        end
    end

    local function hideCallback(row, data)
        if self.editData == data then
            self.editBox:ClearAnchors()
            self.editBox:SetAnchor(BOTTOMRIGHT, nil, TOPRIGHT, 0, -20)
        end
    end

    self:addDataType(RT.GENERIC, "tbugTableInspectorRow", 24, setupGeneric, hideCallback)
    self:addDataType(RT.FONT_OBJECT, "tbugTableInspectorRow", 24, setupFontObject, hideCallback)
    self:addDataType(RT.LOCAL_STRING, "tbugTableInspectorRow", 24, setupLocalString, hideCallback)
    self:addDataType(RT.SOUND_STRING, "tbugTableInspectorRow", 24, setupGeneric, hideCallback)
    self:addDataType(RT.LIB_TABLE, "tbugTableInspectorRow", 24, setupLibTable, hideCallback)
end


function TableInspectorPanel:onRowClicked(row, data, mouseButton, ctrl, alt, shift)
    ClearMenu()
    if mouseButton == MOUSE_BUTTON_INDEX_LEFT then
        self.editBox:LoseFocus()
        if type(data.value) == "string" then
            if data.dataEntry.typeId == RT.SOUND_STRING then
                PlaySound(data.value)
            end
        elseif not shift and self.inspector.openTabFor then
            self.inspector:openTabFor(data.value, tostring(data.key))
        else
            local inspector = tbug.inspect(data.value, tostring(data.key), nil, not shift)
            if inspector then
                inspector.control:BringWindowToTop()
            end
        end
    elseif mouseButton == MOUSE_BUTTON_INDEX_RIGHT then
        if MouseIsOver(row.cVal) and self:canEditValue(data) then
            self:valueEditStart(self.editBox, row, data)
            tbug.buildRowContextMenuData(self, row, data)
        else
            self.editBox:LoseFocus()
        end
    end
end

function TableInspectorPanel:onRowDoubleClicked(row, data, mouseButton, ctrl, alt, shift)
--df("tbug:TableInspectorPanel:onRowDoubleClicked")
    ClearMenu()
    if mouseButton == MOUSE_BUTTON_INDEX_LEFT then
        if MouseIsOver(row.cVal) and self:canEditValue(data) then
            if type(data.value) == "boolean" then
                local oldValue = data.value
                local newValue = not data.value
                data.value = newValue
                tbug.setEditValueFromContextMenu(self, row, data, oldValue)
            end
        end
    end
end

function TableInspectorPanel:populateMasterList(editTable, dataType)
    local masterList, n = self.masterList, 0
    for k, v in next, editTable do
        n = n + 1
        local dataEntry = masterList[n]
        if dataEntry then
            dataEntry.typeId = dataType
            dataEntry.data.key = k
            dataEntry.data.value = v
        else
            local data = {key = k, value = v}
            masterList[n] = ZO_ScrollList_CreateDataEntry(dataType, data)
        end
    end
    return tbug.truncate(masterList, n)
end


function TableInspectorPanel:valueEditConfirmed(editBox, evalResult)
    local editData = self.editData
    if editData then
        local editTable = editData.meta or self.subject
        local ok, setResult = pcall(tbug.setindex, editTable, editData.key, evalResult)
        if not ok then
            return setResult
        end
        self.editData = nil
        editData.value = setResult
        -- refresh only the edited row
        ZO_ScrollList_RefreshVisible(self.list, editData)
    end
    editBox:LoseFocus()
end
