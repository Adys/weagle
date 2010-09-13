------------
-- Weagle --
------------
-- © 2009 - Jerome Leclanche for MMO-Champion

WEAGLE, Weagle = ...
Weagle.NAME = WEAGLE
Weagle.CNAME = "|cff33ff99" .. Weagle.NAME .. "|r"
Weagle.VERSION = "5.0.0"

-- Shortcut globals
VERSION, BUILD, COMPILED, TOC = GetBuildInfo()
BUILD, TOC = tonumber(BUILD), tonumber(TOC)
SERVER = GetRealmName()
LOCALE = GetLocale()
REAL_LOCALE = GetCVar("locale")
PORTAL, REALMLIST, ACCOUNT = GetCVar("portal"), GetCVar("realmlist"), GetCVar("accountname")

-- Slashcommand aliases
SLASH_PICKUP1 = "/pickup"
SlashCmdList["PICKUP"] = PickupItem
SLASH_RELOAD1 = "/rl"
SlashCmdList["RELOAD"] = ReloadUI
SLASH_GXRESTART1 = "/gx"
SlashCmdList["GXRESTART"] = RestartGx
SLASH_SXRESTART1 = "/sx"
SlashCmdList["SXRESTART"] = Sound_GameSystem_RestartSoundSystem
DEFAULT_CHAT_FRAME:SetMaxLines(5000)

-- Library embedding
LibStub("LibTimer-1.0"):Embed(Weagle)

local MAX_ID_ITEM  = 80000
local MAX_ID_QUEST = 40000

Weagle.settings = {
	item = {
		previous = nil,
		get = {},
		cached = {},
		failed = {},
		skip = {},
		max = MAX_ID_ITEM,
		settings = {
			show_cached     = false, -- Feedback on items already cached
			show_caching    = true,  -- Feedback on successful item queries
			show_failed     = true,  -- Feedback on failed item queries
			show_invalid    = false, -- Feedback on invalid queries (not present in Item.dbc)
			use_dbc         = true,  -- Use Item.dbc and skip item queries accordingly
			use_db          = true,  -- Use Item-sparse.db2 page and skip item queries accordingly
		},
		chatcommand = function(input)
			if input == "cached" then
				return Weagle:GetRecentlyCached()
			
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
		max = MAX_ID_QUEST,
		settings = {
			throttle_batch = 3.0,  -- Wait time after every batch
			show_batches   = true, -- Feedback on processed batches
			batch_amount   = 100,  -- How many objects per batch
		},
		chatcommand = function(input)
			Weagle:Print("fixme: use entire range", input)
			Weagle:SniffQuestsRange(1, Weagle.settings.quest.max)
		end
	},
	
	spell = {
		chatcommand = function(input)
			Weagle:ScanSpellList()
		end
	},
	
	message = {
		get = {},
		settings = {
			throttle = 0.1,
			type = "WHISPER",
			target = UnitName("player"),
		}
	},
}

Weagle.alias = {
	items = "item",
	quests = "quest",
	spells = "spell",
}

local ITEMS = Weagle.settings.item
local QUESTS = Weagle.settings.quest
local MESSAGES = Weagle.settings.message


function Weagle:init()
	self.questTooltip = CreateFrame("GameTooltip", "WeagleQuestTooltip", UIParent, "GameTooltipTemplate")
	
	WeagleLastItem = WeagleLastItem or 0
end

function Weagle:Print(...)
	return print(self.CNAME .. ":", ...)
end

-------------
-- Helpers --
-------------

local function tableitems(t) -- Lua sucks
	local i = 0
	for k, v in pairs(t) do i=i+1 end
	return i
end

local function tablein(i, t)
	for k, v in pairs(t) do
		if i == v then return true end
	end
	return false
end

local function color(color, text)
	return ("|cff%s%s|r"):format(color, text)
end

local function RED(text)
	return color("ff0000", text)
end

local function GREEN(text)
	return color("00ff00", text)
end

local function YELLOW(text)
	return color("ffff00", text)
end

local function chatcommand(input)
	local command
	command, input = input:match("(%w+)%W*(.*)")
	if command then
		command = Weagle.alias[command] or command
		if command == "info" then
			local tpl = "WoW %s.%s (%s/%s), TOC %s, compiled on %s"
			local tpl2 = "Connected as %s on %s :: %s :: %s"
			Weagle:Print(tpl:format(VERSION, BUILD, REAL_LOCALE, LOCALE, TOC, COMPILED))
			Weagle:Print(tpl2:format(ACCOUNT or "(unknown)", PORTAL, REALMLIST, SERVER))
			return
		elseif command == "resetstats" then
			return Weagle:ResetStats()
		elseif command == "stats" then
			return Weagle:ShowStats()
		elseif command == "stop" then
			return Weagle:StopSniffing()
		elseif Weagle.settings[command] and Weagle.settings[command].chatcommand then
			return Weagle.settings[command].chatcommand(input:trim())
		end
	end
	Weagle:Print("Usage: /weagle [item|quest] ...")
end

-- WoW API helpers
local function GetItemLink(id)
	local _, link = GetItemInfo(id)
	return link
end

local function GetSpellRealLink(id) -- GetSpellLink is broken
	local name = GetSpellInfo(id)
	if not name then return end
	local link = GetSpellLink(id)
	
	if not link then -- Spell exists but is unlinkable
		link = ("|cff71d5ff|Hspell:%i|h[%s]|h|r"):format(id, name)
	end
	return link
end

local function CreateSpellLink(id, name) -- Create the spell link for spells that still exist serverside
	if not id or not name then return end
	return ("|cff71d5ff|Hspell:%i|h[%s]|h|r"):format(id, name)
end

--[[
 Weagle API
--]]

function Weagle:GetRecentlyCached()
	local i = 0
	for k, v in pairs(ITEMS.cached) do
		self:Print("Recently cached: Item #" .. k, GetItemLink(k))
		i = i+1
	end
	self:Print(GREEN(i) .. " items found.")
end

function Weagle:ShowStats()
	local cached = tableitems(ITEMS.cached)
	local failed = tableitems(ITEMS.failed)
	self:Print(("Items: %s cached, %s failed, %s requests in total"):format(GREEN(cached), RED(failed), YELLOW(cached+failed)))
end

function Weagle:ResetStats()
	ITEMS.processed = { cached = {}, failed = {} }
	self:Print("Statistics have been reset")
end

function Weagle:HandleSniffRequest(msg)
	msg = gsub(msg, "last", tostring(WeagleLastItem))
	
	self:Print("Processing items", msg)
	
	local items = {}
	
	if tonumber(msg) then
		items = { tonumber(msg) }
	
	elseif msg:match("%-") then
		local first, last = msg:match("(%d+)%-(%d+)")
		first, last = tonumber(first), tonumber(last)
		local max = ITEMS.max
		
		if first < last then
			if last > max then -- Avoid freezes
				self:Print("Warning: last > max item id, replacing by " .. max)
				last = max
			end
			for i = first, last do
				table.insert(items, i)
			end
		else
			if first > max then -- Avoid freezes
				self:Print("Warning: first > max item id, replacing by " .. max)
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
	
	else return end -- Nothing to do
	
	self:SniffItems(items)
end

function Weagle:SniffItems(items)
	for k, v in pairs(items) do
		ITEMS.get[#ITEMS.get+1] = v
	end
	self:GrabData()
end

function Weagle:StopSniffing()
	self:CancelAllTimers()
	self:Print("Item processing cancelled.")
	self:ShowStats()
	ITEMS.get = {}
	QUESTS.get = {}
end

function Weagle:GrabData()
	-- First we check whether the last item queried has been cached
	-- If it is, we leave the routine running
	-- If it isn't, we reschedule for later
	if ITEMS.previous then
		-- There has been a query before
		-- Blank and reschedule
		local id = ITEMS.previous
		ITEMS.previous = nil
		local _, link = GetItemInfo(id)
		if link then -- last item has been cached
			if ITEMS.settings.show_caching then
				self:Print(("Item #%i:"):format(id), GREEN("Caching..."), link, ("%i left"):format(#ITEMS.get))
			end
			ITEMS.cached[id] = true
			WeagleLastItem = id
		else
			if ITEMS.settings.show_failed then
				self:Print(("Item #%i:"):format(id), RED("Failed."), ("%i left"):format(#ITEMS.get))
			end
			ITEMS.failed[id] = true
			WeagleLastItem = ITEMS.previous
			ITEMS.handle = self:ScheduleTimer("GrabData", 0)
			return
		end
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
		
		if ITEMS.settings.use_db then
			if tablein(id, Weagle.db) then
				table.remove(ITEMS.get, 1)
				ITEMS.skip[id] = 1
				
				return self:GrabData()
			end
		end
		
		if GetItemInfo(id) then
			local _, link = GetItemInfo(id)
			if ITEMS.settings.show_cached then
				self:Print(("Item #%i:"):format(id), YELLOW("Skipping cached item"), link)
			end
			WeagleLastItem = id
			table.remove(ITEMS.get, 1)
			
			return self:GrabData()
		end
		
		if ITEMS.failed[id] then
			WeagleLastItem = id
			table.remove(ITEMS.get, 1)
			ITEMS.skip[id] = 1
			
			return self:GrabData()
		end
		
		if tablein(id, Weagle.blacklist) then
			self:Print(("Item #%i:"):format(id), YELLOW("Skipping blacklisted item"))
			
			table.remove(ITEMS.get, 1)
			ITEMS.skip[id] = 1
			
			return self:GrabData()
		end
		
		GetItemInfo(id)
		ITEMS.previous = id
		ITEMS.handle = self:ScheduleTimer("GrabData", 0)
		
		table.remove(ITEMS.get, 1)
	else
		self:CancelAllTimers() -- TODO use handle
		self:Print("Item processing finished.")
		self:ShowStats()
	end
end

function Weagle:SendMessages(messages)
	for k, v in pairs(messages) do
		MESSAGES.get[#MESSAGES.get+1] = v
	end
	
	MESSAGES.handle = self:ScheduleTimer("SendNextMessage", MESSAGES.settings.throttle)
end

function Weagle:SendNextMessage()
	local msg = MESSAGES.get[1]
	
	if msg then
		table.remove(MESSAGES.get, 1)
		SendChatMessage(msg, MESSAGES.settings.type, nil, MESSAGES.settings.target)
		MESSAGES.handle = self:ScheduleTimer("SendNextMessage", MESSAGES.settings.throttle)
	else
		self:GrabData()
	end
end

function Weagle:ScanSpellList()
	local name, link, i
	local ids = {}
	local links = {}
	for k, v in pairs(Weagle.spells) do
		link = GetSpellRealLink(k) or CreateSpellLink(k, Weagle.deleted_spells[k])
		if link then
			i = 0
			for _k, _v in pairs(v) do
				if not GetItemInfo(_v) then
					i = i+1
					table.insert(ids, _v)
				end
				if i > 0 then
					table.insert(links, link)
					self:SniffItems(Weagle.spells)
				end
			end
		end
	end
	self:SendMessages(links)
	self:SniffItems(ids)
end


--[[
-- Quests
--]]

function Weagle:SniffQuestsRange(qf, ql)
	self:Print("[QUESTS] Processing: " .. qf .. "-" .. ql)
	currentQuestId = tonumber(qf)
	lastQuestId = tonumber(ql)
	self:QuestSniffer()
end

function Weagle:QuestSniffer()
	questnext = currentQuestId + QUESTS.settings.batch_amount - 1
	self:Print("[QUESTS] Caching Quests: " .. currentQuestId .. "-" .. questnext .. "...")
	
	for toqsniff = currentQuestId, questnext do
		WeagleQuestTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
		WeagleQuestTooltip:SetHyperlink("quest:" .. toqsniff)
	end
	
	currentQuestId = questnext + 1
	if currentQuestId < lastQuestId then
		QUESTS.handle = self:ScheduleTimer("QuestSniffer", QUESTS.settings.throttle_batch)
	else
		self:Print("[QUESTS] Sniffing finished.")
	end
end


-- Register slash commands
SLASH_WEAGLE1 = "/weagle"
SLASH_WEAGLE2 = "/wdb"
SlashCmdList["WEAGLE"] = chatcommand

Weagle:init()
