local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")
local tos = tostring
local type = type

local typeColors = tbug.cache.typeColors

local tbug_truncate = tbug.truncate
local tbug_specialKeyToColorType = tbug.specialKeyToColorType

--------------------------------


-------------------------------
-- class ScriptsInspectorPanel --

local classes = tbug.classes
local ObjectInspectorPanel = classes.ObjectInspectorPanel
local TableInspectorPanel = classes.TableInspectorPanel
local ScriptsInspectorPanel = classes.ScriptsInspectorPanel .. TableInspectorPanel

ScriptsInspectorPanel.CONTROL_PREFIX = "$(parent)PanelScripts"
ScriptsInspectorPanel.TEMPLATE_NAME = "tbugScriptsInspectorPanel"

--Update the table tbug.panelClassNames with the ScriptInspectorPanel class
tbug.panelClassNames["scriptInspector"] = ScriptsInspectorPanel


local RT = tbug.RT

function ScriptsInspectorPanel:__init__(control, ...)
    TableInspectorPanel.__init__(self, control, ...)
    self.scriptEditBox = GetControl(self.control, "ScriptBackdropBox") --tbugGlobalInspectorPanelScripts1ScriptBackdropBox

tbug._selfScriptsInspectorPanel = self
end


function ScriptsInspectorPanel:bindMasterList(editTable, specialMasterListID)
    self.subject = editTable
    self.specialMasterListID = specialMasterListID
end


function ScriptsInspectorPanel:buildMasterList()
--d("[tbug]ScriptsInspectorPanel:buildMasterList")
    self:buildMasterListSpecial()
end


function ScriptsInspectorPanel:buildMasterListSpecial()
    local editTable = self.subject
    local specialMasterListID = self.specialMasterListID
--d(string.format("[tbug]ScriptsInspectorPanel:buildMasterListSpecial - specialMasterListID: %s, scenes: %s, fragments: %s", tos(specialMasterListID), tos(isScenes), tos(isFragments)))

    if rawequal(editTable, nil) then
        return true
    elseif (specialMasterListID and specialMasterListID == RT.SCRIPTHISTORY_TABLE) or rawequal(editTable, tbug.ScriptsData) then
        tbug.refreshScripts()
        self:bindMasterList(tbug.ScriptsData, RT.SCRIPTHISTORY_TABLE)
        self:populateMasterList(editTable, RT.SCRIPTHISTORY_TABLE)
    else
        return false
    end
    return true
end


function ScriptsInspectorPanel:canEditValue(data)
    local dataEntry = data.dataEntry
    if not dataEntry then return false end
    local typeId = dataEntry.typeId
    return typeId == RT.SCRIPTHISTORY_TABLE
end


function ScriptsInspectorPanel:clearMasterList(editTable)
    local masterList = self.masterList
    tbug_truncate(masterList, 0)
    self.subject = editTable
    return masterList
end


function ScriptsInspectorPanel:initScrollList(control)
    TableInspectorPanel.initScrollList(self, control)

    --Check for special key colors!
    local function checkSpecialKeyColor(keyValue)
        if keyValue == "event" or not tbug_specialKeyToColorType then return end
        local newType = tbug_specialKeyToColorType[keyValue]
        return newType
    end

    local function setupValue(cell, typ, val, isKey)
        isKey = isKey or false
        cell:SetColor(typeColors[typ]:UnpackRGBA())
        cell:SetText(tos(val))
    end

    local function setupCommon(row, data, list, font)
        local k = data.key
        local tk = data.meta and "event" or type(k)
        local tkOrig = tk
        tk = checkSpecialKeyColor(k) or tkOrig

        self:setupRow(row, data)
        if row.cKeyLeft then
            setupValue(row.cKeyLeft, tk, k, true)
            if font and font ~= "" then
                row.cKeyLeft:SetFont(font)
            end
        end
        if row.cKeyRight then
            setupValue(row.cKeyRight, tk, "", true)
        end

        return k, tkOrig
    end

    local function setupScriptHistory(row, data, list)
        local k, tk = setupCommon(row, data, list)
        local v = data.value
        local tv = type(v)

        row.cVal:SetText("")
        if tv == "string" then
            setupValue(row.cVal, tv, v)
        end
        if row.cVal2 then
            row.cVal2:SetText("")
            v = nil
            v = tbug.getScriptHistoryComment(data.key)
            if v ~= nil and v ~= "" then
                setupValue(row.cVal2, "comment", v)
            end
        end
    end

    local function hideCallback(row, data)
        if self.editData == data then
            self.editBox:ClearAnchors()
            self.editBox:SetAnchor(BOTTOMRIGHT, nil, TOPRIGHT, 0, -20)
        end
    end

    self:addDataType(RT.SCRIPTHISTORY_TABLE,    "tbugTableInspectorRow3",   40, setupScriptHistory, hideCallback)
end


--Clicking on a tables index (e.g.) 6 should not open a new tab called 6 but tableName[6] instead
function ScriptsInspectorPanel:BuildWindowTitleForTableKey(data)
    local winTitle
    if data.key and type(tonumber(data.key)) == "number" then
        winTitle = self.inspector.activeTab.label:GetText()
        if winTitle and winTitle ~= "" then
            winTitle = tbug.cleanKey(winTitle)
            winTitle = winTitle .. "[" .. tos(data.key) .. "]"
--d(">tabTitle: " ..tos(tabTitle))
        end
    end
    return winTitle
end



function ScriptsInspectorPanel:onRowClicked(row, data, mouseButton, ctrl, alt, shift)
--d("[tbug]ScriptsInspectorPanel:onRowClicked")
    if mouseButton == MOUSE_BUTTON_INDEX_RIGHT then
        TableInspectorPanel.onRowClicked(self, row, data, mouseButton, ctrl, alt, shift)
    else
        if mouseButton == MOUSE_BUTTON_INDEX_LEFT then
            if MouseIsOver(row.cVal) then
                local value = data.value
                if value ~= nil and value ~= "" and data.dataEntry.typeId == RT.SCRIPTHISTORY_TABLE then
                    local typeValue = type(value)
                    if typeValue == "string" then
                        --Load the clicked script text to the script multi line edit box
                        self.scriptEditBox:SetText(value)
                    end
                end
            end
        end
    end
end

function ScriptsInspectorPanel:onRowDoubleClicked(row, data, mouseButton, ctrl, alt, shift)
--df("tbug:ScriptsInspectorPanel:onRowDoubleClicked")
    ClearMenu()
    if mouseButton == MOUSE_BUTTON_INDEX_LEFT then
        local sliderCtrl = self.sliderControl

        local value = data.value
        local typeValue = type(value)
        if MouseIsOver(row.cVal) then
            if sliderCtrl ~= nil then
                sliderCtrl.panel:valueSliderCancel(sliderCtrl)
            end
            if self:canEditValue(data) then
                if typeValue == "string" then
                    if value ~= "" and data.dataEntry.typeId == RT.SCRIPTHISTORY_TABLE then
                        --CHAT_SYSTEM.textEntry.system:StartTextEntry("/script " .. data.value)
                        StartChatInput("/tbug " .. value, CHAT_CHANNEL_SAY, nil, false)
                    end
                end
            end
        end
    end
end

function ScriptsInspectorPanel:populateMasterList(editTable, dataType)
    local masterList, n = self.masterList, 0
    for k, v in next, editTable do
        n = n + 1
        local data = {key = k, value = v}
        masterList[n] = ZO_ScrollList_CreateDataEntry(dataType, data)
    end
    return tbug_truncate(masterList, n)
end

--[[
function ScriptsInspectorPanel:valueEditStart(editBox, row, data)
    d("ScriptsInspectorPanel:valueEditStart")
    ObjectInspectorPanel.valueEditStart(self, editBox, row, data)
end
]]

function ScriptsInspectorPanel:valueEditConfirmed(editBox, evalResult)
    local editData = self.editData
    --d(">editBox.updatedColumnIndex: " .. tos(editBox.updatedColumnIndex))
    local function confirmEditBoxValueChange(p_setIndex, p_editTable, p_key, p_evalResult)
        local l_ok, l_setResult = pcall(p_setIndex, p_editTable, p_key, p_evalResult)
        return l_ok, l_setResult
    end

    if editData then
        local editTable = editData.meta or self.subject
        local updateSpecial = false
        if editBox.updatedColumn ~= nil and editBox.updatedColumnIndex ~= nil then
            updateSpecial = true
        end
        if updateSpecial == false then
            local ok, setResult = confirmEditBoxValueChange(tbug.setindex, editTable, editData.key, evalResult)
            if not ok then return setResult end
            self.editData = nil
            editData.value = setResult
        else
            local typeId = editData.dataEntry.typeId
            --Update script history script or comment
            if typeId and typeId == RT.SCRIPTHISTORY_TABLE then
                tbug.changeScriptHistory(editData.dataEntry.data.key, editBox, evalResult) --Use the row's dataEntry.data table for the key or it will be the wrong one after scrolling!
                editBox.updatedColumn:SetHidden(false)
                if evalResult == "" then
                    editBox.updatedColumn:SetText("")
                end
            --TypeId not given or generic
            elseif (not typeId or typeId == RT.GENERIC) then
                local ok, setResult = confirmEditBoxValueChange(tbug.setindex, editTable, editData.key, evalResult)
                if not ok then return setResult end
                self.editData = nil
                editData.value = setResult
            end
        end
        -- refresh only the edited row
        ZO_ScrollList_RefreshVisible(self.list, editData)
    end
    editBox:LoseFocus()
    editBox.updatedColumn = nil
    editBox.updatedColumnIndex = nil
end

function ScriptsInspectorPanel:testScript(row, data, key)
    d("ScriptsInspectorPanel:testScript - key: " ..tos(key) .. ", value: " ..tos(data.value))
    --local currentScriptEditBoxText = self.scriptEditBox:GetText()
    local value = data.value
    if value == nil or value == "" then return end
    self.scriptEditBox:SetText(value)
    --TODO test the script now
end