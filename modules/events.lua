local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")

local strformat = string.format
local tinsert,tremove,min,max,type = table.insert,table.remove,math.min,math.max,type

--Event tracking code was spyed and copied from the addon Zgoo! All credits go to the authors.
--Authors: Errc, SinusPi, merlight, Rhyono

local tbEvents = {}
tbug.Events = tbEvents

tbEvents.eventList = {}
tbEvents.eventsTable = {}

tbEvents.IsEventTracking = false



function tbEvents.EventHandler(event,...)
	local eventTab = {event,GetFrameTimeMilliseconds(),...}

	tinsert(tbEvents.eventsTable,eventTab)

	--Refresh the list of events in the inspector, if shown!
end

function tbEvents.RegisterAllEvents(inspectorControl)
	if not inspectorControl then return end
    if not tbEvents.IsEventTracking == true then return end

	for id,event in pairs(tbEvents.eventList) do
		inspectorControl:RegisterForEvent(id,tbEvents.EventHandler)
	end
end


function tbug.StartEventTracking()
    if tbEvents.IsEventTracking == true then return end

    tbEvents.eventsTable = {}

    --Start the event tracking by registering all events
    local globalInspector = tbug.getGlobalInspector()
    if not globalInspector then return end
    local eventsInspectorControl = globalInspector.panels.events.control
    tbEvents.RegisterAllEvents(eventsInspectorControl)

    --Show the UI/activate the events tab
    tbug.slashCommandEvents()


    tbEvents.IsEventTracking = true
end

function tbug.StopEventTracking()
    if not tbEvents.IsEventTracking == true then return end
    tbEvents.IsEventTracking = false
end


function tbug.refreshEvents()
--d(">refreshEvents")
    --Refresh the events list
    local wasEventTracking = tbEvents.IsEventTracking
    if wasEventTracking == true then
        tbug.StopEventTracking()
    end
    tbEvents.eventsTable = {}
    if wasEventTracking == true then
        tbug.StartEventTracking()
    end
end


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

for k,v in l_globalprefixes("EVENT_") do
	if type(v)=="number"
	 and k~="EVENT_GLOBAL_MOUSE_DOWN"
	 and k~="EVENT_GLOBAL_MOUSE_UP"
	 then tbEvents.eventList[v]=k
	end
end

setmetatable(tbEvents.eventList,{__index = "NO EVENT IN LIST!?!?"})

tbEvents.eventListR = {}
for k,v in pairs(tbEvents.eventList) do
    tbEvents.eventListR[v]=k
end