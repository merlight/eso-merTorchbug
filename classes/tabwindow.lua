local tbug = LibStub:GetLibrary("merTorchbug")
local TabWindow = tbug.classes.TabWindow
local TextButton = tbug.classes.TextButton


function TabWindow:__init__(control)
    self.control = assert(control)
    self.title = control:GetNamedChild("Title")
    self.contents = control:GetNamedChild("Contents")
    self.tabs = {}
    self.tabScroll = control:GetNamedChild("Tabs")
    self.tabPool = ZO_ControlPool:New("tbugTabLabel", self.tabScroll, "")
    self.activeBg = self.tabScroll:GetNamedChild("ActiveBg")
    self.activeTab = nil
    self.activeColor = ZO_ColorDef:New(1, 1, 1, 1)
    self.inactiveColor = ZO_ColorDef:New(0.6, 0.6, 0.6, 1)

    tbug.confControlColor(control, "Bg", "tabWindowBackground")
    tbug.confControlColor(control, "ContentsBg", "tabWindowPanelBackground")
    tbug.confControlColor(self.activeBg, "tabWindowPanelBackground")
    tbug.confControlVertexColors(control, "TitleBg", "tabWindowTitleBackground")

    local closeButton = TextButton(control, "CloseButton")
    closeButton.onClicked[1] = function() self:release() end
    closeButton:fitText("x", 12)
end


function TabWindow:configure(sv)
    local control = self.control

    if sv.winLeft and sv.winTop then
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, nil, TOPLEFT, sv.winLeft, sv.winTop)
    end

    if sv.winWidth and sv.winHeight then
        control:SetDimensions(sv.winWidth, sv.winHeight)
    end

    local function savePos()
        control:SetHandler("OnUpdate", nil)
        sv.winLeft = math.floor(control:GetLeft())
        sv.winTop = math.floor(control:GetTop())
        sv.winWidth = math.ceil(control:GetWidth())
        sv.winHeight = math.ceil(control:GetHeight())
    end

    local function resizeStart()
        local panel = self.activeTab and self.activeTab.panel
        if panel and panel.onResizeUpdate then
            control:SetHandler("OnUpdate", function()
                panel:onResizeUpdate()
            end)
        end
    end

    control:SetHandler("OnMoveStop", savePos)
    control:SetHandler("OnResizeStart", resizeStart)
    control:SetHandler("OnResizeStop", savePos)
end


function TabWindow:getTabControl(key)
    if type(key) == "number" then
        return self.tabs[key]
    else
        return key
    end
end


function TabWindow:getTabIndex(key)
    if type(key) == "number" then
        return key
    end
    for index, tab in ipairs(self.tabs) do
        if tab == key then
            return index
        end
    end
end


function TabWindow:insertTab(name, panel, index)
    if index > 0 then
        assert(index <= #self.tabs + 1)
    else
        assert(-index <= #self.tabs)
        index = #self.tabs + 1 + index
    end

    local tabControl, tabKey = self.tabPool:AcquireObject()
    tabControl.pkey = tabKey
    self:setTabTitle(tabControl, name)
    tabControl:SetColor(self.inactiveColor:UnpackRGBA())
    tabControl:SetMouseEnabled(true)
    tabControl:SetHandler("OnMouseEnter",
        function(control)
            if control ~= self.activeTab then
                control:SetColor(self.activeColor:UnpackRGBA())
            end
        end)
    tabControl:SetHandler("OnMouseExit",
        function(control)
            if control ~= self.activeTab then
                control:SetColor(self.inactiveColor:UnpackRGBA())
            end
        end)
    tabControl:SetHandler("OnMouseUp",
        function(control, mouseButton, upInside)
            if upInside then
                if mouseButton == 1 then
                    self:selectTab(control)
                elseif mouseButton == 2 then
                    self:removeTab(control):release()
                end
            end
        end)

    tabControl.panel = panel
    panel.control:SetHidden(true)
    panel.control:SetParent(self.contents)
    panel.control:ClearAnchors()
    panel.control:SetAnchorFill()

    table.insert(self.tabs, index, tabControl)

    local prevControl = self.tabs[index - 1]
    if prevControl then
        tabControl:SetAnchor(BOTTOMLEFT, prevControl, BOTTOMRIGHT)
    else
        tabControl:SetAnchor(BOTTOMLEFT)
    end

    local nextControl = self.tabs[index + 1]
    if nextControl then
        nextControl:ClearAnchors()
        nextControl:SetAnchor(BOTTOMLEFT, tabControl, BOTTOMRIGHT)
    end

    return tabControl
end


function TabWindow:release()
end


function TabWindow:removeAllTabs()
    for index = #self.tabs, 1, -1 do
        self.tabs[index].panel:release()
        self.tabs[index] = nil
    end
    self.activeTab = nil
    self.activeBg:SetHidden(true)
    self.activeBg:ClearAnchors()
    self.tabPool:ReleaseAllObjects()
end


function TabWindow:removeTab(key)
    local index = self:getTabIndex(key)
    local tabControl = self.tabs[index]
    if not tabControl then
        return nil
    end
    local nextControl = self.tabs[index + 1]
    if nextControl then
        nextControl:ClearAnchors()
        if index > 1 then
            local prevControl = self.tabs[index - 1]
            nextControl:SetAnchor(BOTTOMLEFT, prevControl, BOTTOMRIGHT)
        else
            nextControl:SetAnchor(BOTTOMLEFT)
        end
    end
    if self.activeTab == tabControl then
        if nextControl then
            self:selectTab(nextControl)
        else
            self:selectTab(index - 1)
        end
    end
    table.remove(self.tabs, index)
    self.tabPool:ReleaseObject(tabControl.pkey)
    return tabControl.panel
end


function TabWindow:reset()
    self.control:SetHidden(true)
    self:removeAllTabs()
end


function TabWindow:selectTab(key)
    local tabControl = self:getTabControl(key)
    if self.activeTab == tabControl then
        return
    end
    if self.activeTab then
        self.activeTab:SetColor(self.inactiveColor:UnpackRGBA())
        self.activeTab.panel.control:SetHidden(true)
    end
    if tabControl then
        tabControl:SetColor(self.activeColor:UnpackRGBA())
        tabControl.panel.control:SetHidden(false)
        self.activeBg:ClearAnchors()
        self.activeBg:SetAnchor(TOPLEFT, tabControl)
        self.activeBg:SetAnchor(BOTTOMRIGHT, tabControl)
        self.activeBg:SetHidden(false)
    else
        self.activeBg:ClearAnchors()
        self.activeBg:SetHidden(true)
    end
    self.activeTab = tabControl
end


function TabWindow:setTabTitle(key, title)
    local tabControl = self:getTabControl(key)
    tabControl:SetText(title)
    tabControl:SetWidth(10 + tabControl:GetStringWidth(title))
end
