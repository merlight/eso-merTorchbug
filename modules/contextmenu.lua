local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")

--======================================================================================================================
--= CONTEXT MENU FUNCTIONS                                                                                     -v-
--======================================================================================================================
--LibCustomMenu custom context menu "OnClick" handling function for inspector row context menu entries
function tbug.setEditValueFromContextMenu(p_self, p_row, p_data, p_oldValue)
--df("tbug:setEditValueFromContextMenu")
    if p_self then
        local editBox = p_self.editBox
        if editBox then
            if p_row and p_data and p_oldValue ~= nil and p_oldValue ~= p_data.value then
                p_self.editData = p_data
                local newVal
                if p_data.value == nil then
                    newVal = "nil"
                else
                    newVal = tostring(p_data.value)
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

--Set the chat's edit box text from a context menu entry
function tbug.setChatEditTextFromContextMenu(p_self, p_row, p_data, copyRawData, copySpecialFuncStr, isKey)
    copyRawData = copyRawData or false
    isKey = isKey or false
    if p_self and p_row and p_data then
        local dataPropOrKey = (p_data.prop and p_data.prop.name) or p_data.key
        --BagId or slotIndex?
        local bagId, slotIndex
        local isBagOrSlotIndex = false
        local itemLink
        local chatMessageText
        if copyRawData then
            chatMessageText = (isKey == true and tostring(p_data.key)) or tostring(p_data.value)
        else
            --Check the row's key value (prop.name)
            if dataPropOrKey then
                --Do not use the masterlist as it is not sorted for the non-control insepctor (e.g. table inspector)
                if dataPropOrKey == "bagId" then
                    isBagOrSlotIndex = true
                    bagId = p_data.value
                    --Get the slotIndex of the control
                    slotIndex = tbug.getPropOfControlAtIndex(p_self.list.data, p_row.index+1, "slotIndex", true)
                elseif dataPropOrKey == "slotIndex" then
                    isBagOrSlotIndex = true
                    slotIndex = p_data.value
                    --Get the bagId of the control
                    bagId = tbug.getPropOfControlAtIndex(p_self.list.data, p_row.index-1, "bagId", true)
                elseif dataPropOrKey == "itemLink" then
                    itemLink = p_data.value
                elseif dataPropOrKey == "itemLink plain text" then
                    itemLink = p_data.value:gsub("%s+", "") --remove spaces in the possible plain text itemLink
                end
            end
            if copySpecialFuncStr ~= nil and copySpecialFuncStr ~= "" then
                if copySpecialFuncStr == "itemlink" then
                    if isBagOrSlotIndex == true then
                        if bagId and slotIndex then
                            --local itemLink = GetItemLink(bagId, slotIndex)
                            chatMessageText = "/tb GetItemLink("..tostring(bagId)..", "..tostring(slotIndex)..")"
                        end
                    end
                elseif copySpecialFuncStr == "itemname" then
                    if isBagOrSlotIndex == true then
                        if bagId and slotIndex then
                            local itemName = GetItemName(bagId, slotIndex)
                            if itemName and itemName ~= "" then
                                itemName = ZO_CachedStrFormat("<<C:1>>", itemName)
                            end
                            chatMessageText = tostring(itemName)
                        end
                    end
                elseif copySpecialFuncStr == "special" then
                    if isBagOrSlotIndex == true then
                        if bagId and slotIndex then
                            chatMessageText = tostring(bagId)..","..tostring(slotIndex)
                        end
                    elseif itemLink ~= nil then
                        chatMessageText = "/tb GetItemLinkXXX(\""..itemLink.."\")"
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
            if tbug.checkIfInspectorPanelIsShown("globalInspector", "scriptHistory") then
                tbug.refreshInspectorPanel("globalInspector", "scriptHistory")
                --TODO: Why does a single datarefresh not work directly where a manual click on the update button does work?! Even a delayed update does not work properly...
                tbug.refreshInspectorPanel("globalInspector", "scriptHistory")
            end
        end
    end
    ClearMenu()
end

--LibCustomMenu custom context menu entry creation for inspector rows
function tbug.buildRowContextMenuData(p_self, p_row, p_data, p_contextMenuForKey)
--d("[tbug.buildRowContextMenuData]")
    if p_contextMenuForKey == nil then p_contextMenuForKey = false end

--tbug._self = p_self
--tbug._row = p_row
--tbug._data = p_data


    if LibCustomMenu ~= nil and p_self and p_row and p_data then
        local doShowMenu = false
        ClearMenu()

        local RT = tbug.RT
        local dataTypeId = p_data.dataEntry.typeId

        --Context menu for the key of the row
        if p_contextMenuForKey == true then
            if p_data.key ~= nil then
                --ScriptHistory KEY context menu
                if dataTypeId == RT.SCRIPTHISTORY_TABLE then
                    AddCustomMenuItem("Delete script history entry",  function() tbug.removeScriptHistory(p_self, p_data.key, true) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                end
                AddCustomMenuItem("Copy key RAW to chat", function() tbug.setChatEditTextFromContextMenu(p_self, p_row, p_data, true, nil, true) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                doShowMenu = true
            end
        --Context menu for the value of the row
        else
            if p_data.value ~= nil then
                local valType = type(p_data.value)
               --boolean entries
                if valType == "boolean" then
                    local oldValue = p_data.value
                    AddCustomMenuItem("- false", function() p_data.value = false tbug.setEditValueFromContextMenu(p_self, p_row, p_data, oldValue) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                    AddCustomMenuItem("+ true",  function() p_data.value = true  tbug.setEditValueFromContextMenu(p_self, p_row, p_data, oldValue) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                    AddCustomMenuItem("   NIL (Attention!)",  function() p_data.value = nil  tbug.setEditValueFromContextMenu(p_self, p_row, p_data, oldValue) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                    doShowMenu = true
               --number or string entries
                elseif valType == "number" or valType == "string" then
                    local oldValue = p_data.value
                    AddCustomMenuItem("Copy RAW to chat", function() tbug.setChatEditTextFromContextMenu(p_self, p_row, p_data, true) end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                    if tbug.isSpecialEntryAtInspectorList(p_self, p_row, p_data) then
                        AddCustomMenuItem("Copy SPECIAL to chat", function() tbug.setChatEditTextFromContextMenu(p_self, p_row, p_data, false, "special") end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                    end
                    local dataPropOrKey = (p_data.prop and p_data.prop.name and p_data.prop.name) or p_data.key
                    if dataPropOrKey and (dataPropOrKey == "bagId" or dataPropOrKey =="slotIndex") then
                        AddCustomMenuItem("Copy ITEMLINK to chat", function() tbug.setChatEditTextFromContextMenu(p_self, p_row, p_data, false, "itemlink") end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                        AddCustomMenuItem("Copy NAME to chat", function() tbug.setChatEditTextFromContextMenu(p_self, p_row, p_data, false, "itemname") end, MENU_ADD_OPTION_LABEL, nil, nil, nil, nil, nil)
                    end
                    doShowMenu = true
                end
            end
        end
        if doShowMenu == true then
            ShowMenu(p_row)
        end
    end
end