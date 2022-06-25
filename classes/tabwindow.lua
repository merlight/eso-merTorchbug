local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")

local classes = tbug.classes

local TabWindow = classes.TabWindow
local TextButton = classes.TextButton

local startsWith = tbug.startsWith

local tos = tostring
local tins = table.insert
local trem = table.remove

local panelData = tbug.panelNames

local function onMouseEnterShowTooltip(ctrl, text, delay)
    if not ctrl or not text or (text and text == "") then return end
    delay = delay or 0
    ctrl.hideTooltip = false
    ZO_Tooltips_HideTextTooltip()
    local function showToolTipNow()
        if ctrl.hideTooltip == true then
            ctrl.hideTooltip = false
            ZO_Tooltips_HideTextTooltip()
            return
        end
        ZO_Tooltips_ShowTextTooltip(ctrl, TOP, text)
    end
    if not delay or (delay and delay == 0) then
        showToolTipNow()
    else
        zo_callLater(function() showToolTipNow() end, delay)
    end
end


local function onMouseExitHideTooltip(ctrl)
    ctrl.hideTooltip = true
    ZO_Tooltips_HideTextTooltip()
end


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
    self.title:SetMouseEnabled(false) -- Else we cannot move the window anymore...
    self.titleBg = control:GetNamedChild("TitleBg")
    self.titleIcon = control:GetNamedChild("TitleIcon")
    self.contents = control:GetNamedChild("Contents")
    self.activeBg = control:GetNamedChild("TabsContainerActiveBg")
    self.bg = control:GetNamedChild("Bg")
    self.contentsBg = control:GetNamedChild("ContentsBg")
    self.activeTab = nil
    self.activeColor = ZO_ColorDef:New(1, 1, 1, 1)
    self.inactiveColor = ZO_ColorDef:New(0.6, 0.6, 0.6, 1)

    self.contentsCount = control:GetNamedChild("ContentsCount")
    self.contentsCount:SetText("")
    self.contentsCount:SetHidden(false)

    self.tabs = {}
    self.tabScroll = control:GetNamedChild("Tabs")
    self:_initTabScroll(self.tabScroll)

    local tabContainer = control:GetNamedChild("TabsContainer")
    self.tabPool = ZO_ControlPool:New("tbugTabLabel", tabContainer, "Tab")
    self.tabPool:SetCustomFactoryBehavior(function(control) self:_initTab(control) end)
    self.tabPool:SetCustomResetBehavior(resetTab)

    local isGlobalInspector = self.control.isGlobalInspector

    tbug.confControlColor(control, "Bg", "tabWindowBackground")
    tbug.confControlColor(control, "ContentsBg", "tabWindowPanelBackground")
    tbug.confControlColor(self.activeBg, "tabWindowPanelBackground")
    tbug.confControlVertexColors(control, "TitleBg", "tabWindowTitleBackground")

    local function setDrawLevel(control, layer, allInspectorWindows)
--d("[TBUG]setDrawLevel")
        layer = layer or DL_CONTROLS
        allInspectorWindows = allInspectorWindows or false
        local tiers = {
            [DL_BACKGROUND] = DT_LOW,
            [DL_CONTROLS] = DT_MEDIUM,
            [DL_OVERLAY] = DT_HIGH,
        }
        local tier = tiers[layer] or DT_MEDIUM

        --Reset all inspector windows to normal layer and level?
        if allInspectorWindows == true then
            for _, inspectorWindow in ipairs(tbug.inspectorWindows) do
                setDrawLevel(inspectorWindow.control, DL_CONTROLS, false)
            end
            if tbug.firstInspector then
                setDrawLevel(tbug.firstInspector.control, DL_CONTROLS, false)
            end
        end

        if not control then return end
        if control.SetDrawTier then
            control:SetDrawTier(tier)
        end
        if control.SetDrawLayer then
            control:SetDrawLayer(layer)
        end
    end

    local closeButton = TextButton(control, "CloseButton")
    closeButton.onClicked[MOUSE_BUTTON_INDEX_LEFT] = function()
        self:release()
        onMouseExitHideTooltip(closeButton.control)
    end
    closeButton:fitText("x", 12)
    closeButton:setMouseOverBackgroundColor(0.4, 0, 0, 0.4)
    closeButton:insertOnMouseEnterHandler(function(ctrl) onMouseEnterShowTooltip(ctrl.control, "Close", 500) end)
    closeButton:insertOnMouseExitHandler(function(ctrl) onMouseExitHideTooltip(ctrl.control) end)
    self.closeButton = closeButton

    local refreshButton = TextButton(control, "RefreshButton")

    local toggleSizeButton = TextButton(control, "ToggleSizeButton")
    toggleSizeButton.toggleState = false
    toggleSizeButton.onClicked[MOUSE_BUTTON_INDEX_LEFT] = function(buttonCtrl)
        if buttonCtrl then
            buttonCtrl.toggleState = not buttonCtrl.toggleState
            if not buttonCtrl.toggleState then
                toggleSizeButton:fitText("^", 12)
                toggleSizeButton:setMouseOverBackgroundColor(0.4, 0.4, 0, 0.4)
            else
                toggleSizeButton:fitText("v", 12)
                toggleSizeButton:setMouseOverBackgroundColor(0.4, 0.4, 0, 0.4)
            end
            refreshButton:setEnabled(not buttonCtrl.toggleState)
            refreshButton:setMouseEnabled(not buttonCtrl.toggleState)

            local sv
            local globalInspector = tbug.getGlobalInspector()
            local isGlobalInspectorWindow = (self == globalInspector) or false
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
                    width, height = sv.winWidth, tbug.minInspectorWindowHeight
                else
                    width, height = widthDefault, tbug.minInspectorWindowHeight
                end
            end
            if width and height then
                --d("TBUG >width: " ..tos(width) .. ", height: " ..tos(height))
                self.bg:ClearAnchors()
                self.bg:SetDimensions(width, height)
                self.control:ClearAnchors()
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
                if self.contentsCount then self.contentsCount:SetHidden(buttonCtrl.toggleState) end

                if self.filterButton then
                    local filterBar = self.filterButton:GetParent()
                    if filterBar then
                        filterBar:SetHidden(buttonCtrl.toggleState)
                        filterBar:SetMouseEnabled(not buttonCtrl.toggleState)
                    end
                end

                --control:SetAnchor(AnchorPosition myPoint, object anchorTargetControl, AnchorPosition anchorControlsPoint, number offsetX, number offsetY)
                self.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.control:GetLeft(), self.control:GetTop())
                self.control:SetDimensions(width, height)
                self.bg:SetAnchor(TOPLEFT, self.control, nil, 4, 6)
                self.bg:SetAnchor(BOTTOMRIGHT, self.control, nil, -4, -6)
                self.bg:SetDrawTier(DT_LOW)
                self.bg:SetDrawLayer(DL_BACKGROUND)
                self.bg:SetDrawLevel(0)
                self.control:SetDrawTier(DT_LOW)
                self.control:SetDrawLayer(DL_CONTROLS)
                self.control:SetDrawLevel(1)
                self.contentsBg:SetDrawTier(DT_LOW)
                self.contentsBg:SetDrawLayer(DL_BACKGROUND)
                self.contentsBg:SetDrawLevel(0)
                self.contents:SetDrawTier(DT_LOW)
                self.contents:SetDrawLayer(DL_BACKGROUND)
                self.contents:SetDrawLevel(1)
            end
        end
        onMouseExitHideTooltip(toggleSizeButton.control)
    end

    toggleSizeButton:fitText("^", 12)
    toggleSizeButton:setMouseOverBackgroundColor(0.4, 0.4, 0, 0.4)
    toggleSizeButton:insertOnMouseEnterHandler(function(ctrl) onMouseEnterShowTooltip(ctrl.control, "Collapse / Expand", 500) end)
    toggleSizeButton:insertOnMouseExitHandler(function(ctrl) onMouseExitHideTooltip(ctrl.control) end)
    self.toggleSizeButton = toggleSizeButton

    refreshButton.onClicked[MOUSE_BUTTON_INDEX_LEFT] = function()
        if toggleSizeButton.toggleState == false then
            if self.activeTab and self.activeTab.panel then
                self.activeTab.panel:refreshData()
            end
        end
        onMouseExitHideTooltip(refreshButton.control)
    end
    refreshButton:fitText("o", 12)
    refreshButton:setMouseOverBackgroundColor(0, 0.4, 0, 0.4)
    refreshButton:insertOnMouseEnterHandler(function(ctrl) onMouseEnterShowTooltip(ctrl.control, "Refresh", 500) end)
    refreshButton:insertOnMouseExitHandler(function(ctrl) onMouseExitHideTooltip(ctrl.control) end)
    self.refreshButton = refreshButton

    --Events tracking
    if isGlobalInspector == true then
        local eventsButton = TextButton(control, "EventsButton")
        eventsButton.toggleState = false
        eventsButton.tooltipText = "Enable EVENT tracking"
        eventsButton.onMouseUp = function(buttonCtrl, mouseButton, upInside, ctrl, alt, shift, command)
            if upInside then
                if LibCustomMenu and mouseButton == MOUSE_BUTTON_INDEX_RIGHT then
                    tbug.ShowEventsContextMenu(buttonCtrl, nil, nil, true)

                elseif mouseButton == MOUSE_BUTTON_INDEX_LEFT then
                    local tbEvents = tbug.Events
                    if not tbEvents then return end
                    if tbEvents.IsEventTracking == true then
                        tbug.StopEventTracking()
                    else
                        tbug.StartEventTracking()
                    end

                    buttonCtrl.toggleState = not buttonCtrl.toggleState
                    onMouseExitHideTooltip(eventsButton.control)

                    if not buttonCtrl.toggleState then
                        eventsButton:fitText("e", 12)
                        eventsButton:setMouseOverBackgroundColor(0, 0.8, 0, 1)
                        eventsButton.tooltipText = "Enable EVENT tracking"
                    else
                        eventsButton:fitText("E", 12)
                        eventsButton:setMouseOverBackgroundColor(0.8, 0.0, 0, 0.4)
                        eventsButton.tooltipText = "Disable EVENT tracking"
                    end
                end
            end
        end
        eventsButton:fitText("e", 12)
        eventsButton:setMouseOverBackgroundColor(0, 0.8, 0, 1)
        eventsButton.tooltipText = "Enable EVENT tracking"
        eventsButton:insertOnMouseEnterHandler(function(ctrl) onMouseEnterShowTooltip(ctrl.control, ctrl.tooltipText, 500) end)
        eventsButton:insertOnMouseExitHandler(function(ctrl) onMouseExitHideTooltip(ctrl.control) end)
        self.eventsButton = eventsButton
    end


    local function updateSizeOnTabWindowAndCallResizeHandler(newWidth, newHeight)
        local left = control:GetLeft()
        local top = control:GetTop()
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, nil, TOPLEFT, left, top)
        control:SetDimensions(newWidth, newHeight)

        local OnResizeStopHandler = control:GetHandler("OnResizeStop")
        if OnResizeStopHandler and type(OnResizeStopHandler) == "function" then
            OnResizeStopHandler(control)
        end
    end

    self.titleIcon:SetMouseEnabled(true)
    --Does not work if OnMouseUp handler is also set
    self.titleIcon:SetHandler("OnMouseDoubleClick", function(selfCtrl, button, upInside, ctrl, alt, shift, command)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            local owner = selfCtrl:GetOwningWindow()
            setDrawLevel(owner, DL_OVERLAY, true)
        end
    end)
    --Context menu at headline torchbug icon
    if LibCustomMenu then
        --Context menu at the title icon
        self.titleIcon:SetHandler("OnMouseUp", function(selfCtrl, button, upInside, ctrl, alt, shift, command)
            if (button == MOUSE_BUTTON_INDEX_RIGHT or button == MOUSE_BUTTON_INDEX_LEFT) and upInside then
                local globalInspector = tbug.getGlobalInspector()
                local isGlobalInspectorWindow = (self == globalInspector) or false

                local owner = selfCtrl:GetOwningWindow()
                local dLayer = owner:GetDrawLayer()

                --Draw layer
                local function resetDrawLayer()
                    setDrawLevel(owner, dLayer)
                end
                --setDrawLevel(owner, DL_CONTROLS)
                ClearMenu()
                local drawLayerSubMenu = {}
                local drawLayerSubMenuEntry = {
                    label = "On top",
                    callback = function() setDrawLevel(owner, DL_OVERLAY, true) end,
                }
                tins(drawLayerSubMenu, drawLayerSubMenuEntry)
                drawLayerSubMenuEntry = {
                    label = "Normal",
                    callback = function() setDrawLevel(owner, DL_CONTROLS, true) end,
                }
                tins(drawLayerSubMenu, drawLayerSubMenuEntry)
                drawLayerSubMenuEntry = {
                    label = "Background",
                    callback = function() setDrawLevel(owner, DL_BACKGROUND, true) end,
                }
                tins(drawLayerSubMenu, drawLayerSubMenuEntry)
                AddCustomSubMenuItem("DrawLayer", drawLayerSubMenu)

                AddCustomMenuItem("-", function() end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                AddCustomMenuItem("Reset size to default", function() updateSizeOnTabWindowAndCallResizeHandler(tbug.defaultInspectorWindowWidth, tbug.defaultInspectorWindowHeight) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                AddCustomMenuItem("Collapse/Expand", function() toggleSizeButton.onClicked[MOUSE_BUTTON_INDEX_LEFT](toggleSizeButton) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                if toggleSizeButton.toggleState == false then
                    AddCustomMenuItem("Refresh", function() refreshButton.onClicked[MOUSE_BUTTON_INDEX_LEFT]() end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                end
                --Not at the global inspector of TBUG itsself, else you'd remove all the libraries, scripts, globals etc. tabs
                if not isGlobalInspectorWindow and toggleSizeButton.toggleState == false and (self.tabs and #self.tabs > 0) then
                    AddCustomMenuItem("-", function() end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                    AddCustomMenuItem("Remove all tabs", function() self:removeAllTabs() end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                    --Only at the global inspector
                elseif isGlobalInspectorWindow and toggleSizeButton.toggleState == false and (self.tabs and #self.tabs < tbug.panelCount ) then
                    AddCustomMenuItem("-", function() end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                    AddCustomMenuItem("+ Restore all standard tabs +", function() tbug.slashCommand("-all-") end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                end
                AddCustomMenuItem("-", function() end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                AddCustomMenuItem("Hide", function() owner:SetHidden(true) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                AddCustomMenuItem("|cFF0000X Close|r", function() self:release() end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                if dLayer == DL_OVERLAY then
                    setDrawLevel(owner, DL_CONTROLS)
                end
                ShowMenu(owner)
            end
        end)
    end

    --Right click on tabsScroll or vertical scoll bar: Set window to top draw layer!
    local controlsToAddRigtClickSetTopDrawLayer = {
        self.tabScroll,
    }
    for _, controlToProcess in ipairs(controlsToAddRigtClickSetTopDrawLayer) do
        if controlToProcess ~= nil and controlToProcess.SetHandler then
            controlToProcess:SetHandler("OnMouseUp", function(selfCtrl, button, upInside, ctrl, alt, shift, command)
                if button == MOUSE_BUTTON_INDEX_RIGHT and upInside then
                    local owner = selfCtrl:GetOwningWindow()
--d(">right mouse clicked: " ..tos(selfCtrl:GetName()) .. ", owner: " ..tos(owner:GetName()))
                    setDrawLevel(owner, DL_OVERLAY, true)
--tbug._clickedTabWindowTabScrollAtBottomSelf = self
                end
            end, "TBUG", nil, nil)
        end

    end
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
                    ZO_Tooltips_HideTextTooltip()
                    self:selectTab(control)
                elseif mouseButton == MOUSE_BUTTON_INDEX_RIGHT then
                    ZO_Tooltips_HideTextTooltip()
                    self:removeTab(control)
                end
            end
        end)
end


local function tabScroll_OnMouseWheel(self, delta)
--d("[TB]tabScroll_OnMouseWheel-delta: " ..tos(delta))
    local tabWindow = self.tabWindow
    local selectedIndex = tabWindow:getTabIndex(tabWindow.activeTab)
    if selectedIndex then
        local targetTab = tabWindow.tabs[selectedIndex - zo_sign(delta)]
        if targetTab then
            ZO_Tooltips_HideTextTooltip()
            tabWindow:selectTab(targetTab)
        end
    end
end


local function tabScroll_OnScrollExtentsChanged(self, horizontal, vertical)
--d("[TB]tabScroll_OnScrollExtentsChanged-horizontal: " ..tos(horizontal) .. ", vertical: " ..tos(vertical))
    local extent = horizontal
    local offset = self:GetScrollOffsets()
    self:SetFadeGradient(1, 1, 0, zo_clamp(offset, 0, 15))
    self:SetFadeGradient(2, -1, 0, zo_clamp(extent - offset, 0, 15))
    -- this is necessary to properly scroll to the active tab if it was
    -- inserted and immediately selected, before anchors were processed
    -- and scroll extents changed accordingly

    local xStart, xEnd = 0, self:GetWidth()
    self.animation:SetHorizontalStartAndEnd(xStart, xEnd)

    if self.tabWindow.activeTab then
        self.tabWindow:scrollToTab(self.tabWindow.activeTab)
    end
end


local function tabScroll_OnScrollOffsetChanged(self, horizontal, vertical)
--d("[TB]tabScroll_OnScrollOffsetChanged-horizontal: " ..tos(horizontal) .. ", vertical: " ..tos(vertical))
    local extent = self:GetScrollExtents()
    local offset = horizontal
    self:SetFadeGradient(1, 1, 0, zo_clamp(offset, 0, 15))
    self:SetFadeGradient(2, -1, 0, zo_clamp(extent - offset, 0, 15))
end


function TabWindow:_initTabScroll(tabScroll)
--d("[TB]_initTabScroll")
    local animation, timeline = CreateSimpleAnimation(ANIMATION_SCROLL, tabScroll)
    animation:SetDuration(400)
    animation:SetEasingFunction(ZO_BezierInEase)
    local xStart, xEnd = 0, tabScroll:GetWidth()
    animation:SetHorizontalStartAndEnd(xStart, xEnd)

    tabScroll.animation = animation
    tabScroll.timeline = timeline
    tabScroll.tabWindow = self

    tabScroll:SetHandler("OnMouseWheel", tabScroll_OnMouseWheel)
    tabScroll:SetHandler("OnScrollExtentsChanged", tabScroll_OnScrollExtentsChanged)
    tabScroll:SetHandler("OnScrollOffsetChanged", tabScroll_OnScrollOffsetChanged)
end


function TabWindow:configure(sv)
    local control = self.control

    local function isCollapsed()
        local toggleSizeButton = self.toggleSizeButton
        local isCurrentlyCollapsed = toggleSizeButton and toggleSizeButton.toggleState or false
--d(">isCurrentlyCollapsed: " ..tos(isCurrentlyCollapsed))
        return isCurrentlyCollapsed
    end

    local function reanchorAndResize(wasMoved, isCollapsed)
        wasMoved = wasMoved or false
        isCollapsed = isCollapsed or false
--d("reanchorAndResize - wasMoved: " .. tos(wasMoved) .. ", isCollapsed: " ..tos(isCollapsed))
        if isCollapsed == true then
            --Not moved but resized in height?
            if not wasMoved then
                local height = control:GetHeight()
                if height > tbug.minInspectorWindowHeight then
                    height = tbug.minInspectorWindowHeight
                    control:SetHeight(height)
                end
            end
        end
        if sv.winLeft and sv.winTop then
            control:ClearAnchors()
            control:SetAnchor(TOPLEFT, nil, TOPLEFT, sv.winLeft, sv.winTop)
        end
        if isCollapsed == true then
            return
        end

        local width = control:GetWidth()
        local height = control:GetHeight()
--d(">sv.winWidth/width: " ..tos(sv.winWidth).."/"..tos(width) .. ", sv.winHeight/height: " ..tos(sv.winHeight).."/"..tos(height))

        if sv.winWidth ~= nil and sv.winHeight ~= nil and (width~=sv.winWidth or height~=sv.winHeight) then
--d(">>width and height")
            width, height = sv.winWidth, sv.winHeight
            if width < tbug.minInspectorWindowWidth then width = tbug.minInspectorWindowWidth end
            if height < tbug.minInspectorWindowHeight then height = tbug.minInspectorWindowHeight end
            control:SetDimensions(width, height)
        elseif not sv.winWidth or not sv.winHeight then
            sv.winWidth = sv.winWidth or tbug.minInspectorWindowWidth
            sv.winHeight = sv.winHeight or tbug.minInspectorWindowHeight
            control:SetDimensions(sv.winWidth, sv.winHeight)
        end
    end

    local function savePos(ctrl, wasMoved)
        ZO_Tooltips_HideTextTooltip()
        wasMoved = wasMoved or false
        --Check if the position really changed
        local newLeft = math.floor(control:GetLeft())
        local newTop = math.floor(control:GetTop())
        if wasMoved == true and (newLeft == sv.winLeft and newTop == sv.winTop) then
            wasMoved = false
        end

        local isCurrentlyCollapsed = isCollapsed()
--d("SavePos, wasMoved: " ..tos(wasMoved) .. ", isCollapsed: " ..tos(isCurrentlyCollapsed))

        control:SetHandler("OnUpdate", nil)

        --Always save the current x and y coordinates and the width of the window, even if collapsed
        sv.winLeft = newLeft
        sv.winTop = newTop
        local width = control:GetWidth()
        if width < tbug.minInspectorWindowWidth then width = tbug.minInspectorWindowWidth end
        sv.winWidth = math.ceil(width)

        local height = control:GetHeight()
        if height <= 0 or height < tbug.minInspectorWindowHeight then height = tbug.minInspectorWindowHeight end

--d(">width: " ..tos(width) .. ", height: " ..tos(height))

        if isCurrentlyCollapsed == true then
            reanchorAndResize(wasMoved, isCurrentlyCollapsed)
            return
        end
--d(">got here, as not collapsed!")

        --Only update the height if not collapsed!
        sv.winHeight = math.ceil(height)

        --d(">savePos - width: " ..tos(sv.winWidth) .. ", height: " .. tos(sv.winHeight) .. ", left: " ..tos(sv.winLeft ) .. ", top: " .. tos(sv.winTop))

        reanchorAndResize()
        if not wasMoved then
            --Refresh the panel to commit the scrollist etc.
            self.refreshButton.onClicked[MOUSE_BUTTON_INDEX_LEFT]()
        end
    end

    local function resizeStart()
        ZO_Tooltips_HideTextTooltip()
        local toggleSizeButton = self.toggleSizeButton
        local isCurrentlyCollapsed = isCollapsed()
--d("resizeStart, isCollapsed: " ..tos(isCurrentlyCollapsed))
        if isCurrentlyCollapsed == true then return end

--d(">got here, as not collapsed! Starting OnUpdate")

        local panel = self.activeTab and self.activeTab.panel
        if panel and panel.onResizeUpdate then
            control:SetHandler("OnUpdate", function()
                panel:onResizeUpdate()
            end)
        end
    end

    reanchorAndResize()
    control:SetHandler("OnMoveStop", function() savePos(control, true) end)
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

function TabWindow:getTabIndexByName(tabName)
    for index, tab in ipairs(self.tabs) do
        if tab.tabName and tab.tabName == tabName then
            return index
        end
    end
end

function TabWindow:insertTab(name, panel, index, inspectorTitle, useInspectorTitle, isGlobalInspectorTab)
--d("[TB]insertTab-name: " ..tos(name) .. ", panel: " ..tos(panel).. ", index: " ..tos(index).. ", inspectorTitle: " ..tos(inspectorTitle).. ", useInspectorTitel: " ..tos(useInspectorTitle) .. ", isGlobalInspectorTab: " ..tos(isGlobalInspectorTab))
--tbug._panelInsertedATabTo = panel
--tbug._insertTabSELF = self
    ZO_Tooltips_HideTextTooltip()
    useInspectorTitle = useInspectorTitle or false
    isGlobalInspectorTab = isGlobalInspectorTab or false
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
    panelData = tbug.panelNames --Attention: These are only the GlobalInspector panel names like "AddOns", "Scripts" etc.
    local tabKeyStr = (isGlobalInspectorTab == true and panelData[tabKey].key) or tabControl.tabName
    tabControl.pKeyStr = tabKeyStr

    tabControl.label:SetColor(self.inactiveColor:UnpackRGBA())
    tabControl.label:SetText(useInspectorTitle == true and inspectorTitle or name)

    panel.control:SetHidden(true)
    panel.control:SetParent(self.contents)
    panel.control:ClearAnchors()
    panel.control:SetAnchorFill()

    tins(self.tabs, index, tabControl)

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
    ZO_Tooltips_HideTextTooltip()
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
    trem(self.tabs, index)
    self.tabPool:ReleaseObject(tabControl.pkey)

--tbug._selfControl = self.control
    if not self.tabs or #self.tabs == 0 then
        self.title:SetText("")
        --No tabs left in this inspector? Hide it then
        --self.control:SetHidden(true)
        self:release()
    end
end


function TabWindow:reset()
    self.control:SetHidden(true)
    self:removeAllTabs()
end


function TabWindow:scrollToTab(key)
    --d("[TB]scrollToTab-key: " ..tos(key))
    --After the update to API 101031 the horizontal scroll list was always centering the tab upon scrolling.
    --Even if the window was wide enough to show all tabs properly -> In the past the selected tab was just highlighted
    --and no scrolling was done then.
    --So this function here should only scroll if the tab to select is not visible at the horizontal scrollbar
    --Attention: key is the tabControl! Not a number
    local tabControl = self:getTabControl(key)
    --local tabCenter = tabControl:GetCenter()
    local tabLeft = tabControl:GetLeft()
    local tabWidth = tabControl:GetWidth()
    local scrollControl = self.tabScroll
--Debugging
--tbug._scrollControl = scrollControl
--tbug._tabControlToScrollTo = tabControl
    --local scrollCenter = scrollControl:GetCenter()
    local scrollWidth = scrollControl:GetWidth()
    local scrollLeft = scrollControl:GetLeft()
    local scrollRight = scrollLeft + scrollWidth
    --The center of the tab is >= the width of the scroll container -> So it is not/partially visible.
    --Scroll the scrollbar to the left for the width of the tab + 10 pixels if it's not fully visible at the right edge,
    --or scroll to the left if it's not fully visible at the left edge
    --d(">scrollRight: " ..tos(scrollRight) .. ", tabLeft: " ..tos(tabLeft) .. ", tabWidth: " ..tos(tabWidth))
    --d(">scrollLeft: " ..tos(scrollLeft) .. ", tabLeft: " ..tos(tabLeft) .. ", tabWidth: " ..tos(tabWidth))
    if (tabLeft + tabWidth) >= scrollRight then
        scrollControl.timeline:Stop()
        scrollControl.animation:SetHorizontalRelative(-1 * (scrollRight - (tabLeft + tabWidth)))
        scrollControl.timeline:PlayFromStart()
    elseif tabLeft < scrollLeft then
        scrollControl.timeline:Stop()
        scrollControl.animation:SetHorizontalRelative(-1 * (scrollLeft - tabLeft))
        scrollControl.timeline:PlayFromStart()
    end
    ----old code!
    ----scrollControl.timeline:Stop()
    ----scrollControl.animation:SetHorizontalRelative(tabCenter - scrollCenter)
    ----scrollControl.timeline:PlayFromStart()
end

function TabWindow:selectTab(key)
    local tabIndex = self:getTabIndex(key)
--d("[TabWindow:selectTab]key: " ..tos(tabIndex))
    ZO_Tooltips_HideTextTooltip()
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
                    local keyValue = tabIndex --(type(key) ~= "number" and self:getTabIndex(key)) or key
                    local keyText = firstInspector.tabs[keyValue].tabName
                    local keyPreText = firstInspector.tabs[keyValue].label:GetText()
                    if keyPreText and keyText and keyPreText ~= "" and keyText ~= "" then
                        if startsWith(keyPreText, "[MOC_") == true and keyPreText ~= keyText then
                            keyText = keyPreText .. keyText
                        elseif keyPreText ~= keyText then
                            keyText = keyPreText
                        end
                    end
                    title:SetText(keyText)
                end
            end
        end
    else
        self.activeBg:ClearAnchors()
        self.activeBg:SetHidden(true)
    end

    local isGlobalInspector = self.control.isGlobalInspector
    if isGlobalInspector == true then
--d(">call globalInspector:connectFilterComboboxToPanel")
        local globalInspector = tbug.getGlobalInspector(true)
        if globalInspector ~= nil then
            -->See globalinspector.lua, GlobalInspector:connectFilterComboboxToPanel(tabIndex)
            globalInspector:connectFilterComboboxToPanel(tabIndex)
        end
    end

    self.activeTab = tabControl
end


function TabWindow:setTabTitle(key, title)
    local tabControl = self:getTabControl(key)
    tabControl.label:SetText(title)
end
