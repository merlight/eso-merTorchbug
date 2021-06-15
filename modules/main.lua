local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")
local myNAME = TBUG.name
local startTime = tbug.startTime
local sessionStartTime = tbug.sessionStartTime
local ADDON_MANAGER

local addOns = {}
tbug.IsEventTracking = false

local titlePatterns = tbug.titlePatterns
local titleTemplate =       titlePatterns.normalTemplate
local titleMocTemplate =    titlePatterns.mouseOverTemplate

local strformat = string.format
local strfind = string.find
local firstToUpper = tbug.firstToUpper
local startsWith = tbug.startsWith
local endsWith = tbug.endsWith

local function compareBySubTablesKeyName(a,b)
    if a.name and b.name then return a.name < b.name
    elseif a.__name and b.__name then return a.__name < b.__name end
end

local function compareBySubTablesLoadOrderIndex(a,b)
    if a._loadOrderIndex and b._loadOrderIndex then return a._loadOrderIndex < b._loadOrderIndex end
end

local function showDoesNotExistError(object, winTitle, tabTitle)
    local errText = "tbug: No inspector for \'%s\' (%q)"
    local title = (winTitle ~= nil and tostring(winTitle)) or tostring(tabTitle)
    df(errText, title, tostring(object))
end

function tbug.prepareItemLink(control, asPlainText)
    asPlainText = asPlainText or false
    local itemLink = ""
    local bagId = (control.dataEntry and control.dataEntry.data and (control.dataEntry.data.bagId or control.dataEntry.data.bag)) or
            (control.dataEntry and (control.dataEntry.bagId or control.dataEntry.bag))
            or control.bagId or control.bag
    local slotIndex = (control.dataEntry and control.dataEntry.data and (control.dataEntry.data.slotIndex or control.dataEntry.data.index or control.dataEntry.data.slot)) or
            (control.dataEntry and (control.dataEntry.slotIndex or control.dataEntry.index or control.dataEntry.slot))
            or control.slotIndex or control.index or control.slot
    if bagId and slotIndex and type(bagId) == "number" and type(slotIndex) == "number" then
        itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_BRACKETS)
    end
    if itemLink and itemLink ~= "" and asPlainText == true then
        --Controls within ESO will show itemLinks "comiled" as clickable item's link. If we only want the ||h* plain text
        --we need to remove the leading | so that it's not recognized as an itemlink anymore
        local ilPlaintext = itemLink:gsub("^%|", "", 1)
        itemLink = "| " .. ilPlaintext
    end
    return itemLink
end

function tbug.inspect(object, tabTitle, winTitle, recycleActive, objectParent)
    local inspector = nil
    local resType = type(object)
--d("[tbug.inspect]object: " ..tostring(object) .. ", objType: "..tostring(resType) ..", tabTitle: " ..tostring(tabTitle) .. ", winTitle: " ..tostring(winTitle))
    if rawequal(object, _G) then
        inspector = tbug.getGlobalInspector()
        inspector.control:SetHidden(false)
        inspector:refresh()
    elseif resType == "table" then
        local title = tbug.glookup(object) or winTitle or tostring(object)
        if not endsWith(title, "[]") then title = title .. "[]" end
        inspector = tbug.classes.ObjectInspector:acquire(object, tabTitle, recycleActive, title)
        inspector.control:SetHidden(false)
        inspector:refresh()
    elseif tbug.isControl(object) then
        local title = ""
        if type(winTitle) == "string" then
            title = winTitle
        else
            title = tbug.getControlName(object)
        end
        inspector = tbug.classes.ObjectInspector:acquire(object, tabTitle, recycleActive, title)
        inspector.control:SetHidden(false)
        inspector:refresh()
    elseif resType == "function" then
        local wasRunWithoutErrors, resultsOfFunc = pcall(setfenv(object, tbug.env))
        local title = (winTitle ~= nil and tostring(winTitle)) or tostring(tabTitle) or ""
        title = (objectParent ~= nil and objectParent ~= "" and objectParent and ".") or "" .. title
        if wasRunWithoutErrors then
            d("tbug: Results of function \'" .. tostring(title) .. "\':")
        else
            d("<<<ERROR>>> tbug: Function \'" .. tostring(title) .. "\' ended with errors:")
        end
        if type(resultsOfFunc) == "table" then
            for _, v in ipairs(resultsOfFunc) do
                d(v)
            end
        else
            d(resultsOfFunc)
        end
    else
        showDoesNotExistError(object, winTitle, tabTitle)
    end

    return inspector
end

--Get a panel of an inspector
function tbug.getInspectorPanel(inspectorName, panelName)
    if tbug[inspectorName] then
        local inspector = tbug[inspectorName]
        local panels = inspector.panels
        if panels and panels[panelName] then
            return panels[panelName]
        end
    end
    return nil
end

--Refresh the panel of a TableInspector
function tbug.refreshInspectorPanel(inspectorName, panelName, delay)
    delay = delay or 0
--d("[tbug.refreshInspectorPanel]inspectorName: " ..tostring(inspectorName) .. ", panelName: " ..tostring(panelName) .. ", delay: " ..tostring(delay))
    local function refreshPanelNow()
        local panel = tbug.getInspectorPanel(inspectorName, panelName)
        if panel and panel.refreshData then
            --d(">refreshing now...")
            panel:refreshData()
            if panel.refreshVisible then panel:refreshVisible() end
        end
    end
    --Delayed call?
    if delay > 0 then
        zo_callLater(function() refreshPanelNow() end, delay)
    else
        refreshPanelNow()
    end
end

--Check if the TBUG TableInspector with the scripts tab is currently shown and needs a refresh then
function tbug.checkIfInspectorPanelIsShown(inspectorName, panelName)
    if tbug[inspectorName] then
        local panel = tbug.getInspectorPanel(inspectorName, panelName)
        local panelCtrl = panel.control
        if panelCtrl and panelCtrl.IsHidden then
            return not panelCtrl:IsHidden()
        end
    end
    return false
end

--Select the tab at the global inspector
function tbug.inspectorSelectTabByName(inspectorName, tabName, tabIndex, doCreateIfMissing)
    doCreateIfMissing = doCreateIfMissing or false
    if tbug[inspectorName] then
        local inspector = tbug[inspectorName]
        if inspector.getTabIndexByName and inspector.selectTab then
            --Special treatment: Restore all the global inspector tabs
            if inspectorName == "globalInspector" and tabName == "-all-" and doCreateIfMissing == true then
                inspector:connectPanels(nil, true, true)
                tabIndex = 1
            else
                tabIndex = tabIndex or inspector:getTabIndexByName(tabName)
                if not tabIndex and doCreateIfMissing == true then
                    inspector:connectPanels(tabName, true, false)
                    tabIndex = inspector:getTabIndexByName(tabName)
                end
            end
            if tabIndex then inspector:selectTab(tabIndex) end
        end
    end
end

--Check if a key or value is already inside a table
--checkKeyOrValue - true: Check the key, false: Check the value
local function checkIfAlreadyInTable(table, key, value, checkKeyOrValue)
    if not table or checkKeyOrValue == nil then return false end
    if checkKeyOrValue == true then
        if not key then return false end
        if table[key] == nil then return true end
    else
        if not value then return false end
        for k, v in pairs(table) do
            if key ~= nil then
                if k == key then
                    if v == value then return true end
                end
            else
                if v == value then return true end
            end
        end
    end
    return false
end

local function evalString(source)
    -- first, try to compile it with "return " prefixed,
    -- this way we can evaluate things like "_G.tab[5]"
    local func, err = zo_loadstring("return " .. source)
    if not func then
        -- failed, try original source
        func, err = zo_loadstring(source, "<< " .. source .. " >>")
        if not func then
            return func, err
        end
    end
    -- run compiled chunk in custom environment
    return pcall(setfenv(func, tbug.env))
end


local function inspectResults(specialInspectionString, source, status, ...)
--d("tb: inspectResults")
--TBUG._status = status
--TBUG._evalData = {...}
    local isMOC = specialInspectionString and specialInspectionString == "MOC" or false
    if not status then
        local err = tostring(...)
        err = err:gsub("(stack traceback)", "|cff3333%1", 1)
        err = err:gsub("%S+/(%S+%.lua:)", "|cff3333> |c999999%1")
        df("%s", err)
        return
    end
    local firstInspectorShow = false
    local firstInspector = tbug.firstInspector
    local globalInspector = nil
    local nres = select("#", ...)
    local numTabs = 0
    local errorOccured = false
    if firstInspector and firstInspector.tabs then
        numTabs = #firstInspector.tabs
--d(">>firstInspector found with numTabs: " ..tostring(numTabs))
    end
    --Increase the number of tabs by 1 to show the correct number at the tab title and do some checks
    --The actual number of tabs increases in #firstInspector.tabs after (further down below) a new tab was created
    --via local newTab = firstInspector:openTabFor(...)
    numTabs = numTabs + 1
    local calledRes = 0
    for ires = 1, nres do
        local res = select(ires, ...)
        calledRes = calledRes +1
        if rawequal(res, _G) then
            if not globalInspector then
--d(">>globalInspector shows _G var")
                globalInspector = tbug.getGlobalInspector()
                globalInspector:refresh()
                globalInspector.control:SetHidden(false)
                globalInspector.control:BringWindowToTop()
            end
        else
--d(">>no _G var")
            local tabTitle = ""
            if isMOC == true then
                tabTitle = titleMocTemplate
            end
            if not isMOC and specialInspectionString and specialInspectionString ~= "" then
                tabTitle = specialInspectionString
            else
                tabTitle = strformat("%d", tonumber(numTabs) or ires)
            end
            tabTitle = strformat(titleTemplate, tostring(tabTitle))
            if firstInspector then
                if type(source) ~= "string" then
                    source = tbug.getControlName(res)
                else
                    if not isMOC and not specialInspectionString and type(tonumber(tabTitle)) == "number" then
                        local objectKey = tbug.getKeyOfObject(source)
                        if objectKey and objectKey ~= "" then
                            tabTitle = objectKey
                        end
                    end
                end
                --Open existing tab in firstInspector
                local newTab = firstInspector:openTabFor(res, tabTitle, source)
                if newTab ~= nil then
--d(">>newTab!")
                    --local newTabLabelText = newTab.label:GetText()
                    --local newTabLabelTextNew = ((isMOC == true and newTabLabelText .. " " .. source) or (specialInspectionString ~= nil and newTabLabelText)) or source
--df(">newTabLabelTextNew: %s, tabTitle: %s, source: %s", tostring(newTabLabelTextNew), tostring(tabTitle), tostring(source))
                    --firstInspector.title:SetText(newTabLabelTextNew)
                    firstInspectorShow = true
                else
                    showDoesNotExistError(res, source)
                    errorOccured = true
                end
            else
--d(">Creating firstInspector")
                --Create new firstInspector
                local recycle = not IsShiftKeyDown()
                if not isMOC and not specialInspectionString and source and source ~= "" and type(source) == "string" and type(tonumber(tabTitle)) == "number" then
                    local objectKey = tbug.getKeyOfObject(source)
                    if objectKey and objectKey ~= "" then
                        tabTitle = objectKey
                    end
                end
                firstInspector = tbug.inspect(res, tabTitle, source, recycle, nil)
                firstInspectorShow = true
            end
        end
    end
    if calledRes == 0 then
        errorOccured = true
    end
    if firstInspector then
--d(">firstInspector found, numTabs: " ..tostring(numTabs) .. ", #firstInspector.tabs: " ..tostring(#firstInspector.tabs))
        if not errorOccured then
            if not firstInspectorShow and numTabs > 0 and #firstInspector.tabs > 0 then firstInspectorShow = true end
            if firstInspectorShow == true then
                firstInspector.control:SetHidden(false)
                firstInspector.control:BringWindowToTop()
            end
        end
        tbug.firstInspector = firstInspector
    end
end

function tbug.slashCommand(args)
    local supportedGlobalInspectorArgs = tbug.allowedSlashCommandsForPanels
    local supportedGlobalInspectorArgsLookup = tbug.allowedSlashCommandsForPanelsLookup
    local specialInspectTabTitles = {
        ["listtlc"] = "TLCs of GuiRoot",
    }

    args = zo_strtrim(args)
    if args ~= "" then
        local argsLower = tostring(args):lower()
        if argsLower == "mouse" or argsLower == "m" then
            tbug.slashCommandMOC()
        else
            local isSupportedGlobalInspectorArg = supportedGlobalInspectorArgs[argsLower] or false
            local supportedGlobalInspectorArg = firstToUpper(argsLower)
--d(">args: " ..tostring(args) .. ", isSupportedGlobalInspectorArg: " ..tostring(isSupportedGlobalInspectorArg) .. ", supportedGlobalInspectorArg: " ..tostring(supportedGlobalInspectorArg))
            if isSupportedGlobalInspectorArg then
                --Call/show the global inspector
                if tbugGlobalInspector and tbugGlobalInspector:IsHidden() then
                    inspectResults(nil, "_G", true, _G)
                end
                --Select the tab named in the slashcommand parameter
                local tabIndexToShow = supportedGlobalInspectorArgsLookup[supportedGlobalInspectorArg]
--d(">>tabIndexToShow: " ..tostring(tabIndexToShow))
                if tabIndexToShow then
                    tbug.inspectorSelectTabByName("globalInspector", supportedGlobalInspectorArg, tabIndexToShow, true)
                else
                    inspectResults(nil, args, evalString(args)) --evalString uses pcall and returns boolean, table(nilable)
                end
            else
                local specialInspectTabTitle
                for startStr, replaceStr in pairs(specialInspectTabTitles) do
                    if startsWith(argsLower, startStr) then
                        specialInspectTabTitle = replaceStr
                    end
                end
--d(">>>>>specialInspectTabTitle: " ..tostring(specialInspectTabTitle) .. ", args: " ..tostring(args))
                inspectResults(specialInspectTabTitle, args, evalString(args)) --evalString uses pcall and returns boolean, table(nilable)
            end
        end
    elseif tbugGlobalInspector then
        if tbugGlobalInspector:IsHidden() then
            inspectResults(nil, "_G", true, _G)
        else
            tbugGlobalInspector:SetHidden(true)
        end
    end
end

function tbug.slashCommandMOC()
--d("tbug.slashCommandMOC")
    local env = tbug.env
    local wm = env.wm
    if not wm then return end
    local mouseOverControl = wm:GetMouseOverControl()
    local mocName = (mouseOverControl ~= nil and ((mouseOverControl.GetName and mouseOverControl:GetName()) or mouseOverControl.name)) or "n/a"
--d(">mouseOverControl: " .. tostring(mocName))
    if mouseOverControl == nil then return end
    inspectResults("MOC", mouseOverControl, true, mouseOverControl)
end

function tbug.slashCommandSavedVariables()
    tbug.slashCommand("sv")
end

function tbug.slashCommandEvents()
    tbug.slashCommand("events")
end

function tbug.slashCommandScripts()
    tbug.slashCommand("scripts")
end

function tbug.slashCommandAddOns()
    tbug.slashCommand("addons")
end

function tbug.slashCommandTBUG()
    tbug.slashCommand("TBUG")
end

function tbug.slashCommandITEMLINK()
    local il = tbug.prepareItemLink(moc(), false)
    if not il or il=="" then return end
    --d(il)
    --StartChatInput("/tbiinfo "..il, CHAT_CHANNEL_SAY, nil)
    tbug.slashCommandITEMLINKINFO(il)
end

function tbug.slashCommandSCENEMANAGER()
    tbug.slashCommand("SCENE_MANAGER")
end

function tbug.dumpConstants()
    --Dump the constants to the SV table merTorchbugSavedVars_Dumps
    merTorchbugSavedVars_Dumps = merTorchbugSavedVars_Dumps or {}
    local worldName = GetWorldName()
    merTorchbugSavedVars_Dumps[worldName] = merTorchbugSavedVars_Dumps[worldName] or {}
    local APIVersion = GetAPIVersion()
    merTorchbugSavedVars_Dumps[worldName][APIVersion] = merTorchbugSavedVars_Dumps[worldName][APIVersion] or {}
    merTorchbugSavedVars_Dumps[worldName][APIVersion]["Constants"] = {}
    merTorchbugSavedVars_Dumps[worldName][APIVersion]["SI_String_Constants"] = {}
    --Save the "Constants" tab of the global inspector to the DUMP SVs
    local globalInspector = tbug.getGlobalInspector()
    if not globalInspector then return end
    local constants = globalInspector.panels.constants
    if not constants then return end
    local masterList = constants.masterList
    if not masterList then return end
    local cntConstants, cntSIConstants = 0, 0
    --No entries in the constants list yet? Create it by forcing the /tbug slash command to show the global inspector,
    --and updating all variables
    if #masterList == 0 then
        tbug.slashCommand("Constants")
    end
    for idx, dataTable in ipairs(masterList) do
        --Do not save the SI_ string constants to the same table
        local data = dataTable.data
        local key = data.key
        if key ~= nil then
            local value = data.value
            if value ~= nil then
                local tvIsNumber = (type(value) == "number") or false
                if tvIsNumber == true and string.match(key, '^SI_(.*)') ~= nil then
                    merTorchbugSavedVars_Dumps[worldName][APIVersion]["SI_String_Constants"][key] = value
                    cntSIConstants = cntSIConstants + 1
                else
                    merTorchbugSavedVars_Dumps[worldName][APIVersion]["Constants"][key] = value
                    cntConstants = cntConstants + 1
                end
            end
        end
    end
    d(string.format("[merTorchbug]Dumped %s constants, and %s SI_ string constants to the SavedVariables!\nPlease reload the UI to save the data to the disk!", tostring(cntConstants), tostring(cntSIConstants)))
end

function tbug.slashCommandITEMLINKINFO(args)
    if not args or args=="" then return end
    args = zo_strtrim(args)
    if args ~= "" then
        local il = args
        d(">>>~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~>>>")
        d("[tBug]Itemlink Info: " .. il .. ", id: " ..tostring(GetItemLinkItemId(il)))
        local itemType, specItemType = GetItemLinkItemType(il)
        d(string.format("-itemType: %s, specializedItemtype: %s", tostring(itemType), tostring(specItemType)))
        d(string.format("-armorType: %s, weaponType: %s, equipType: %s", tostring(GetItemLinkArmorType(il)), tostring(GetItemLinkWeaponType(il)), tostring(GetItemLinkEquipType(il))))
        d("<<<~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~<<<")
    end
end


--Chat text's entry return key was pressed
local function tbugChatTextEntry_Execute(control)
    --Update the script history if the text entry is not empty
    local chatTextEntry = CHAT_SYSTEM.textEntry
    if not chatTextEntry then return end
    local chatTextEntryText = chatTextEntry.editControl:GetText()
    if not chatTextEntryText or chatTextEntryText == "" then return end
    --Check if the chat text begins with "/script"
    local startingChatText = string.lower(string.sub(chatTextEntryText, 1, 7))
    if not startingChatText or startingChatText == "" then return end
    if startingChatText == "/script" then
        --Add the script to the script history (if not already in)
        tbug.addScriptHistory(string.sub(chatTextEntryText, 9))
    end
end

--Add a script to the script history
function tbug.addScriptHistory(scriptToAdd)
    if scriptToAdd == nil or scriptToAdd == "" then return end
    --Check if script is not already in
    if tbug.savedVars and tbug.savedVars.scriptHistory then
        local scriptHistory = tbug.savedVars.scriptHistory
        --Check value of scriptHistory table
        local alreadyInScriptHistory = checkIfAlreadyInTable(scriptHistory, nil, scriptToAdd, false)
        if alreadyInScriptHistory == true then return end
        table.insert(tbug.savedVars.scriptHistory, scriptToAdd)
        --is the scripts panel currently shown? Then update it
        if tbug.checkIfInspectorPanelIsShown("globalInspector", "scriptHistory") then
            tbug.refreshInspectorPanel("globalInspector", "scriptHistory")
        end
    end
end

--Add a script comment to the script history
function tbug.changeScriptHistory(scriptRowId, editBox, scriptOrCommentText, doNotRefresh)
--d("[tbug]changeScriptHistory")
    doNotRefresh = doNotRefresh or false
    if scriptRowId == nil or scriptOrCommentText == nil then return end
    if not editBox or not editBox.updatedColumnIndex then return end
    if not tbug.savedVars then return end

    local updatedColumnIndex = editBox.updatedColumnIndex
    if scriptOrCommentText == "" then scriptOrCommentText = nil end

    --Update the script
    if updatedColumnIndex == 1 then
        if tbug.savedVars.scriptHistory then
            if not scriptOrCommentText then
                --Remove the script? Then remove the script comment as well!
                table.remove(tbug.savedVars.scriptHistory, scriptRowId)
                table.remove(tbug.savedVars.scriptHistoryComments, scriptRowId)
            else
                tbug.savedVars.scriptHistory[scriptRowId] = scriptOrCommentText
            end
        end

    --Update the script comment
    elseif updatedColumnIndex == 2 then
        if tbug.savedVars.scriptHistoryComments then
            if scriptOrCommentText == "" then scriptOrCommentText = nil end
            if not scriptOrCommentText then
                --Only remove the script comment
                table.remove(tbug.savedVars.scriptHistoryComments, scriptRowId)
            else
                tbug.savedVars.scriptHistoryComments[scriptRowId] = scriptOrCommentText
            end
        end
    end
    --is the scripts panel currently shown? Then update it
    if not doNotRefresh then
        if tbug.checkIfInspectorPanelIsShown("globalInspector", "scriptHistory") then
            tbug.refreshInspectorPanel("globalInspector", "scriptHistory")
            --Todo: Again the problem with non-updated table columns that's why the refresh is done twice for the non-direct SavedVariables update
            --column
            if updatedColumnIndex == 1 then
                tbug.refreshInspectorPanel("globalInspector", "scriptHistory")
            end
        end
    end
end

--Get a script comment from the script history
function tbug.getScriptHistoryComment(scriptRowId)
    if scriptRowId == nil then return end
    --Check if script is not already in
    if tbug.savedVars and tbug.savedVars.scriptHistoryComments then
        return tbug.savedVars.scriptHistoryComments[scriptRowId]
    end
    return
end

function tbug.UpdateAddOns()
    if addOns == nil or #addOns <= 0 then return end
    --Read each addon from the EVENT_ADD_ON_LOADED event: Read the addonData
    --and add infos from the AddOnManager
    for loadOrderIndex, addonData in ipairs(addOns) do
        local name = addonData.__name
        tbug.AddOnsOutput[loadOrderIndex] = {}
        local addonDataForOutput = {
            _directory = addonData.dir,
            _loadOrderIndex = loadOrderIndex,
            name = name,
            version = addonData.version,
            author = addonData.author,
            title = addonData.title,
            description = addonData.description,
            isOutOfDate = addonData.isOutOfDate,
            loadDateTime = addonData._loadDateTime,
            loadFrameTime = addonData._loadFrameTime,
            loadGameTime = addonData._loadGameTime,
            loadedAtGameTimeMS = addonData.loadedAtGameTimeMS,
            loadedAtFrameTimeMS = addonData.loadedAtFrameTimeMS,
        }
        if addonData.isLibrary then
            addonDataForOutput.isLibrary = addonData.isLibrary
            addonDataForOutput.LibraryGlobalVar = tbug.LibrariesOutput[name]
        end
        tbug.AddOnsOutput[loadOrderIndex] = addonDataForOutput
    end
end

function tbug.UpdateAddOnsAndLibraries()
    tbug.AddOnsOutput = {}
    tbug.LibrariesData = {}
    --Non LibStub libraries here
    --Example
    --[[
        tbug.LibrariesData["LibSets"] = {
            name = "LibSets",
            version = "15",
            globalVarName = "LibSets",
            globalVar = { global table LibSets },
        }
    ]]

    --Table of library names (key) to _G variable (value)
    local specialLibraryGlobalVarNames = {
        ["CustomCompassPins"]           = "COMPASS_PINS",
        ["libCommonInventoryFilters"]   = "LibCIF",
        ["LibBinaryEncode"]             = "LBE",
        ["LibNotification"]             = "LibNotifications",
        ["LibScootworksFunctions"]      = "LIB_SCOOTWORKS_FUNCTIONS",
        ["NodeDetection"]               = "LibNodeDetection",
        ["LibGPS"]                      = "LibGPS2",
    }

    local addonsLoaded = {}
    --Build local table of loaded addons
    for loadIndex, addonData in ipairs(addOns) do
        addonsLoaded[addonData.__name] = true
    end
    tbug.addOnsLoaded = addonsLoaded

    --Get the addon manager and scan it for IsLibrary tagged libs
    ADDON_MANAGER = GetAddOnManager()
    if ADDON_MANAGER then
        local libs = {}
        local numAddOns = ADDON_MANAGER:GetNumAddOns()
        for i = 1, numAddOns do
            local name, title, author, description, enabled, state, isOutOfDate, isLibrary = ADDON_MANAGER:GetAddOnInfo(i)
            local addonVersion = ADDON_MANAGER:GetAddOnVersion(i)
            local addonDirectory = ADDON_MANAGER:GetAddOnRootDirectoryPath(i)
            if enabled == true and state == ADDON_STATE_ENABLED then
                if isLibrary == true then
                    local libData = {
                        name = name,
                        version = addonVersion,
                        dir = addonDirectory,
                    }
                    table.insert(libs, libData)
                end
                --Is the currently looped addon loaded (no matter if library or real AddOn)?
                local addonIsLoaded = addonsLoaded[name] == true or false
                if addonIsLoaded == true then
                    --Add the addonManager data of the addon to the table addOns
                    local addonIndexInTbugAddOns
                    for idx, addonData in ipairs(addOns) do
                        if addonData.__name == name then
                            addonIndexInTbugAddOns = idx
                            break
                        end
                    end
                    if addonIndexInTbugAddOns ~= nil then
                        local addonDataOfTbugAddOns = addOns[addonIndexInTbugAddOns]
                        addonDataOfTbugAddOns.author = author
                        addonDataOfTbugAddOns.title = title
                        addonDataOfTbugAddOns.description = description
                        addonDataOfTbugAddOns.isOutOfDate = isOutOfDate
                        addonDataOfTbugAddOns.version = addonVersion
                        addonDataOfTbugAddOns.dir = addonDirectory
                        addonDataOfTbugAddOns.isLibrary = isLibrary
                    end
                end
            end
        end
        --Update library data for output in tbug "Libs" globalInspector tab
        if libs and #libs > 0 then
            table.sort(libs, compareBySubTablesKeyName)
            --Check if a global variable exists with the same name as the librarie's name
            for _, addonData in ipairs(libs) do
                local addonName = addonData.name
                --Does the name contain a - (like in LibAddonMenu-2.0)?
                --Then split the string there and convert the 2.0 to an integer number
                local checkNameTable = {}
                if specialLibraryGlobalVarNames[addonName] ~= nil then
                    table.insert(checkNameTable, specialLibraryGlobalVarNames[addonName])
                else
                    table.insert(checkNameTable, addonName)
                    local firstCharUpperCaseName = firstToUpper(addonName)
                    if addonName ~= firstCharUpperCaseName then
                        table.insert(checkNameTable, firstCharUpperCaseName)
                    end
                    local nameStr, versionNumber = zo_strsplit("-", addonName)
                    if versionNumber and versionNumber ~= "" then
                        versionNumber = tonumber(versionNumber)
                        local nameStrWithVersion = nameStr .. tostring(versionNumber)
                        table.insert(checkNameTable, nameStrWithVersion)
                        local firstCharUpperCaseNameWithVersion = firstToUpper(nameStrWithVersion)
                        if nameStrWithVersion ~= firstCharUpperCaseNameWithVersion then
                            table.insert(checkNameTable, firstCharUpperCaseNameWithVersion)
                        end
                        if nameStr ~= addonName then
                            table.insert(checkNameTable, nameStr)
                        end
                    end
                end
                local libWasAdded = false
                for _, nameToCheckInGlobal in ipairs(checkNameTable) do
                    if _G[nameToCheckInGlobal] ~= nil then
                        --d(">>>global was found!")
                        tbug.LibrariesData[addonName] = {
                            name = addonName,
                            version = addonData.version,
                            dir = addonData.dir,
                            globalVarName = nameToCheckInGlobal,
                            globalVar = _G[nameToCheckInGlobal],
                        }
                        _G[nameToCheckInGlobal]._directory = addonData.dir
                        libWasAdded = true
                        break -- exit the loop
                    end
                end
                if libWasAdded == false then
                    tbug.LibrariesData[addonName] = {
                        name = addonName,
                        version = addonData.version,
                        dir = addonData.dir,
                        globalVarName = addonData.dir,
                        globalVar = addonData.dir,
                    }
                    libWasAdded = true
                end
            end
        end
    end
end

function tbug.refreshAddOnsAndLibraries()
--d(">refreshLibraries")
    --Update and refresh the libraries list
    tbug.UpdateAddOnsAndLibraries()

    tbug.LibrariesOutput = {}
    if LibStub then
        local lsLibs = LibStub.libs
        if lsLibs then
            for k,v in pairs(lsLibs) do
                tbug.LibrariesOutput[k]=v
            end
        end
    end
    if tbug.LibrariesData then
        for k,v in pairs(tbug.LibrariesData) do
            tbug.LibrariesOutput[k]=v.globalVar
        end
    end

    --Update the addonData now for the table output on tbug globalInspector tab "AddOns"
    tbug.UpdateAddOns()
end

function tbug.refreshScripts()
--d(">refreshScripts")
    --Refresh the scripts history list
    tbug.ScriptsData = {}
    local svScriptsHist = tbug.savedVars.scriptHistory
    if svScriptsHist then
        tbug.ScriptsData = ZO_ShallowTableCopy(svScriptsHist)
    end
end

function tbug.refreshSavedVariablesTable()
    --Code taken from addon zgoo. All rights and thanks to the authors!
    tbug.SavedVariablesOutput = {}
    local svFound = tbug.SavedVariablesOutput
    local svSuffix = tbug.svSuffix
    local specialAddonSVTableNames = tbug.svSpecialTableNames
    local servers = tbug.servers
    local patternVersion = "^version$"
    local patternNumber = "number"


    local function hasMember(tab, keyPattern, valueType, maxDepth)
        if type(tab) == "table" and maxDepth > 0 then
            for k, v in zo_insecureNext, tab do
                if type(v) == valueType and type(k) == "string" and strfind(k, keyPattern) then
                    return true
                elseif hasMember(v, keyPattern, valueType, maxDepth - 1) then
                    return true
                end
            end
        end
        return false
    end

    --First check the addons found for possible "similar" global SV tables
    if tbug.addOnsLoaded ~= nil then
        for addonName, _ in pairs(tbug.addOnsLoaded) do
            local addonsSVTabFound = false
            for _, suffix in ipairs(svSuffix) do
                if addonsSVTabFound == false then
                    local addSVTable = 0
                    local possibeSVName = tostring(addonName  .. suffix)
                    local possibeSVNameLower
                    local possibeSVNameUpper
                    local possibleSVTable = _G[possibeSVName]
                    if possibleSVTable ~= nil and type(possibleSVTable) == "table" then
                        addSVTable = 1
                    else
                        possibeSVNameLower = tostring(addonName  .. suffix:lower())
                        possibleSVTable = _G[possibeSVNameLower]
                        if possibleSVTable ~= nil and type(possibleSVTable) == "table" then
                            addSVTable = 2
                        else
                            possibeSVNameUpper = tostring(addonName  .. suffix:upper())
                            possibleSVTable = _G[possibeSVNameUpper]
                            if possibleSVTable ~= nil and type(possibleSVTable) == "table" then
                                addSVTable = 3
                            else

                            end
                        end
                    end
                    if addSVTable > 0 and possibleSVTable ~= nil then
                        addonsSVTabFound = true
                        if addSVTable == 1 and possibeSVName ~= nil then
                            svFound[possibeSVName] = rawget(_G, possibeSVName)
                        elseif addSVTable == 2 and possibeSVNameLower ~= nil then
                            svFound[possibeSVNameLower] = rawget(_G, possibeSVNameLower)
                        elseif addSVTable == 3 and possibeSVNameUpper ~= nil then
                            svFound[possibeSVNameUpper] = rawget(_G, possibeSVNameUpper)
                        end
                    end
                end
            end
        end
    end

    --Then check all other global tables for the "Default"/"EU/NA Megaserver/PTS" subtable with a value "version = <number>"
    for k, v in zo_insecureNext, _G do
        if svFound[k] == nil and type(v) == "table" then
            --"Default" entry
            if hasMember(rawget(v, "Default"), patternVersion, patternNumber, 4) then
                svFound[k] = v
            else
                --EU/NA Megaserveror PTS
                for _, serverName in ipairs(servers) do
                    if hasMember(rawget(v, serverName), patternVersion, patternNumber, 4) then
                        svFound[k] = v
                    end
                end
            end
        end
    end

    --Special tables not found before (not using ZO_SavedVariables wrapper e.g.)
    for _, k in ipairs(specialAddonSVTableNames) do
        svFound[k] = rawget(_G, k)
    end

    return svFound
end

local function onPlayerActivated(event, init)
    --Update libs and AddOns
    tbug.refreshAddOnsAndLibraries()
    --Find and update global SavedVariable tables
    tbug.refreshSavedVariablesTable()
end

local function slashCommands()
    --Add slash commands to the chat
    SLASH_COMMANDS["/tbug"]     = tbug.slashCommand
    if SLASH_COMMANDS["/tb"] == nil then
        SLASH_COMMANDS["/tb"]   = tbug.slashCommand
    end
    SLASH_COMMANDS["/tbugt"]    = tbug.slashCommandTBUG
    if SLASH_COMMANDS["/tbt"] == nil then
        SLASH_COMMANDS["/tbt"]   = tbug.slashCommandTBUG
    end
    if SLASH_COMMANDS["/tbm"] == nil then
        SLASH_COMMANDS["/tbm"]   = tbug.slashCommandMOC
    end
    SLASH_COMMANDS["/tbugm"]    = tbug.slashCommandMOC

    if SLASH_COMMANDS["/tbs"]  == nil then
        SLASH_COMMANDS["/tbs"]  = tbug.slashCommandScripts
    end
    SLASH_COMMANDS["/tbugs"]    = tbug.slashCommandScripts

    if SLASH_COMMANDS["/tbe"]  == nil then
        SLASH_COMMANDS["/tbe"]  = tbug.slashCommandEvents
    end
    SLASH_COMMANDS["/tbevents"] = tbug.slashCommandEvents
    SLASH_COMMANDS["/tbuge"]    = tbug.slashCommandEvents

    if SLASH_COMMANDS["/tbsv"]  == nil then
        SLASH_COMMANDS["/tbsv"]  = tbug.slashCommandSavedVariables
    end
    SLASH_COMMANDS["/tbugsv"]    = tbug.slashCommandSavedVariables

    if SLASH_COMMANDS["/tba"] == nil then
        SLASH_COMMANDS["/tba"]   = tbug.slashCommandAddOns
    end
    SLASH_COMMANDS["/tbuga"]    = tbug.slashCommandAddOns

    if SLASH_COMMANDS["/tbi"] == nil then
        SLASH_COMMANDS["/tbi"]   = tbug.slashCommandITEMLINK
    end
    SLASH_COMMANDS["/tbugi"]    = tbug.slashCommandITEMLINK
    SLASH_COMMANDS["/tbugitemlink"]    = tbug.slashCommandITEMLINK

    SLASH_COMMANDS["/tbiinfo"]   = tbug.slashCommandITEMLINKINFO

    SLASH_COMMANDS["/tbsc"]   = tbug.slashCommandSCENEMANAGER
    SLASH_COMMANDS["/tbugsc"] = tbug.slashCommandSCENEMANAGER

    SLASH_COMMANDS["/tbugdumpconstants"] = tbug.dumpConstants


    --Compatibilty with ZGOO (if not activated)
    if SLASH_COMMANDS["/zgoo"] == nil then
        SLASH_COMMANDS["/zgoo"] = tbug.slashCommand
    end
    if SLASH_COMMANDS["/rl"] == nil then
        SLASH_COMMANDS["/rl"] = function() ReloadUI("ingame") end
    end
end

local function loadKeybindings()
    -- Register Keybindings
    ZO_CreateStringId("SI_BINDING_NAME_TBUG_TOGGLE",    "Toggle UI (/tbug)")
    ZO_CreateStringId("SI_BINDING_NAME_TBUG_MOUSE",     "Control below mouse (/tbugm)")
    ZO_CreateStringId("SI_BINDING_NAME_TBUG_RELOADUI",  "Reload the UI")
end

local function onAddOnLoaded(event, addOnName)
    --Add all loaded AddOns and libraries to the global "TBUG.AddOns" table of merTorchbug
    local loadTimeMs = GetGameTimeMilliseconds()
    local loadTimeFrameMs = GetFrameTimeMilliseconds()
    local loadTimeMsSinceMerTorchbugStart = sessionStartTime + loadTimeMs
    local loadTimeFrameMsSinceSessionStart = sessionStartTime + loadTimeFrameMs
    local currentlyLoadedAddOnTab = {
        __name              = addOnName,
        _loadDateTime       = tbug.formatTime(loadTimeMsSinceMerTorchbugStart),
        _loadFrameTime      = loadTimeFrameMsSinceSessionStart,
        _loadGameTime       = loadTimeMsSinceMerTorchbugStart,
        loadedAtGameTimeMS  = loadTimeMs,
        loadedAtFrameTimeMS = loadTimeFrameMs,
    }
    table.insert(addOns, currentlyLoadedAddOnTab)

    if addOnName ~= myNAME then return end

    tbug.initSavedVars()

    local env =
    {
        gg = _G,
        am = ANIMATION_MANAGER,
        cm = CALLBACK_MANAGER,
        em = EVENT_MANAGER,
        sm = SCENE_MANAGER,
        wm = WINDOW_MANAGER,
        tbug = tbug,
        conf = tbug.savedVars,
    }

    env.env = setmetatable(env, {__index = _G})
    tbug.env = env

    --Load the slash commands
    slashCommands()

    --Load keybindings
    loadKeybindings()

    --PreHook the chat#s return key pressed function in order to check for run /script commands
    --and add them to the script history
    ZO_PreHook("ZO_ChatTextEntry_Execute", tbugChatTextEntry_Execute)

    --Add a global OnMouseDown handler so we can track mouse button left + right + shift key for the "inspection start"
    local mouseUpBefore = {}
    local function onGlobalMouseUp(eventId, button, ctrl, alt, shift, command)
        --d(string.format("[merTorchbug]onGlobalMouseUp-button %s, ctrl %s, alt %s, shift %s, command %s", tostring(button), tostring(ctrl), tostring(alt), tostring(shift), tostring(command)))
        if not shift == true then return end
        local goOn = false
        if button == MOUSE_BUTTON_INDEX_LEFT_AND_RIGHT then
            goOn = true
            mouseUpBefore = {}
        else
            --The companion scenes do not send any MOUSE_BUTTON_INDEX_LEFT_AND_RIGHT :-( We need to try to detect it by other means
            --Get the active scene
            local activeSceneIsCompanion = (env.sm.currentScene == COMPANION_CHARACTER_KEYBOARD_SCENE) or false
            if activeSceneIsCompanion == true then
                local controlbelowMouse = moc()
                if controlbelowMouse ~= nil then
                    local currentTimestamp = GetTimeStamp()
                    mouseUpBefore[controlbelowMouse] = mouseUpBefore[controlbelowMouse] or  {}
                    if mouseUpBefore[controlbelowMouse][MOUSE_BUTTON_INDEX_LEFT] ~= nil then
                        if currentTimestamp - mouseUpBefore[controlbelowMouse][MOUSE_BUTTON_INDEX_LEFT] <= 1000 then
                            if button == MOUSE_BUTTON_INDEX_RIGHT then
                                goOn = true
                            end
                        end
                    elseif mouseUpBefore[controlbelowMouse][MOUSE_BUTTON_INDEX_RIGHT] ~= nil then
                        if currentTimestamp - mouseUpBefore[controlbelowMouse][MOUSE_BUTTON_INDEX_RIGHT] <= 1000 then
                            if button == MOUSE_BUTTON_INDEX_LEFT then
                                goOn = true
                            end
                        end
                    end
                    if goOn == false then
                        mouseUpBefore[controlbelowMouse][button] = currentTimestamp
                    end
                end
            end
        end
        if not goOn then return end
        mouseUpBefore = {}
        --If we are currenty in combat do not execute this!
        if IsUnitInCombat("player") then return end
        tbug.slashCommandMOC()
    end
    EVENT_MANAGER:RegisterForEvent(myNAME.."_OnGlobalMouseUp", EVENT_GLOBAL_MOUSE_UP, onGlobalMouseUp)

    EVENT_MANAGER:RegisterForEvent(myNAME.."_AddOnActivated", EVENT_PLAYER_ACTIVATED, onPlayerActivated)
end


EVENT_MANAGER:RegisterForEvent(myNAME .."_AddOnLoaded", EVENT_ADD_ON_LOADED, onAddOnLoaded)
