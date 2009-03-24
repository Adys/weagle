local function toggle(name, value)
	local t = {}
	t.name = name
	t.desc = name
	t.type = "toggle"
	t.get  = function() return Weagle_data[value] end
	t.set  = function()
			Weagle_data[value] = not Weagle_data[value]
			Weagle:Print(name .. " is now set to " .. tostring(Weagle_data[value]))
		end
	return t
end

local function findobj(name)
	local t = {}
	t.name = "Find " .. name
	t.desc = "Find " .. name .. "s by name or id"
	t.type = "execute"
	t.func = function(msg)
		msg = gsub(msg["input"], msg[1] .. " ", "") -- Yeah well fuck Ace
		QuickFindAPIObject(msg, name)
	end
	t.guiHidden = true
	return t
end

Weagle_Options = {
	type = "group",
	desc = "A badass fucking datamining war machine.",
	args = {
		settings = {
			name = "Settings",
			type = "execute",
			desc = "Open the Weagle settings panel",
			func = function() InterfaceOptionsFrame_OpenToCategory(Weagle.optionsFrame) end,
			guiHidden = true,
		},
		
		dontreprocess	= toggle("Don't process items twice in a session", "Item_dontreprocess"),
		usedbc		= toggle("Use Item.dbc for validity checks", "Item_usedbc"),
		
		showblacklisted	= toggle("Feedback when skipping blacklisted items", "Item_blacklisted"),
		showcached		= toggle("Feedback when skipping items already cached", "Item_showcached"),
		showcaching		= toggle("Feedback when successfuly caching an item", "Item_showcaching"),
		showfailed		= toggle("Feedback when an item query failed", "Item_showfailed"),
		showinvalid		= toggle("Feedback when skipping an invalid item", "Item_showinvalid"),
		showprocessed	= toggle("Feedback when skipping items already processed", "Item_showprocessed"),
		
		findach		= findobj("Achievement"),
		findcreature	= findobj("Creature"),
		findglyph		= findobj("Glyph"),
		finditem		= findobj("Item"),
		findquest		= findobj("Quest"),
		findspell		= findobj("Spell"),
		findtalent		= findobj("Talent"),
		
		findtal = findtalent,
		
		findstructure = {
			name = "Show itemcache.wdb structure",
			type = "execute",
			desc = "Print every cached, uncached and lacking entry from Item.dbc",
			func = function(msg)
				msg = gsub(msg["input"], msg[1] .. " ", "")
				Weagle:FindStructure(msg)
			end,
			guiHidden = true,
		},
		
		item = {
			name = "Sniff items",
			type = "execute",
			desc = "Gather specific items",
			func = function(msg) Weagle:HandleSniffRequest(msg["input"]) end,
			guiHidden = true,
		},
		quest = {
			name = "Sniff quests",
			type = "execute",
			desc = "Gather specific quests",
			func = function(msg) Weagle:HandleQuestSniffRequest(msg["input"]) end,
			guiHidden = true,
		},
		quests = {
			name = "Sniff all quests",
			type = "execute",
			desc = "Gather all quests",
			func = function() Weagle:SniffQuestsRange(1, WeagleLib_MaxIDs.Quest) end,
		},
		stop = {
			name = "Stop all processing",
			type = "execute",
			desc = "Stops all current processing",
			func = "StopSniffing",
		},
		scandbc = {
			name = "Scan Item.dbc",
			type = "execute",
			desc = "Save a snapshot of Item.dbc",
			func = function() Weagle:ScanItemDBC() end,
		},
		cached = {
			name = "Print recently cached",
			type = "execute",
			desc = "Print items cached this session",
			func = function() Weagle:GetRecentlyCached() end,
		},
		stats = {
			name = "Show statistics",
			type = "execute",
			desc = "Shows current sniffing statistics",
			func = function() Weagle:ShowStats() end,
		},
		reset = {
			name = "Reset all settings",
			type = "execute",
			desc = "Reset all settings to default",
			func = function() Weagle:ResetSettings() end,
		},
		resetstats = {
			name = "Reset statistics",
			type = "execute",
			desc = "Reset processing statistics to zero",
			func = function() Weagle:ResetStats() end,
		},
		info = {
			name = "Info",
			type = "execute",
			desc = "Info",
			func = function() Weagle:GameInfo() Weagle:ShowStats() end,
			guiHidden = true,
		},
	}
}


Weagle_DefaultSettings = {
	-- Settings
	["Item_usedbc"]			= true,
	["Item_dontreprocess"]		= true,
	["Item_showblacklisted"]	= true,
	["Item_showcached"]		= false,
	["Item_showcaching"]		= true,
	["Item_showfailed"]		= true,
	["Item_showinvalid"]		= false,
	["Item_showtooltip"]		= false,
	["Quest_showtooltip"]		= false,
	["Quest_showcaching"]		= true,
	
	-- Preferences
	["Icon_invalid"]			= "interface/icons/inv_misc_questionmark",
	
	-- Throttles
	["Item_throttle"]			= 0.8,
	["Item_invalidthrottle"]	= 4.5,
	["Quest_batchamount"]		= 100,
	["Quest_batchthrottle"]		= 5.0,
	["Quest_throttle"]		= 0.1,
	
	-- Misc
	["Item_last"] = 1,
	["Quest_last"] = 1,
}


