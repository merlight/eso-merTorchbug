local myNAME = "merTorchbug"
local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")
local strformat = string.format
tbug.minInspectorTitleWidth     = 100
tbug.minInspectorTitleHeight    = 24

local function showDoesNotExistError(object, winTitle, tabTitle)
    local errText = "tbug: No inspector for \'%s\' (%q)"
    local title = (winTitle ~= nil and tostring(winTitle)) or tostring(tabTitle)
    df(errText, title, tostring(object))
end

function tbug.inspect(object, tabTitle, winTitle, recycleActive, objectParent)
    local inspector = nil

    if rawequal(object, _G) then
        inspector = tbug.getGlobalInspector()
        inspector.control:SetHidden(false)
        inspector:refresh()
    elseif type(object) == "table" then
        inspector = tbug.classes.ObjectInspector:acquire(object, tabTitle, recycleActive)
        inspector.title:SetText(tbug.glookup(object) or winTitle or tostring(object))
        inspector.control:SetHidden(false)
        inspector:refresh()
    elseif tbug.isControl(object) then
        inspector = tbug.classes.ObjectInspector:acquire(object, tabTitle, recycleActive)
        local inspectorTabName = ""
        if type(winTitle) == "string" then
            inspectorTabName = winTitle
        else
            inspectorTabName = tbug.getControlName(object)
        end
        inspector.title:SetText(inspectorTabName)
        inspector.control:SetHidden(false)
        inspector:refresh()
    elseif type(object) == "function" then
        local wasRunWithoutErrors, resultsOfFunc = pcall(setfenv(object, tbug.env))
        local title = (winTitle ~= nil and tostring(winTitle)) or tostring(tabTitle) or "HELLO"
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


local function inspectResults(isMOC, source, status, ...)
    if not status then
        local err = tostring(...)
        err = err:gsub("(stack traceback)", "|cff3333%1", 1)
        err = err:gsub("%S+/(%S+%.lua:)", "|cff3333> |c999999%1")
        df("%s", err)
        return
    end
    local firstInspector = tbug.firstInspector
    local globalInspector = nil
    local nres = select("#", ...)
    for ires = 1, nres do
        local res = select(ires, ...)
        if rawequal(res, _G) then
            if not globalInspector then
                globalInspector = tbug.getGlobalInspector()
                globalInspector:refresh()
                globalInspector.control:SetHidden(false)
                globalInspector.control:BringWindowToTop()
            end
        else
            local tabTitle = ""
            local numTabs = (firstInspector and firstInspector.tabs and #firstInspector.tabs>0 and #firstInspector.tabs) or 1
            tabTitle = strformat("%d", numTabs or ires)
            local mocPre = ""
            if isMOC then mocPre = "MOC_" end
            tabTitle = "[" .. mocPre .. tabTitle .. "]"
            if firstInspector then
                if type(source) ~= "string" then
                    source = tbug.getControlName(res)
                end
                local newTab = firstInspector:openTabFor(res, tabTitle, source)
                if newTab ~= nil then
                    firstInspector.title:SetText((isMOC == true and newTab.label:GetText() .. source) or source)
                else
                    showDoesNotExistError(res, source)
                end
            else
                local recycle = not IsShiftKeyDown()
                firstInspector = tbug.inspect(res, tabTitle, source, recycle)
            end
        end
    end
    if firstInspector then
        firstInspector.control:SetHidden(false)
        firstInspector.control:BringWindowToTop()
        tbug.firstInspector = firstInspector
    end
end


function tbug.slashCommand(args)
    local args = zo_strtrim(args)
    if args ~= "" then
        if tostring(args):lower() == "mouse" then
            tbug.slashCommandMOC()
        else
            inspectResults(false, args, evalString(args))
        end
    elseif tbugGlobalInspector:IsHidden() then
        --APIVersion 1000029 Dragonhold got a bug with insecure entries in _G table!
        if GetAPIVersion() ~= 100029 and GetWorldName() ~= "PTS" then
            inspectResults(false, "_G", true, _G)
        else
            d("tbug: Due to an error in function 'zo_insecureNext' (API 100029 Dragonhold -> PTS) the global table _G currently cannot be inspectec, or yopur client would crash!\nPlease add a variable name after /tbug command.")
        end
    else
        tbugGlobalInspector:SetHidden(true)
    end
end

function tbug.slashCommandMOC()
    local env = tbug.env
    local wm = env.wm
    if not wm then return end
    local mouseOverControl = wm:GetMouseOverControl()
    if mouseOverControl == nil then return end
    inspectResults(true, mouseOverControl, true, mouseOverControl)
end

local function onAddOnLoaded(event, addOnName)
    if addOnName ~= myNAME then return end
    EVENT_MANAGER:UnregisterForEvent(myNAME, EVENT_ADD_ON_LOADED)

    tbug.initSavedVars()

    local env =
    {
        gg = _G,
        am = ANIMATION_MANAGER,
        cm = CALLBACK_MANAGER,
        em = EVENT_MANAGER,
        wm = WINDOW_MANAGER,
        tbug = tbug,
        conf = tbug.savedVars,
    }

    env.env = setmetatable(env, {__index = _G})
    tbug.env = env

    SLASH_COMMANDS["/tbug"]     = tbug.slashCommand
    SLASH_COMMANDS["/tbugm"]    = tbug.slashCommandMOC
    --Compatibilty with ZGOO (if not activated)
    if SLASH_COMMANDS["/zgoo"] == nil then
        SLASH_COMMANDS["/zgoo"] = tbug.slashCommand
    end
    -- Register Keybindings
    ZO_CreateStringId("SI_BINDING_NAME_TBUG_TOGGLE",    "Toggle UI (/tbug)")
    ZO_CreateStringId("SI_BINDING_NAME_TBUG_MOUSE",     "Control below mouse (/tbugm)")
end


EVENT_MANAGER:RegisterForEvent(myNAME, EVENT_ADD_ON_LOADED, onAddOnLoaded)
