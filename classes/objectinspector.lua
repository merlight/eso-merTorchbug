local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")
local cm = CALLBACK_MANAGER
local wm = WINDOW_MANAGER

local BLUE = ZO_ColorDef:New(0.8, 0.8, 1.0)
local RED  = ZO_ColorDef:New(1.0, 0.2, 0.2)

local endsWith = tbug.endsWith

--------------------------------
-- class ObjectInspectorPanel --

local BasicInspectorPanel = tbug.classes.BasicInspectorPanel
local ObjectInspectorPanel = tbug.classes.ObjectInspectorPanel .. BasicInspectorPanel


local function valueEdit_OnEnter(editBox)
    editBox.panel:valueEditConfirm(editBox)
end


local function valueEdit_OnFocusLost(editBox)
    editBox.panel:valueEditCancel(editBox)
end


local function valueEdit_OnTextChanged(editBox)
    editBox.panel:valueEditUpdate(editBox)
end


function ObjectInspectorPanel:__init__(control, ...)
    BasicInspectorPanel.__init__(self, control, ...)

    self:initScrollList(control)
    self:createValueEditBox(self.list.contents)

    cm:RegisterCallback("tbugChanged:typeColor", function() self:refreshVisible() end)
end


function ObjectInspectorPanel:anchorEditBoxToListCell(editBox, listCell)
    editBox:ClearAnchors()
    editBox:SetAnchor(TOPRIGHT, listCell, TOPRIGHT, 0, 4)
    editBox:SetAnchor(BOTTOMLEFT, listCell, BOTTOMLEFT, 0, -3)
    listCell:SetHidden(true)
end


function ObjectInspectorPanel:createValueEditBox(parent)
    local editBox = wm:CreateControlFromVirtual("$(parent)ValueEdit", parent,
                                                "ZO_DefaultEdit")
    self.editBox = editBox
    self.editData = nil
    editBox.panel = self

    editBox:SetDrawLevel(10)
    editBox:SetMaxInputChars(1024) -- hard limit in ESO 2.1.7
    editBox:SetFont("ZoFontGameSmall")
    editBox:SetHandler("OnEnter", valueEdit_OnEnter)
    editBox:SetHandler("OnFocusLost", valueEdit_OnFocusLost)
    editBox:SetHandler("OnTextChanged", valueEdit_OnTextChanged)
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
    if self.editData ~= data then
        editBox.updatedColumn = nil
        editBox.updatedColumnIndex = nil
        editBox:LoseFocus()
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


---------------------------
-- class ObjectInspector --

local BasicInspector = tbug.classes.BasicInspector
local ObjectInspector = tbug.classes.ObjectInspector .. BasicInspector

ObjectInspector._activeObjects = {}
ObjectInspector._inactiveObjects = {}
ObjectInspector._nextObjectId = 1
ObjectInspector._templateName = "tbugTabWindow"


function ObjectInspector.acquire(Class, subject, name, recycleActive, titleName)
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
        inspector.subjectName = name
        inspector.titleName = titleName
    end
    return inspector
end


function ObjectInspector:__init__(id, control)
    BasicInspector.__init__(self, id, control)

    self.conf = tbug.savedTable("objectInspector" .. id)
    self:configure(self.conf)
end

function ObjectInspector:openTabFor(object, title, inspectorTitle, useInspectorTitel)
    useInspectorTitel = useInspectorTitel or false
    local newTabIndex = 0
    local tabControl, panel
--d("[tbug:openTabFor]title: " ..tostring(title) .. ", inspectorTitle: " ..tostring(inspectorTitle) .. ", useInspectorTitel: " ..tostring(useInspectorTitel))
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
        title = tbug.glookup(object) or title or tostring(object)
        if title and title ~= "" and not endsWith(title, "[]") then
            title = title .. "[]"
        end
        panel = self:acquirePanel(tbug.classes.TableInspectorPanel)
    elseif tbug.isControl(object) then
        title = title or tbug.getControlName(object)
        panel = self:acquirePanel(tbug.classes.ControlInspectorPanel)
    end

    if panel then
        tabControl = self:insertTab(title, panel, newTabIndex, inspectorTitle, useInspectorTitel)
        panel.subject = object
        panel:refreshData()
        self:selectTab(tabControl)
    end

    return tabControl
end


function ObjectInspector:refresh()
    --df("tbug: refreshing %s (%s / %s)", tostring(self.subject), tostring(self.subjectName), tostring(self.titleName))
    self:removeAllTabs()
    self:openTabFor(self.subject, self.subjectName, self.titleName)
end


function ObjectInspector:release()
    if self.subject then
        self._activeObjects[self.subject] = nil
        self.subject = nil
        table.insert(self._inactiveObjects, self)
    end
    self.control:SetHidden(true)
    self:removeAllTabs()
end
