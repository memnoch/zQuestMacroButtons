--
--	Grail
--	Written by scott@mithrandir.com
--
--	Version History
--		001	Initial version.
--		002	Converted to using a hooked function to register completed quests.
--			Made it so quests that never appear in the quest log can be marked completed assuming the quest data is up to date.
--			Condensed the debug statements.
--			Changed the architecture so extra information can be returned for failure conditions.
--			Switched ProfessionExceeds to be able to use localized names of professions.
--		003	Made it so Darkmoon Faire NPCs return the location based on where the Darkmoon Faire currently is.
--			Removed the QUEST_AUTOCOMPLETE event handling since it seems to be unneeded.
--			Added specialZones which allow mapping of GetZoneText() to things we prefer.
--			Removed the check for IsDaily() and IsWeekly() from the Status routine since they are marked as non-complete when reset happens.
--			Added IsYearly() because there are holiday quests that can be completed only once.
--			Resettable quests (daily/weekly/yearly) are now recorded specially so quests can be queried as to whether they have ever been completed using HasQuestEverBeenCompleted().
--			Added a notification system for accepting and completing quests.
--			Added API to get quests that are available during an event (holiday).
--		004	Corrected a problem where resettable quests could not be saved for initial use.
--			Augmented level checking to maximum level is checked as well.
--			Added a targetLevel parameter to filtering quests.
--			Made it so "Near" NPCs can have a specific zone associated with them which makes their return location table entry have the zone name and the word "Near".
--			Removed the need for specialZones since GetRealZoneText() does what we need.  Switched the use of GetZoneText() to GetRealZoneText().
--			ProfessionExceeds() now returns success and skill level, where skill level can be Grail.NO_SKILL if the player does not have that skill at all.
--			LocationNPC() now has more parameters to refine the locations returned.
--			LocationQuest() now makes use of LocationNPC() changes and can return the NPC name as well.
--		005	Quest titles that do not match our internal database are recorded, which helpfully gives us localizations as well.
--			Made it so repeatable quests are also recorded in the resettable quests list.
--			Did a little optimization by declaring some LUA functions local.
--			Made some quest traversal routines take an optional argument to force garbage collection, which greatly increases the time to return the desired data, but brings the footprint back down.
--			Added a routine to get the riding skill level.
--			Made it so QueryQuestsCompleted() is called at startup because the earlier assumption did not take into account that there was still another add-on that did it.
--			Made it so we call QueryQuestsCompleted() if GetQuestResetTime() indicates that quests have been reset.  LIMITATION: The check that triggers this only happens upon accepting or completing a quest.
--			Corrected a problem in ProfessionExceeds() where the comparison was incorrect.  Also made sure the skill exists before API is called.  Changed the value of Grail.NO_SKILL.
--			IsNPCAvailable() now can work with heroic NPCs in their instances.
--		006	Corrected a problem where the questResetTime variable was misspelled.
--			Made it so the SpecialQuests are cleaned out of the GrailDatabase properly.
--			Switched City of Ironforge to Ironforge to match GetRealZoneText() return value.
--			Added a table that contains the quests per zone to allow QuestsInZone() to return the cached information immediately.
--			Made it so a callback can be registered for quest abandoning.
--
--	Known Issues
--
--			The use of GetQuestResetTime() is not adequate, nor is the API good enough to provide us accurate information for weeklies (and possibly yearlies depending on when they actually reset compared to dailies).
--				The check is only made when a quest is accepted or completed, and this means the reset could happen during play and the Blizzard-provided data would be out of date until a restart or one of our
--				monitored events occurs.  This is the price one pays for not using something like OnUpdate.
--
--			Need to clean up the "NewQuests", "NewNPCs" and "BadQuestData" data when our internal database gets information that is found in it.
--			Process quests and NPCs (adding markers) for the following holidays: 'Brewfest',"Children's Week",'Darkmoon Faire','Midsummer Fire Festival',"Hallow's End"
--			Contemplate what should happen when accepting a quest that is already in the NewNPCs table.  For example, should we examine the current coordinates to see if they should be added to the table
--				because this could be another instance of the same object?  We would need to examine the currently recorded coordinates with some sort of proximity formula to determine if the new
--				coordinates should be added.  Also note that this would also be applicable to quests that already exist in the Grail.npcs table as well.
--
--	UTF-8 file
--

Grail_File_Version = 006

if nil == Grail or Grail.versionNumber < Grail_File_Version then

	local tinsert = tinsert
	local strsplit, strfind, strformat, strsub = strsplit, string.find, string.format, string.sub
	local pairs = pairs

	--	Even though it is documented that UNIT_QUEST_LOG_CHANGED is preferable to QUEST_LOG_UPDATE, in practice UNIT_QUEST_LOG_CHANGED fails
	--	to do what it is supposed to do.  In fact, processing cannot properly happen using it and not QUEST_LOG_UPDATE, even with proper
	--	priming of the data structures.  Therefore, this addon makes use of QUEST_LOG_UPDATE instead.  Actually, this has proven to be a
	--	little unreliable as well, so a hooked function is now used instead.

	--	It would be really convenient to be able not to store the localized names of the quests and the NPCs.  However, the only real way
	--	to get any arbitrary one (that is not in the quest log) is to populate the tooltip with a hyperlink.  However, that will not normally
	--	return results immediately from a server query, so another attempt at tooltip population is needed.  In the case of quests, this
	--	works pretty well.  However, with NPCs the results are less than satisfactory.  In reality, we want the information to be readily
	--	available for when someone needs it, so polling the server is not convenient.  Therefore, we will continue to store the localized
	--	names of these objects so they are available immediately to the caller.  This means the size of the add-on in memory is going to
	--	be constant and not growing overtime if we were to attempt to populate the information in the background (which we would want to do
	--	to make the information available).

	--	Instead of trying to deal with the concept of having NPCs who have unique IDs to be associated with each other but only be available
	--	in specific "phases", the availability of an NPC should probably be checked through the use of determining whether a quest can be
	--	obtained.  Normally, the prerequisite structure of the quests will indicate specific quests cannot yet be obtained, and those are
	--	likely to be associated with the NPCs that will be in new "phases".  Therefore, nothing special needs be done in this library, but
	--	the onus can be put on the user of this library to ensure only quest givers for available quests are listed/shown.

	--	Database of stored information per character.
	GrailDatabase = { }
	--	The completedQuests is a table of 32-bit integers.  The index in the table indicates which set of 32 bits are being used and the value at that index
	--	is a bit representation of completed quests in that 32 quest range.  For example, quest 7 being the only one completed in the quests from 1 to 32
	--	would mean table entry 0 would have a value of 64.  Quest 33 being done would mean [1] = 1, while quests 33 and 35 would mean [1] = 5.  The user need
	--	not know any of this since the API to access this information takes care of the dirty work.
	--	The completedResettableQuests is just like completedQuests except it records only those quests that Blizzard resets like dailies and weeklies.  This
	--	is used for API that can determine if a quest has ever been completed (since a daily could have been completed in the past, but Blizzard's API would
	--	indicate that it is currently not completed (because it has been reset)).
	--	There are four possible tables of interest:  NewNPCs, NewQuests, SpecialQuests and BadQuestData.
	--	These tables could be used to provide feedback which can be used to update the internal database to provide more accurate quest information.

	Grail = {
		versionNumber = Grail_File_Version,
		questsVersionNumber = 0,
		npcsVersionNumber = 0,
		zonesVersionNumber = 0,
		zonesIndexedVersionNumber = 0,
		NO_SKILL = -1,
		abandoningQuestIndex = nil,
		classMapping = { ['K'] = 'DEATH KNIGHT', ['D'] = 'DRUID', ['H'] = 'HUNTER', ['M'] = 'MAGE', ['P'] = 'PALADIN', ['T'] = 'PRIEST', ['R'] = 'ROGUE', ['S'] = 'SHAMAN', ['L'] = 'WARLOCK', ['W'] = 'WARRIOR', },
		completingQuest = nil,
		darkmoonFaireLocation = nil,
		debug = true,
		eventDispatch = {			-- table of functions whose keys are the events
			['PLAYER_ENTERING_WORLD'] = function(self, frame)
				frame:RegisterEvent("QUEST_ACCEPTED")
				frame:RegisterEvent("QUEST_COMPLETE")
				frame:RegisterEvent("QUEST_QUERY_COMPLETE")
				self:CleanDatabase()
				self:UpdateQuestResetTime()
			end,
			['QUEST_ACCEPTED'] = function(self, frame, questIndex)
				local questTitle, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questId = GetQuestLogTitle(questIndex)
				local npcId = nil
				local version = self.versionNumber.."/"..self.questsVersionNumber.."/"..self.npcsVersionNumber.."/"..self.zonesVersionNumber

				-- Get the target information to ensure the target exists in the database of NPCs
				local targetName, npcId, coordinates = self:TargetInformation()
				self:UpdateTargetDatabase(targetName, npcId, coordinates, version)

				--	If this quest is not in our internal database attempt to record some information about it so we have a chance the
				--	user can provide this to us to update the database.
				if not isHeader then
					self:UpdateQuestDatabase(questId, questTitle, npcId, isDaily, 'A:', version)
				end

				--	If we think we should not have been able to accept this quest we should record some information that may help us update our faulty database.
				local canAccept, reason, failures = self:Status(questId, false, false, false, false, true)
				if not canAccept and reason ~= "Nonexistent" then
					-- look at the reason and record the reason and contrary information for that reason
					if nil == GrailDatabase["BadQuestData"] then GrailDatabase["BadQuestData"] = { } end
					if nil == GrailDatabase["BadQuestData"][questId] then GrailDatabase["BadQuestData"][questId] = { } end
					if reason == "Completed" then
						tinsert(GrailDatabase["BadQuestData"][questId], version.." "..reason)
					elseif reason == "Nonexistent" then
						-- ignore this since it should be added to NewQuests above
					elseif reason == "Level" then
						tinsert(GrailDatabase["BadQuestData"][questId], version.." "..reason.." actual: "..UnitLevel('player'))
					elseif reason == "Prerequisites" then
						tinsert(GrailDatabase["BadQuestData"][questId], { version.." "..reason, failures })
					elseif reason == "Invalidated" then
						tinsert(GrailDatabase["BadQuestData"][questId], { version.." "..reason, failures })
					elseif reason == "Class" then
						tinsert(GrailDatabase["BadQuestData"][questId], version.." "..reason.." actual: "..self.playerClass)
					elseif reason == "Race" then
						tinsert(GrailDatabase["BadQuestData"][questId], version.." "..reason.." actual: "..self.playerRace)
					elseif reason == "Gender" then
						tinsert(GrailDatabase["BadQuestData"][questId], version.." "..reason.." actual: "..self.playerGender)
					elseif reason == "Faction" then
						tinsert(GrailDatabase["BadQuestData"][questId], version.." "..reason.." actual: "..self.playerFaction)
					elseif reason == "Profession" then
						tinsert(GrailDatabase["BadQuestData"][questId], { version.." "..reason, failures })
					elseif reason == "Reputation" then
						tinsert(GrailDatabase["BadQuestData"][questId], { version.." "..reason, failures })
					elseif reason == "Holiday" then
						tinsert(GrailDatabase["BadQuestData"][questId], { version.." "..reason, failures })
					end
				end

				--	If the questTitle is different from what we have recorded, note that as BadQuestData (even though it could just be a localization issue)
				if self:DoesQuestExist(questId) and questTitle ~= self.quests[questId][0] then
					tinsert(GrailDatabase["BadQuestData"][questId], { version.." Quest title mismatch: "..self.playerLocale.." "..questTitle })
				end

				self:PostNotification("Accept", questId)
				if self.debug then
					local debugMessage = "Grail Debug: Accepted quest: ".. questTitle .. " (" .. questId .. ") from "
					if nil ~= targetName then debugMessage = debugMessage .. targetName .. " (" .. npcId .. ") " .. coordinates else debugMessage = debugMessage .. "no target" end
					if not canAccept and reason ~= "Nonexistent" then debugMessage = debugMessage .. " but should not accept because of: " .. reason else debugMessage = debugMessage .. " without problems" end
					DEFAULT_CHAT_FRAME:AddMessage(debugMessage)
				end
				self:UpdateQuestResetTime()
			end,
			['QUEST_COMPLETE'] = function(self, frame)
				local titleText = GetTitleText()
				self.completingQuest = self:QuestInQuestLogMatchingTitle(titleText)
				if nil == self.completingQuest then self.completingQuest = self.specialQuests[titleText] end	-- if not in the quest log look in the special quest table
				if nil == self.completingQuest then	-- if we still do not have it, mark it in the saved variables for possible future inclusion
					if nil == GrailDatabase["SpecialQuests"] then GrailDatabase["SpecialQuests"] = { } end
					if nil == GrailDatabase["SpecialQuests"][titleText] then GrailDatabase["SpecialQuests"][titleText] = true end
				end
				self:UpdateQuestResetTime()
			end,
			['QUEST_QUERY_COMPLETE'] = function(self, frame, arg1)
				DEFAULT_CHAT_FRAME:AddMessage("Grail starting to process completed query results")
				local completedQuests = { }
				GetQuestsCompleted(completedQuests)
				if nil == GrailDatabase[self.playerRealm] then GrailDatabase[self.playerRealm] = { } end
				if nil == GrailDatabase[self.playerRealm][self.playerName] then GrailDatabase[self.playerRealm][self.playerName] = { } end
				local hour, minute = GetGameTime()
				local weekday, month, day, year = CalendarGetDate()
				GrailDatabase[self.playerRealm][self.playerName]["serverUpdated"] = strformat("%4d-%02d-%02d %02d:%02d", year, month, day, hour, minute)
				GrailDatabase[self.playerRealm][self.playerName]["completedQuests"] = { }
				for v,_ in pairs(completedQuests) do
					self:MarkQuestComplete(v)
				end
				if nil == GrailDatabase[self.playerRealm][self.playerName]["completedResettableQuests"] then GrailDatabase[self.playerRealm][self.playerName]["completedResettableQuests"] = { } end
				DEFAULT_CHAT_FRAME:AddMessage("Grail finished processing completed query results")
			end,
			['VARIABLES_LOADED'] = function(self, frame)
				--	Ensure the tooltip is not messed up
				if not com_mithrandir_grailTooltip:IsOwned(UIParent) then
					com_mithrandir_grailTooltip:SetOwner(UIParent, "ANCHOR_NONE")
				end
				frame:RegisterEvent("PLAYER_ENTERING_WORLD")
			end,
			},
		factionMapping = { ['A'] = 'Alliance', ['H'] = 'Horde', },
		genderMapping = { ['M'] = 2, ['F'] = 3, },
		holidayMapping = { ['A'] = 'Love is in the Air', ['B'] = 'Brewfest', ['C'] = "Children's Week", ['D'] = 'Day of the Dead', ['F'] = 'Darkmoon Faire', ['H'] = 'Harvest Festival', ['L'] = 'Lunar Festival', ['M'] = 'Midsummer Fire Festival', ['N'] = 'Noblegarden', ['P'] = "Pirates' Day", ['Q'] = "Ahn'Qiraj War Effort", ['U'] = 'New Year', ['V'] = 'Feast of Winter Veil', ['W'] = "Hallow's End", ['Y'] = "Pilgrim's Bounty", },
		observers = { },
		origAbandonQuestFunction,
		origConfirmAbandonQuestFunction,
		origHookFunction,
		playerClass,
		playerFaction,
		playerGender,
		playerLocale,
		playerName,
		playerRace,
		playerRealm,
		professionMapping = { ['A'] = 'Alchemy', ['B'] = 'Blacksmithing', ['C'] = 'Cooking', ['E'] = 'Enchanting', ['F'] = 'Fishing', ['H'] = 'Herbalism', ['I'] = 'Inscription', ['J'] = 'Jewelcrafting', ['L'] = 'Leatherworking', ['M'] = 'Mining', ['N'] = 'Engineering', ['P'] = 'Lockpicking', ['R'] = 'Riding', ['S'] = 'Skinning', ['T'] = 'Tailoring', ['U'] = 'Runeforging', ['X'] = 'Archaeology', ['+'] = 'First Aid', },
		questResetTime = 0,
		raceMapping = { ['H'] = 'Human', ['F'] = 'Dwarf', ['E'] = 'NightElf', ['N'] = 'Gnome', ['D'] = 'Draenei', ['W'] = 'Worgen', ['O'] = 'Orc', ['U'] = 'Scourge', ['T'] = 'Tauren', ['L'] = 'Troll', ['B'] = 'Blood Elf', ['G'] = 'Goblin', },
		reputationMapping = {
			[01] = 'Darnassus', [02] = 'Gnomeregan Exiles', [03] = 'Ironforge', [04] = 'Stormwind', [05] = 'Exodar', [06] = 'Gilneas', [07] = 'Darkspear Trolls', [08] = 'Orgrimmar',
			[09] = 'Thunder Bluff', [10] = 'Undercity', [11] = 'Silvermoon City', [12] = 'Bilgewater Cartel', [13] = 'The League of Arathor', [14] = 'Silverwing Sentinels', [15] = 'Stormpike Guard', [16] = 'The Defilers',
			[17] = 'Frostwolf Clan', [18] = 'Warsong Outriders', [19] = 'Booty Bay', [20] = 'Everlook', [21] = 'Gadgetzan', [22] = 'Ratchet', [23] = 'Cenarion Expedition', [24] = 'Honor Hold',
			[25] = 'Kurenai', [26] = "The Mag'har", [27] = "Ogri'la", [28] = 'Netherwing', [29] = 'Sporeggar', [30] = 'The Consortium', [31] = 'Thrallmar', [32] = 'Lower City',
			[33] = "Sha'tari Skyguard", [34] = 'Shattered Sun Offensive', [35] = 'The Aldor', [36] = 'The Scryers', [37] = "The Sha'tar", [38] = 'Alliance Vanguard', [39] = 'Argent Crusade', [40] = "Explorers' League",
			[41] = 'Frenzyheart Tribe', [42] = 'The Frostborn', [43] = 'The Hand of Vengeance', [44] = 'Horde Expedition', [45] = "The Kalu'ak", [46] = 'Knights of the Ebon Blade', [47] = 'The Oracles', [48] = 'The Sons of Hodir',
			[49] = 'The Taunka', [50] = 'Valiance Expedition', [51] = 'Warsong Offensive', [52] = 'The Wyrmrest Accord', [53] = 'Kirin Tor', [54] = 'The Silver Covenant', [55] = 'The Sunreavers', [56] = 'Guardians of Hyjal',
			[57] = 'The Earthen Ring', [58] = 'Therazane', [59] = 'The Ashen Verdict', [60] = 'Ashtongue Deathsworn', [61] = 'Brood of Nozdormu', [62] = 'Cenarion Circle', [63] = 'Hydraxian Waterlords', [64] = 'The Scale of the Sands',
			[65] = 'Zandalar Tribe', [66] = 'Argent Dawn', [67] = 'Bloodsail Buccaneers', [68] = 'Darkmoon Faire', [69] = 'Gelkis Clan Centaur', [70] = 'Keepers of Time', [71] = 'Magram Clan Centaur', [72] = 'Ravenholdt',
			[73] = "Shen'dralar", [74] = 'Syndicate', [75] = 'Thorium Brotherhood', [76] = 'Timbermaw Hold', [77] = 'Tranquillien', [78] = 'The Violet Eye', [79] = 'Wintersaber Trainers', [80] = 'Wildhammer Clan',
			[81] = 'Ramkahen',
			},
		specialQuests = { },

		--	this looks at the code with appropriate prefix from the specified log and analyzes it to determine if any of the quests
		--	the code contains have been completed, or if checkLog is true, are in the quest log.  The format for the code is a comma
		--	separated list of single questIds that match or if more than one is required to match, they are separated by plus.  So:
		--	123,456,789+1122,3344
		--	means any of the following quests would match:
		--		123
		--		456
		--		789 and 1122
		--		3344
		--	this returns both whether any evaluate true and whether there was an actual requirement present
		AnyEvaluateTrue = function(self, questId, codePrefix, checkLog)
			if nil == questId or not tonumber(questId) then return false end
			questId = tonumber(questId)
			local anyEvaluateTrue = false
			local requirementPresent = false
			local codeValues = self:CodesWithPrefixQuest(questId, codePrefix)
			local failures = { }
			if nil ~= codeValues then
				for x = 1, #(codeValues), 1 do
					requirementPresent = true
					local requirementArray = { strsplit(",", strsub(codeValues[x], 3)) }
					local eachRequirement
					local stillGood
					local questCompleted
					local questInLog
					local requirementQuest
					for i = 1, #(requirementArray), 1 do
						eachRequirement = { strsplit("+", requirementArray[i]) }
						stillGood = true
						local plusArray = { }
						for j = 1, #(eachRequirement), 1 do
							requirementQuest = tonumber(eachRequirement[j])
							questCompleted = self:IsQuestCompleted(requirementQuest)
							questInLog = self:IsQuestInQuestLog(requirementQuest)
							stillGood = questCompleted or (checkLog and questInLog)
							if questInLog then tinsert(plusArray, "L"..requirementQuest)
							elseif questCompleted then tinsert(plusArray, "C"..requirementQuest)
							else tinsert(plusArray, "N"..requirementQuest)
							end
						end
						if stillGood then
							anyEvaluateTrue = true
						end
						if 0 < #(plusArray) then
							tinsert(failures, table.concat(plusArray, "+"))
						end
					end
				end
			end
			if 0 == #(failures) then failures = nil end
			return anyEvaluateTrue, requirementPresent, failures
		end,

		--	Returns true if the soughtHolidayName is currently being celebrated.
		--	Has the side effect of setting the current location for Darkmoon Faire NPCs.
		CelebratingHoliday = function(self, soughtHolidayName)
			local retval = false
			local weekday, month, day, year = CalendarGetDate()
			local i = 1
			local darkmoonFaireFound = false
			while CalendarGetDayEvent(0, day, i) do
				local title, hour, minute, calendarType, sequenceType, eventType, texture, modStatus, inviteStatus, invitedBy, difficulty, inviteType = CalendarGetDayEvent(0, day, i)
				if eventType == 0 and calendarType == 'HOLIDAY' then
					if title == soughtHolidayName then
						retval = true
					end
					if title == self.holidayMapping['F'] then	-- Darkmoon Faire is special because its NPCs change locations based on where it is
						darkmoonFaireFound = true
						if nil == self.darkmoonFaireLocation then
							local _, description, _ = CalendarGetHolidayInfo(0, day, i)
							if nil ~= strfind(description, self.zones[3703]) then	-- Shattrath City
								self.darkmoonFaireLocation = 3519			-- Terokkar Forest
							elseif nil ~= strfind(description, self.zones[215]) then	-- Mulgore
								self.darkmoonFaireLocation = 215			-- Mulgore
							elseif nil ~= strfind(description, self.zones[12]) then	-- Elwynn Forest
								self.darkmoonFaireLocation = 12				-- Elwynn Forest
							end
						end
					end
				end
				i = i + 1
			end

			-- The location of the Darkmoon Faire is cleared if it is not found in the calendar, because someone
			-- running Grail over the boundary of when the Faire disappears could have wrong information otherwise.
			if not darkmoonFaireFound then
				self.darkmoonFaireLocation = nil
			end

			return retval
		end,

		CleanDatabase = function(self)
			-- Remove quests from SpecialQuests that have been marked as special in our internal database.
			if nil ~= GrailDatabase["SpecialQuests"] then
				for questName, _ in pairs(GrailDatabase["SpecialQuests"]) do
					local questId = self:QuestWithName(questName)
					if nil ~= questId and self:HasCode(questId, "SP") then
						GrailDatabase["SpecialQuests"][questName] = nil
					end
				end
			end

			-- Remove quests from NewQuests that have been added to our internal database
			if nil ~= GrailDatabase["NewQuests"] then
				for questId, q in pairs(GrailDatabase["NewQuests"]) do
					if self:DoesQuestExist(questId) then
						if q[self.playerLocale] == self.quests[questId][0] then
-- TODO: If all of the codes in q[1] are in our database we can nuke the questId from NewQuests
							
						end
					end
				end
			end

		end,

		--	this returns a table of matching codes with the matching prefix for the specified string or nil if none exists
		CodesWithPrefix = function(self, victim, soughtPrefix)
			local retval = { }
			local codeArray = { strsplit(" ", victim) }
			if nil ~= codeArray then
				for i = 1, #(codeArray), 1 do
					if 1 == strfind(codeArray[i], soughtPrefix) then
						tinsert(retval, codeArray[i])
					end
				end
			end
			-- return nil if there is nothing in the table of matching codes
			if 0 == #(retval) then
				retval = nil
			end
			return retval
		end,

		--	this returns a table of matching codes with the matching prefix for the specified NPC or nil if none exists
		CodesWithPrefixNPC = function(self, npcId, soughtPrefix)
			return self:CodesWithPrefix(self.npcs[npcId][1], soughtPrefix)
		end,

		--	this returns a table of matching codes with the matching prefix for the specified quest or nil if none exists
		CodesWithPrefixQuest = function(self, questId, soughtPrefix)
			return self:CodesWithPrefix(self.quests[questId][1], soughtPrefix)
		end,

		--	simply checks to see whether our internal quest list contains the desired questId
		DoesQuestExist = function(self, questId)
			if nil == questId or not tonumber(questId) then return false end
			questId = tonumber(questId)
			retval = false
			if self.quests[questId] ~= nil then
				retval = true
			end
			return retval
		end,

		DebugCallback = function(callbackType, questId)
			DEFAULT_CHAT_FRAME:AddMessage("Callback "..callbackType.." "..Grail.quests[questId][0])
		end,

		DebugDumpOneNPCInfo = function(self, npcId)
			if nil == npcId or not tonumber(npcId) then return end
			npcId = tonumber(npcId)
			local locations, name = self:LocationNPC(npcId)
			if nil ~= name then
				DEFAULT_CHAT_FRAME:AddMessage("NPC id " .. npcId .. " " .. name .. " => " .. self.npcs[npcId][1])
				if nil ~= locations then
					for i = 1, #(locations), 1 do
						if 1 == #(locations[i]) then
							DEFAULT_CHAT_FRAME:AddMessage(locations[i][1])
						else
							DEFAULT_CHAT_FRAME:AddMessage(locations[i][1] .. " " .. locations[i][2])
						end
					end
				else
					DEFAULT_CHAT_FRAME:AddMessage("No Locations")
				end
			else
				DEFAULT_CHAT_FRAME:AddMessage("There is no NPC with id "..npcId)
			end
		end,

		DebugDumpOneQuestInfo = function(self, questId, aOrT)
			if nil == questId or not tonumber(questId) then return end
			npcId = tonumber(questId)
			local locations, name = self:LocationQuest(questId, aOrT)
			if nil ~= name then
				DEFAULT_CHAT_FRAME:AddMessage("Quest id " .. questId .. " " .. name .. " => " .. self.quests[questId][1])
				if nil ~= locations then
					for i = 1, #(locations), 1 do
						if 1 == #(locations[i]) then
							DEFAULT_CHAT_FRAME:AddMessage(locations[i][1])
						else
							DEFAULT_CHAT_FRAME:AddMessage(locations[i][1] .. " " .. locations[i][2])
						end
					end
				else
					DEFAULT_CHAT_FRAME:AddMessage("No Locations")
				end
			else
				DEFAULT_CHAT_FRAME:AddMessage("There is no Quest with id ".. questId)
			end
		end,

		DebugDumpQuestInfo = function(self, idTable)
			if nil ~= idTable then
				local questId
				for i = 1, #(idTable), 1 do
					questId = idTable[i]
					DEFAULT_CHAT_FRAME:AddMessage(questId .. " " .. self.quests[questId][0] .. " => " .. self.quests[questId][1])
				end
			else
				DEFAULT_CHAT_FRAME:AddMessage("Grail Debug: No quests")
			end
		end,

		--	returns true if the specified quest has the exact code sought…only useful for things like daily markers and things like that
		HasCode = function(self, questId, soughtCode)
			if nil == questId or not tonumber(questId) then return false end
			questId = tonumber(questId)
			local retval = false
			local codeArray = { strsplit(" ", self.quests[questId][1]) }
			if nil ~= codeArray then
				for i = 1, #(codeArray), 1 do
					if codeArray[i] == soughtCode then
						retval = true
					end
				end
			end
			return retval
		end,

		--	Returns true if either the quest has been completed or if it is a resettable quest that has been completed.
		HasQuestEverBeenCompleted = function(self, questId)
			return self:IsQuestCompleted(questId) or self:IsResettableQuestCompleted(questId)
		end,

		--	Returns true if the player is in the same instance and one where the heroic NPC is located
		InWithHeroicNPC = function(self, npcId)
			local retval = false
			local isHeroic, instanceName = self:IsInHeroicInstance()
			if isHeroic then
				-- Note that we use GetRealZoneText() here instead of instanceName because the instanceName is very different and our data is based on GetRealZoneText()
				local locations = self:LocationNPC(npcId, false, false, true, GetRealZoneText())	-- only return things that match the current zone
				if nil ~= locations and 0 < #(locations) then
					retval = true
				end
			end
			return retval
		end,

		--	returns whether our internal quest list considers the quest a daily quest
		IsDaily = function(self, questId)
			return self:HasCode(questId, '+D')
		end,

		IsHeroicNPC = function(self, npcId)
			retval = false
			local codes = self:CodesWithPrefixNPC(npcId, 'X')
			if nil ~= codes and 0 < #(codes) then
				retval = true
			end
			return retval
		end,

		IsInHeroicInstance = function(self)
			local retval = false
			local name, type, difficultyIndex, difficultyName, maxPlayers, dynamicDifficulty, isDynamic = GetInstanceInfo()
			if "none" ~= type then
				if 3 == difficultyIndex or 4 == difficultyIndex or (2 == difficultyIndex and "raid" ~= type) then
					retval = true
				end
			end
			return retval, name
		end,

		--	the concept of invalidated means certain quests are mutually exclusive, and if one on the list is either completed or in the
		--	quest log then the queried quest is "invalidated"
		IsInvalidated = function(self, questId)
			local retval = false
			local any, present, failures = self:AnyEvaluateTrue(questId, "I:", true)
			if present then
				retval = any
			end
			return retval, failures
		end,

		IsNPCAvailable = function(self, npcId)
			if nil == npcId or not tonumber(npcId) then return false end
			npcId = tonumber(npcId)
			local retval = true
			local codes = self:CodesWithPrefixNPC(npcId, 'H')
			if nil ~= codes then
				local holidayGood = true
				for i = 1, #(codes), 1 do
					if holidayGood then
						holidayGood = self:CelebratingHoliday(self.holidayMapping[strsub(codes[i], 2, 2)])
					end
				end
				retval = holidayGood
			end
			if retval and self:IsHeroicNPC(npcId) then
				retval = self:InWithHeroicNPC(npcId)
			end
			return retval
		end,

		--	Returns true is the specified quest has been completed in the past and is one of the class of quests that Blizzard
		--	resets periodically (daily, weekly, yearly).  This does not mean that IsQuestCompleted() will return true as the
		--	quest could have been reset and therefore available. 
		IsResettableQuestCompleted = function(self, questId)
			if nil == questId or not tonumber(questId) then return false end
			questId = tonumber(questId)
			local retval = false
			local index = math.floor((questId - 1) / 32)
			local offset = questId - (index * 32) - 1
			if (nil ~= GrailDatabase[self.playerRealm][self.playerName]["completedResettableQuests"][index]) then
				if bit.band(GrailDatabase[self.playerRealm][self.playerName]["completedResettableQuests"][index], 2^offset) > 0 then
					retval = true
				end
			end
			return retval
		end,

		--	returns true if the specified quest has been completed as indicated from Blizzard's list returned in the QUEST_QUERY_COMPLETE event
		--	and our additions to that during gameplay where more quests are completed.  upon restart, Blizzard's list should be updated automatically.
		--	Note that quests may still be available if marked completed (like a Daily).
		IsQuestCompleted = function(self, questId)
			if nil == questId or not tonumber(questId) then return false end
			questId = tonumber(questId)
			local retval = false
			local index = math.floor((questId - 1) / 32)
			local offset = questId - (index * 32) - 1
			if (nil ~= GrailDatabase[self.playerRealm][self.playerName]["completedQuests"][index]) then
				if bit.band(GrailDatabase[self.playerRealm][self.playerName]["completedQuests"][index], 2^offset) > 0 then
					retval = true
				end
			end
			return retval
		end,

		-- This returns two things: (1) whether the quest is in the log, and (2) whether it is marked complete, which means it
		-- can be checked to short circuit things like turning it in.
		IsQuestInQuestLog = function(self, questId)
			if nil == questId or not tonumber(questId) then return false end
			questId = tonumber(questId)
			local retval = false
			local retvalComplete = false
			local i = 1
			while GetQuestLogTitle(i) and false == retval do
				local questTitle, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questID = GetQuestLogTitle(i)
				if (not isHeader) then
					if questID == questId then
						retval = true
						retvalComplete = isComplete
					end
				end
				i = i + 1
			end
			return retval, retvalComplete
		end,

		IsRepeatable = function(self, questId)
			return self:HasCode(questId, '++')
		end,

		IsWeekly = function(self, questId)
			return self:HasCode(questId, '+W')
		end,

		IsYearly = function(self, questId)
			return self:HasCode(questId, '+Y')
		end,

		-- This returns a table of locations for the NPC, and the localized NPC name.  See LocationQuest for more information.
		LocationNPC = function(self, npcId, requiresNPCAvailable, onlySingleReturn, onlyZoneReturn, preferredZoneName)
			if nil == npcId or not tonumber(npcId) then return nil, nil end
			npcId = tonumber(npcId)
			if nil == self.npcs[npcId] then return nil, nil end
			local retval = { }
			local codes = self.npcs[npcId][1]
			local npcIsDarkmoonFaire = false
			local zoneNameToUse = preferredZoneName or GetRealZoneText()
			if nil ~= codes and (not requiresNPCAvailable or self:IsNPCAvailable(npcId)) then
				local codeArray = { strsplit(" ", codes) }

				-- First we check for the Darkmoon Faire code to see if we must limit the returned locations to the current Darkmoon Faire location
				for i = 1, #(codeArray), 1 do
					if codeArray[i] == 'HF' then
						npcIsDarkmoonFaire = true
					end
				end

				for i = 1, #(codeArray), 1 do
					local controlCode = strsub(codeArray[i], 1, 1)
					local zoneName
					if 'Z' == controlCode then
						zoneName = self.zones[tonumber(strsub(codeArray[i], 2))]
						if not onlyZoneReturn or (onlyZoneReturn and zoneName == zoneNameToUse) then
							tinsert(retval, { zoneName })
						end
					elseif 'H' == controlCode then
						-- ignore this because it indicates the NPC is only present during a holiday
					elseif 'A' == controlCode then
						-- ignore this because it is an alias marker indicating the real NPC id
					elseif 'X' == controlCode then
						-- ignore this because it indicates the NPC is only present in heroic mode
					elseif 'P' == controlCode
					    or 'C' == controlCode
					    or 'M' == controlCode
					    or 'S' == controlCode then
						tinsert(retval, { codeArray[i] })	-- Preowned, Created, Mailbox, Self
					elseif 'N' == controlCode then
						if strlen(codeArray[i]) > 4 then	--	NearXXXX where XXXX is the only zone where this Near can appear
							zoneName = self.zones[tonumber(strsub(codeArray[i], 5))]
							if not onlyZoneReturn or (onlyZoneReturn and zoneName == zoneNameToUse) then
								tinsert(retval, {zoneName, "Near" })
							end
						else
							tinsert(retval, { codeArray[i] })	-- Near
						end
					else	-- a real coordinate
						local zoneId, coord = strsplit(":", codeArray[i])
						if not npcIsDarkmoonFaire or (npcIsDarkmoonFaire and nil ~= self.darkmoonFaireLocation and tonumber(zoneId) == self.darkmoonFaireLocation) then
							zoneName = self.zones[tonumber(zoneId)]
							if not onlyZoneReturn or (onlyZoneReturn and zoneName == zoneNameToUse) then
								tinsert(retval, {zoneName, coord })
							end
						end
					end
				end
			end
			if onlySingleReturn and 1 < #(retval) then
				retval = { retval[1] }		-- pick the first item for no better algorithm to use to decide
			end
			if 0 == #(retval) then
				retval = nil
			end
			return retval, self.npcs[npcId][0]
		end,

		-- This returns a table of locations for the NPCs involved in "A" accepting the quest or "T" turning in the quest, and the NPC name.
		-- Faction specific locations will be preferred over general ones.
		-- requiresNPCAvailable, if true, requires the NPC be currently available (like celebrating the holiday that the NPC is in)
		-- onlySingleReturn, if true, returns only one location if there is more than one that can be returned
		-- onlyZoneReturn, if true, only returns locations from the preferred zone
		-- preferredZoneName specifies the zone of interest, and if not given then the current zone will be used
		-- Each table element is itself a table with either one or two
		-- entries.  Those with two entries are normal (mostly), with the first entry the localized name of the zone, and the second entry
		-- the x,y pair of the coordinates in the zone (or the special word Near (see below)).  Those with one entry are special, and the
		-- value can be a localized zone name which is most likely where the item that starts the quest can be found, or one of these special words:
		--	Preowned	the character already has to own this item because it is no longer in the game
		--	Created		this item can be created
		--	Mailbox		this will be sent to the character by Blizzard
		--	Self		this will be used for quests that are automatically accepted or have no NPC from which to accept
		--	Near		the NPC should be nearby (they may have just been summoned for example)
		LocationQuest = function(self, questId, acceptOrTurnin, requiresNPCAvailable, onlySingleReturn, onlyZoneReturn, preferredZoneName)
			if nil == questId or not tonumber(questId) then return nil, nil end
			questId = tonumber(questId)
			local retval = { }
			local newRetval = { }
			local npcNameRetval = nil
			local codeToUse = acceptOrTurnin or 'A'
			if 'A' ~= codeToUse and 'T' ~= codeToUse then codeToUse = 'A' end
			local factionCode = 'A'
			if 'Horde' == self.playerFaction then factionCode = 'H' end
			local factionSpecificValue = codeToUse..factionCode
			local npcCodes = self:CodesWithPrefixQuest(questId, factionSpecificValue..':') or self:CodesWithPrefixQuest(questId, codeToUse..':')
			if nil ~= npcCodes then
				for i = 1, #(npcCodes), 1 do
					local _, npcs = strsplit(":", npcCodes[i])
					local npcTable = { strsplit(",", npcs) }
					for j = 1, #(npcTable), 1 do
						local npcLocations, npcName = self:LocationNPC(npcTable[j], requiresNPCAvailable, onlySingleReturn, onlyZoneReturn, preferredZoneName)
						if nil ~= npcLocations then
							for _, value in pairs(npcLocations) do
								tinsert(retval, { value, npcName })
							end
						end
					end
				end
			end
			if onlySingleReturn and 1 < #(retval) then
				retval = { retval[1] }		-- pick the first item for no better algorithm to use to decide
			end
			if 0 == #(retval) then
				retval = nil
			else
				for i = 1, #(retval), 1 do
					tinsert(newRetval, retval[i][1])
					if nil == npcNameRetval then npcNameRetval = retval[i][2] end
				end
				retval = newRetval
			end
			return retval, npcNameRetval
		end,

		MarkQuestComplete = function(self, questId, updateDatabase)
			local v = tonumber(questId)
			local index = math.floor((v - 1) / 32)
			local offset = v - (index * 32) - 1
			if (nil == GrailDatabase[self.playerRealm][self.playerName]["completedQuests"][index]) then
				GrailDatabase[self.playerRealm][self.playerName]["completedQuests"][index] = 0
			end
			GrailDatabase[self.playerRealm][self.playerName]["completedQuests"][index] = GrailDatabase[self.playerRealm][self.playerName]["completedQuests"][index] + (2^offset)

			if updateDatabase then

				if not self:IsResettableQuestCompleted(questId) and (self:IsDaily(questId) or self:IsWeekly(questId) or self:IsYearly(questId) or self:IsRepeatable(questId)) then
					if (nil == GrailDatabase[self.playerRealm][self.playerName]["completedResettableQuests"][index]) then
						GrailDatabase[self.playerRealm][self.playerName]["completedResettableQuests"][index] = 0
					end
					GrailDatabase[self.playerRealm][self.playerName]["completedResettableQuests"][index] = GrailDatabase[self.playerRealm][self.playerName]["completedResettableQuests"][index] + (2^offset)
				end

				-- Get the target information to ensure the target exists in the database of NPCs
				local version = self.versionNumber.."/"..self.questsVersionNumber.."/"..self.npcsVersionNumber.."/"..self.zonesVersionNumber
				local targetName, npcId, coordinates = self:TargetInformation()
				self:UpdateTargetDatabase(targetName, npcId, coordinates, version)
				if self.debug then
					if nil ~= targetName then
						DEFAULT_CHAT_FRAME:AddMessage("Grail Debug: Marked questId "..questId.." complete, turned in to: "..targetName.."("..npcId..") "..coordinates)
					else
						DEFAULT_CHAT_FRAME:AddMessage("Grail Debug: Turned in quest "..questId.." with no target")
					end
				end
				self:UpdateQuestDatabase(questId, 'No Title Stored', npcId, false, 'T:', version)
				self:PostNotification("Complete", questId)
			end

		end,

		MeetsPrerequisites = function(self, questId)
			local retval = true
			local any, present, failures = self:AnyEvaluateTrue(questId, "P:", false)
			if present then
				retval = any
			end
			return retval, failures
		end,

		MeetsRequirement = function(self, questId, requirementCode)
			if nil == questId or not tonumber(questId) then return false end
			questId = tonumber(questId)
			local retval = true
			local failures = { }
			local foundAnyRequirement = false
			local foundAnyMatchingRequirement = false
			local codeArray = { strsplit(" ", self.quests[questId][1]) }
			local possibleFailures = { }
			if nil ~= codeArray then
				for i = 1, #(codeArray), 1 do
					local controlCode = strsub(codeArray[i], 1, 1)
					local controlValue = strsub(codeArray[i], 2, 2)
					if requirementCode == controlCode then
						if 'G' == controlCode then
							if self.genderMapping[controlValue] ~= self.playerGender then
								retval = false
							end
						elseif 'F' == controlCode then
							if self.factionMapping[controlValue] ~= self.playerFaction then
								retval = false
							end
						elseif 'C' == controlCode then
							foundAnyRequirement = true
							if self.classMapping[controlValue] == self.playerClass then
								foundAnyMatchingRequirement = true
							end
						elseif 'H' == controlCode then
							foundAnyRequirement = true
							if self:CelebratingHoliday(self.holidayMapping[controlValue]) then
								foundAnyMatchingRequirement = true
							else
								tinsert(possibleFailures, codeArray[i])
							end
						elseif 'R' == controlCode then
							foundAnyRequirement = true
							if self.raceMapping[controlValue] == self.playerRace then
								foundAnyMatchingRequirement = true
							end
						elseif 'V' == controlCode then
							local repIndex = tonumber(strsub(codeArray[i], 2, 3))
							local repValue = tonumber(strsub(codeArray[i], 4, 8))
							local exceeds, earnedValue = self:ReputationExceeds(self.reputationMapping[repIndex], repValue)
							if not exceeds then
								retval = false
								if nil ~= earnedValue then
									tinsert(failures, codeArray[i].." actual: "..earnedValue)
								end
							end
						elseif 'W' == controlCode then
							local repIndex = tonumber(strsub(codeArray[i], 2, 3))
							local repValue = tonumber(strsub(codeArray[i], 4, 8))
							local exceeds, earnedValue = self:ReputationExceeds(self.reputationMapping[repIndex], repValue)
							if exceeds then
								retval = false
								if nil ~= earnedValue then
									tinsert(failures, codeArray[i].." actual: "..earnedValue)
								end
							end
						elseif 'P' == controlCode and ':' ~= controlValue then
							local profValue = tonumber(strsub(codeArray[i], 3, 5))
							local exceeds, skillLevel = self:ProfessionExceeds(controlValue, profValue)
							if not exceeds then
								retval = false
								tinsert(failures, codeArray[i].." actual: "..skillLevel)
							end
						end
					end
				end
			end
			if foundAnyRequirement then
				retval = foundAnyMatchingRequirement
				if false == retval and 0 < #(possibleFailures) then
					tinsert(failures, table.concat(possibleFailures, " "))
				end
			end
			if 0 == #(failures) then failures = nil end
			return retval, failures
		end,

		MeetsRequirementClass = function(self, questId)
			return self:MeetsRequirement(questId, 'C')
		end,

		MeetsRequirementFaction = function(self, questId)
			return self:MeetsRequirement(questId, 'F')
		end,

		MeetsRequirementGender = function(self, questId)
			return self:MeetsRequirement(questId, 'G')
		end,

		MeetsRequirementHoliday = function(self, questId)
			return self:MeetsRequirement(questId, 'H')
		end,

		-- Returns true if the player level meets or exceeds any level requirement for the specified quest
		-- but does not exceed any maximum level requirement.  Returns false otherwise.
		MeetsRequirementLevel = function(self, questId, optionalComparisonLevel)
			if nil == questId or not tonumber(questId) then return false end
			questId = tonumber(questId)
			local retval = true
			local levelToCompare = optionalComparisonLevel or UnitLevel('player')
			local levelCodes = self:CodesWithPrefixQuest(questId, "L")
			local levelRequired = 1
			if nil ~= levelCodes then	-- there should only be one level code or nil returned
				levelRequired = tonumber(strsub(levelCodes[1], 2))
			end
			local levelNotToExceed = 100000
			levelCodes = self:CodesWithPrefixQuest(questId, "M")
			if nil ~= levelCodes then
				levelNotToExceed = tonumber(strsub(levelCodes[1], 2))
			end
			if levelToCompare < levelRequired or levelToCompare > levelNotToExceed then
				retval = false
			end
			return retval
		end,

		MeetsRequirementProfession = function(self, questId)
			return self:MeetsRequirement(questId, 'P')
		end,

		MeetsRequirementRace = function(self, questId)
			return self:MeetsRequirement(questId, 'R')
		end,

		MeetsRequirementReputation = function(self, questId)
			local first, failures = self:MeetsRequirement(questId, 'V')
			local second, failures2 = self:MeetsRequirement(questId, 'W')
			local retval = first and second
			if nil == failures then
				failures = failures2
			else
				if nil ~= failures2 then
					for i = 1, #(failures2), 1 do
						tinsert(failures, failures[1])
					end
				end
			end
			return retval, failures
		end,

		PostNotification = function(self, eventName, questId)
			if nil ~= self.observers[eventName] then
				for i = 1, #(self.observers[eventName]), 1 do
					self.observers[eventName][i](eventName, questId)
				end
			end
		end,

		ProfessionExceeds = function(self, professionCode, professionValue)
			local retval = false
			local skillLevel = self.NO_SKILL
			local skillName = nil
			local prof1, prof2, archaeology, fishing, cooking, firstAid = GetProfessions();

			if "X" == professionCode and nil ~= archaeology then
				_, _, skillLevel = GetProfessionInfo(archaeology)
			elseif "F" == professionCode and nil ~= fishing then
				_, _, skillLevel = GetProfessionInfo(fishing)
			elseif "C" == professionCode and nil ~= cooking then
				_, _, skillLevel = GetProfessionInfo(cooking)
			elseif "+" == professionCode and nil ~= firstAid then
				_, _, skillLevel = GetProfessionInfo(firstAid)
			elseif "R" == professionCode then
				skillLevel = self:RidingSkillLevel()
			else
				professionName = self.professionMapping[professionCode]
				if nil ~= prof1 then
					skillName, _, skillLevel = GetProfessionInfo(prof1)
				end
				if skillName ~= professionName then
					if nil ~= prof2 then
						skillName, _, skillLevel = GetProfessionInfo(prof2)
					end
					if skillName ~= professionName then
						skillLevel = self.NO_SKILL
					end
				end
			end
			if skillLevel >= professionValue then
				retval = true
			end
			return retval, skillLevel
		end,

		QuestAbandonStart = function(self)
			self.abandoningQuestIndex = GetQuestLogSelection()
			self.origAbandonQuestFunction()
		end,

		QuestAbandonStop = function(self)
			local questTitle, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questId = GetQuestLogTitle(self.abandoningQuestIndex)
			self:PostNotification("Abandon", questId)
			self.origConfirmAbandonQuestFunction()
		end,

		-- Returns the quest ID of the quest in the quest log whose title matches soughtTitle, or nil if there is no quest matching.
		QuestInQuestLogMatchingTitle = function(self, soughtTitle)
			local retval = nil
			local i = 1
			local cleanedTitle = strtrim(soughtTitle)
			while GetQuestLogTitle(i) and nil == retval do
				local questTitle, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questId = GetQuestLogTitle(i)
				if not isHeader and questTitle == cleanedTitle then
					retval = questId
				end
				i = i + 1
			end
			return retval
		end,

		-- Internal use function that is used instead of the normal QuestRewardCompleteButton_OnClick() which is being hooked
		-- so we can record the quest as being complete.  This seems to be the best way to record the quest as it completes
		-- because the events that Blizzard issues are inadequate.
		QuestRewardCompleteButton_OnClick = function(self)
			if self.completingQuest then
				self:MarkQuestComplete(self.completingQuest, true)
				self.completingQuest = nil
			end
			self.origHookFunction()
		end,

		-- Returns a table of quest IDs for quests that take place during the eventName (holiday) or nil if there are none.
		-- Note that eventName is supposed to be the localized name.
		QuestsDuringEvent = function(self, eventName, forceGarbageCollection)
			local retval = nil
			local desiredEventCode = nil
			for holidayCode, holidayName in pairs(self.holidayMapping) do
				if eventName == holidayName then desiredEventCode = holidayCode end
			end
			if nil ~= desiredEventCode then retval = self:QuestsDuringEventCode(desiredEventCode, forceGarbageCollection) end
			return retval
		end,

		-- Returns a table of quest IDs for quests that take place during the event referenced in Grail.holidayMapping or nil if there are none.
		-- This eventNameCode is not localized, while the actual event name is, so this API can be easier to use in certain circumstances.
		QuestsDuringEventCode = function(self, eventNameCode, forceGarbageCollection)
			return self:QuestsWithCode("H"..eventNameCode, forceGarbageCollection)
		end,

		-- Returns a table of quest IDs from questTable that are required to match the player's faction, class, etc.
		-- The targetLevel parameter is used to require level compliance at that level.  This means that quests requiring a higher level
		-- will not be included in the returned filtered list.
		QuestsFiltered = function(self, questTable, faction, class, race, gender, targetLevel)
			local retval = { }
			local stillGood
			if nil ~= questTable then
				for _, questId in pairs(questTable) do
					stillGood = true
					if faction and not self:MeetsRequirementFaction(questId) then stillGood = false end
					if class and not self:MeetsRequirementClass(questId) then stillGood = false end
					if race and not self:MeetsRequirementRace(questId) then stillGood = false end
					if gender and not self:MeetsRequirementGender(questId) then stillGood = false end
					if targetLevel and not self:MeetsRequirementLevel(questId, targetLevel) then stillGood = false end
					if stillGood then tinsert(retval, questId) end
				end
			end
			if 0 == #(retval) then retval = nil end
			return retval
		end,

		-- Returns a table of quest IDs for the quests in the quest log.
		-- Note that this will return an empty table and not nil for no quests in the log.
		QuestsInQuestLog = function(self)
			local retval = { }
			local i = 1
			while GetQuestLogTitle(i) do
				local questTitle, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questId = GetQuestLogTitle(i)
				if not isHeader then
					tinsert(retval, questId)
				end
				i = i + 1
			end
			return retval
		end,

		-- Returns a table of quest IDs for quests that can start in the zone name specified.
		-- Returns nil if no quests can start in the zone name specified.
		-- This will return the contents of the Grail.zoneQuests table unless forceSearch is true.
		QuestsInZone = function(self, zoneText, forceGarbageCollection, forceSearch)
			local retval = { }
			local zoneToUse = zoneText or GetRealZoneText()		-- if no zoneText is specified use the results from GetRealZoneText()
			local locations
			local shouldAdd
			local zoneIdToUse = nil
			for zoneId, zoneName in pairs(self.zones) do
				if zoneName == zoneToUse then zoneIdToUse = zoneId break end
			end
			if nil ~= zoneIdToUse and not forceSearch then
				retval = Grail.zoneQuests[zoneIdToUse]
			else
				for questId, _ in pairs(self.quests) do
					locations = self:LocationQuest(questId, "A")
					shouldAdd = false
					if nil ~= locations then
						for i = 1, #(locations), 1 do
							if locations[i][1] == zoneToUse then shouldAdd = true end
						end
					end
					if shouldAdd then tinsert(retval, questId) end
				end
			end
			if forceGarbageCollection then collectgarbage() end
			if 0 == #(retval) then retval = nil end
			return retval
		end,

		-- Returns a table of quest IDs for quests that have the sought code.
		-- Returns nil if no quests have the sought code.
		QuestsWithCode = function(self, soughtCode, forceGarbageCollection)
			assert((nil ~= soughtCode), "Grail Error: sought code cannot be nil")
			local retval = { }
			for questId, _ in pairs(self.quests) do
				if self:HasCode(questId, soughtCode) then tinsert(retval, questId) end
			end
			if forceGarbageCollection then collectgarbage() end
			if 0 == #(retval) then retval = nil end
			return retval
		end,

		QuestWithName = function(self, soughtName)
			assert((nil ~= soughtName), "Grail Error: sought name cannot be nil")
			local retval = nil
			for questId, _ in pairs(self.quests) do
				if self.quests[questId][0] == soughtName then
					retval = questId
				end
			end
			return retval
		end,

		RegisterObserver = function(self, eventName, callback)
			assert((nil ~= callback), "Grail Error: cannot register a nil callback")
			if nil == self.observers[eventName] then self.observers[eventName] = { } end
			tinsert(self.observers[eventName], callback)
		end,

		RegisterObserverQuestAbandon = function(self, callback)
			self:RegisterObserver("Abandon", callback)
		end,

		RegisterObserverQuestAccept = function(self, callback)
			self:RegisterObserver("Accept", callback)
		end,

		RegisterObserverQuestComplete = function(self, callback)
			self:RegisterObserver("Complete", callback)
		end,

		ReputationExceeds = function(self, reputationName, reputationValue)
			local retval = false
			local actualEarnedValue = nil
			local factionIndex = 1
			reputationValue = tonumber(reputationValue)
			while GetFactionInfo(factionIndex) and false == retval do
				local name, description, standingId, bottomValue, topValue, earnedValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild = GetFactionInfo(factionIndex)
				if not isHeader then
					if name == reputationName then
						earnedValue = earnedValue + 42000	-- the reputationValue is stored with 42000 added to it so we do not have to deal with negative numbers, so we normalize here
						retval = (earnedValue > reputationValue)
						actualEarnedValue = earnedValue
					end
				end
				factionIndex = factionIndex + 1
			end
			return retval, actualEarnedValue
		end,

		RidingSkillLevel = function(self)
			-- Need to search the spell book for the Riding skill
			local retval = self.NO_SKILL
			local spellIdMapping = { [33388] = 75, [33391] = 150, [34090] = 225, [34091] = 300, [90265] = 375 }
			local _, _, _, numberSpells = GetSpellTabInfo(1)
			for i = 1, numberSpells, 1 do
				local name = GetSpellBookItemName(i, BOOKTYPE_SPELL)
				local link = GetSpellLink(name)
				if link then
					local spellId = tonumber(link:match("^|c%x+|H(.+)|h%[.+%]"):match("(%d+)"))
					if spellId then
						local newLevel = spellIdMapping[spellId]
						if newLevel and newLevel > retval then
							retval = newLevel
						end
					end
				end
			end
			return retval
		end,

		SlashCommand = function(self, frame, msg)
			msg = strlower(msg)
			if "debug" == msg then
				self.debug = not self.debug
				local statusMessage = self.debug and "ON" or "OFF"
				DEFAULT_CHAT_FRAME:AddMessage("Grail Debug now " .. statusMessage)
			elseif "target" == msg then
				local targetName, npcId, coordinates = self:TargetInformation()
				if targetName == nil then targetName = 'nil target' end
				if npcId == nil then npcId = -1 end
				if coordinates == nil then coordinates = 'no coords' end
				DEFAULT_CHAT_FRAME:AddMessage(targetName.."("..npcId..") "..coordinates)
			elseif "npc" == strsub(msg, 1, 3) then
				debugprofilestart()
				self:DebugDumpOneNPCInfo(strsub(msg, 5))
				DEFAULT_CHAT_FRAME:AddMessage("Elapsed milliseconds: "..debugprofilestop())
			elseif "holiday" == strsub(msg, 1, 7) then
				debugprofilestart()
				self:DebugDumpQuestInfo(self:QuestsDuringEventCode(strupper(strsub(msg, 9))))
				DEFAULT_CHAT_FRAME:AddMessage("Elapsed milliseconds: "..debugprofilestop())
			elseif "quest" == strsub(msg, 1, 5) then
				local questToUse = strsub(msg, 7)
				frame:ClearLines()
				frame:SetHyperlink(format("quest:%d", questToUse))
				DEFAULT_CHAT_FRAME:AddMessage("Quest "..questToUse)
				local numLines = frame:NumLines()
				if nil == numLines then numLines = 0 end
				DEFAULT_CHAT_FRAME:AddMessage("Tooltip has "..numLines.." lines")
				for i = 1, numLines, 1 do
					local text = _G["com_mithrandir_grailTooltipTextLeft"..i]
					if text then
						DEFAULT_CHAT_FRAME:AddMessage(text:GetText())
					end
				end
			elseif "completed" == strsub(msg, 1, 9) then
				local questToUse = strsub(msg, 11)
				local normal = self:IsQuestCompleted(questToUse) and "YES" or "NO"
				local resettable = self:IsResettableQuestCompleted(questToUse) and "YES" or "NO"
				DEFAULT_CHAT_FRAME:AddMessage("Quest " .. questToUse .. " completed: " .. normal .. " and resettable completed: " .. resettable)
			elseif "riding" == msg then
				DEFAULT_CHAT_FRAME:AddMessage("Riding skill is "..self:RidingSkillLevel())
			elseif "zone" == msg then
				DEFAULT_CHAT_FRAME:AddMessage("All quests in current zone")
				debugprofilestart()
				local questsInZone = self:QuestsInZone()
				for i = 1, #(questsInZone), 1 do
					DEFAULT_CHAT_FRAME:AddMessage(questsInZone[i].." "..self.quests[questsInZone[i]][0])
				end
				DEFAULT_CHAT_FRAME:AddMessage("Elapsed milliseconds: "..debugprofilestop())
			elseif "zonesearch" == msg then
				DEFAULT_CHAT_FRAME:AddMessage("All quests in current zone")
				debugprofilestart()
				local questsInZone = self:QuestsInZone(GetRealZoneText(), false, true)
				for i = 1, #(questsInZone), 1 do
					DEFAULT_CHAT_FRAME:AddMessage(questsInZone[i].." "..self.quests[questsInZone[i]][0])
				end
				DEFAULT_CHAT_FRAME:AddMessage("Elapsed milliseconds: "..debugprofilestop())
			elseif "abandon" == msg then
				self:RegisterObserverQuestAbandon(Grail.DebugCallback)
			else
				DEFAULT_CHAT_FRAME:AddMessage("Grail initiating server database query")
				QueryQuestsCompleted()
			end
		end,

		--	Returns retval, reason, failures
		--	where retval is true if the player can get the quest (and not an error state) and false otherwise
		--	and reason indicates further information about why false is returned
		--	failures will be nil or a table containing some specific information about failure conditions
		Status = function(self, questId, ignoreLevelRequirement, ignoreProfessionRequirement, ignoreReputationRequirement, ignoreHolidayRequirement, ignorePresenceInLog)
			local retval = false
			local reason = "Error"
			local success
			local failures = { }
			if questId ~= nil and tonumber(questId) then
				questId = tonumber(questId)
				if self:IsQuestCompleted(questId) and not self:IsRepeatable(questId) then
					reason = "Completed"
				elseif not ignorePresenceInLog and self:IsQuestInQuestLog(questId) then
					reason = "InLog"
				elseif not self:DoesQuestExist(questId) then
					reason = "Nonexistent"
				elseif not ignoreLevelRequirement and not self:MeetsRequirementLevel(questId) then
					reason = "Level"
				elseif not self:MeetsRequirementClass(questId) then
					reason = "Class"
				elseif not self:MeetsRequirementRace(questId) then
					reason = "Race"
				elseif not self:MeetsRequirementGender(questId) then
					reason = "Gender"
				elseif not self:MeetsRequirementFaction(questId) then
					reason = "Faction"
				else
					success, failures = self:MeetsPrerequisites(questId)
					if not success then
						reason = "Prerequisites"
					else
						success, failures = self:IsInvalidated(questId)
						if success then		-- note that the word success here is a misnomer.  if IsInvalidated returns true we have failed
							reason = "Invalidated"
						else
							success, failures = self:MeetsRequirementProfession(questId)
							if not ignoreProfessionRequirement and not success then
								reason = "Profession"
							else
								success, failures = self:MeetsRequirementReputation(questId)
								if not ignoreReputationRequirement and not success then
									reason = "Reputation"
								else
									success, failures = self:MeetsRequirementHoliday(questId)
									if not ignoreHolidayRequirement and not success then
										reason = "Holiday"
									else
										retval = true
										reason = ""
									end
								end
							end
						end
					end
				end
			end
			if nil ~= failures and 0 == #(failures) then failures = nil end
			return retval, reason, failures
		end,

		-- Returns targetName, npcId, coordinates for the player's target.
		-- Note that coordinates is actually for the player since Blizzard disallows getting the map position of the target.
		TargetInformation = function(self)
			local targetName = UnitName("target")
			local npcId = nil
			local coordinates = nil
			if nil ~= targetName then
				local guid = UnitGUID("target")
				if nil ~= guid then
					local targetType = tonumber(guid:sub(5,5), 16) % 8
					npcId = tonumber(guid:sub(7,10), 16)
					if 1 == targetType then npcId = npcId + 1000000 end	-- world object
					local zoneText = GetRealZoneText()
					local x, y = GetPlayerMapPosition("player")	-- cannot get target x,y since Blizzard disabled that and returns 0,0 all the time for it
					local zoneId = -1
					for zone, zoneName in pairs(self.zones) do
						if zoneName == zoneText then zoneId = zone end
					end
					coordinates = strformat("%d:%.2f,%.2f", zoneId, x*100, y*100)
				end
			end
			return targetName, npcId, coordinates
		end,

		Tooltip_OnEvent = function(self, frame, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
			if self.eventDispatch[event] then
				self.eventDispatch[event](self, frame, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
			end
		end,

		Tooltip_OnLoad = function(self, frame)
			self.playerRealm = GetRealmName()
			self.playerName = UnitName('player')
			_, self.playerClass = UnitClass('player')
			_, self.playerRace = UnitRace('player')
			self.playerFaction = UnitFactionGroup('player')
			self.playerGender = UnitSex('player')
			self.playerLocale = GetLocale()
			SlashCmdList["GRAIL"] = function(msg)
				self:SlashCommand(frame, msg)
			end
			SLASH_GRAIL1 = "/grail"

			-- Now to hook the QuestRewardCompleteButton_OnClick function
			self.origHookFunction = QuestRewardCompleteButton_OnClick
			QuestFrameCompleteQuestButton:SetScript("OnClick", function() self:QuestRewardCompleteButton_OnClick() end);

			self.origAbandonQuestFunction = SetAbandonQuest
			SetAbandonQuest = function() self:QuestAbandonStart() end

			self.origConfirmAbandonQuestFunction = AbandonQuest
			AbandonQuest = function() self:QuestAbandonStop() end

			-- Populate our special list of quests that are gained and completed without ever entering the quest log
			for questId, _ in pairs(self.quests) do
				if self:HasCode(questId, "SP") or self:IsRepeatable(questId) then
					self.specialQuests[self.quests[questId][0]] = questId
				end
			end

			-- Find out where the Darkmoon Faire is
			self:CelebratingHoliday('Can Be Ignored')

			frame:SetScript("OnEvent", function(frame, event, ...) self:Tooltip_OnEvent(frame, event, ...) end)
			frame:RegisterEvent("VARIABLES_LOADED")
		end,

		UnregisterObserver = function(self, eventName, callback)
			if nil ~= callback and nil ~= self.observers[eventName] then
				for i = 1, #(self.observers[eventName]), 1 do
					if callback == self.observers[eventName][i] then
						tremove(self.observers[eventName], i)
						break
					end
				end
			end
		end,

		UnregisterObserverQuestAbandon = function(self, callback)
			self:UnregisterObserver("Abandon", callback)
		end,

		UnregisterObserverQuestAccept = function(self, callback)
			self:UnregisterObserver("Accept", callback)
		end,

		UnregisterObserverQuestComplete = function(self, callback)
			self:UnregisterObserver("Complete", callback)
		end,

		UpdateQuestDatabase = function(self, questId, questTitle, npcId, isDaily, npcCode, version)
			if nil == questId or not tonumber(questId) then return end
			questId = tonumber(questId)
			if not self:DoesQuestExist(questId) or nil == self:CodesWithPrefixQuest(questId, npcCode) then
				if nil == GrailDatabase["NewQuests"] then GrailDatabase["NewQuests"] = { } end
				if nil == GrailDatabase["NewQuests"][questId] then
					GrailDatabase["NewQuests"][questId] = { }
					GrailDatabase["NewQuests"][questId][self.playerLocale] = questTitle
					local codes = nil
					if isDaily then codes = "+D" end
					if nil ~= npcId then
						if nil == codes then codes = npcCode..npcId else codes = codes.." "..npcCode..npcId end
					end
					if nil ~= codes then GrailDatabase["NewQuests"][questId][1] = codes end
					GrailDatabase["NewQuests"][questId][2] = version
				else
					local codes = GrailDatabase["NewQuests"][questId][1]
					if nil == self:CodesWithPrefix(codes, npcCode) then
						if nil ~= npcId then
							if nil == codes then codes = npcCode..npcId else codes = codes.." "..npcCode..npcId end
						end
						if nil ~= codes then GrailDatabase["NewQuests"][questId][1] = codes end
					end
				end
			end
		end,

		UpdateQuestResetTime = function(self)
			local seconds = GetQuestResetTime()
			if seconds > self.questResetTime then
				QueryQuestsCompleted()
			end
			self.questResetTime = seconds
		end,

		UpdateTargetDatabase = function(self, targetName, npcId, coordinates, version)
			if nil ~= npcId then
				if nil == self.npcs[npcId] then
					if nil == GrailDatabase["NewNPCs"] then	GrailDatabase["NewNPCs"] = { } end
					if nil == GrailDatabase["NewNPCs"][npcId] then GrailDatabase["NewNPCs"][npcId] = { } end
					GrailDatabase["NewNPCs"][npcId][self.playerLocale] = targetName
					GrailDatabase["NewNPCs"][npcId][1] = coordinates
					GrailDatabase["NewNPCs"][npcId][2] = version
				end
			end
		end,

		}

end
