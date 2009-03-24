local WeagleLibTooltip = CreateFrame("GameTooltip", "WeagleLibTooltip", UIParent, "GameTooltipTemplate")
WeagleLibTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
WeagleLibTooltip:SetPoint("CENTER", "UIParent")
WeagleLibTooltip:Hide()

-- local DEFAULT_ICON = "interface/icons/inv_misc_questionmark"

local function Trace(...)
	print("|c336666ffWeagleLib|r:", ...)
end


-- Max IDs
WeagleLib_MaxIDs = {
	["Achievement"]	= 5000,
	["Creature"]	= 40000,
	["Glyph"]		= 1000,
	["Item"]		= 50000,
	["Quest"]		= 18000,
	["Spell"]		= 80000,
	["Talent"]		= 5000,
}

-- Tooltip parsing

local function SetTooltipHack(link) -- XXX
	WeagleLibTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
	WeagleLibTooltip:SetHyperlink("spell:1")
	WeagleLibTooltip:Show()
	WeagleLibTooltip:SetHyperlink(link)
end

local function UnsetTooltipHack() -- XXX
	WeagleLibTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
	WeagleLibTooltip:Hide()
end

function ScanTooltip(link)
	SetTooltipHack(link)
	
	local lines = WeagleLibTooltip:NumLines()
	local tooltiptxt = ""
	
	for i = 1, lines do
		local left = _G["WeagleLibTooltipTextLeft"..i]:GetText()
		local right = _G["WeagleLibTooltipTextRight"..i]:GetText()
		
		if left then
			tooltiptxt = tooltiptxt .. left
			if right then
				tooltiptxt = tooltiptxt .. "\t" .. right .. "\n"
			else
				tooltiptxt = tooltiptxt .. "\n"
			end
		elseif right then
			tooltiptxt = tooltiptxt .. right .. "\n"
		end
	end
	
	UnsetTooltipHack()
	return tooltiptxt
end

function GetTooltipLine(link, line, side)
	side = side or "Left"
	SetTooltipHack(link)
	
	local lines = WeagleLibTooltip:NumLines()
	if line > lines then return UnsetTooltipHack() end
	
	local text = _G["WeagleLibTooltipText"..side..line]:GetText()
	
	UnsetTooltipHack()
	return text
end

function GetTooltipLines(link, ...)
	local lines = {}
	SetTooltipHack(link)
	
	for k,v in pairs({...}) do
		lines[#lines+1] = _G["WeagleLibTooltipTextLeft"..v]:GetText()
	end
	
	UnsetTooltipHack()
	return unpack(lines)
end


-- Item functions

function GetItemLink(id)
	local _, link = GetItemInfo(id)
	return link
end

function GetItemQuality(id)
	local _, _, quality = GetItemInfo(id)
	return quality
end

function GetItemLevel(id)
	local _, _, _, lvl = GetItemInfo(id)
	return lvl
end

function GetItemIconName(id)
	local icon = GetItemIcon(id)
	if not icon then return end
	icon = gsub(strlower(icon), "interface\\icons\\", "")
	return icon
end

function GetItemDisenchantInfo(id)
	if not SpellIsTargeting() then return end
	
	local _, _, lvl = string.find(ScanTooltip("item:"..id), "Disenchanting requires Enchanting %((%d+)%)")
	return tonumber(lvl)
end

GetItemExtInfo = GetItemInfo
GetItemExtLink = GetItemLink


-- Achievement functions

function GetAchievementIcon(id)
	local _, _, _, _, _, _, _, _, _, icon = GetAchievementInfo(id)
	return icon
end

function GetAchievementName(id)
	local _, name = GetAchievementInfo(id)
	return name
end

function GetAchievementExtInfo(id)
	local _, name, points, isach, cat, subcat, descr, something, icon, somethingelse = GetAchievementInfo(id)
	if not name then return end
	
	return name, points, isach, cat, subcat, descr, something, icon, somethingelse
end

GetAchievementExtLink = GetAchievementLink


-- Spell functions

function GetSpellIcon(id)
	_, _, icon = GetSpellInfo(id)
	return icon
end

function GetSpellExtLink(id)
	-- ffs blizz ...
	local name = GetSpellInfo(id)
	if not name then return end
	local link = GetSpellLink(id)
	
	if link then
		return link, true
	else -- Spell exists but is unlinkable
		local reallink = "|cff71d5ff|Hspell:" .. id .. "|h[" .. name .. "]|h|r"
		return reallink, false
	end
end

GetSpellExtInfo = GetSpellInfo


-- Creature functions

function GetCreatureInfo(id) -- GenerateGUID
	local hexid = strupper(string.format("%x", id))
	if id < 4096 then hexid = "0" .. hexid end
	if id < 256 then hexid = "0" .. hexid end
	if id < 16 then hexid = "0" .. hexid end
	local guid = "0xF13000" .. hexid .. "000000" -- Adding 373 at the end removes the mob type (humanoid...)
	local name = GetTooltipLine("unit:" .. guid, 1)
	if not name then return end
	local link = "|cffffffff|Hunit:" .. guid .. ":" .. name .. "|h[" .. name .. "]|h|r"
	
	return name, hexid, guid, link
end

function GetCreatureLink(id)
	local _, _, _, link = GetCreatureInfo(id)
	
	return link
end

GetCreatureExtInfo = GetCreatureInfo
GetCreatureExtLink = GetCreatureLink


-- Talent functions

function GetTalentExtInfo(id)
	local name, rank = GetTooltipLines("talent:" .. id, 1, 2)
	if name == "Word of Recall (OLD)" then return end -- Invalid tooltips' names.. go figure.
	local _, _, ranks = string.find(rank, "Rank 0/(%d+)") -- I know there's no talent with over 5 ranks ingame, but still
	local link = "|cff4e96f7|Htalent:" .. id .. ":-1|h[" .. name .. "]|h|r"
	
	return name, ranks, link
end

function GetTalentExtLink(id)
	local _, _, link = GetTalentExtInfo(id)
	
	return link
end


-- Glyph functions

function GetGlyphInfo(id)
	local name, gtype, text = GetTooltipLines("glyph:21:" .. id, 1, 2, 3) -- Always returns Major Glyph
	
	if name == "Empty" then return end -- All invalid tooltips are shown as an empty glyph slot
	
	local link = "|cff66bbff|Hglyph:21:" .. id .. "|h[" .. name .. "]|h|r"
	local icon = "interface/icons/trade_engineering" -- :(
	
	return name, gtype, text, link, icon
end

function GetGlyphIcon(id)
	local _, _, _, _, icon = GetGlyphInfo(id)
	
	return icon
end

function GetGlyphLink(id)
	local _, _, _, link = GetGlyphInfo(id)
	
	return link
end

GetGlyphExtInfo = GetGlyphInfo
GetGlyphExtLink = GetGlyphLink


-- Quest functions

function GetQuestInfo(id)
	local name = GetTooltipLine("quest:" .. id, 1)
	local lvl = 80
	
	return name, lvl
end

function GetQuestExtInfo(id)
	local name, lvl = GetQuestInfo(id)
	if not name then return end
	
	local link = "|cffffff00|Hquest:" .. id .. ":" .. lvl .. "|h[" .. name .. "]|h|r"
	
	return name, lvl, link
end

function GetQuestExtLink(id)
	local _, _, link = GetQuestExtInfo(id)
	
	return link
end

-- Unit/NPC functions

function GetUnitId(unit)
	guid = UnitGUID(unit)
	id = tonumber(string.sub(guid,6,12), 16)
	return id
end

function GetUnitInfo(unit)
	local guid = UnitGUID(unit)
	local id = GetUnitId(unit)
	local name, title = UnitName(unit)
	local lvl = UnitLevel(unit)
	local health = UnitHealthMax(unit)
	local power = UnitManaMax(unit)
	local powertype = UnitPowerType(unit)
	
	return guid, id, name, title, lvl, health, power, powertype
end


-- IsCached functions

function IsItemCached(id)
	return GetItemInfo(id) ~= nil
end

function IsQuestCached(id)
	WeagleLibTooltip:SetHyperlink("quest:" .. id)
	return WeagleLibTooltip:NumLines() > 0
end


-- Link functions

function GetLinkData(link)
	if link:match("|H") then -- convert the link to a linkstring if necessary
		link = link:match("|H(%w+:[^:]+)")
	end
	
	return link:match("(%w+):([^:]+)")
end

function EscapeLink(link)
	link = gsub(link, "|", "||")
	return link
end

function MakeLink(link, text, color)
	color = color or "ffffff00"
	
	local full = "|c" .. color .. "|H" .. link .. "|h" .. text .. "|h|r"
	full = gsub(full, "||", "|")
	
	return full
end

function MakeHeirloomLink(id, name, lvl)
	link = "|cffe6cc80|Hitem:" .. id .. ":0:0:0:0:0:0:0:" .. lvl .. "|h[" .. name .. "]|h|r"
	return link
end


-- Find functions

function FindAPIObject(ftype, min, max, criteria)
	local GetInfo = _G["Get" .. ftype .. "ExtInfo"]
	
	local found = {}
	
	for i = min, max do
		if GetInfo(i) then
			local matches = true
			local item = {GetInfo(i)}
			for k, v in pairs(criteria) do
				if v then
					if type(v) == "string" then -- Maybe needs some cleanup
						if not strlower(item[k]):match(strlower(v)) then
							matches = false
							break
						end
					elseif type(v) == "table" then
						if not ((item[k] >= v[1]) and (item[k] <= v[2])) then
							matches = false
							break
						end
					elseif v ~= item[k] then
						matches = false
						break
					end
				end
			end
			if matches then
				table.insert(found, i)
			end
		end
	end
	
	return found
end

function FindAchievement(min, max, ...)
--	local id, name, ... = ...
	return FindAPIObject("Achievement", min, max, {...})
end

function FindCreature(min, max, ...)
--	local name, hexid, guid, link = ...
	return FindAPIObject("Creature", min, max, {...})
end

function FindGlyph(min, max, ...)
--	local name, type, descr, link, icon = ...
	return FindAPIObject("Glyph", min, max, {...})
end

function FindItem(min, max, ...)
--	local name, link, quality, level, reqlevel, type, subtype, stack, slot, icon = ...
	return FindAPIObject("Item", min, max, {...})
end

function FindQuest(min, max, ...)
	-- Use carefully, it requests the quests even if they aren't cached.
--	local name, level, link = ...
	return FindAPIObject("Quest", min, max, {...})
end

function FindSpell(min, max, ...)
--	local name, rank, icon, level, mana, _, _, _, _, range = ...
	return FindAPIObject("Spell", min, max, {...})
end

function FindTalent(min, max, ...)
	-- local name, ranks, link = ...
	return FindAPIObject("Talent", min, max, {...})
end

function QuickFindAPIObject(msg, ftype)
	local max = WeagleLib_MaxIDs[ftype]
	local Find = _G["Find" .. ftype]
	local GetInfo = _G["Get" .. ftype .. "ExtInfo"]
	local GetLink = _G["Get" .. ftype .. "ExtLink"]
	
	local found = {}
	
	if msg:match("%d+%-%d+") then
		local first, last = msg:match("(%d+)%-(%d+)")
		found = Find(first, last)
	elseif tonumber(msg) then
		if GetInfo(msg) then
			found = {tonumber(msg)}
		end
	else
		found = Find(1, max, msg)
	end
	
	for k, v in pairs(found) do
		Trace(ftype .. " #" .. v, GetLink(v))
	end
	
	Trace(#found .. " matches.")
end
