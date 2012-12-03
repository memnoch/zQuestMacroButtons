--------------------------------------------------------------------------------
-- Author: Dustin Z.                                      zQuestMacroButtons.lua
-- Name: zQuestMacroButtons
-- Abstract: 
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 
--------------------------------------------------------------------------------
local zQuestMacroButtons = LibStub("AceAddon-3.0"):NewAddon("zQuestMacroButtons", "AceEvent-3.0", "AceConsole-3.0","AceTimer-3.0")

-- Localization
local L = LibStub("AceLocale-3.0"):GetLocale("zQuestMacroButtons")

-- Defines the name of our mod
local mod = zQuestMacroButtons

local auto_options = {
	type = "group",
	desc = "Automations",
	args = {
		AutoRepair = {
			name = "Auto-repair",
			type = "select",
			desc = "Repair all Equipment and Inventory automatically.",
			values = {"Disabled", "Own Money", "Guild Money"},
			get = function() return db.AutoRepair end,
			set = function(i, value)
				db.AutoRepair = value
				if db.AutoRepair < 2 then
					if db.AutoSellJunk then
						return
					else
						mod:UnregisterEvent("MERCHANT_SHOW")
						mod.Merchant_Show = false
					end
				else
					mod:RegisterEvent("MERCHANT_SHOW")
					mod.Merchant_Show = true 
				end
			end
		},
        AutoSellJunk = {
			name = "Auto-Sell grey Items",
			type = "toggle",
			desc = "Sell Grey (junk) Items in your Bags automatically.",
			get = function() return db.AutoSellJunk end,
			set = function(i, switch)
				db.AutoSellJunk = switch
				if switch then
					mod:RegisterEvent("MERCHANT_SHOW")
					mod.Merchant_Show = true 
				else
					if db.AutoSellJunk or db.AutoRepair then return end
					mod:UnregisterEvent("MERCHANT_SHOW")
					mod.Merchant_Show = false
				end
			end
		}
	}
}



local chat_options = {
	type = "group",
	desc = "Chat",
	args = {
		ChatFade = {
			name = "Disable Chat Fading",
			type = "toggle",
			desc = "Disable Chat Frames Fading Chat after Inactivity.",
			get = function() return db.ChatFade end,
			set = function(i, switch)
				db.ChatFade = switch
                mod:ChatFadeToggle()
			end
		},
		PartyFrames = {
			name = "Disable Blizzard Party Frames",
			type = "toggle",
			desc = "Disable Blizzard Party Frames.",
			get = function() return db.PartyFrames end,
			set = function(i, switch)
				db.PartyFrames = switch
                mod:PartyFrames()
			end
		},
		RaidFrames = {
			name = "Disable Blizzard Raid Frames",
			type = "toggle",
			desc = "Disable Blizzard Raid Frames.",
			get = function() return db.RaidFrames end,
			set = function(i, switch)
				db.RaidFrames = switch
                mod:RaidFrames()
			end
		}
    }
}



local ui_options = {
	type = "group",
	desc = "Interface",
	args = {	
		Gryphons = {
			name = "Disable Gryphons",
			type = "toggle",
			desc = "Toggle Display of Gryphons on Main Toolbar.",
			get = function() return db.Gryphons end,
			set = function(i, switch)
				db.Gryphons = switch
                mod:GryphonsToggle()
			end
		}
    }
}



local minimap_options = {
	type = "group",
	desc = "Minimap",
	args = {
        Clock = {
            name = "Toggle Game Clock",
            type = "toggle",
            desc = "Toggle Game Clock below the minimap.",
            get = function() return db.Clock end,
			set = function(i, switch)
				db.Clock = switch
                mod:ClockToggle()
			end
        },
		Coordinates = {
			name = "Map X,Y Coords",
			type = "toggle",
			desc = "Adds Numeric X,Y Coordinates below the Minimap.",
			get = function() return db.Coordinates end,
			set = function(i, switch)
				db.Coordinates = switch
				if switch then
					mod:MapLocOn()
				else
					mod:MapLocOff()
				end
			end
		},
		Mapscroll = {
			name = "MouseWheel Zoom",
			type = "toggle",
			desc = "Enables MouseWheel zooming of the Minimap.",
			get = function() return db.Mapscroll end,
			set = function(i, switch)
				db.Mapscroll = switch
				if switch then
					mod:MapScroll()
				else
					mod:MapScroll()
				end
			end
		}
    }
}




-- Crawfish Creole questid = 26226
-- Muddy Crawfish npcid = 42548
-- Muddy Crawfish itemid = 57765

-- Even Thieves Get Hungry questid = 26235
-- Orgrimmar Thief npcid = 42594
-- Horde Infantry Rations itemid = 57879

-- The Fate Of The Fallen questid = 14107
-- Fallen Hero's Spirit npcid = 32149
-- Light-Blessed Relic itemid = 47033

-- Get Kraken questid = 14108
-- Kvaldir Deepcaller npcid = 35092
-- North Sea Kraken npcid = 34925
-- Flaming Spears itemid = 46954

-- Gormok Wants His Snobolds questid = 14090
-- Snowblind Follower npcid = 29618
-- Weighted Net itemid = 46885

-- Maintaining Discipline questid = 13422
-- Exhausted Vrykul npcid = 30146
-- Disciplining Rod itemid = 42837


--------------------------------------------------------------------------------
-- Name: Macros
-- Abstract: A table which holds our macros
--------------------------------------------------------------------------------
local Macros = {
    ["CrawfishCreole"] = {
        ["Name"] = "Crawfish Creole",
        ["QuestID"] = 26626,
        ["Icon"] = GetItemIcon(57765),
        ["Text"] = {
            [index] = "/target [nodead] Muddy Crawfish",
            [index + 1] = "\n",
            [index + 2] = "/script if UnitName("target") and not UnitIsDead("target") and not GetRaidTargetIndex("target") then SetRaidTargetIcon("target",3); end",
            [index + 3] = "\n"
            [index + 4] = "/cleartarget [dead]"
        },
        ["Body"] = table.concat(Text),
    },
    ["OrgHungryThief"] = {
        ["Name"] = "Even Thieves Get Hungry",
        ["QuestID"] = 26235,
        ["Icon"] = GetItemIcon(57879),
        ["Text"] = {
            [index] = "/target [nodead] Orgrimmar Thief",
            [index + 1] = "\n",
            [index + 2] = "/script if UnitName("target") and not UnitIsDead("target") and not GetRaidTargetIndex("target") then SetRaidTargetIcon("target",1); end",
            [index + 3] = "\n"
            [index + 4] = "/cleartarget [dead]"
        },
        ["Body"] = table.concat(Text),
    },
    ["FateOfTheFallen"] = {
        ["Name"] = "The Fate Of The Fallen",
        ["QuestID"] = 14107,
        ["Icon"] = GetItemIcon(47033),
        ["Text"] = {
            [index] = "/target Fallen Hero's Spirit",
            [index + 1] = "\n",
            [index + 2] = "/use Light-Blessed Relic",
        },
        ["Body"] = table.concat(Text),
    },
    ["GetKraken"] = {
        ["Name"] = "Get Kraken",
        ["QuestID"] = 14108,
        ["Icon"] = GetItemIcon(46954),
        ["Text"] = {
            [index] = "/target [nodead] Kvaldir Deepcaller",
            [index + 1] = "\n",
            [index + 2] = "/use [harm] Flaming Spears",
            [index + 3] = "\n",
            [index + 4] = "/target [nodead] North Sea Kraken",
            [index + 5] = "\n",
            [index + 6] = "/use [harm] Flaming Spears",
        },
        ["Body"] = table.concat(Text),
    },
    ["GormokSnobolds"] = {
        ["Name"] = "Gormok Wants His Snobolds",
        ["QuestID"] = 14090,
        ["Icon"] = GetItemIcon(46885),
        ["Text"] = {
            [index] = "/target Snowblind Follower",
            [index + 1] = "\n",
            [index + 2] = "/use [exists,nodead] Weighted Net",
        },
        ["Body"] = table.concat(Text),
    },
    ["MaintainDisc"] = {
        ["Name"] = "Maintaining Discipline",
        ["QuestID"] = 13422,
        ["Icon"] = GetItemIcon(42837),
        ["Text"] = {
            [index] = "/target [nodead] Exhausted Vrykul",
            [index + 1] = "\n",
            [index + 2] = "/use [harm,nodead] Disciplining Rod",
        },
        ["Body"] = table.concat(Text),
    },
}



--------------------------------------------------------------------------------
-- Name: defaults
-- Abstract: A table which holds our preference variables
--------------------------------------------------------------------------------
local defaults = {
    profile = {
        AutoRepair = 3,
        AutoSellJunk = true,
        ChatFade = true,
        Clock = true,
        Coordinates = true,
        Gryphons = true,
        Mapscroll = true,
        PartyFrames = true,
        RaidFrames = true,
    }
}



local function ProfileSetup()
	local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(zQuestMacroButtons.db)
	return profiles
end



--------------------------------------------------------------------------------
-- Name: zQuestMacroButtons:OnInitialize()
-- Abstract: Our would be constructor, isn't it cute?
--------------------------------------------------------------------------------
function zQuestMacroButtons:OnInitialize()
	self.Merchant_Show = true
	self.abacus = LibStub("LibAbacus-3.0")
	self.ACR = LibStub("AceConfigRegistry-3.0")
	self.ACD = LibStub("AceConfigDialog-3.0")
    
	--# Initialize DB
	self.db = LibStub("AceDB-3.0"):New("zQuestMacroButtonsDB", defaults)
	db = self.db.profile

	--# Register our options
	self.ACR:RegisterOptionsTable("zQuestMacroButtons", ProfileSetup)
	self.ACR:RegisterOptionsTable("zQuestMacroButtons Automation",auto_options)
	self.ACR:RegisterOptionsTable("zQuestMacroButtons Chat",chat_options)
    self.ACR:RegisterOptionsTable("zQuestMacroButtons Interface",ui_options)
	self.ACR:RegisterOptionsTable("zQuestMacroButtons Minimap",minimap_options)
	self.ACD:AddToBlizOptions("zQuestMacroButtons")
	self.ACD:AddToBlizOptions("zQuestMacroButtons Automation", "Automation", "zQuestMacroButtons")
	self.ACD:AddToBlizOptions("zQuestMacroButtons Chat", "Chat", "zQuestMacroButtons")
    self.ACD:AddToBlizOptions("zQuestMacroButtons Interface", "Interface", "zQuestMacroButtons")
	self.ACD:AddToBlizOptions("zQuestMacroButtons Minimap", "Minimap", "zQuestMacroButtons")
    
	SlashCmdList["zQuestMacroButtons"] = function() end
	SLASH_zQuestMacroButtons1 = "/zQuestMacroButtons"
	SLASH_zQuestMacroButtons2 = "/zqmb"
  SLASH_zQuestMacroButtons3 = "/zq"

        
	-- camera now shows up to 50yrd and not only 35yrd
	ConsoleExec("CameraDistanceMax 50")
	ConsoleExec("CameraDistanceMaxFactor 8")

	-- set max FPS to 70, and limit fps down to 30 when WoW is minimized (saves GPU/CPU)
	SetCVar("maxFPSBk","30")
    
    mod:zAddMessage("Loaded!")
end



--------------------------------------------------------------------------------
-- Name: zQuestMacroButtons:OnEnable()
-- Abstract: Our would be constructor, isn't it cute?
--------------------------------------------------------------------------------
function zQuestMacroButtons:OnEnable()
    dzMinimap = CreateFrame("Frame", nil, Minimap)
    dzMinimap:SetAllPoints(Minimap)
    dzMinimap.loc = dzMinimap:CreateFontString(nil, 'OVERLAY')
    dzMinimap.loc:SetWidth(90)
    dzMinimap.loc:SetHeight(16)
    dzMinimap.loc:SetPoint('CENTER', Minimap, 'BOTTOM', 0, -16)
    dzMinimap.loc:SetJustifyV('MIDDLE')
    dzMinimap.loc:SetJustifyH('CENTER')
    dzMinimap.loc:SetFontObject(GameFontNormal)

	for varname, val in pairs(auto_options.args) do
		if db[varname] then auto_options.args[varname].set(true, db[varname]) end
	end
	for varname, val in pairs(chat_options.args) do
		if db[varname] then chat_options.args[varname].set(true, db[varname]) end
	end
	for varname, val in pairs(ui_options.args) do
		if db[varname] then ui_options.args[varname].set(true, db[varname]) end
	end
	for varname, val in pairs(minimap_options.args) do
		if db[varname] then minimap_options.args[varname].set(true, db[varname]) end
	end
    
    -- load events
    mod:UnregisterAllEvents();
    mod:RegisterEvent("ADDON_LOADED", "dzOnEvent")
    mod:RegisterEvent("MERCHANT_SHOW")
    mod:RegisterEvent("PLAYER_ENTERING_WORLD", "dzOnEvent")
    mod:RegisterEvent("PARTY_MEMBERS_CHANGED", "dzOnEvent")
    mod:RegisterEvent("RAID_ROSTER_UPDATE", "dzOnEvent")
    
    -- send msg on enable
    mod:zAddMessage("Enabled!")
end



--------------------------------------------------------------------------------
-- Name: zQuestMacroButtons:OnDisable()
-- Abstract: Our would be de-constructor, isn't it cute?
--------------------------------------------------------------------------------
function zQuestMacroButtons:OnDisable()
--   -- Unhook, Unregister Events, Hide frames that you created.
--   -- You would probably only use an OnDisable if you want to 
--   -- build a "standby" mode, or be able to toggle modules on/off.
    -- send messag eon disable
    mod:zAddMessage("Disabled!")
end



--------------------------------------------------------------------------------
-- Name: zQuestMacroButtons:dzOnEvent()
-- Abstract: 
--------------------------------------------------------------------------------
function zQuestMacroButtons:dzOnEvent(event, ...)
	local arg1 = ...

    if (event == "PARTY_MEMBERS_CHANGED") then
        mod:PartyFrames()
    elseif (event == "RAID_ROSTER_CHANGED") then
        mod:RaidFrames()
    end
end



--------------------------------------------------------------------------------
-- Name: zQuestMacroButtons:zAddMessage(msg, r, g, b)
-- Abstract: 
--------------------------------------------------------------------------------
function zQuestMacroButtons:zmsg(msg, r, g, b)
    -- strMod = format("|cff0062ffdz|r|cff0deb11Utilities|r")
    strMod = format("|cff696969z|r|cff008B8BQuestMacroButtons|r")
    DEFAULT_CHAT_FRAME:AddMessage("" .. strMod .. ": " .. tostring(msg), r, g, b)
end



--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Name: zQuestMacroButtons:ZONE_CHANGED_NEW_AREA()
-- Abstract: 
--------------------------------------------------------------------------------
function zQuestMacroButtons:ZONE_CHANGED_NEW_AREA()
	SetMapToCurrentZone()
end



--------------------------------------------------------------------------------
-- Name: zQuestMacroButtons:GenerateMacros()
-- Abstract: 
--------------------------------------------------------------------------------
function zQuestMacroButtons:GenerateMacros()

    -- Fallen Hero's Spirit npcid = 32149
    -- Light-Blessed Relic itemid = 47033
    local index = 1
    local tMacroText[ index ] = "/target Fallen Hero's Spirit"
    local tMacroText[ index + 1 ] = "\n"
    local tMacroText[ index + 2 ] = "/use Light-Blessed Relic"
    local iMacroTexture = GetItemIcon(47033)
    local mMacroText = table.concat(tMacroText)
    local mFateoftheFallen = mod:CreateMacro("FateoftheFallen", iMacroTexture, mMacroText, nil, nil)
end


