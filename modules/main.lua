local myNAME = "merTorchbug"
local tbug = SYSTEMS:GetSystem("merTorchbug")
local strformat = string.format


function tbug.inspect(object, tabTitle, winTitle, recycleActive)
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
        inspector.title:SetText(winTitle or tbug.getControlName(object))
        inspector.control:SetHidden(false)
        inspector:refresh()
    else
        df("no inspector for %q", tostring(object))
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


local function inspectResults(source, status, ...)
    if not status then
        local err = tostring(...)
        err = err:gsub("(stack traceback)", "|cff3333%1", 1)
        err = err:gsub("%S+/(%S+%.lua:)", "|cff3333> |c999999%1")
        df("%s", err)
        return
    end
    local firstInspector = nil
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
            local tabTitle = strformat("[%d]", ires)
            if firstInspector then
                firstInspector:openTabFor(res, tabTitle)
            else
                local recycle = not IsShiftKeyDown()
                firstInspector = tbug.inspect(res, tabTitle, source, recycle)
            end
        end
    end
    if firstInspector then
        firstInspector.control:BringWindowToTop()
    end
end


function tbug.slashCommand(args)
    local args = zo_strtrim(args)
    if args ~= "" then
        inspectResults(args, evalString(args))
    elseif tbugGlobalInspector:IsHidden() then
        inspectResults("_G", true, _G)
    else
        tbugGlobalInspector:SetHidden(true)
    end
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

    SLASH_COMMANDS["/tbug"] = tbug.slashCommand
end


EVENT_MANAGER:RegisterForEvent(myNAME, EVENT_ADD_ON_LOADED, onAddOnLoaded)
