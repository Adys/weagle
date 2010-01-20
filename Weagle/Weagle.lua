------------
-- Weagle --
------------
-- © 2009 - Jerome Leclanche for MMO-Champion

Weagle = LibStub("AceAddon-3.0"):NewAddon("Weagle", "AceConsole-3.0", "AceTimer-3.0")

local VERSION, BUILD, COMPILED, TOC = GetBuildInfo()
BUILD, TOC = tonumber(BUILD), tonumber(TOC)

Weagle.NAME = "Weagle"
Weagle.CNAME = "|cff33ff99" .. Weagle.NAME .. "|r"
Weagle.VERSION = "4.0.0"

function Weagle:Print(...)
	return print(Weagle.CNAME .. ":", ...)
end

Weagle.settings = {
	item = {
		previous = nil,
		get = {},
		cached = {},
		failed = {},
		skip = {},
		max = 60000,
		settings = {
			throttle_cached = 0.8,   -- Wait time after every successful query
			throttle_fail   = 4.5,   -- Wait time after every failed query
			show_cached     = false, -- Feedback on items already cached
			show_caching    = true,  -- Feedback on successful item queries
			show_failed     = true,  -- Feedback on failed item queries
			show_invalid    = false, -- Feedback on invalid queries (not present in Item.dbc)
			use_dbc         = true,  -- Use Item.dbc and skip item queries accordingly
			no_reprocess    = true,  -- Don't process an item twice in a session
		},
		chatcommand = function(input)
			if input == "cached" then
				return Weagle:GetRecentlyCached()
			
			elseif input == "count" then
				local cached = 0;
				for i=1, ITEMS.max do
					if GetItemInfo(i) then cached = cached + 1 end
				end
				return Weagle:Print("Total cached items:", cached)
			
			elseif input == "scandbc" then
				Weagle:ScanItemDBC()
			
			elseif input == "stop" then
				return Weagle:StopSniffing() -- TODO item handle only
			
			elseif input == "spells" then
				return Weagle:ScanSpellList()
			
			elseif input:match("%d+") then
				return Weagle:HandleSniffRequest(input)
			end
			
			Weagle:Print("Usage: /weagle item [cached|stop|...]")
		end
	},
	
	quest = {
		previous = nil,
		get = {},
		cached = {},
		max = 35000,
		settings = {
			throttle_batch = 3.0,  -- Wait time after every batch
			show_batches   = true, -- Feedback on processed batches
			batch_amount   = 100,  -- How many objects per batch
		},
		chatcommand = function(input)
			Weagle:Print("fixme: use entire range")
			Weagle:SniffQuestsRange(1, Weagle.settings.quest.max)
		end
	}
}

-------------
-- Helpers --
-------------

function tableitems(t) -- Lua sucks
	i=0
	for k, v in pairs(t) do i=i+1 end
	return i
end

function tablein(i, t)
	for k, v in pairs(t) do
		if i == v then return true end
	end
	return false
end

ITEMS = Weagle.settings.item
QUESTS = Weagle.settings.quest

local function RED(text)
	return "|cffff0000" .. text .. "|r"
end

local function GREEN(text)
	return "|cff00ff00" .. text .. "|r"
end

local function YELLOW(text)
	return "|cffffff00" .. text .. "|r"
end

local function chatcommand(input)
	local command
	command, input = input:match("(%w+)%W*(.*)")
	if command then
		if Weagle.settings[command] then
			return Weagle.settings[command].chatcommand(input:trim())
		else
			if command == "info" then
				return Weagle:GameInfo()
			elseif command == "resetstats" then
				return Weagle:ResetStats()
			elseif command == "stats" then
				return Weagle:ShowStats()
			elseif command == "stop" then
				return Weagle:StopSniffing()
			end
		end
	end
	Weagle:Print("Usage: /weagle [item|quest] ...")
end

local function GetSpellRealLink(id) -- GetSpellLink is broken
	local name = GetSpellInfo(id)
	if not name then return end
	local link = GetSpellLink(id)
	
	if not link then -- Spell exists but is unlinkable
		link = "|cff71d5ff|Hspell:" .. id .. "|h[" .. name .. "]|h|r"
	end
	return link
end

local function CreateSpellLink(id, name) -- Create the spell link for spells that still exist serverside
	return ("|cff71d5ff|Hspell:%i|h[%s]|h|r"):format(id, name)
end


function Weagle:ResetSettings()
	Weagle_data = Weagle_DefaultSettings
	Weagle_data.itemdbc = {}
	
	self:Print("All saved settings have been reset.")
end

function Weagle:OnInitialize()
	DEFAULT_CHAT_FRAME:SetMaxLines(5000)
	
	CreateFrame("GameTooltip", "WeagleItemTooltip", UIParent, "GameTooltipTemplate")
	CreateFrame("GameTooltip", "WeagleQuestTooltip", UIParent, "GameTooltipTemplate")
	
	if not Weagle_data then
		self:ResetSettings()
	end
	
	pages["ITEM: Item.dbc"] = Weagle_data.itemdbc
end


function Weagle:GameInfo()
	self:Print("WoW version "..VERSION.."."..BUILD..", TOC "..TOC.." compiled on "..COMPILED.." - Server: "..SERVER)
end

function Weagle:GetRecentlyCached()
	local i = 0
	for k, v in pairs(ITEMS.cached) do
		self:Print("Recently cached: Item #" .. k, GetItemLink(k))
		i = i+1
	end
	self:Print(GREEN(i) .. " items found.")
end

function Weagle:ScanItemDBC()
	Weagle_data.itemdbc = {}
	local items = Weagle_data.itemdbc
	
	for i = 1, ITEMS.max do
		if GetItemIcon(i) then
			items[#items+1] = i
		end
	end
	
	Weagle:Print("Saved " .. YELLOW(#items) .. " items for this build.")
end

function Weagle:FindStructure(msg)
	local items = {}
	if tonumber(msg) then
		items = {tonumber(msg)}
	
	elseif msg:match("%-") then
		local first, last = msg:match("(%d+)%-(%d+)")
		first, last = tonumber(first), tonumber(last)
		
		if first < last then
			for i = first, last do
				table.insert(items, i)
			end
		else
			local range = first - last
			local id = first
			
			for i = 0, range do
				table.insert(items, id)
				id = id - 1
			end
		end
	end
	
	for k,v in pairs(items) do
		if GetItemInfo(v) then
			self:Print(("Item #%i:"):format(v), GREEN("Cached:"), GetItemLink(v))
		elseif GetItemIcon(v) then
			self:Print(("Item #%i:"):format(v), YELLOW("Not cached"))
		else
			self:Print(("Item #%i:"):format(v), RED("Missing from game files"))
		end
	end
end

function Weagle:ShowStats()
	local cached = tableitems(ITEMS.cached)
	local failed = tableitems(ITEMS.failed)
	self:Print(("Items: %s cached, %s failed, %s requests in total"):format(GREEN(cached), RED(failed), YELLOW(cached+failed)))
	self:Print("Last item processed:", YELLOW(Weagle_data.Item_last))
end

function Weagle:ResetStats()
	ITEMS.processed = { cached = {}, failed = {} }
	self:Print("Statistics have been reset")
end

function Weagle:HandleSniffRequest(msg)
	msg = gsub(msg, "last", tostring(Weagle_data.Item_last))
	
	Weagle:Print("Processing items: " .. msg)
	
	local items = {}
	
	if tonumber(msg) then
		items = { tonumber(msg) }
	
	elseif msg:match("%-") then
		local first, last = msg:match("(%d+)%-(%d+)")
		first, last = tonumber(first), tonumber(last)
		local max = ITEMS.max
		
		if first < last then
			if last > max then -- Avoid freezes
				Weagle:Print("Warning: last > max item id, replacing by " .. max)
				last = max
			end
			for i = first, last do
				table.insert(items, i)
			end
		else
			if first > max then -- Avoid freezes
				Weagle:Print("Warning: first > max item id, replacing by " .. max)
				first = max
			end
			local range = first - last
			local id = first
			
			for i = 0, range do
				table.insert(items, id)
				id = id - 1
			end
		end
	
	elseif msg:match(',') then
		for id in msg:gmatch('(%d+)') do
			table.insert(items, tonumber(id))
		end
	
	else return end
	
	self:SniffItems(items)
end

function Weagle:SniffItems(items)
	for k, v in pairs(items) do
		ITEMS.get[#ITEMS.get+1] = v
	end
--	if not Weagle:IsEventScheduled('Weagle:DataGrabber') then -- TODO
	Weagle:CancelAllTimers()
	Weagle:GrabData()
end

function Weagle:StopSniffing()
	Weagle:CancelAllTimers() -- TODO: :CancelTimer(handle) etc
	Weagle:Print("Item processing cancelled.")
	Weagle:ShowStats()
	ITEMS.get = {}
	QUESTS.get = {}
end

function Weagle:GrabData()
	if ITEMS.previous then -- last item has been cached
		local id = ITEMS.previous
		local _, link = GetItemInfo(ITEMS.previous)
		if link then
			if ITEMS.settings.show_caching then
				self:Print(("Item #%i:"):format(id), GREEN("Caching..."), link, ("%i left"):format(#ITEMS.get))
			end
			ITEMS.cached[id] = true
			Weagle_data.Item_last = id
		else
			if ITEMS.settings.show_failed then
				self:Print(("Item #%i:"):format(id), RED("Failed."), ("%i left"):format(#ITEMS.get))
			end
			ITEMS.failed[id] = true
			Weagle_data.Item_last = ITEMS.previous
			self:ScheduleTimer("GrabData", 4.5)
			ITEMS.previous = nil
			return
		end
		ITEMS.previous = nil
	end

	if ITEMS.get[1] then -- there are still items to process
		local id = ITEMS.get[1]
		
		if ITEMS.settings.use_dbc then
			if not GetItemIcon(id) then -- We check if the item exists in Item.dbc
				if ITEMS.settings.show_invalid then
					self:Print(("Item #%i:"):format(id), YELLOW("Skipping invalid item"))
				end
				table.remove(ITEMS.get, 1)
				return self:GrabData()
			end
		end
		
		if GetItemInfo(id) then
			local _, link = GetItemInfo(id)
			if ITEMS.settings.show_cached then
				self:Print(("Item #%i:"):format(id), YELLOW("Skipping cached item"), link)
			end
			Weagle_data.Item_last = id
			table.remove(ITEMS.get, 1)
			
			return self:GrabData()
		end
		
		if ITEMS.failed[id] then
			Weagle_data.Item_last = id
			table.remove(ITEMS.get, 1)
			ITEMS.skip[id] = 1
			
			return self:GrabData()
		end
		
		if tablein(id, blacklist) then
			self:Print(("Item #%i:"):format(id), YELLOW("Skipping blacklisted item"))
			
			table.remove(ITEMS.get, 1)
			ITEMS.skip[id] = 1
			
			return self:GrabData()
		end
		
		WeagleItemTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
		WeagleItemTooltip:SetHyperlink("item:" .. id)
		WeagleItemTooltip:Show()
		ITEMS.previous = id
		Weagle:ScheduleTimer("GrabData", 0.8)
		
		table.remove(ITEMS.get, 1)
	else
		self:CancelAllTimers() -- TODO use handle
		self:Print("Item processing finished.")
		self:ShowStats()
	end
end


function Weagle:ScanSpellList()
	local name, link, i
	local ids = {}
	for k, v in pairs(WEAGLE_SPELLS) do
		link = GetSpellRealLink(k) or CreateSpellLink(k, DELETED_SPELLS[k])
		i = 0
		for _k, _v in pairs(v) do
			if not GetItemInfo(_v) then
				i = i+1
				table.insert(ids, _v)
			end
			if i > 0 then
				SendChatMessage(link, "WHISPER", nil, UnitName("player"))
			end
		end
	end
	self:SniffItems(ids)
end


--[[
-- Quests
--]]

function Weagle:SniffQuestsRange(qf, ql)
	Weagle:Print("[QUESTS] Processing: " .. qf .. "-" .. ql)
	currentQuestId = tonumber(qf)
	lastQuestId = tonumber(ql)
	Weagle:QuestSniffer()
end

function Weagle:QuestSniffer()
	questnext = currentQuestId + QUESTS.settings.batch_amount - 1
	Weagle:Print("[QUESTS] Caching Quests: " .. currentQuestId .. "-" .. questnext .. "...")
	
	for toqsniff = currentQuestId, questnext do
		WeagleQuestTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
		WeagleQuestTooltip:SetHyperlink("quest:" .. toqsniff)
	end
	
	currentQuestId = questnext + 1
	if currentQuestId < lastQuestId then
		Weagle:ScheduleTimer("QuestSniffer", QUESTS.settings.throttle_batch)
	else
		Weagle:Print("[QUESTS] Sniffing finished.")
	end
end


SLASH_WEAGLE1 = "/weagle"
SLASH_WEAGLE2 = "/wdb"
SlashCmdList["WEAGLE"] = chatcommand

SLASH_PICKUP1 = "/pickup"
SlashCmdList["PICKUP"] = PickupItem
