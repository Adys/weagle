LinkHover = Weagle:NewModule("Link Hover", "AceHook-3.0")

local mod = LinkHover
mod.modName = "Link Hover"

local strmatch = _G.string.match
local linkTypes = {
	achievement	= true,
	channel	= false,
	enchant	= true,
	glyph		= true,
	item		= true,
	player	= false,
	quest		= true,
	spell		= true,
	talent	= true,
	unit		= true,
}

function mod:OnEnable()
	for i = 1, NUM_CHAT_WINDOWS do
		local frame = _G["ChatFrame"..i]
		self:HookScript(frame, "OnHyperlinkEnter", enter)
		self:HookScript(frame, "OnHyperlinkLeave", leave)
	end
end

function mod:OnHyperlinkEnter(f, link)
	local t = strmatch(link, "^(.-):")
	if IsAltKeyDown() then
		Weagle:Print(link)
	end
	if linkTypes[t] then
		ShowUIPanel(GameTooltip)
		GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
		GameTooltip:SetHyperlink(link)
		GameTooltip:Show()
	end			
end

function mod:OnHyperlinkLeave(f, link)
	local t = strmatch(link, "^(.-):")
	if linkTypes[t] then
		HideUIPanel(GameTooltip)
	end
end

function mod:Info()
	return "Makes link tooltips show when you hover them in chat."
end
