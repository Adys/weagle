local maxitems = 100
local DEFAULT_LIST = "ITEM: Bookmarks"
local DEFAULT_INVALID_ICON = Weagle_data.icon_invalid

WeagleGUI = Weadgets:NewPanel("WeagleGUI")


local f = CreateFrame("ScrollFrame", "WeagleGUIListsScroller", WeagleGUI, "UIPanelScrollFrameTemplate")
f:SetPoint("LEFT", -20)
f:SetWidth(210)
f:SetHeight(420)

f = CreateFrame("Frame", "WeagleGUILists", WeagleGUIListsScroller)
f:SetAllPoints(WeagleGUIListsScroller)
WeagleGUIListsScroller:SetScrollChild(f)

f = CreateFrame("ScrollFrame", "WeagleGUIContentScroller", WeagleGUI, "UIPanelScrollFrameTemplate")
f:SetPoint("RIGHT")
f:SetWidth(550)
f:SetHeight(420)

f = CreateFrame("Frame", "WeagleGUIContent", WeagleGUI)
--f:SetAllPoints(WeagleGUIContentScroller)
WeagleGUIContentScroller:SetScrollChild(f)
f:SetPoint("RIGHT")
f:SetWidth(550)
f:SetHeight(420)


f = CreateFrame("Frame", "WeagleGUIList0", WeagleGUIListsScroller) -- Anchor frame for WeagleGUIList1
f:SetPoint("TOP")
f:SetWidth(210)
f:SetHeight(1)

f = CreateFrame("Frame", "WeagleGUIListItem0", WeagleGUIContent) -- Anchor frame for WeagleGUIListItem1
f:SetPoint("TOP")
f:SetWidth(550)
f:SetHeight(1)


function WeagleGUI:NewList(name, num)
	local fname = "WeagleGUIList" .. num
	local f = CreateFrame("Button", fname, WeagleGUILists)
	f:SetPoint("TOP", "WeagleGUIList" .. num-1, "BOTTOM")
	f:SetWidth(210)
	f:SetHeight(16)

	f:SetText(name)
	f:SetNormalFontObject(GameFontHighlight)
	
	f:SetScript("OnClick", function() if IsShiftKeyDown() then Weagle:SniffItems(pages[name]) else Weagle:ShowList(name) end end)
	
	f:Show()
end

function WeagleGUI:NewListItem(n)
	local f = CreateFrame("Frame", "WeagleGUIListItem" .. n, WeagleGUIContent)
	f:SetPoint("TOP", "WeagleGUIListItem" .. n-1, "BOTTOM")
	f:SetWidth(550)
	f:SetHeight(38)
	f:SetBackdrop({
		bgFile =   "interface/tooltips/ui-tooltip-background",
		edgeFile = "interface/tooltips/ui-tooltip-border",
		tile = true, tileSize = 16, edgeSize = 14,
		insets = { left = 5, right = 6, top = 6, bottom = 5 }
	})
	
	return f
end

function WeagleGUI:NewIcon(name, parent, path)
	local f = CreateFrame("Button", name, parent)
	f:SetPoint("LEFT")
	f:SetWidth(26)
	f:SetHeight(26)
	f:SetScript("OnClick", function(self, button) Weagle:HandleIconClick(self, button, self:GetParent().obj, self:GetParent().id) end)
	f:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetHyperlink(self:GetParent().obj .. ":" .. self:GetParent().id)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
	
	f.t = f:CreateTexture(name .. "Texture", "ARTWORK")
	f.t:SetTexture("interface/icons/temp")
	f.t:SetPoint("LEFT")
	f.t:SetWidth(24)
	f.t:SetHeight(24)
	
	return f
end

function Weagle:AddListItem(obj, id, n)
	local icon, name
	
	local FrameName = "WeagleGUIListItem" .. n
	
	local f = _G[FrameName] or WeagleGUI:NewListItem(n)
	f:SetBackdropColor(0, 0.18, 0.35)
	
	local nameframe = _G[FrameName .. "Title"]
	
	if obj == "item" then
		icon, name = GetItemIcon(id), GetItemLink(id)
		if not icon then
			icon = DEFAULT_INVALID_ICON
			name = "Invalid item #" .. id
			f:SetBackdropColor(1, 0.3, 0.3)
		elseif not name then
			name = "Uncached item #" .. id
			f:SetBackdropColor(1, 0.5, 0)
		end
	end
	
	local txt = "#" .. id .. " - " .. name
--	iconframe:SetTexture(icon)
	local _ = _G[FrameName.."Icon"] or WeagleGUI:NewIcon(FrameName.."Icon", f, "LEFT", icon)
	_.t:SetTexture(icon)
	local _ = _G[FrameName.."Title"] or Weadgets:NewText(FrameName.."Title", f, "CENTER", txt)
	_:SetText(txt) -- ugly
	
	
	f.obj = obj
	f.id = id
	f:Show()
end

function Weagle:ClearList()
	for _, f in ipairs({ WeagleGUIContent:GetChildren() }) do
		if f:GetName() ~= "WeagleGUIListItem0" then
			f:Hide()
		end
	end
end

function Weagle:SendLink(obj, id)
	local msg
	if obj == "item" then
		msg = GetItemLink(id)
	end
	
	if msg then
		Weagle:SendMsg(msg)
	end
end

function Weagle:GUISetName(f, name)
	local Frame = _G[f:GetName() .. "Texture"]
	IconFrame:SetTexture(icon)
	f:Show()
	IconFrame:Show()
end


function Weagle:AddPageNav(min, name)
--	WeagleGUINextButton:SetScript("OnClick", function() Weagle:ShowList(name, min) WeagleGUIPageChooser:SetText((min+maxitems)/maxitems) end)
--	WeagleGUINextButton:Enable()
--	WeagleGUIPageChooser:SetScript("OnEnterPressed", function() Weagle:ShowList(name, tonumber(WeagleGUIPageChooser:GetText()) * maxitems - maxitems) WeagleGUIPageChooser:ClearFocus() end)
--	
--	if min-maxitems >= maxitems then
--		WeagleGUIPrevButton:SetScript("OnClick", function() local num = min-maxitems*2 Weagle:ShowList(name, num) WeagleGUIPageChooser:SetText((num+maxitems)/maxitems) end)
--		WeagleGUIPrevButton:Enable()
--	end
end

function Weagle:ShowList(name, min)
	Weagle:ClearList()
	min = min or 0
	local i = 0
	local last
	
	for k,v in pairs(pages[name]) do
		if i < min+maxitems then -- if 0 < 0+100; if 100 < 0+100; if 100 < 100+100;
			if i >= min then -- if 0 >= 0; if 0 >= 100; if 100 >= 0; if 100 >= 100;
				Weagle:AddListItem("item", v, i-min+1) -- 0-0;
			end
			i=i+1
		end
	end
--	WeagleGUIPageChooser:SetText(1)
	if i == min+maxitems then -- if 100 == 0+100; if 200 == 100+100
		Weagle:AddPageNav(i, name)
	end
end

function WeagleGUI:ShowAllLists()
	local i = 1
	for k,v in pairs(pages) do
		WeagleGUI:NewList(k, i)
		i = i+1
	end
end
