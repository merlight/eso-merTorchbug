TBUG = {}
local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")

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
    "^ZO_%a+Backpack%dRow%d%d*",                                          --Inventory backpack
    "^ZO_%a+InventoryList%dRow%d%d*",                                     --Inventory backpack
    "^ZO_CharacterEquipmentSlots.+$",                                     --Character
    "^ZO_CraftBagList%dRow%d%d*",                                         --CraftBag
    "^ZO_Smithing%aRefinementPanelInventoryBackpack%dRow%d%d*",           --Smithing refinement
    "^ZO_RetraitStation_%a+RetraitPanelInventoryBackpack%dRow%d%d*",      --Retrait
    "^ZO_QuickSlotList%dRow%d%d*",                                        --Quickslot
    "^ZO_RepairWindowList%dRow%d%d*",                                     --Repair at vendor
    "^ZO_ListDialog1List%dRow%d%d*",                                      --List dialog (Repair, Recharge, Enchant, Research)
    "^ZO_%a+Equipment_Panel_KeyboardList%dRow%d%d*",                      --Companion Inventory backpack
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
}
tbug.specialKeyToColorType = specialKeyToColorType

--Keys of entries in tables which normally are used for a GetString() value
local getStringKeys = {
    ["text"]        = true,
    ["defaultText"] = true,
}
tbug.getStringKeys = getStringKeys

--The panel names for the global inspector tabs
--Index of the table = tab's index
--Key:  the tab's internal key value
--Name: the tab's name shown at the label to selec the tab and used to find the tab via tbug.inspectorSelectTabByName
--slashCommand: The slash command / used in the chat edit box to show the tab, e.g /tbe -> show the "events" tab
--lookup:   Used to map the entered slashcommand (1st character will be turned to uppercase) to the tab's name (if they do not match by default)
-->         e.g. slash command /tbs -> uses "sv" as search string, 1st char turned to upper -> Sv, but the tab's anem is SV (both upper) -> lookup fixes this
local panelNames = {
    { key="addons",         name="AddOns",          slashCommand="addons" },
    { key="classes",        name="Classes",         slashCommand="classes" },
    { key="objects",        name="Objects",         slashCommand="objects" },
    { key="controls",       name="Controls",        slashCommand="controls" },
    { key="fonts",          name="Fonts",           slashCommand="fonts" },
    { key="functions",      name="Functions",       slashCommand="functions" },
    { key="constants",      name="Constants",       slashCommand="constants" },
    { key="strings",        name="Strings",         slashCommand="strings" },
    { key="sounds",         name="Sounds",          slashCommand="sounds" },
    { key="dialogs",        name="Dialogs",         slashCommand="dialogs" },
    { key="scenes",         name="Scenes",          slashCommand="scenes" },
    { key="libs",           name="Libs",            slashCommand="libs" },
    { key="scriptHistory",  name="Scripts",         slashCommand="scripts" },
    { key="events",         name="Events",          slashCommand="events" },
    { key="sv",             name="SV",              slashCommand="sv",      lookup = "Sv" },
}
tbug.panelNames = panelNames
tbug.panelCount = NonContiguousCount(panelNames)

--The possible search modes at teh global inspector
local filterModes = { "str", "pat", "val", "con"}
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
tbug.RTSpecialReturnValues = rtSpecialReturnValues

--The enumeration prefixes
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