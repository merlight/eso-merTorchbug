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
local strformat = string.format
local tinsert,tremove,min,max,type = table.insert,table.remove,math.min,math.max,type

local startTimeTimeStamp = TBUG.startTimeTimeStamp

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


------------------------------------------------------------------------------------------------------------------------
--The events tracker functions
function tbEvents.EventHandler(eventId, ...)
	local lookupEventName = tbEvents.eventList
    local timeStampAdded = startTimeTimeStamp + GetFrameTimeMilliseconds()
    local eventTab = {eventId, timeStampAdded, ...}
    eventTab.timestamp  = timeStampAdded
    eventTab.eventName  = lookupEventName[eventId] or "? UNKNOWN EVENT ?"

	tinsert(tbEvents.eventsInternalTable, eventTab)

    if not tbEvents.IsEventTracking == true then return end

    --TODO
	--Add the added line to the output list as well, if the list is currently visible!
    --
end

function tbEvents.RegisterAllEvents(inspectorControl)
    if not inspectorControl then return end
    --Event tracking is enabled?
    if not tbEvents.IsEventTracking == true then return end
    --No need to register al events multiple times!
    if tbEvents.AreAllEventsRegistered == true then return end

    for id, _ in pairs(tbEvents.eventList) do
        inspectorControl:RegisterForEvent(id, tbEvents.EventHandler)
    end
    tbEvents.AreAllEventsRegistered = true
end


function tbug.StartEventTracking()
    if tbEvents.IsEventTracking == true then return end

    --Start the event tracking by registering all events
    local globalInspector = tbug.getGlobalInspector()
    if not globalInspector then return end
    local eventsInspectorControl = globalInspector.panels and globalInspector.panels.events and globalInspector.panels.events.control

    tbEvents.IsEventTracking = true

    tbEvents.RegisterAllEvents(eventsInspectorControl)

    --Show the UI/activate the events tab
    tbug.slashCommandEvents()
end

function tbug.StopEventTracking()
    if not tbEvents.IsEventTracking == true then return false end
    tbEvents.IsEventTracking = false
    return true
end

function tbug.RefreshTrackedEventsList()
    tbEvents.eventsTable = {}
    local intEventTable = tbEvents.eventsInternalTable
    if intEventTable == nil or #intEventTable == 0 then return end

    for _, eventDataTable in ipairs(intEventTable) do
        tbEvents.eventsTable[eventDataTable.timestamp] = eventDataTable
    end
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