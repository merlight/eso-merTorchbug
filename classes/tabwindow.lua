local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")
local TabWindow = tbug.classes.TabWindow
local TextButton = tbug.classes.TextButton


local function resetTab(tabControl)
    if tabControl.panel then
        tabControl.panel:release()
        tabControl.panel = nil
    end
end


function TabWindow:__init__(control, id)
    self.control = assert(control)
    tbug.inspectorWindows = tbug.inspectorWindows or {}
    tbug.inspectorWindows[id] = self
    self.title = control:GetNamedChild("Title")
    self.titleIcon = control:GetNamedChild("TitleIcon")
    self.contents = control:GetNamedChild("Contents")
    self.activeBg = control:GetNamedChild("TabsContainerActiveBg")
    self.bg = control:GetNamedChild("Bg")
    self.contentsBg = control:GetNamedChild("ContentsBg")
    self.activeTab = nil
    self.activeColor = ZO_ColorDef:New(1, 1, 1, 1)
    self.inactiveColor = ZO_ColorDef:New(0.6, 0.6, 0.6, 1)

    self.tabs = {}
    self.tabScroll = control:GetNamedChild("Tabs")
    self:_initTabScroll(self.tabScroll)

    local tabContainer = control:GetNamedChild("TabsContainer")
    self.tabPool = ZO_ControlPool:New("tbugTabLabel", tabContainer, "Tab")
    self.tabPool:SetCustomFactoryBehavior(function(control) self:_initTab(control) end)
    self.tabPool:SetCustomResetBehavior(resetTab)

    tbug.confControlColor(control, "Bg", "tabWindowBackground")
    tbug.confControlColor(control, "ContentsBg", "tabWindowPanelBackground")
    tbug.confControlColor(self.activeBg, "tabWindowPanelBackground")
    tbug.confControlVertexColors(control, "TitleBg", "tabWindowTitleBackground")

    local closeButton = TextButton(control, "CloseButton")
    closeButton.onClicked[1] = function() self:release() end
    closeButton:fitText("x", 12)
    closeButton:setMouseOverBackgroundColor(0.4, 0, 0, 0.4)

    local refreshButton = TextButton(control, "RefreshButton")
    refreshButton.onClicked[1] = function()
        if self.activeTab and self.activeTab.panel then
            self.activeTab.panel:refreshData()
        end
    end
    refreshButton:fitText("o", 12)
    refreshButton:setMouseOverBackgroundColor(0, 0.4, 0, 0.4)

    local toggleSizeButton = TextButton(control, "ToggleSizeButton")
    toggleSizeButton.toggleState = false
    toggleSizeButton.onClicked[1] = function(buttonCtrl)
        if buttonCtrl then
            buttonCtrl.toggleState = not buttonCtrl.toggleState
            if not buttonCtrl.toggleState then
                toggleSizeButton:fitText("^", 12)
                toggleSizeButton:setMouseOverBackgroundColor(0.4, 0, 0, 0.4)
            else
                toggleSizeButton:fitText("v", 12)
                toggleSizeButton:setMouseOverBackgroundColor(0, 0.4, 0, 0.4)
            end
            local globalInspector = tbug.getGlobalInspector()
            local isGlobalInspectorWindow = (self == globalInspector) or false
            local sv
            if not isGlobalInspectorWindow then
                sv = tbug.savedTable("objectInspector" .. id)
            else
                sv = tbug.savedTable("globalInspector1")
            end
            local width, height
            local widthDefault  = 400
            local heightDefault = 600
            if isGlobalInspectorWindow then
                widthDefault    = 800
                heightDefault   = 600
            end
            if not buttonCtrl.toggleState == true then
                if sv and sv.winWidth and sv.winHeight then
                    width, height = sv.winWidth, sv.winHeight
                else
                    width, height = widthDefault, heightDefault
                end
            else
                if sv and sv.winWidth then
                    width, height = sv.winWidth, tbug.minInspectorTitleHeight
                else
                    width, height = widthDefault, tbug.minInspectorTitleHeight
                end
            end
            if width and height then
--d(">width: " ..tostring(width) .. ", height: " ..tostring(height))
                self.bg:ClearAnchors()
                self.bg:SetDimensions(width, height)
                self.control:SetDimensions(width, height)
                --Call the resize handler as if it was manually resized
                local panel = self.activeTab and self.activeTab.panel
                if panel and panel.onResizeUpdate then
                    panel:onResizeUpdate(height)
                end
                self.contents:SetHidden(buttonCtrl.toggleState)
                self.contentsBg:SetHidden(buttonCtrl.toggleState)
                self.tabScroll:SetHidden(buttonCtrl.toggleState)
                self.bg:SetHidden(buttonCtrl.toggleState)
                self.activeBg:SetHidden(buttonCtrl.toggleState)
                self.contents:SetMouseEnabled(not buttonCtrl.toggleState)
                self.contentsBg:SetMouseEnabled(not buttonCtrl.toggleState)
                self.tabScroll:SetMouseEnabled(not buttonCtrl.toggleState)
                self.activeBg:SetMouseEnabled(not buttonCtrl.toggleState)
                --control:SetAnchor(AnchorPosition myPoint, object anchorTargetControl, AnchorPosition anchorControlsPoint, number offsetX, number offsetY)
                self.bg:SetAnchor(TOPLEFT, self.control, nil, 4, 6)
                self.bg:SetAnchor(BOTTOMRIGHT, self.control, nil, -4, -6)
            end
        end
    end
    toggleSizeButton:fitText("^", 12)
    toggleSizeButton:setMouseOverBackgroundColor(0.4, 0, 0, 0.4)
end


function TabWindow:_initTab(tabControl)
    tabControl:SetHandler("OnMouseEnter",
        function(control)
            if control ~= self.activeTab then
                control.label:SetColor(self.activeColor:UnpackRGBA())
            end
        end)
    tabControl:SetHandler("OnMouseExit",
        function(control)
            if control ~= self.activeTab then
                control.label:SetColor(self.inactiveColor:UnpackRGBA())
            end
        end)
    tabControl:SetHandler("OnMouseUp",
        function(control, mouseButton, upInside)
            if upInside then
                if mouseButton == MOUSE_BUTTON_INDEX_LEFT then
                    self:selectTab(control)
                elseif mouseButton == MOUSE_BUTTON_INDEX_RIGHT then
                    self:removeTab(control)
                end
            end
        end)
end


local function tabScroll_OnMouseWheel(self, delta)
    local tabWindow = self.tabWindow
    local selectedIndex = tabWindow:getTabIndex(tabWindow.activeTab)
    if selectedIndex then
        local targetTab = tabWindow.tabs[selectedIndex - zo_sign(delta)]
        if targetTab then
            tabWindow:selectTab(targetTab)
        end
    end
end


local function tabScroll_OnScrollExtentsChanged(self, horizontal, vertical)
    local extent = horizontal
    local offset = self:GetScrollOffsets()
    self:SetFadeGradient(1, 1, 0, zo_clamp(offset, 0, 15))
    self:SetFadeGradient(2, -1, 0, zo_clamp(extent - offset, 0, 15))
    -- this is necessary to properly scroll to the active tab if it was
    -- inserted and immediately selected, before anchors were processed
    -- and scroll extents changed accordingly
    if self.tabWindow.activeTab then
        self.tabWindow:scrollToTab(self.tabWindow.activeTab)
    end
end


local function tabScroll_OnScrollOffsetChanged(self, horizontal, vertical)
    local extent = self:GetScrollExtents()
    local offset = horizontal
    self:SetFadeGradient(1, 1, 0, zo_clamp(offset, 0, 15))
    self:SetFadeGradient(2, -1, 0, zo_clamp(extent - offset, 0, 15))
end


function TabWindow:_initTabScroll(tabScroll)
    local animation, timeline = CreateSimpleAnimation(ANIMATION_SCROLL, tabScroll)
    animation:SetDuration(400)
    animation:SetEasingFunction(ZO_BezierInEase)

    tabScroll.animation = animation
    tabScroll.timeline = timeline
    tabScroll.tabWindow = self

    tabScroll:SetHandler("OnMouseWheel", tabScroll_OnMouseWheel)
    tabScroll:SetHandler("OnScrollExtentsChanged", tabScroll_OnScrollExtentsChanged)
    tabScroll:SetHandler("OnScrollOffsetChanged", tabScroll_OnScrollOffsetChanged)
end


function TabWindow:configure(sv)
    local control = self.control

    if sv.winLeft and sv.winTop then
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, nil, TOPLEFT, sv.winLeft, sv.winTop)
    end

    if sv.winWidth and sv.winHeight then
        local width, height = sv.winWidth, sv.winHeight
        if width < tbug.minInspectorTitleWidth then width = tbug.minInspectorTitleWidth end
        if height < tbug.minInspectorTitleHeight then height = tbug.minInspectorTitleHeight end
        control:SetDimensions(width, height)
    end

    local function savePos()
        control:SetHandler("OnUpdate", nil)
        sv.winLeft = math.floor(control:GetLeft())
        sv.winTop = math.floor(control:GetTop())
        local width = control:GetWidth()
        if width < tbug.minInspectorTitleWidth then width = tbug.minInspectorTitleWidth end
        sv.winWidth = math.ceil(width)
        local height = control:GetHeight()
        if height < tbug.minInspectorTitleHeight then height = tbug.minInspectorTitleHeight end
        sv.winHeight = math.ceil(height)

--d(">savePos - width: " ..tostring(sv.winWidth) .. ", height: " .. tostring(sv.winHeight) .. ", left: " ..tostring(sv.winLeft ) .. ", top: " .. tostring(sv.winTop))
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


function TabWindow:insertTab(name, panel, index, inspectorTitle)
    if index > 0 then
        assert(index <= #self.tabs + 1)
    else
        assert(-index <= #self.tabs)
        index = #self.tabs + 1 + index
    end

    local tabControl, tabKey = self.tabPool:AcquireObject()
    tabControl.pkey = tabKey
    tabControl.tabName = inspectorTitle or name
    tabControl.panel = panel

    tabControl.label:SetColor(self.inactiveColor:UnpackRGBA())
    tabControl.label:SetText(name)

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
    self.activeTab = nil
    self.activeBg:SetHidden(true)
    self.activeBg:ClearAnchors()
    self.tabPool:ReleaseAllObjects()
    tbug.truncate(self.tabs, 0)
end


function TabWindow:removeTab(key)
    local index = self:getTabIndex(key)
    local tabControl = self.tabs[index]
    if not tabControl then
        return
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
    if not self.tabs or #self.tabs == 0 then
        self.title:SetText("")
        --self.control:SetHidden(true)
    end
end


function TabWindow:reset()
    self.control:SetHidden(true)
    self:removeAllTabs()
end


function TabWindow:scrollToTab(key)
    local tabControl = self:getTabControl(key)
    local tabCenter = tabControl:GetCenter()
    local scrollControl = self.tabScroll
    local scrollCenter = scrollControl:GetCenter()
    scrollControl.timeline:Stop()
    scrollControl.animation:SetHorizontalRelative(tabCenter - scrollCenter)
    scrollControl.timeline:PlayFromStart()
end


function TabWindow:selectTab(key)
    local tabControl = self:getTabControl(key)
    if self.activeTab == tabControl then
        return
    end
    if self.activeTab then
        self.activeTab.label:SetColor(self.inactiveColor:UnpackRGBA())
        self.activeTab.panel.control:SetHidden(true)
    end
    if tabControl then
        tabControl.label:SetColor(self.activeColor:UnpackRGBA())
        tabControl.panel:refreshData()
        tabControl.panel.control:SetHidden(false)
        self.activeBg:ClearAnchors()
        self.activeBg:SetAnchor(TOPLEFT, tabControl)
        self.activeBg:SetAnchor(BOTTOMRIGHT, tabControl)
        self.activeBg:SetHidden(false)
        self:scrollToTab(tabControl)

        local firstInspector = tabControl.panel.inspector
        if firstInspector then
            local firstInspectorControl = firstInspector.control
            if not firstInspectorControl:IsHidden() then
                local title = firstInspector.title
                if title and title.SetText then
                    local keyValue = (type(key) ~= "number" and self:getTabIndex(key)) or key
                    local keyText = firstInspector.tabs[keyValue].tabName
                    local keyPreText = firstInspector.tabs[keyValue].label:GetText()
                    if keyPreText ~= keyText then
                        keyText = keyPreText .. keyText
                    end
                    title:SetText(keyText)
                end
            end
        end
    else
        self.activeBg:ClearAnchors()
        self.activeBg:SetHidden(true)
    end
    self.activeTab = tabControl
end


function TabWindow:setTabTitle(key, title)
    local tabControl = self:getTabControl(key)
    tabControl.label:SetText(title)
end
