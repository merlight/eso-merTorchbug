TBUG = {}
local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")

--Version and name of the AddOn
tbug.version =  "1.55"
tbug.name =     "merTorchbug"
tbug.author =   "merlight, Baertram"

------------------------------------------------------------------------------------------------------------------------
-- TODOs, planned features and known bugs
------------------------------------------------------------------------------------------------------------------------
--
-- [Cursors]
--[[
/esoui/art/cursors/cursor_champbasic.dds
/esoui/art/cursors/cursor_champmage.dds
/esoui/art/cursors/cursor_champsubcon.dds
/esoui/art/cursors/cursor_champthief.dds
/esoui/art/cursors/cursor_champwarrior.dds
/esoui/art/cursors/cursor_default.dds
/esoui/art/cursors/cursor_erase.dds
/esoui/art/cursors/cursor_fill.dds
/esoui/art/cursors/cursor_hand.dds
/esoui/art/cursors/cursor_iconoverlay.dds
/esoui/art/cursors/cursor_nextleft.dds
/esoui/art/cursors/cursor_nextright.dds
/esoui/art/cursors/cursor_paint.dds
/esoui/art/cursors/cursor_pan.dds
/esoui/art/cursors/cursor_preview.dds
/esoui/art/cursors/cursor_resizeew.dds
/esoui/art/cursors/cursor_resizenesw.dds
/esoui/art/cursors/cursor_resizens.dds
/esoui/art/cursors/cursor_resizenwse.dds
/esoui/art/cursors/cursor_rotate.dds
/esoui/art/cursors/cursor_sample.dds
/esoui/art/cursors/cursor_setfill.dds
]]

-- [Known bugs]
-- Error on function "SetShowHiddenGearOnActivePreviewRules" (maybe also "GetShowHiddenGearFromActivePreviewRules") -> Insecure call in
--[[
Attempt to access a private function 'SetShowHiddenGearOnActivePreviewRules' from insecure code. The callstack became untrusted 10 stack frame(s) from the top.
|rstack traceback:
[C]: in function 'next'
user:/AddOns/merTorchbug/classes/tableinspector.lua:239: in function 'setupGeneric'
]]
-->Cannot reproduce. Should be catched by IsPrivateFunction() call ?!

--[[Sharlikran on right click at inspector key:
-->Right clicked on left key "InitRightclickMenu" of FuCDevUtility -> Opened by tbug -> Objects -> Search for FurCDev
user:/AddOns/merTorchbug/modules/contextmenu.lua:57: attempt to index a nil value
stack traceback:
user:/AddOns/merTorchbug/modules/contextmenu.lua:57: in function 'tbug.setChatEditTextFromContextMenu'
user:/AddOns/merTorchbug/modules/contextmenu.lua:327: in function 'OnSelect'
/EsoUI/Libraries/ZO_ContextMenus/ZO_ContextMenus.lua:451: in function 'ZO_Menu_ClickItem'
user:/AddOns/LibCustomMenu/LibCustomMenu.lua:600: in function 'MouseUp'
--> Not reproducable so far
]]

--[[2022-01-02, inspecting LibFilters3.mapping.callbacks.usingControls.false ->
Checking type on argument stringToLowercase failed in LocaleAwareToLower_lua
|rstack traceback:
[C]: in function 'LocaleAwareToLower'
user:/AddOns/merTorchbug/classes/basicinspector.lua:263: in function 'isTimeStampRow'
|caaaaaa<Locals> row = ud, data = [table:1]{value = 0}, value = 0, key = [table:2]{LibFilters3_filterType = 31} </Locals>|r
user:/AddOns/merTorchbug/classes/basicinspector.lua:311: in function 'BasicInspectorPanel:onRowMouseEnter'
|caaaaaa<Locals> self = [table:3]{_pendingUpdate = 0, _pkey = 3, _lockedForUpdates = F, filterFunc = F}, row = ud, data = [table:1], propName = [table:2], value = 0 </Locals>|r
user:/AddOns/merTorchbug/classes/basicinspector.lua:86: in function 'rowMouseEnter'
|caaaaaa<Locals> row = ud, data = [table:1] </Locals>|r
]]


-- [Planned features]
-- Add a tab with a "Run history" of inspected /tbug slash command variables/functions and their return values (only current session, not saved per SVs)


-- [Working on]

--------------------------------------- Version 1.51 - Baertram (since 2022-02-14, last worked on 2022-02-14)
---- [Added]
--Slash command /tbuglang or /tblang <2char lang> to change the language of the client


---- [Fixed]

--
------------------------------------------------------------------------------------------------------------------------

--Global inspector default and min/max width/height values
tbug.defaultInspectorWindowWidth        = 760
tbug.defaultInspectorWindowHeight       = 800

tbug.minInspectorWindowWidth            = 250
tbug.minInspectorWindowHeight           = 50

tbug.maxInspectorTexturePreviewWidth    = 400
tbug.maxInspectorTexturePreviewHeight   = 400


--The megasevers and the testserver
tbug.servers = {
    "EU Megaserver",
    "NA Megaserver",
    "PTS",
}

--Global SavedVariable table suffix to test for existance
local svSuffix = {
    "SavedVariables",
    "SavedVars",
    "SV",
    "Settings",
    "_Data",
    "_SV",
    "_SavedVariables",
    "_SavedVars",
    "_Settings",
    "_Opts",
    "_Options",
}
tbug.svSuffix = svSuffix

--SavedVariables table names that do not match the standard suffix
tbug.svSpecialTableNames = {
    "AddonProfiles_SavedVariables2",
}

--Patterns for a string.match to find supported inventory rows (for their dataEntry.data subtables), or other controls
--like the e.g. character equipment button controls
local inventoryRowPatterns = {
    "^ZO_%a+Backpack%dRow%d%d*",                                            --Inventory backpack
    "^ZO_%a+InventoryList%dRow%d%d*",                                       --Inventory backpack
    "^ZO_CharacterEquipmentSlots.+$",                                       --Character
    "^ZO_CraftBagList%dRow%d%d*",                                           --CraftBag
    "^ZO_Smithing%aRefinementPanelInventoryBackpack%dRow%d%d*",             --Smithing refinement
    "^ZO_RetraitStation_%a+RetraitPanelInventoryBackpack%dRow%d%d*",        --Retrait
    "^ZO_QuickSlotList%dRow%d%d*",                                          --Quickslot
    "^ZO_RepairWindowList%dRow%d%d*",                                       --Repair at vendor
    "^ZO_ListDialog1List%dRow%d%d*",                                        --List dialog (Repair, Recharge, Enchant, Research, ...)
    "^ZO_CompanionEquipment_Panel_.+List%dRow%d%d*",                        --Companion Inventory backpack
    "^ZO_CompanionCharacterWindow_.+_TopLevelEquipmentSlots.+$",            --Companion character
    "^ZO_UniversalDeconstructionTopLevel_%a+PanelInventoryBackpack%dRow%d%d*",--Universal deconstruction
}
tbug.inventoryRowPatterns = inventoryRowPatterns

--Special keys at the inspector list, which add special contextmenu entries
local specialEntriesAtInspectorLists = {
    ["bagId"]       = true,
    ["slotIndex"]   = true,
}
tbug.specialEntriesAtInspectorLists = specialEntriesAtInspectorLists

--Special colors for some entries in the object inspector (key)
local specialKeyToColorType = {
    ["LibStub"] = "obsolete",
    ["__invokerObject"] = "invoker",
    ["__usedInScenes"]  = "sceneName",
}
tbug.specialKeyToColorType = specialKeyToColorType

--Keys of entries in tables which normally are used for a GetString() value
local getStringKeys = {
    ["text"]        = true,
    ["defaultText"] = true,
}
tbug.getStringKeys = getStringKeys

--For the __invokerControl: Do not use :GetName() function on controls/tableswhich got these entries/Attributes
local doNotGetParentInvokerNameAttributes = {
    sceneManager = true
}
tbug.doNotGetParentInvokerNameAttributes = doNotGetParentInvokerNameAttributes

--The panel names for the global inspector tabs
--Index of the table = tab's index
--Key:  the tab's internal key value
--Name: the tab's name shown at the label to select the tab and used to find the tab via tbug.inspectorSelectTabByName
--slashCommand: The slash command / used in the chat edit box to show the tab, e.g /tbe -> show the "events" tab
--lookup:   Used to map the entered slashcommand (1st character will be turned to uppercase) to the tab's name (if they do not match by default)
-->         e.g. slash command /tbs -> uses "sv" as search string, 1st char turned to upper -> Sv, but the tab's anem is SV (both upper) -> lookup fixes this
--comboBoxFilters:  If true this tab will provide a multi select combobox filter. The entries are defined at the globalinspector.lua->function selectTab,
-->                 and the values will defined there, e.g. CT_* control types at teh controls tab
local panelNames = {
    { key="addons",         name="AddOns",          slashCommand="addons",      lookup=nil,     comboBoxFilters=nil, },
    { key="classes",        name="Classes",         slashCommand="classes",     lookup=nil,     comboBoxFilters=nil,  },
    { key="objects",        name="Objects",         slashCommand="objects",     lookup=nil,     comboBoxFilters=nil,  },
    { key="controls",       name="Controls",        slashCommand="controls",    lookup=nil,     comboBoxFilters=true,  },
    { key="fonts",          name="Fonts",           slashCommand="fonts",       lookup=nil,     comboBoxFilters=nil,  },
    { key="functions",      name="Functions",       slashCommand="functions",   lookup=nil,     comboBoxFilters=nil,  },
    { key="constants",      name="Constants",       slashCommand="constants",   lookup=nil,     comboBoxFilters=nil,  },
    { key="strings",        name="Strings",         slashCommand="strings",     lookup=nil,     comboBoxFilters=nil,  },
    { key="sounds",         name="Sounds",          slashCommand="sounds",      lookup=nil,     comboBoxFilters=nil,  },
    { key="dialogs",        name="Dialogs",         slashCommand="dialogs",     lookup=nil,     comboBoxFilters=nil,  },
    { key="scenes",         name="Scenes",          slashCommand="scenes",      lookup=nil,     comboBoxFilters=nil,  },
    { key="fragments",      name="Fragm.",          slashCommand="fragments",   lookup=nil,     comboBoxFilters=nil,  },
    { key="libs",           name="Libs",            slashCommand="libs",        lookup=nil,     comboBoxFilters=nil,  },
    { key="scriptHistory",  name="Scripts",         slashCommand="scripts",     lookup=nil,     comboBoxFilters=nil,  },
    { key="events",         name="Events",          slashCommand="events",      lookup=nil,     comboBoxFilters=nil, },
    { key="sv",             name="SV",              slashCommand="sv",          lookup = "Sv",  comboBoxFilters=nil, },
}
tbug.panelNames = panelNames
tbug.panelCount = NonContiguousCount(panelNames)
tbug.filterComboboxFilterTypesPerPanel = {} --for the filter comboBox dropdown entries, see file glokup.lua function doRefresh for the fill

--The string prefix for special /tb <specialInspectTabTitle> calls
local specialInspectTabTitles = {
    ["listtlc"] = { --Calls function ListTLC()
        tabTitle =          "TLCs of GuiRoot",
        functionToCall =    "ListTLC()",
    }
}
tbug.specialInspectTabTitles = specialInspectTabTitles

--The possible search modes at teh global inspector
local filterModes = { "str", "pat", "val", "con" }
tbug.filterModes = filterModes

--The rowTypes ->  the ZO_SortFilterScrollList DataTypes
local rt = {}
rt.GENERIC = 1
rt.FONT_OBJECT = 2
rt.LOCAL_STRING = 3
rt.SOUND_STRING = 4
rt.LIB_TABLE = 5
rt.SCRIPTHISTORY_TABLE = 6
rt.ADDONS_TABLE = 7
rt.EVENTS_TABLE = 8
rt.SAVEDVARIABLES_TABLE = 9
tbug.RT = rt

--The rowTypes that need to return another value than the key via "raw copy" context menu, and which need to use another
--dataEntry or value attribute for the string search
local rtSpecialReturnValues = {}
rtSpecialReturnValues[rt.ADDONS_TABLE] = "value.name"
rtSpecialReturnValues[rt.EVENTS_TABLE] = "value._eventName"
rtSpecialReturnValues[rt.LOCAL_STRING] = "keyText"
tbug.RTSpecialReturnValues = rtSpecialReturnValues

--The enumeration prefixes which should be skipped
tbug.nonEnumPrefixes = {
    ["ABILITY_"] = true,
    ["ACTION_"] = true,
    ["ACTIVE_"] = "_SETTING_ID$",
    ["COLLECTIBLE_"] = true,
    ["GAMEPAD_"] = true,
    ["GROUP_"] = true,
    ["INFAMY_"] = true,
    ["MAIL_"] = true,
    ["QUEST_"] = true,
    ["RAID_"] = true,
    ["STAT_"] = "^STAT_STATE_",
    ["TRADE_"] = true,
    ["TUTORIAL_"] = true,
    ["UI_"] = true,
    ["VOICE_"] = "^VOICE_CHAT_REQUEST_DELAY$",
}

--Texture string entries in the inspectors for the OnMouseEnter, see basicinspector -> BasicInspectorPanel:onRowMouseEnter
tbug.textureNamesSupported = {
    ["textureFileName"] = true,
    ["iconFile"] = true,
}

--The inspector title constants/patterns
tbug.titlePatterns = {
    normalTemplate          =  "%s",
    mouseOverTemplate       = "[MOC_%s]",
}