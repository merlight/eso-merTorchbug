local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")

--Event tracking code was spyed and copied from the addon Zgoo! All credits go to the authors.
--Authors: Errc, SinusPi, merlight, Rhyono

------------------------------------------------------------------------------------------------------------------------
local tbEvents = {}
tbug.Events = tbEvents

------------------------------------------------------------------------------------------------------------------------
--The possible events of the game
tbEvents.eventList = {}
--Lookup table with key&value reversed
tbEvents.eventListLookup = {}

------------------------------------------------------------------------------------------------------------------------
--The events currently tracked/fired list
tbEvents.eventsTable = {}
tbEvents.eventsInternalTable = {}

tbEvents.IsEventTracking = false
tbEvents.AreAllEventsRegistered = false

------------------------------------------------------------------------------------------------------------------------
--Local helper pointers
local startTimeTimeStamp = TBUG.startTimeTimeStamp
local tinsert,type,wm = table.insert,type, WINDOW_MANAGER

local eventsInspectorControl
local globalInspector

------------------------------------------------------------------------------------------------------------------------
--Local helper functions
local l_globalprefixes = function(prefix)
	local strfind = string.find
	local l_safeglobalnext = function(tab,index)
		for k, v in zo_insecureNext, tab, index do
			if type(k) == "string" and strfind(k, prefix, 1, true) == 1 then
				return k, v
			end
		end
	end
	return l_safeglobalnext,_G,nil
end

local function getEventsTrackerInspectorControl()
    if eventsInspectorControl ~= nil then return eventsInspectorControl end
    --Start the event tracking by registering all events
    globalInspector = globalInspector or tbug.getGlobalInspector()
    if not globalInspector then return end
    eventsInspectorControl = globalInspector.panels and globalInspector.panels.events and globalInspector.panels.events.control
    return eventsInspectorControl
end

local function scrollScrollBarToIndex(list, index, animateInstantly)
    if not list then return end
    local onScrollCompleteCallback = function() end
    animateInstantly = animateInstantly or false
    ZO_ScrollList_ScrollDataIntoView(list, index, onScrollCompleteCallback, animateInstantly)
end

local function updateEventTrackerLines()
    --Is the events panel currently visible?
    local eventsPanel = globalInspector.panels.events
    if not eventsPanel or (eventsPanel and eventsPanel.control and eventsPanel.control:IsHidden() == true) then return end

    --Add the event to the masterlist of the outpt table
    tbug.RefreshTrackedEventsList()

    --Update the visual ZO_ScrollList
    eventsPanel:refreshData()

    --Scroll to the bottom
    local eventsListOutput = eventsPanel.list
    local numEventsInList = #eventsListOutput.data
d(">numEventsInList: " ..tostring(numEventsInList))
    if numEventsInList <= 0 then return end
    local numVisibleData = #eventsListOutput.visibleData
d(">numVisibleData: " ..tostring(numVisibleData))
    if numVisibleData <= 0 or numVisibleData <= numEventsInList then return end
    scrollScrollBarToIndex(eventsListOutput, numEventsInList, true)
end

local function throttledCall(callbackName, timer, callback, ...)
    if not callbackName or callbackName == "" or not callback then return end
    local args
    if ... ~= nil then
        args = {...}
    end
    local function Update()
        EVENT_MANAGER:UnregisterForUpdate(callbackName)
        if args then
            callback(unpack(args))
        else
            callback()
        end
    end
    EVENT_MANAGER:UnregisterForUpdate(callbackName)
    EVENT_MANAGER:RegisterForUpdate(callbackName, timer, Update)
end

------------------------------------------------------------------------------------------------------------------------


--The events tracker functions
function tbEvents.EventHandler(eventId, ...)
    if not tbEvents.IsEventTracking == true then return end

	local lookupEventName = tbEvents.eventList
    local timeStampAdded = GetTimeStamp()
    local frameTime = GetFrameTimeMilliseconds()
    local eventParametersOriginal = {...}
    local eventTab = {}
    eventTab._timeStamp  = timeStampAdded
    eventTab._frameTime  = frameTime
    eventTab._eventName  = lookupEventName[eventId] or "? UNKNOWN EVENT ?"
    for eventParamNo, eventParamValue in ipairs(eventParametersOriginal) do
        --EventId
        if eventParamNo == 1 then
            eventTab._eventId = eventParamValue
        else
            eventTab["param" .. tostring(eventParamNo)] = eventParamValue
        end
    end

	local tabPosAdded = tinsert(tbEvents.eventsInternalTable, eventTab)

	--Add the added line to the output list as well, if the list is currently visible!
    throttledCall("UpdateTBUGEventsList", 100, updateEventTrackerLines)
end

--Fill the masterlist of the events output ZO_SortFilterList with the tracked events data rows
function tbug.RefreshTrackedEventsList()
    tbEvents.eventsTable = {}
    local intEventTable = tbEvents.eventsInternalTable
    if intEventTable == nil or #intEventTable == 0 then return end

    for numEventAdded, eventDataTable in ipairs(intEventTable) do
        tbEvents.eventsTable[numEventAdded] = eventDataTable
    end
end

function tbEvents.RegisterAllEvents(inspectorControl)
    if not inspectorControl then return end
    --Event tracking is enabled?
    if not tbEvents.IsEventTracking then return end
    --No need to register all events multiple times!
    if tbEvents.AreAllEventsRegistered == true then return end

    for id, _ in pairs(tbEvents.eventList) do
        inspectorControl:RegisterForEvent(id, tbEvents.EventHandler)
    end
    tbEvents.AreAllEventsRegistered = true
end

function tbEvents.UnRegisterAllEvents(inspectorControl)
    if not inspectorControl then return end
    --Event tracking is enabled?
    if tbEvents.IsEventTracking == true then return end
    --No need to register all events multiple times!
    if not tbEvents.AreAllEventsRegistered then return end

    for id, _ in pairs(tbEvents.eventList) do
        inspectorControl:UnregisterForEvent(id)
    end
    tbEvents.AreAllEventsRegistered = false
end

function tbug.StartEventTracking()
    --Start the event tracking by registering all events
    if tbEvents.IsEventTracking == true then return end
    tbEvents.IsEventTracking = true

    local eventsInspectorControl = getEventsTrackerInspectorControl()
    if not eventsInspectorControl then
        tbEvents.IsEventTracking = false
        return
    end
    tbEvents.RegisterAllEvents(eventsInspectorControl)

    --Show the UI/activate the events tab
    tbug.slashCommandEvents()
end

function tbug.StopEventTracking()
    if not tbEvents.IsEventTracking == true then return false end
    tbEvents.IsEventTracking = false

    local eventsInspectorControl = getEventsTrackerInspectorControl()
    if not eventsInspectorControl then return end
    tbEvents.UnRegisterAllEvents(eventsInspectorControl)
end


--Add the possible events of the game (from _G table) to the eventsList
for k,v in l_globalprefixes("EVENT_") do
	if type(v)=="number"
	 and k~="EVENT_GLOBAL_MOUSE_DOWN"
	 and k~="EVENT_GLOBAL_MOUSE_UP"
	 then tbEvents.eventList[v]=k
	end
end
setmetatable(tbEvents.eventList,{__index = "-NO EVENT-"})

--Build the reversed lookup table
for k,v in pairs(tbEvents.eventList) do
    tbEvents.eventListLookup[v]=k
end