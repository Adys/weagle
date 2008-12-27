
--[[ TODO

Need to implement a nice function to use whispers/says optimally to speed up the caching process.

Implementing a few panels to regroup some stuff. My original plan was to have a settings panel, and a panel
for each type of sniffing - quests, spells, items... maybe more if we can find them.

No rush: Id like to make some useful off-functions, like something to reveal maps fully etc.
--]]


Weagle = LibStub("AceAddon-3.0"):NewAddon("Weagle", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0")
Weagle.name = "Weagle"

local options = Weagle_Options

local QUEST_SNIFF_AMOUNT = 100
local QUEST_SNIFF_DELAY  = 2
local ITEM_FAILED_DELAY  = 4.5
local ITEM_SNIFF_DELAY   = 0.8

local previous
local toget = {}
local processed = { ["cached"] = {}, ["failed"] = {} }
local skip = {}

local currentQuestId
local lastQuestId

local Tooltips = {}
local UnusedTooltips = {}

TooltipAmt = 0

VERSION, BUILD, COMPILED, TOC = GetBuildInfo()
SERVER = GetRealmName()

function tableitems(t) -- Lua sucks
	i=0
	for k,v in pairs(t) do i=i+1 end
	return i
end

function Weagle:ResetSettings()
	Weagle_data = Weagle_DefaultSettings
	Weagle_data.itemdbc = {}
	
	Weagle:Print("All saved settings have been reset. Don't forget to run /weagle scandbc.")
end

if not Weagle_data then Weagle:ResetSettings() end

function Weagle:ChatCommand(input)
	if not input then
		return WeagleGUI:Toggle()
	end
	
	if input:trim() == "" then
		WeagleGUI:Toggle()
		WeagleGUI:ShowAllLists()
	else
		LibStub("AceConfigCmd-3.0").HandleCommand(Weagle, "wdb", "Weagle", input)
	end
end

function Weagle:OnInitialize()
	DEFAULT_CHAT_FRAME:SetMaxLines(5000)
	LibStub("AceConfig-3.0"):RegisterOptionsTable("Weagle", options, {"weagle", "wdb"})
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Weagle", "Weagle")
	
	self:RegisterChatCommand("rl", ReloadUI)
	self:RegisterChatCommand("wdb", "ChatCommand")
	self:RegisterChatCommand("weagle", "ChatCommand")
	
	ChatFrame_OnHyperlinkShow = Weagle_OnHyperlinkShow
	
	CreateFrame("GameTooltip", "WeagleHiddenTooltip", UIParent, "GameTooltipTemplate")
	WeagleHiddenTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
	-- TODO REMOVE THIS CRAP
	CreateFrame("GameTooltip", "WeagleHiddenItemTooltip", UIParent, "GameTooltipTemplate")
	CreateFrame("GameTooltip", "WeagleHiddenQuestTooltip", UIParent, "GameTooltipTemplate")
	
	
	if not Weagle_data then
		Weagle:ResetSettings()
	end
	
	pages["ITEM: Item.dbc"] = Weagle_data.itemdbc
end

function Weagle:OnProfileEnable()

end


-- Tooltips

function Weagle:SetItemRef(link, text, button)
	-- We create our own SetItemRef to
	-- be able to hook it more easily
	if strsub(link, 1, 6) == "player" then
		return SetItemRef(link, text, button) -- We don't care about player links
	elseif strsub(link, 1, 7) == "channel" then
		return SetItemRef(link, text, button) -- We don't care about channel links either
	elseif strsub(link, 1, 5) == "trade" then
		return SetItemRef(link, text, button) -- You got the trick
	end
		
	
	if IsModifiedClick() then
		return HandleModifiedItemClick(text)
	end
	Weagle:SetupTooltip(link)
end


function Weagle:SetHyperlink(f, link)
	local obj, id = GetLinkData(link)
	
	f.obj = obj
	f.id = id
	f:SetOwner(UIParent, "ANCHOR_PRESERVE") -- ffs blizz =(
	f:SetHyperlink(link)
	Weagle:LoadTooltipIcon(_G[f:GetName() .. "Icon"], obj, id)
	
	Tooltips[f] = link
	if not f:IsShown() then
		f:Show()
	end
end

function Weagle_OnHyperlinkShow(self, link, text, button)
	Weagle:SetItemRef(link, text, button)
end

function Weagle:SetupTooltip(link)
	-- Here, we handle all the tooltips. We check for
	-- unused ones, duplicates, otherwise we will
	-- create a new one.
	
	-- First, is it already shown?
	local f = Weagle:IsLinkShown(link)
	if f then
		return Weagle:CloseTooltip(f)
	end
	
	-- Now, is there an unused frame to recycle?
	f = Weagle:UnusedTooltipExists()
	if f then
		table.remove(UnusedTooltips, #UnusedTooltips)
		return Weagle:SetHyperlink(f, link)
	end
	
	-- Ok, we gotta create a new one then
	Weagle:CreateTooltip(link)
end

function Weagle:CreateTooltip(link)
	TooltipAmt = TooltipAmt + 1
	local TooltipName = "WeagleTooltip" .. TooltipAmt
	local f = CreateFrame("GameTooltip", TooltipName, UIParent, "WeagleTooltipTemplate")
	
	f:SetOwner(UIParent, "ANCHOR_PRESERVE")
	Weagle:SetHyperlink(f, link)
	
	if RatingBuster then
		RatingBuster.ProcessTooltip(f, TooltipName, f.obj .. ":" .. f.id)
	end
	
	tinsert(UISpecialFrames, f:GetName()) -- Make it closable with esc
	-- <TODO> Better garbage collection: need to hook CloseSpecialWindows </TODO>
end

function Weagle:UnusedTooltipExists()
	if #UnusedTooltips > 0 then
		return UnusedTooltips[#UnusedTooltips]
	end
end

function Weagle:IsLinkShown(link)
	for k,v in pairs(Tooltips) do
		if link == v and k:IsVisible() then
			return k
		end
	end
	return false
end

function Weagle:CloseTooltip(f)
	if f:IsVisible() then
		f:Hide()
		UnusedTooltips[#UnusedTooltips+1] = f
		Tooltips[f] = nil
	end
end

function Weagle:LoadTooltipIcon(frame, obj, id)
	local icon
	local texture = getglobal(frame:GetName() .. "Texture")
	
	if obj == "item" then
		icon = GetItemIcon(id)
	elseif obj == "spell" or obj == "enchant" then
		icon = GetSpellIcon(id)
	elseif obj == "achievement" then
		icon = GetAchievementIcon(id)
	elseif obj == "unit" then
		return SetPortraitTexture(texture, "player")
	end
	
	if not icon then icon = DEFAULT_ICON end
	
	texture:SetTexture(icon)
end

function Weagle:HandleIconClick(frame, button, obj, id)
	if IsAltKeyDown() and IsControlKeyDown() then
		return frame:Hide()
	end
	
	if obj == "item" then
		if button == "LeftButton" then
			if IsAltKeyDown() and IsShiftKeyDown() then
				PickupItem(id)
			elseif IsAltKeyDown() then
				Weagle:Print(GetItemInfo(id))
			elseif IsControlKeyDown() then
				return DressUpItemLink(id)
			elseif IsShiftKeyDown() then
				local link = GetItemLink(id)
				if ChatFrameEditBox:IsVisible() then
					ChatFrameEditBox:Insert(link)
				else
					Weagle:SendMsg(link)
				end
			end
		end
	end
	
	if obj == "spell" then
		if button == "LeftButton" then
			if IsAltKeyDown() and IsShiftKeyDown() then
				PickupSpell(id)
			elseif IsAltKeyDown() then
				Weagle:Print(GetSpellInfo(id))
			elseif IsShiftKeyDown() then
				local link = GetSpellLink(id)
				if ChatFrameEditBox:IsVisible() then
					ChatFrameEditBox:Insert(link)
				else
					Weagle:SendMsg(link)
				end
			end
		end
	end
	
	if obj == "achievement" then
		if button == "LeftButton" then
			if IsAltKeyDown() then
				Weagle:Print(GetAchievementInfo(id))
			elseif IsShiftKeyDown() then
				local link = GetAchievementLink(id)
				if ChatFrameEditBox:IsVisible() then
					ChatFrameEditBox:Insert(link)
				else
					Weagle:SendMsg(link)
				end
			end
		end
	end
end



function Weagle:GameInfo()
	Weagle:Print("WoW version "..VERSION.."."..BUILD..", TOC "..TOC.." compiled on "..COMPILED.." - Server: "..SERVER)
end

function Weagle:PrintHeirloomRange(id)
	local range = {1, 10, 20, 30, 40, 50, 60, 70, 80}
	
	local name = GetItemInfo(id)
	
	if not name then 
		return Weagle:Print(id .. " not cached.")
	end
	
	local link
	
	for k, lvl in pairs(range) do
		link = MakeHeirloomLink(id, name, lvl)
		Weagle:Print(link, lvl)
	end
end

function Weagle:SendMsg(msg)
	SendChatMessage(msg, "WHISPER", nil, GetUnitName("player"))
end


function Weagle:CountCachedItems()
	local amt = 0
	for i=1, WeagleLib_MaxIDs.Item do
		if IsItemCached(i) then
			amt = amt + 1
		end
	end
	return amt
end

function Weagle:GetRecentlyCached()
	for k, v in pairs(processed.cached) do
		Weagle:Print("Recently cached: Item #" .. k .. " - " .. GetItemLink(k))
	end
	Weagle:Print(tableitems(processed.cached) .. " items found.")
end

function Weagle:ScanItemDBC()
	Weagle_data.itemdbc = {}
	local items = Weagle_data.itemdbc
	
	for i=1, WeagleLib_MaxIDs.Item do
		local icon = GetItemIcon(i)
		if icon then
			items[#items+1] = i
		end
	end
	
	Weagle:Print("Saved " .. #items .. " items for this build.")
end


function Weagle:ShowStats()
	Weagle:Print("Items: |cff00ff00" .. tableitems(processed.cached) .. "|r cached, |cffff0000" .. tableitems(processed.failed) .."|r failed, |cffffff00" .. tableitems(processed.cached)+tableitems(processed.failed) .. "|r requests in total. Type |cffffff00/wdb resetstats|r to reset the statistics.")
	Weagle:Print("Last item processed: |cffffff00" .. Weagle_data.Item_last .. "|r")
end

function Weagle:ResetStats()
	processed = { ["cached"] = {}, ["failed"] = {} }
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

function Weagle:QuestSniffer()
	questnext = currentQuestId + QUEST_SNIFF_AMOUNT - 1
	
	Weagle:Print("[QUESTS] Caching Quests: " .. currentQuestId .. "-" .. questnext .. "...")
	
	local uncachedQuests = 0
	local cachedQuests = 0
	
	for toqsniff = currentQuestId, questnext do
		WeagleHiddenQuestTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
		WeagleHiddenQuestTooltip:SetHyperlink("quest:" .. toqsniff)

		if (WeagleHiddenQuestTooltip:NumLines() == 0) then
			--Weagle:Print("[QUESTS] Requesting uncached quest: " .. toqsniff)
			uncachedQuests = uncachedQuests + 1
		else
			--local text = WeagleHiddenQuestTooltipTextLeft1:GetText()
			--Weagle:Print("[QUESTS] Cached quest: " .. toqsniff .. "[" .. text .. "]")
			cachedQuests = cachedQuests + 1
		end
	end
	
--	Weagle:Print("[QUESTS] Already Cached: " .. cachedQuests)
	
	currentQuestId = questnext + 1

	if(currentQuestId < lastQuestId) then
		Weagle:ScheduleTimer("QuestSniffer", QUEST_SNIFF_DELAY)
	else
		Weagle:Print("[QUESTS] Sniffing finished.")
	end
end


function Weagle:StopQuestSniffing()
	Weagle:ClearAllTimers() -- TODO use handle
	currentQuestId = nil
	lastQuestId = nil
	Weagle:Print('[QUESTS] Forced stop.')
end

function Weagle:HandleSniffRequest(msg)
	if not msg then return end
	msg = gsub(msg, "item ", "")
	msg = gsub(msg, "last", tostring(Weagle_data.Item_last))
	
	Weagle:Print("Processing items: " .. msg)
	
	local items = {}
	
	if tonumber(msg) then
		items = {tonumber(msg)}
	
	elseif msg:match("%-") then
		local first, last = msg:match("(%d+)%-(%d+)")
		first, last = tonumber(first), tonumber(last)
		
		if first < last then
			if last > WeagleLib_MaxIDs.Item then -- Avoid freezes
				Weagle:Print("Warning: last > max item id, replacing by " .. WeagleLib_MaxIDs.Item)
				last = WeagleLib_MaxIDs.Item
			end
			for i = first, last do
				table.insert(items, i)
			end
		else
			if first > WeagleLib_MaxIDs.Item then -- Avoid freezes
				Weagle:Print("Warning: first > max item id, replacing by " .. WeagleLib_MaxIDs.Item)
				first = WeagleLib_MaxIDs.Item
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
	
	elseif msg:match('stop') then
		Weagle:Print('Stopping item sniffing session...')
		return Weagle:StopSniffing()
	
	elseif msg:match('pause') then -- TODO
		Weagle:Print('Stopping item sniffing session...')
		return Weagle:StopSniffing()
	
	else return end
	
	Weagle:SniffItems(items)
end


function Weagle:SniffItems(items)
	for k, v in pairs(items) do
		toget[#toget+1] = v
	end
--	if not Weagle:IsEventScheduled('Weagle:DataGrabber') then -- TODO
	Weagle:CancelAllTimers()
	Weagle:GrabData()
end

function Weagle:StopSniffing()
	Weagle:CancelAllTimers() -- TODO: :CancelTimer(handle) etc
	Weagle:Print("Item processing cancelled.")
	Weagle:ShowStats()
	toget = {}
end

function Weagle:GrabData()
	if previous then -- last item has been cached
		local id = previous
		local _, link = GetItemInfo(previous)
		if link then
			
			Weagle:Print('Item #' .. id .. ': |cff00ff00Caching...|r ' .. link .. ' - ' .. #toget .. ' left')
			
			processed.cached[id] = true
			Weagle_data.Item_last = id
		else
			if Weagle_data.Item_showfailed then
				Weagle:Print('Item #' .. previous ..': |cffff0000Processing failed.|r ' .. #toget .. ' left')
			end
			
			processed.failed[id] = true
			Weagle_data.Item_last = previous
			Weagle:ScheduleTimer("GrabData", ITEM_FAILED_DELAY)
			previous = nil
			return
		end
		previous = nil
	end

	if toget[1] then -- there are still items to process
		local id = toget[1]
		
		if GetItemIcon(id) == nil and Weagle_data.Item_ignoredbc == false then -- We check if the item exists first
			if Weagle_data.Item_showskipped then
				Weagle:Print('Item #' .. id..': |cffffff00Skipping invalid item.|r')
			end
			
			Weagle_data.Item_last = id
			table.remove(toget, 1)
			return Weagle:GrabData()
		end
		
		if IsItemCached(id) then
			local _, link = GetItemInfo(id)
			
			if Weagle_data.Item_showcached then
				Weagle:Print('Item #' .. id ..': |c00FFFF00Skipping cached item. |r' .. link)
			end
			
			Weagle_data.Item_last = id
			table.remove(toget, 1)
			
			return Weagle:GrabData()
			
		elseif processed.failed[id] then
			if Weagle_data.Item_showskipped then
				Weagle:Print('Item #' .. id ..': |c00FFFF00Skipping previously processed item. |r' .. link)
			end
			
			Weagle_data.Item_last = id
			table.remove(toget, 1)
			skip[id] = 1
			
			return Weagle:GrabData()
			
		else
			if Weagle_data.Item_showtooltip then
				ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
				ItemRefTooltip:SetHyperlink("item:" .. id)
				ItemRefTooltip:Show()
			else
				WeagleHiddenItemTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
				WeagleHiddenItemTooltip:SetHyperlink("item:" .. id)
				WeagleHiddenItemTooltip:Show()
			end
			previous = id
			Weagle:ScheduleTimer("GrabData", ITEM_SNIFF_DELAY)
		end
		
		table.remove(toget, 1)
	else
		self:CancelAllTimers() -- TODO use handle
		Weagle:Print("Item processing finished.")
		Weagle:ShowStats()
	end
end
