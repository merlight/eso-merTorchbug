local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")

local strformat = string.format
local tos = tostring

local EM = EVENT_MANAGER
local getterOrSetterStr = "%s()"
local getterOrSetterWithControlStr = "%s:%s()"

local checkForSpecialDataEntryAsKey = tbug.checkForSpecialDataEntryAsKey

local DEFAULT_TEXT_COLOR = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_NORMAL))
local DEFAULT_TEXT_HIGHLIGHT = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_CONTEXT_HIGHLIGHT))
local DISABLED_TEXT_COLOR = ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_TEXT_COLORS, INTERFACE_TEXT_COLOR_DISABLED))

local eventsInspector
local tbug_checkIfInspectorPanelIsShown = tbug.checkIfInspectorPanelIsShown
local tbug_refreshInspectorPanel = tbug.refreshInspectorPanel
local clickToIncludeAgainStr = " (Click to include)"

local tbug_endsWith = tbug.endsWith

local RT = tbug.RT
local globalInspector

--======================================================================================================================
--= CONTEXT MENU FUNCTIONS                                                                                     -v-
--======================================================================================================================

------------------------------------------------------------------------------------------------------------------------
--CONTEXT MENU -> INSPECTOR ROW edit FIELD VALUE
--LibCustomMenu custom context menu "OnClick" handling function for inspector row context menu entries
function tbug.setEditValueFromContextMenu(p_self, p_row, p_data, p_oldValue)
--df("tbug:setEditValueFromContextMenu - newValue: " ..tos(p_data.value) .. ", oldValue: " ..tos(p_oldValue))
    if p_self then
        local editBox = p_self.editBox
        if editBox then
            local currentVal = p_data.value
            if p_row and p_data and p_oldValue ~= nil and p_oldValue ~= currentVal then
                p_self.editData = p_data
                local newVal
                if currentVal == nil then
                    newVal = "nil"
                else
                    newVal = tos(currentVal)
                end
                editBox:SetText(newVal)
                p_row.cVal:SetText(newVal)
            end
            if editBox.panel and editBox.panel.valueEditConfirm then
                editBox.panel:valueEditConfirm(editBox)
            end
        end
    end
    ClearMenu()
end
local setEditValueFromContextMenu = tbug.setEditValueFromContextMenu

------------------------------------------------------------------------------------------------------------------------
--CONTEXT MENU -> CHAT EDIT BOX
--Set the chat's edit box text from a context menu entry
function tbug.setChatEditTextFromContextMenu(p_self, p_row, p_data, copyRawData, copySpecialFuncStr, isKey)
    copyRawData = copyRawData or false
    isKey = isKey or false
    if p_self and p_row and p_data then
        local controlOfInspectorRow = p_self.subject
        local key = p_data.key
        local value = p_data.value
        local prop = p_data.prop
        local dataPropOrKey = (prop  ~= nil and prop.name) or key
        local getterName = (prop ~= nil and (prop.getOrig or prop.get))
        local setterName = (prop ~= nil and (prop.setOrig or prop.set))

        --For special function strings
        local bagId, slotIndex
        local isBagOrSlotIndex = false
        local itemLink

        --For the editBox text
        local chatMessageText

        --Copy only raw data?
        if copyRawData == true then
            local valueToCopy = value
            --Copy raw value?
            if not isKey then
                local valueType = type(value)
                if valueType == "userdata" then
                    --Get name of the "userdata" from global table _G
                    local objectName = tbug.glookup(value)
                    if objectName ~= nil and objectName ~= "" and objectName ~= value then
                        valueToCopy = objectName
                    end
                end
            end
            chatMessageText = (isKey == true and tos(checkForSpecialDataEntryAsKey(p_data))) or tos(valueToCopy)
        else
            --Check the row's key value (prop.name)
            if dataPropOrKey then
                --Do not use the masterlist as it is not sorted for the non-control insepctor (e.g. table inspector)
                if dataPropOrKey == "bagId" then
                    isBagOrSlotIndex = true
                    bagId = value
                    --Get the slotIndex of the control
                    slotIndex = tbug.getPropOfControlAtIndex(p_self.list.data, p_row.index+1, "slotIndex", true)
                elseif dataPropOrKey == "slotIndex" then
                    isBagOrSlotIndex = true
                    slotIndex = value
                    --Get the bagId of the control
                    bagId = tbug.getPropOfControlAtIndex(p_self.list.data, p_row.index-1, "bagId", true)
                elseif dataPropOrKey == "itemLink" then
                    itemLink = value
                elseif dataPropOrKey == "itemLink plain text" then
                    itemLink = value:gsub("%s+", "") --remove spaces in the possible plain text itemLink
                end
            end

            --Copy special strings
            if copySpecialFuncStr ~= nil and copySpecialFuncStr ~= "" then
                if copySpecialFuncStr == "itemlink" then
                    if isBagOrSlotIndex == true then
                        if bagId and slotIndex then
                            --local itemLink = GetItemLink(bagId, slotIndex)
                            chatMessageText = "/tb GetItemLink("..tos(bagId)..", "..tos(slotIndex)..")"
                        end
                    end
                elseif copySpecialFuncStr == "itemname" then
                    if isBagOrSlotIndex == true then
                        if bagId and slotIndex then
                            local itemName = GetItemName(bagId, slotIndex)
                            if itemName and itemName ~= "" then
                                itemName = ZO_CachedStrFormat("<<C:1>>", itemName)
                            end
                            chatMessageText = tos(itemName)
                        end
                    end
                elseif copySpecialFuncStr == "special" then
                    if isBagOrSlotIndex == true then
                        if bagId and slotIndex then
                            chatMessageText = tos(bagId)..","..tos(slotIndex)
                        end
                    elseif itemLink ~= nil then
                        chatMessageText = "/tb GetItemLinkXXX(\""..itemLink.."\")"
                    end
                elseif copySpecialFuncStr == "getterName" then
                    if getterName then chatMessageText = strformat(getterOrSetterStr, tos(getterName)) end
                elseif copySpecialFuncStr == "setterName" then
                    if setterName then chatMessageText = strformat(getterOrSetterStr, tos(setterName)) end
                elseif copySpecialFuncStr == "control:getter" then
                    if getterName then
                        local ctrlName = (controlOfInspectorRow.GetName and controlOfInspectorRow:GetName()) or "???"
                        chatMessageText = strformat(getterOrSetterWithControlStr, ctrlName, tos(getterName))
                    end
                elseif copySpecialFuncStr == "control:setter" then
                    if setterName then
                        local ctrlName = (controlOfInspectorRow.GetName and controlOfInspectorRow:GetName()) or "???"
                        chatMessageText = strformat(getterOrSetterWithControlStr, ctrlName, tos(setterName))
                    end
                end
            end

        end
        if chatMessageText and chatMessageText ~= "" then
            --CHAT_SYSTEM:StartTextEntry(chatMessageText, CHAT_CHANNEL_SAY, nil, false)
            StartChatInput(chatMessageText, CHAT_CHANNEL_SAY, nil)
        end
        local editBox = p_self.editBox
        if editBox then
            if editBox.panel and editBox.panel.valueEditCancel then
                editBox.panel:valueEditCancel(editBox)
            end
        end
        ClearMenu()
    end
end
local setChatEditTextFromContextMenu = tbug.setChatEditTextFromContextMenu

------------------------------------------------------------------------------------------------------------------------
--CONTROL OUTLINE
local blinksDonePerControl = {}
local function hideOutlineNow(p_controlToOutline, removeAllOutlines)
    removeAllOutlines = removeAllOutlines or false
    if removeAllOutlines == true then
        ControlOutline_ReleaseAllOutlines()
    else
        if ControlOutline_IsControlOutlined(p_controlToOutline) then ControlOutline_ReleaseOutlines(p_controlToOutline) end
    end
end

function tbug.hideOutline(p_self, p_row, p_data, removeAllOutlines)
    local controlToRemoveOutlines = p_self.subject
    if controlToRemoveOutlines ~= nil or removeAllOutlines == true then
        hideOutlineNow(controlToRemoveOutlines, removeAllOutlines)
    end
end
local hideOutline = tbug.hideOutline

local function blinkOutlineNow(p_controlToOutline, p_uniqueBlinkName, p_blinkCountTotal)
    --Hide the outline control at first call, if it is currently shown
    if blinksDonePerControl[p_controlToOutline] == 0 then
        hideOutlineNow(p_controlToOutline)
    end
    --Show/Hide the outline now (toggles on each call to this update function of the RegisterForUpdate event)
    --but only if the control is currently shown (else we cannot see the outline)
    if not p_controlToOutline:IsHidden() then
        ControlOutline_ToggleOutline(p_controlToOutline)
    end

    --Increase blinks done
    blinksDonePerControl[p_controlToOutline] = blinksDonePerControl[p_controlToOutline] + 1

    --End blinking and unregister updater
    if blinksDonePerControl[p_controlToOutline] >= p_blinkCountTotal then
        EM:UnregisterForUpdate(p_uniqueBlinkName)
        blinksDonePerControl[p_controlToOutline] = nil
        hideOutlineNow(p_controlToOutline)
    end
end

local function outlineWithChildControlsNow(control, withChildren)
    withChildren = withChildren or false
    if control == nil then return end
    if withChildren == true then
        hideOutlineNow(control)
        ControlOutline_OutlineParentChildControls(control)
    else
        if ControlOutline_IsControlOutlined(control) then return end
        ControlOutline_ToggleOutline(control)
    end
end
function tbug.outlineControl(p_self, p_row, p_data, withChildren)
    local controlToOutline = p_self.subject
    outlineWithChildControlsNow(controlToOutline, withChildren)
end
local outlineControl = tbug.outlineControl


function tbug.blinkControlOutline(p_self, p_row, p_data, blinkCount)
--d("[TBUG]Blink control outline - blinkCount: " ..tos(blinkCount))
--Debugging
--tbug._blinkControlOutline = {}
--tbug._blinkControlOutline.self = p_self
--tbug._blinkControlOutline.data =p_data
--tbug._blinkControlOutline.row = p_row
    local controlToOutline = p_self.subject
    if controlToOutline ~= nil then
        local controlToOutlineName = controlToOutline.GetName and controlToOutline:GetName()
        if not controlToOutlineName then return end
        local uniqueBlinkName = "TBUG_BlinkOutline_" .. controlToOutlineName
        EM:UnregisterForUpdate(uniqueBlinkName)
        blinksDonePerControl[controlToOutline] = 0
        EM:RegisterForUpdate(uniqueBlinkName, 550, function()
            local blinkCountTotal = blinkCount * 2 --duplicate the blink count to respect each "on AND off" as 1 blink
            blinkOutlineNow(controlToOutline, uniqueBlinkName, blinkCountTotal)
        end)
    end
end
local blinkControlOutline = tbug.blinkControlOutline


------------------------------------------------------------------------------------------------------------------------
--SCRIPT HISTORY
--Remove a script from the script history by help of the context menu
function tbug.removeScriptHistory(panel, scriptRowId, refreshScriptsTableInspector)
    if not panel or not scriptRowId then return end
    refreshScriptsTableInspector = refreshScriptsTableInspector or false
    --Check if script is not already in
    if tbug.savedVars and tbug.savedVars.scriptHistory then
        --Set the column to update to 1
        local editBox = {}
        editBox.updatedColumnIndex = 1
        tbug.changeScriptHistory(scriptRowId, editBox, "", refreshScriptsTableInspector)
        if refreshScriptsTableInspector == true then
            if tbug_checkIfInspectorPanelIsShown("globalInspector", "scriptHistory") then
                tbug_refreshInspectorPanel("globalInspector", "scriptHistory")
                --TODO: Why does a single data refresh not work directly where a manual click on the update button does work?! Even a delayed update does not work properly...
                tbug_refreshInspectorPanel("globalInspector", "scriptHistory")
            end
        end
    end
    ClearMenu()
end
local removeScriptHistory = tbug.removeScriptHistory


------------------------------------------------------------------------------------------------------------------------
--EVENTS
local function reRegisterAllEvents()
    eventsInspector = eventsInspector or tbug.Events.getEventsTrackerInspectorControl()
    tbug.Events.ReRegisterAllEvents(eventsInspector)
end

local function registerExcludedEventId(eventId)
    eventsInspector = eventsInspector or tbug.Events.getEventsTrackerInspectorControl()
    tbug.Events.UnRegisterSingleEvent(eventsInspector, eventId)
end

local function addToExcluded(eventId)
    table.insert(tbug.Events.eventsTableExcluded, eventId)
end
local function removeFromExcluded(eventId, removeAll)
    removeAll = removeAll or false
    if removeAll == true then
        tbug.Events.eventsTableExcluded = {}
    else
        for idx, eventIdToFind in ipairs(tbug.Events.eventsTableExcluded) do
            if eventIdToFind == eventId then
                table.remove(tbug.Events.eventsTableExcluded, idx)
                return true
            end
        end
    end
end

local function registerOnlyIncludedEvents()
    local events = tbug.Events
    eventsInspector = eventsInspector or events.getEventsTrackerInspectorControl()
    tbug.Events.UnRegisterAllEvents(eventsInspector, events.eventsTableIncluded)
end

local function addToIncluded(eventId, onlyThisEvent)
    onlyThisEvent = onlyThisEvent or false
    if onlyThisEvent == true then
        tbug.Events.eventsTableIncluded = {}
    end
    table.insert(tbug.Events.eventsTableIncluded, eventId)
end
local function removeFromIncluded(eventId, removeAll)
    removeAll = removeAll or false
    if removeAll == true then
        tbug.Events.eventsTableIncluded = {}
    else
        for idx, eventIdToFind in ipairs(tbug.Events.eventsTableIncluded) do
            if eventIdToFind == eventId then
                table.remove(tbug.Events.eventsTableIncluded, idx)
                return true
            end
        end
    end
end

local function showEventsContextMenu(p_self, p_row, p_data, isEventMainUIToggle)
    --Did we right click the main UI's e/E toggle button?
    isEventMainUIToggle = isEventMainUIToggle or false
    if isEventMainUIToggle == true then
        ClearMenu()
    end

    local events    = tbug.Events
    eventsInspector = eventsInspector or events.getEventsTrackerInspectorControl()

    AddCustomMenuItem("Event tracking actions", function() end, MENU_ADD_OPTION_HEADER, nil, nil, nil, nil, nil)

    --If the events list is not empty
    if eventsInspector ~= nil and #events.eventsTableInternal > 0 then
        AddCustomMenuItem("Clear events list", function()
            events.eventsTableInternal = {}
            tbug.RefreshTrackedEventsList()
            globalInspector = globalInspector or tbug.getGlobalInspector(true)
            --globalInspector.panels["events"]:populateMasterList(events.eventsTable, RT.EVENTS_TABLE)
            globalInspector.panels["events"]:refreshData()

        end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
    end

    local currentValue
    if p_data == nil then
        if isEventMainUIToggle == true then
            p_data = {
                key = nil,
                value = {
                    _eventName = "Settings",
                    _eventId   = nil
                }
            }
        else
            return
        end
    end
    currentValue = p_data.value
    local eventName = currentValue._eventName
    local eventId   = currentValue._eventId

    --Actual event actions
    local eventTrackingSubMenuTable = {}
    local eventTrackingSubMenuTableEntry = {}
    if not isEventMainUIToggle then
        eventTrackingSubMenuTableEntry = {
            label = strformat("Exclude this event"),
            callback = function()
                addToExcluded(eventId)
                removeFromIncluded(eventId, false)
                registerExcludedEventId(eventId)
            end,
        }
        table.insert(eventTrackingSubMenuTable, eventTrackingSubMenuTableEntry)
        eventTrackingSubMenuTableEntry = {
            label = strformat("Include this event"),
            callback = function()
                addToIncluded(eventId, false)
                removeFromExcluded(eventId, false)
                registerOnlyIncludedEvents()
            end,
        }
        table.insert(eventTrackingSubMenuTable, eventTrackingSubMenuTableEntry)
        eventTrackingSubMenuTableEntry = {
            label = strformat("ONLY show this event"),
            callback = function()
                addToIncluded(eventId, true)
                removeFromExcluded(nil, true)
                registerOnlyIncludedEvents()
            end,
        }
        table.insert(eventTrackingSubMenuTable, eventTrackingSubMenuTableEntry)
        eventTrackingSubMenuTableEntry = {
            label = "-",
            callback = function() end,
        }
        table.insert(eventTrackingSubMenuTable, eventTrackingSubMenuTableEntry)
    end
    eventTrackingSubMenuTableEntry = {
        label = "Re-register ALL events (clear excluded/included)",
        callback = function()
            reRegisterAllEvents()
        end,
    }
    table.insert(eventTrackingSubMenuTable, eventTrackingSubMenuTableEntry)
    AddCustomSubMenuItem(strformat("Event: \'%s\'", tos(eventName)), eventTrackingSubMenuTable)


    --Included events
    local includedEvents = events.eventsTableIncluded
    if includedEvents and #includedEvents > 0 then
        local eventTrackingIncludedSubMenuTable = {}
        local eventTrackingIncludedSubMenuTableEntry = {}
        for _, eventIdIncluded in ipairs(includedEvents) do
            local eventNameIncluded = events.eventList[eventIdIncluded]
            eventTrackingIncludedSubMenuTableEntry = {
                label = eventNameIncluded,
                callback = function()
                    --Todo Any option needed?
                end,
            }
            table.insert(eventTrackingIncludedSubMenuTable, eventTrackingIncludedSubMenuTableEntry)
        end
        AddCustomSubMenuItem("INcluded events",  eventTrackingIncludedSubMenuTable)
    end

    --Excluded events
    local excludedEvents = events.eventsTableExcluded
    if excludedEvents and #excludedEvents > 0 then
        eventsInspector = eventsInspector or tbug.Events.getEventsTrackerInspectorControl()

        local eventTrackingExcludedSubMenuTable = {}
        local eventTrackingExcludedSubMenuTableEntry = {}
        for _, eventIdExcluded in ipairs(excludedEvents) do
            local eventNameExcluded = events.eventList[eventIdExcluded]
            eventTrackingExcludedSubMenuTableEntry = {
                label = eventNameExcluded .. clickToIncludeAgainStr,
                callback = function()
                    --Remove the excluded event again -> Include it again
                    removeFromExcluded(eventIdExcluded, false)
                    tbug.Events.RegisterSingleEvent(eventsInspector, eventIdExcluded)
                end,
            }
            table.insert(eventTrackingExcludedSubMenuTable, eventTrackingExcludedSubMenuTableEntry)
        end
        AddCustomSubMenuItem("EXcluded events", eventTrackingExcludedSubMenuTable)
    end

    if isEventMainUIToggle == true then
        ShowMenu(p_self)
    end
end
tbug.ShowEventsContextMenu = showEventsContextMenu


------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--Row context menu at inspectors
--LibCustomMenu custom context menu entry creation for inspector rows
function tbug.buildRowContextMenuData(p_self, p_row, p_data, p_contextMenuForKey)
    p_contextMenuForKey = p_contextMenuForKey or false
--d("[tbug.buildRowContextMenuData]isKey: " ..tos(p_contextMenuForKey))
    if LibCustomMenu == nil or p_self == nil or p_row == nil or p_data == nil then return end

    --TODO: for debugging
--[[
tbug._contextMenuLast = {}
tbug._contextMenuLast.self   = p_self
tbug._contextMenuLast.row    = p_row
tbug._contextMenuLast.data   = p_data
tbug._contextMenuLast.isKey  = p_contextMenuForKey
]]
    local doShowMenu = false
    ClearMenu()

    local RT = tbug.RT
    local dataEntry = p_data.dataEntry
    local dataTypeId = dataEntry and dataEntry.typeId

    local canEditValue = p_self:canEditValue(p_data)
    local key          = p_data.key
    --local keyType      = type(key)
    local currentValue = p_data.value
    local valType      = type(currentValue)
    local prop         = p_data.prop
    local propName = prop and prop.name
    local dataPropOrKey = (propName ~= nil and propName ~= "" and propName) or key
    local keyToEnums = tbug.keyToEnums
--d(">canEditValue: " ..tos(canEditValue) .. ", forKey: " .. tos(p_contextMenuForKey) .. ", key: " ..tos(key) ..", keyType: "..tos(keyType) .. ", value: " ..tos(currentValue) .. ", valType: " ..tos(valType) .. ", propName: " .. tos(propName) ..", dataPropOrKey: " ..tos(dataPropOrKey))

    --Context menu for the key of the row
    if p_contextMenuForKey == true then
        ------------------------------------------------------------------------------------------------------------------------
        ------------------------------------------------------------------------------------------------------------------------
        ------------------------------------------------------------------------------------------------------------------------
        if key ~= nil then
            --General entries
            AddCustomMenuItem("Row actions", function() end, MENU_ADD_OPTION_HEADER, nil, nil, nil, nil, nil)
            AddCustomMenuItem("Copy key RAW to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, true, nil, true) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
            AddCustomMenuItem("-", function() end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
            --Add copy "value" raw to chat
            --Default "copy raw etc." entries
            AddCustomMenuItem("Copy value RAW to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, true, nil, nil) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
            if tbug.isSpecialEntryAtInspectorList(p_self, p_row, p_data) then
                AddCustomMenuItem("Copy value SPECIAL to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, false, "special", nil) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
            end

            doShowMenu = true --to show general entries
            ------------------------------------------------------------------------------------------------------------------------

            --Is key a string ending on "SCENE_NAME" and the value is a string e.g. "trading_house"
            -->Show a context menu entry "Open scene"
            if type(key) == "string" and valType == "string" and (tbug_endsWith(key, "_SCENE_NAME") == true or tbug_endsWith(key, "_SCENE_IDENTIFIER") == true) then
                local slashCmdToShowScene = "SCENE_MANAGER:Show(\'" ..tos(currentValue) .. "\')"
                AddCustomMenuItem("Scene actions", function() end, MENU_ADD_OPTION_HEADER, nil, nil, nil, nil, nil)
                AddCustomMenuItem("Show scene", function() tbug.slashCommand(slashCmdToShowScene) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                if SCENE_MANAGER:IsShowing(tos(currentValue)) then
                    local slashCmdToHideScene = "SCENE_MANAGER:Hide(\'" ..tos(currentValue) .. "\')"
                    AddCustomMenuItem("Hide scene", function() tbug.slashCommand(slashCmdToHideScene) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                end
            end
            ------------------------------------------------------------------------------------------------------------------------


           --ScriptHistory KEY context menu
            if dataTypeId == RT.SCRIPTHISTORY_TABLE then
                AddCustomMenuItem("Script history actions", function() end, MENU_ADD_OPTION_HEADER, nil, nil, nil, nil, nil)
                AddCustomMenuItem("Delete script history entry",
                        function()
                            removeScriptHistory(p_self, key, true)
                        end,
                        MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                doShowMenu = true
                ------------------------------------------------------------------------------------------------------------------------
                --Event tracking KEY context menu
            elseif dataTypeId == RT.EVENTS_TABLE then

                showEventsContextMenu(p_self, p_row, p_data, false)
                doShowMenu = true --to show general entries
            end

        end
        ------------------------------------------------------------------------------------------------------------------------
        --Properties are given?
        if prop ~= nil then
            --Getter and Setter - To chat
            local controlOfInspectorRow = p_self.subject
            if controlOfInspectorRow ~= nil then
                local getterName = prop.getOrig or prop.get
                local setterName = prop.setOrig or prop.set
                local getterOfCtrl = controlOfInspectorRow[getterName]
                local setterOfCtrl = controlOfInspectorRow[setterName]
                --d(">prop found - get: " ..tos(getterName) ..", set: " ..tos(setterName))

                if getterOfCtrl ~= nil or setterOfCtrl ~= nil then
                    AddCustomMenuItem("Get & Set", function() end, MENU_ADD_OPTION_HEADER, nil, nil, nil, nil, nil)
                    if getterOfCtrl ~= nil then
                        --p_self, p_row, p_data, copyRawData, copySpecialFuncStr, isKey
                        AddCustomMenuItem("Copy getter name to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, false, "getterName", true) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                        AddCustomMenuItem("Copy <control>:Getter() to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, false, "control:getter", true) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                    end
                    if setterOfCtrl ~= nil then
                        AddCustomMenuItem("Copy setter name to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, false, "setterName", true) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                        AddCustomMenuItem("Copy <control>:Setter() to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, false, "control:setter", true) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                    end
                    doShowMenu = true
                end
            end

            ------------------------------------------------------------------------------------------------------------------------
            --Boolean value at the key, even if no "key" was provided
            if valType == "boolean" then

                --Control outline KEY context menu
                if ControlOutline and dataPropOrKey and dataPropOrKey == "outline" then
                    AddCustomMenuItem("Outline actions", function() end, MENU_ADD_OPTION_HEADER, nil, nil, nil, nil, nil)
                    if not controlOfInspectorRow or controlOfInspectorRow:IsHidden() then
                        AddCustomMenuItem("Control is hidden - no outline possible", function() end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                    else
                        AddCustomMenuItem("Outline", function() outlineControl(p_self, p_row, p_data, false) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                        AddCustomMenuItem("Outline + child controls", function() outlineControl(p_self, p_row, p_data, true) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                        AddCustomMenuItem("-", function() end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                        AddCustomMenuItem("Blink outline 1x", function() blinkControlOutline(p_self, p_row, p_data, 1) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                        AddCustomMenuItem("Blink outline 3x", function() blinkControlOutline(p_self, p_row, p_data, 3) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                        AddCustomMenuItem("Blink outline 5x", function() blinkControlOutline(p_self, p_row, p_data, 5) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)

                        local controlToOutline = p_self.subject
                        local addControlClearOutline = (controlToOutline ~= nil and ControlOutline_IsControlOutlined(controlToOutline) and true) or false
                        local addClearAllOutlines = (#ControlOutline.pool.m_Active > 0 and true) or false
                        local addDividerForClearOutlines = addControlClearOutline or addClearAllOutlines
                        if addDividerForClearOutlines == true then
                            AddCustomMenuItem("-", function() end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                        end
                        if addControlClearOutline == true then
                            AddCustomMenuItem("Remove control outlines", function() hideOutline(p_self, p_row, p_data, false) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                        end
                        if addClearAllOutlines == true then
                            AddCustomMenuItem("Remove all outlines", function() hideOutline(p_self, p_row, p_data, true) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                        end
                    end
                    doShowMenu = true
                end

            end
        end

------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
    --Context menu for the value of the row
    else
        if currentValue ~= nil then
------------------------------------------------------------------------------------------------------------------------
            --boolean entries
            if valType == "boolean" then
                if canEditValue then
                    if currentValue == false then
                        AddCustomMenuItem("+ true",  function() p_data.value = true  setEditValueFromContextMenu(p_self, p_row, p_data, false) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                    else
                        AddCustomMenuItem("- false", function() p_data.value = false setEditValueFromContextMenu(p_self, p_row, p_data, true) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                    end
                    AddCustomMenuItem("   NIL (Attention!)",  function() p_data.value = nil  setEditValueFromContextMenu(p_self, p_row, p_data, currentValue) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                    doShowMenu = true
                end
                ------------------------------------------------------------------------------------------------------------------------
                --number or string entries
            elseif valType == "number" or valType == "string" then
                --Do we have a setter function given?
                --Check if any enumeration is provided and add the givenenum entries to the context menu entries
                local enumsWereAdded = false
                local enumContextMenuEntries = {}
                if prop == nil then
                    if dataPropOrKey ~= nil then
                        --No prop given e.g. at a tableInspector of dataEntry of inventory item
                        --Check if dataPropOrKey == "bagId" e.g. and get the mapped enum for bagId
                        prop = {}
                        prop.enum = keyToEnums[key]
--d(">no props found, used key: " ..tos(key) .. " to get: " ..tos(prop.enum))
                        if prop.enum == nil then prop = nil end
                    end
                end
                if prop ~= nil then
                    local enumProp = prop.enum
                    --Check for enums
                    if enumProp ~= nil then
                        local enumsTab = tbug.enums[enumProp]
                        if enumsTab ~= nil then
                    --for debugging
                    --tbug._contextMenuLast.enumsTab = enumsTab
                            local controlOfInspectorRow = p_self.subject
                            if controlOfInspectorRow then
                                --Setter control and func are given, enums as well
                                --Loop all enums now
                                for enumValue, enumName in pairs(enumsTab) do
                                    table.insert(enumContextMenuEntries, {enumName = enumName, enumValue=enumValue})

                                end
                                enumsWereAdded = #enumContextMenuEntries > 0

                                local setterName = prop.setOrig or prop.set
                                local setterOfCtrl
                                if setterName then
                                    setterOfCtrl = controlOfInspectorRow[setterName]
                                end
                                if setterOfCtrl ~= nil then
                                    canEditValue = true
                                end
                            end
                        end
                    end
                end
                local function insertEnumsToContextMenu(dividerLate)
                    if not dividerLate then
                        --Divider line at the top
                        AddCustomMenuItem("-", function() end)
                    end
                    --Divider line needed from enums?
                    if enumsWereAdded then
                        local headlineText = canEditValue and "Choose value" or "Possible values"
                        local entryFont = canEditValue and "ZoFontGame" or "ZoFontGameSmall"
                        local entryFontColorNormal = canEditValue and DEFAULT_TEXT_COLOR or DISABLED_TEXT_COLOR
                        local entryFontColorHighlighted = canEditValue and DEFAULT_TEXT_HIGHLIGHT or DISABLED_TEXT_COLOR
                        AddCustomMenuItem(headlineText, function() end, MENU_ADD_OPTION_HEADER, nil, entryFontColorNormal, entryFontColorHighlighted, nil, nil)
                        for _, enumData in ipairs(enumContextMenuEntries) do
                            local funcCalledOnEntrySelected = canEditValue and function() p_data.value = enumData.enumValue  setEditValueFromContextMenu(p_self, p_row, p_data, currentValue) end or function()  end
                            AddCustomMenuItem(enumData.enumName, funcCalledOnEntrySelected, MENU_ADD_OPTION_LABEL, entryFont, entryFontColorNormal, entryFontColorHighlighted, nil, nil)
                        end
                        if dividerLate then
                            --Divider line at the bottom
                            AddCustomMenuItem("-", function() end)
                        end
                    end
                end
                if enumsWereAdded and canEditValue then
                    insertEnumsToContextMenu(canEditValue)
                end
                --Default "copy raw etc." entries
                AddCustomMenuItem("Copy RAW to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, true, nil, nil) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                if tbug.isSpecialEntryAtInspectorList(p_self, p_row, p_data) then
                    AddCustomMenuItem("Copy SPECIAL to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, false, "special", nil) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                end
                if dataPropOrKey and (dataPropOrKey == "bagId" or dataPropOrKey =="slotIndex") then
                    AddCustomMenuItem("Copy ITEMLINK to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, false, "itemlink", nil) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                    AddCustomMenuItem("Copy NAME to chat", function() setChatEditTextFromContextMenu(p_self, p_row, p_data, false, "itemname", nil) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                end
                if enumsWereAdded and not canEditValue then
                    insertEnumsToContextMenu(canEditValue)
                end
                doShowMenu = true
            end
        end
------------------------------------------------------------------------------------------------------------------------
    end
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
    if doShowMenu == true then
        ShowMenu(p_row)
    end
end