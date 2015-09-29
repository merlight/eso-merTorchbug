local tbug = LibStub:GetLibrary("merTorchbug")
local wm = WINDOW_MANAGER


---------------------------
-- class ObjectInspector --

local BasicInspector = tbug.classes.BasicInspector
local ObjectInspector = tbug.classes.ObjectInspector .. BasicInspector

ObjectInspector._activeObjects = {}
ObjectInspector._inactiveObjects = {}
ObjectInspector._nextObjectId = 1
ObjectInspector._templateName = "tbugTabWindow"


function ObjectInspector.acquire(Class, subject, name, recycleActive)
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
    end
    return inspector
end


function ObjectInspector:__init__(id, control)
    BasicInspector.__init__(self, id, control)

    self.conf = tbug.savedTable("objectInspector" .. id)
    self:configure(self.conf)
end


function ObjectInspector:openTabFor(object, title)
    local newTabIndex = 0
    local tabControl, panel

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

    if type(object) == "table" then
        title = tbug.glookup(object) or title or tostring(object)
        panel = self:acquirePanel(tbug.classes.TableInspectorPanel)
        panel.editTable = object
    elseif tbug.isControl(object) then
        title = title or tbug.getControlName(object)
        panel = self:acquirePanel(tbug.classes.ControlInspectorPanel)
    end

    if panel then
        tabControl = self:insertTab(title, panel, newTabIndex)
        panel.subject = object
        panel:refreshData()
        self:selectTab(tabControl)
    end

    return tabControl
end


function ObjectInspector:refresh()
    df("tbug: refreshing %s (%s)", tostring(self.subject), tostring(self.subjectName))
    self:removeAllTabs()
    self:openTabFor(self.subject, self.subjectName)
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
