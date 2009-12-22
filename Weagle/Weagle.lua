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
				for i=1, Weagle.settings.item.max do
					if GetItemInfo(i) then cached = cached + 1 end
				end
				return Weagle:Print("Total cached items:", cached)
			elseif input == "scandbc" then
				Weagle:ScanItemDBC()
			elseif input == "stop" then
				return Weagle:StopSniffing() -- TODO item handle only
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
			throttle_batch = 5.0,  -- Wait time after every batch
			show_batches   = true, -- Feedback on processed batches
			batch_amount   = 100,  -- How many objects per batch
		},
		chatcommand = function(input)
			Weagle:SniffQuestsRange(1, Weagle.settings.quest.max)
			return Weagle:Print("TODO")
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
		Weagle:ResetSettings()
	end
	
	pages["ITEM: Item.dbc"] = Weagle_data.itemdbc
end


function Weagle:GameInfo()
	Weagle:Print("WoW version "..VERSION.."."..BUILD..", TOC "..TOC.." compiled on "..COMPILED.." - Server: "..SERVER)
end

function Weagle:GetRecentlyCached()
	for k, v in pairs(ITEMS.cached) do
		Weagle:Print("Recently cached: Item #" .. k .. " - " .. GetItemLink(k))
	end
	Weagle:Print(tableitems(ITEMS.cached) .. " items found.")
end

function Weagle:ScanItemDBC()
	Weagle_data.itemdbc = {}
	local items = Weagle_data.itemdbc
	
	for i = 1, ITEMS.max do
		local icon = GetItemIcon(i)
		if icon then
			items[#items+1] = i
		end
	end
	
	Weagle:Print("Saved " .. #items .. " items for this build.")
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
			Weagle:Print("Item #"..v..": |cff00ff00Cached|r - " .. GetItemLink(v))
		elseif GetItemIcon(v) then
			Weagle:Print("Item #"..v..": |cffffff00Not cached|r")
		else
			Weagle:Print("Item #"..v..": |cffff0000Missing from game files|r")
		end
	end
end

function Weagle:ShowStats()
	Weagle:Print("Items: |cff00ff00" .. tableitems(ITEMS.cached) .. "|r cached, |cffff0000" .. tableitems(ITEMS.failed) .. "|r failed, |cffffff00" .. tableitems(ITEMS.cached)+tableitems(ITEMS.failed) .. "|r requests in total. Type |cffffff00/wdb resetstats|r to reset the statistics.")
	Weagle:Print("Last item processed: |cffffff00" .. Weagle_data.Item_last .. "|r")
end

function Weagle:ResetStats()
	ITEMS.processed = { ["cached"] = {}, ["failed"] = {} }
	Weagle:Print("Statistics have been reset")
end

-- ===================================
-- Quest Sniffer
-- ===================================
function Weagle:SniffQuestsRange(qf, ql)
	Weagle:Print("[QUESTS] Processing: " .. qf .. "-" .. ql)
	currentQuestId = tonumber(qf)
	lastQuestId = tonumber(ql)
	Weagle:QuestSniffer()
end

function Weagle:HandleSniffRequest(msg)
	print(msg)
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
	
	Weagle:SniffItems(items)
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
				self:Print("Item #" .. id .. ': |cff00ff00Caching...|r ' .. link .. ' - ' .. #ITEMS.get .. ' left')
			end
			ITEMS.cached[id] = true
			Weagle_data.Item_last = id
		else
			if ITEMS.settings.show_failed then
				self:Print("Item #" .. ITEMS.previous ..': |cffff0000Processing failed.|r ' .. #ITEMS.get .. ' left')
			end
			ITEMS.failed[id] = true
			Weagle_data.Item_last = ITEMS.previous
			Weagle:ScheduleTimer("GrabData", 4.5)
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
					Weagle:Print("Item #" .. id..': |cffffff00Skipping invalid item.|r')
				end
				table.remove(ITEMS.get, 1)
				return Weagle:GrabData()
			end
		end
		
		if GetItemInfo(id) then
			local _, link = GetItemInfo(id)
			if ITEMS.settings.show_cached then
				Weagle:Print('Item #' .. id ..': |c00FFFF00Skipping cached item. |r' .. link)
			end
			Weagle_data.Item_last = id
			table.remove(ITEMS.get, 1)
			
			return Weagle:GrabData()
		end
		
		if ITEMS.failed[id] then
			Weagle_data.Item_last = id
			table.remove(ITEMS.get, 1)
			ITEMS.skip[id] = 1
			
			return Weagle:GrabData()
		end
		
		if tablein(id, blacklist) then
			Weagle:Print("Item #" .. id ..": |c00FFFF00Skipping blacklisted item. |r")
			
			table.remove(ITEMS.get, 1)
			ITEMS.skip[id] = 1
			
			return Weagle:GrabData()
		end
		
		WeagleItemTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
		WeagleItemTooltip:SetHyperlink("item:" .. id)
		WeagleItemTooltip:Show()
		ITEMS.previous = id
		Weagle:ScheduleTimer("GrabData", 0.8)
		
		table.remove(ITEMS.get, 1)
	else
		self:CancelAllTimers() -- TODO use handle
		Weagle:Print("Item processing finished.")
		Weagle:ShowStats()
	end
end


SLASH_WEAGLE1 = "/weagle"
SLASH_WEAGLE2 = "/wdb"
SlashCmdList["WEAGLE"] = chatcommand
