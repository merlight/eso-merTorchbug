local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")
local cm = CALLBACK_MANAGER
local wm = WINDOW_MANAGER

local BLUE = ZO_ColorDef:New(0.8, 0.8, 1.0)
local RED  = ZO_ColorDef:New(1.0, 0.2, 0.2)

local endsWith = tbug.endsWith
local tbug_glookup = tbug.glookup

--------------------------------
local function roundDecimalToPlace(decimal, place)
    return tonumber(string.format("%." .. tostring(place) .. "f", decimal))
end

local function clampValue(value, min, max)
    return math.max(math.min(value, max), min)
end

--------------------------------
-- class ObjectInspectorPanel --
local classes = tbug.classes
local BasicInspectorPanel = classes.BasicInspectorPanel
local ObjectInspectorPanel = classes.ObjectInspectorPanel .. BasicInspectorPanel


local function valueEdit_OnEnter(editBox)
    editBox.panel:valueEditConfirm(editBox)
end


local function valueEdit_OnFocusLost(editBox)
    editBox.panel:valueEditCancel(editBox)
end


local function valueEdit_OnTextChanged(editBox)
    editBox.panel:valueEditUpdate(editBox)
end

local function valueSlider_OnEnter(sliderCtrl)
d("valueSlider_OnEnter")
    sliderCtrl.panel:valueSliderConfirm(sliderCtrl)
end


local function valueSlider_OnFocusLost(sliderCtrl)
d("valueSlider_OnFocusLost")
    sliderCtrl.panel:valueSliderCancel(sliderCtrl)
end


local function valueSlider_OnValueChanged(sliderCtrl)
d("valueSlider_OnValueChanged")
    sliderCtrl.panel:valueSliderUpdate(sliderCtrl)
end


function ObjectInspectorPanel:__init__(control, ...)
    BasicInspectorPanel.__init__(self, control, ...)

    self:initScrollList(control)
    local contentsOfList = self.list.contents
    self:createValueEditBox(contentsOfList)
    self:createValueSliderControl(contentsOfList)

    cm:RegisterCallback("tbugChanged:typeColor", function() self:refreshVisible() end)
end


--Edit box control
function ObjectInspectorPanel:createValueEditBox(parent)
    local editBox = wm:CreateControlFromVirtual("$(parent)ValueEdit", parent,
                                                "ZO_DefaultEdit")
    self.editBox = editBox
    self.editData = nil
    self.editBoxActive = nil
    editBox.panel = self

    editBox:SetDrawLevel(10)
    editBox:SetMaxInputChars(1024) -- hard limit in ESO 2.1.7
    editBox:SetFont("ZoFontGameSmall")
    editBox:SetHandler("OnEnter", valueEdit_OnEnter)
    editBox:SetHandler("OnFocusLost", valueEdit_OnFocusLost)
    editBox:SetHandler("OnTextChanged", valueEdit_OnTextChanged)
end

function ObjectInspectorPanel:anchorEditBoxToListCell(editBox, listCell)
    editBox:ClearAnchors()
    editBox:SetAnchor(TOPRIGHT, listCell, TOPRIGHT, 0, 4)
    editBox:SetAnchor(BOTTOMLEFT, listCell, BOTTOMLEFT, 0, -3)
    listCell:SetHidden(true)
    self.sliderCtrlActive = false
end

function ObjectInspectorPanel:valueEditCancel(editBox)
    ClearMenu()
    local editData = self.editData
    if editData then
        self.editData = nil
        ZO_ScrollList_RefreshVisible(self.list, editData)
    end
    editBox:SetHidden(true)
    editBox.updatedColumn = nil
    editBox.updatedColumnIndex = nil
    self.editBoxActive = false
end


function ObjectInspectorPanel:valueEditConfirm(editBox)
    ClearMenu()
    local expr = editBox:GetText()
--df("tbug: edit confirm: %s", expr)
    if editBox.updatedColumn ~= nil and editBox.updatedColumnIndex ~= nil then
        if self.editData and self.editData.dataEntry and self.editData.dataEntry.typeId == tbug.RT.SCRIPTHISTORY_TABLE then
            self:valueEditConfirmed(editBox, expr)
            return
        end
    end

    local func, err = zo_loadstring("return " .. expr)
    if not func then
        df("|c%stbug: %s", RED:ToHex(), err)
        return
    end

    local ok, evalResult = pcall(setfenv(func, tbug.env))
    if not ok then
        df("|c%stbug: %s", RED:ToHex(), evalResult)
        return
    end

    local err = self:valueEditConfirmed(editBox, evalResult)
    if err then
        df("|c%stbug: %s", RED:ToHex(), err)
    end
end


function ObjectInspectorPanel:valueEditConfirmed(editBox, evalResult)
    return "valueEditConfirmed: intended to be overridden"
end


function ObjectInspectorPanel:valueEditStart(editBox, row, data)
--[[
tbug._clickedRow = {
    self = self,
    editBox = editBox,
    row = row,
    data = data,
    slider = self.sliderControl,
}
]]
    if self.editData ~= data then
        editBox.updatedColumn = nil
        editBox.updatedColumnIndex = nil
        editBox:LoseFocus()

        local sliderCtrl = self.sliderControl
        sliderCtrl.updatedColumn = nil
        sliderCtrl.updatedColumnIndex = nil

        --df("tbug: edit start")
        local cValRow
        local columnIndex
        if MouseIsOver(row.cVal) then
            cValRow = row.cVal
            columnIndex = 1
        elseif MouseIsOver(row.cVal2) then
            cValRow = row.cVal2
            columnIndex = 2
        end
        if cValRow then
            --The row should show a number slider to change the values?
            if data.prop and data.prop.sliderData and self.sliderData ~= data then
                --sliderData={min=0, max=1, step=0.1}
                self.sliderSetupData = data.prop.sliderData
                 local sliderSetupData = self.sliderSetupData
                --d(">slider should show: " ..tostring(sliderData.min) .."-"..tostring(sliderData.max) .. ", step: " ..tostring(sliderData.step))
                sliderCtrl.updatedColumn = cValRow
                sliderCtrl.updatedColumnIndex = columnIndex
                --sliderCtrl:SetValue(roundDecimalToPlace(2, tonumber(cValRow:GetText())))
                local currentValue = tonumber(cValRow:GetText())
d(">currentValue: " ..tostring(currentValue))
                currentValue = clampValue(currentValue, tonumber(sliderSetupData.min), tonumber(sliderSetupData.max))
d(">currentValueClamped: " ..tostring(currentValue))
                currentValue = roundDecimalToPlace(currentValue, 2)
d(">currentValueRounded: " ..tostring(currentValue))
                sliderCtrl:SetMinMax(tonumber(sliderSetupData.min), tonumber(sliderSetupData.max))
                sliderCtrl:SetValueStep(tonumber(sliderSetupData.step))
                sliderCtrl:SetValue(tonumber(currentValue))
                sliderCtrl:SetHidden(false)
                self:anchorSliderControlToListCell(sliderCtrl, cValRow)
                self.sliderData = data
            end
            if not self.sliderCtrlActive == true then
                editBox.updatedColumn = cValRow
                editBox.updatedColumnIndex = columnIndex
                editBox:SetText(cValRow:GetText())
                editBox:SetHidden(false)
                editBox:TakeFocus()
                self:anchorEditBoxToListCell(editBox, cValRow)
                self.editData = data
            end
        end
    end
end


function ObjectInspectorPanel:valueEditUpdate(editBox)
    ClearMenu()
    local expr = editBox:GetText()
    if editBox.updatedColumn ~= nil and editBox.updatedColumnIndex ~= nil then
        if self.editData and self.editData.dataEntry and self.editData.dataEntry.typeId == tbug.RT.SCRIPTHISTORY_TABLE then
            return
        end
    end
    local func, err = zo_loadstring("return " .. expr)
    -- syntax check only, no evaluation yet
    if func then
        editBox:SetColor(BLUE:UnpackRGBA())
    else
        editBox:SetColor(RED:UnpackRGBA())
    end
end


--Slider control
function ObjectInspectorPanel:createValueSliderControl(parent)
    local sliderControl = wm:CreateControlFromVirtual("$(parent)ValueSlider", parent,
                                                "tbugValueSlider")
    self.sliderControl = sliderControl
    self.sliderSetupData = nil
    self.sliderData = nil
    self.sliderCtrlActive = nil
    sliderControl.panel = self
    self.sliderSaveButton = GetControl(sliderControl, "SaveButton")
    self.sliderSaveButton:SetHandler("OnMouseUp", function(sliderSaveButtonControl, mouseButton, upInside, shift, ctrl, alt, command)
        --Clear the context menu
        ClearMenu()
        if mouseButton == MOUSE_BUTTON_INDEX_LEFT and upInside then
            --Save the current chosen value of the slider
d(">Save slider value: " ..tostring(sliderControl:GetValue()))
            --Update the value to the row label
            sliderControl.panel:valueSliderConfirm(sliderControl)

            --Hide the slider
            sliderControl:SetHidden(true)
        end
    end)


    sliderControl:SetDrawLevel(10)
    sliderControl:SetHandler("OnEnter", valueSlider_OnEnter)
    sliderControl:SetHandler("OnFocusLost", valueSlider_OnFocusLost) --todo FocusLost exists?
    sliderControl:SetHandler("OnValueChanged", valueSlider_OnValueChanged)
end

function ObjectInspectorPanel:anchorSliderControlToListCell(sliderControl, listCell)
d("tbug: anchorSliderControlToListCell")
    sliderControl:ClearAnchors()
    sliderControl:SetAnchor(TOPRIGHT, listCell, TOPRIGHT, -30, 4)
    sliderControl:SetAnchor(BOTTOMLEFT, listCell, BOTTOMLEFT, 100, -3) --anchor offset 100 pixel to the right to see the original value
    --listCell:SetHidden(true)
    self.sliderCtrlActive = true
end

function ObjectInspectorPanel:valueSliderConfirm(sliderCtrl)
    ClearMenu()
    local expr = tostring(sliderCtrl:GetValue())
    local sliderSetupData = self.sliderSetupData
    expr = clampValue(roundDecimalToPlace(expr, 2), sliderSetupData.min, sliderSetupData.max)
df("tbug: slider confirm: %s", expr)
    --[[
    if sliderCtrl.updatedColumn ~= nil and sliderCtrl.updatedColumnIndex ~= nil then
        if self.sliderData  then
            --self:valueSliderConfirmed(sliderCtrl, expr)
            return
        end
    end
    ]]

    local func, err = zo_loadstring("return " .. expr)
    if not func then
        df("|c%stbug: %s", RED:ToHex(), err)
        return
    end

    local ok, evalResult = pcall(setfenv(func, tbug.env))
    if not ok then
        df("|c%stbug: %s", RED:ToHex(), evalResult)
        return
    end

    local err = self:valueSliderConfirmed(sliderCtrl, evalResult)
    if err then
        df("|c%stbug: %s", RED:ToHex(), err)
    end
end


function ObjectInspectorPanel:valueSliderUpdate(sliderCtrl)
    ClearMenu()
    ZO_Tooltips_HideTextTooltip()
    local expr = tostring(sliderCtrl:GetValue())
    local sliderSetupData = self.sliderSetupData
    expr = clampValue(roundDecimalToPlace(expr, 2), sliderSetupData.min, sliderSetupData.max)

    d("tbug: slider update - value: " ..tostring(expr))
--[[
    if sliderCtrl.updatedColumn ~= nil and sliderCtrl.updatedColumnIndex ~= nil then
        if self.sliderData  then
            return
        end
    end
]]
    --Show a tooltip at the slider
    ZO_Tooltips_ShowTextTooltip(sliderCtrl, TOP, tostring(expr))

    local func, err = zo_loadstring("return " .. expr)
    -- syntax check only, no evaluation yet
    if func then
        sliderCtrl:SetColor(BLUE:UnpackRGBA())
    else
        sliderCtrl:SetColor(RED:UnpackRGBA())
    end
end

function ObjectInspectorPanel:valueSliderConfirmed(sliderControl, evalResult)
d("tbug: slider confirmed")
    return "valueSliderConfirmed: intended to be overridden"
end

function ObjectInspectorPanel:valueSliderCancel(sliderCtrl)
d("tbug: slider cancel")
    ClearMenu()
    local sliderData = self.sliderData
    if sliderData then
        self.sliderData = nil
        ZO_ScrollList_RefreshVisible(self.list, sliderData)
    end
    sliderCtrl:SetHidden(true)
    sliderCtrl.updatedColumn = nil
    sliderCtrl.updatedColumnIndex = nil
    self.sliderCtrlActive = false
end



function ObjectInspectorPanel:reset()
    tbug.truncate(self.masterList, 0)
    ZO_ScrollList_Clear(self.list)
    self:commitScrollList()
    self.control:SetHidden(true)
    self.control:ClearAnchors()
    self.subject = nil
end


function ObjectInspectorPanel:setupRow(row, data)
    BasicInspectorPanel.setupRow(self, row, data)

    if self.editData == data then
        self:anchorEditBoxToListCell(self.editBox, row.cVal)
    else
        if row.cVal then
            row.cVal:SetHidden(false)
        end
        if row.cVal2 then
            row.cVal2:SetHidden(false)
        end
    end
end


---------------------------
-- class ObjectInspector --
local BasicInspector = classes.BasicInspector
local ObjectInspector = classes.ObjectInspector .. BasicInspector

ObjectInspector._activeObjects = {}
ObjectInspector._inactiveObjects = {}
ObjectInspector._nextObjectId = 1
ObjectInspector._templateName = "tbugTabWindow"


function ObjectInspector.acquire(Class, subject, name, recycleActive, titleName, data)
local lastActive = (Class ~= nil and Class._lastActive ~= nil and true) or false
local lastActiveSubject = (lastActive == true and Class._lastActive.subject ~= nil and true) or false
--d("[TBUG]ObjectInspector.acquire-name: " ..tostring(name) .. ", recycleActive: " ..tostring(recycleActive) .. ", titleName: " ..tostring(titleName) .. ", lastActive: " ..tostring(lastActive) .. ", lastActiveSubject: " ..tostring(lastActiveSubject))
    local inspector = Class._activeObjects[subject]
    if not inspector then
        if recycleActive and Class._lastActive and Class._lastActive.subject then
            inspector = Class._lastActive
            Class._activeObjects[inspector.subject] = nil
        else
            inspector = table.remove(Class._inactiveObjects)
            if not inspector then
                local id = Class._nextObjectId
                local templateName = Class._templateName
                local controlName = templateName .. id
                local control = wm:CreateControlFromVirtual(controlName, nil,
                                                            templateName)
                Class._nextObjectId = id + 1
                inspector = Class(id, control)
            end
            if Class._lastActive then
                Class._lastActive.titleIcon:SetDesaturation(0)
            end
            Class._lastActive = inspector
            Class._lastActive.titleIcon:SetDesaturation(1)
        end
        Class._activeObjects[subject] = inspector
        inspector.subject = subject
        inspector._parentSubject = (data ~= nil and data._parentSubject) or nil
        inspector.subjectName = name
        inspector.titleName = titleName
    end
    return inspector
end


function ObjectInspector:__init__(id, control)
    BasicInspector.__init__(self, id, control)

    self.conf = tbug.savedTable("objectInspector" .. id)
    self:configure(self.conf)

    --self.subjectsToPanel = {}
end

function ObjectInspector:openTabFor(object, title, inspectorTitle, useInspectorTitel, data)
    useInspectorTitel = useInspectorTitel or false
    local newTabIndex = 0
    local tabControl, panel
local parentSubjectFound = (data ~= nil and data._parentSubject ~= nil and true) or false
--d("[tbug:openTabFor]title: " ..tostring(title) .. ", inspectorTitle: " ..tostring(inspectorTitle) .. ", useInspectorTitel: " ..tostring(useInspectorTitel) .. ", data._parentSubject: " ..tostring(parentSubjectFound))
    -- the global table should only be viewed in GlobalInspector
    if rawequal(object, _G) then
        local inspector = tbug.getGlobalInspector()
        if inspector.control:IsHidden() then
            inspector.control:SetHidden(false)
            inspector:refresh()
        end
        inspector.control:BringWindowToTop()
        return
    end

    -- try to find an existing tab inspecting the given object
    for tabIndex, tabControl in ipairs(self.tabs) do
        if rawequal(tabControl.panel.subject, object) then
            self:selectTab(tabControl)
            return tabControl
        elseif tabControl == self.activeTab then
            newTabIndex = tabIndex + 1
        end
    end

    --df("[ObjectInspector:openTabFor]object %s, title: %s, inspectorTitle: %s, newTabIndex: %s", tostring(object), tostring(title), tostring(inspectorTitle), tostring(newTabIndex))


    if type(object) == "table" then
--d(">table")
        title = tbug_glookup(object) or title or tostring(object)
        if title and title ~= "" and not endsWith(title, "[]") then
            title = title .. "[]"
        end
        panel = self:acquirePanel(classes.TableInspectorPanel)
    elseif tbug.isControl(object) then
--d(">control")
        title = title or tbug.getControlName(object)
        panel = self:acquirePanel(classes.ControlInspectorPanel)
    end

    if panel then
--d(">>panel found")

        tabControl = self:insertTab(title, panel, newTabIndex, inspectorTitle, useInspectorTitel)
        panel.subject = object
        panel._parentSubject = (data ~= nil and data._parentSubject) or nil
        --self.subjectsToPanel = self.subjectsToPanel or {}
        --self.subjectsToPanel[panel.subject] = panel
        panel:refreshData()
        self:selectTab(tabControl)
    end

    return tabControl
end


function ObjectInspector:refresh()
    --df("tbug: refreshing %s (%s / %s)", tostring(self.subject), tostring(self.subjectName), tostring(self.titleName))
    --d("[tbug]ObjectInspector:refresh")
    self:removeAllTabs()
    local data = {}
    data._parentSubject = self._parentSubject
    self:openTabFor(self.subject, self.subjectName, self.titleName, data)
end


function ObjectInspector:release()
    --d("[tbug]ObjectInspector:release")
    if self.subject then
        self._activeObjects[self.subject] = nil
        --self.subjectsToPanel[self.subject] = nil
        self.subject = nil
        table.insert(self._inactiveObjects, self)
    end
    self._parentSubject = nil
    self.control:SetHidden(true)
    self:removeAllTabs()
end
