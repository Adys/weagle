Weadgets = {}

function Weadgets:NewPanelBackground(name)
	local frame = CreateFrame("Frame", name .. "Panel", UIParent)
	frame:SetWidth(790)
	frame:SetHeight(440)
	frame:SetPoint("CENTER")
	frame:SetMovable(true)
	frame:EnableMouse()
	frame:SetBackdrop({
		bgFile =   "interface/dialogframe/ui-dialogbox-background",
		edgeFile = "interface/tooltips/ui-tooltip-border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 5, bottom = 5 }
	})
	return frame
end

function Weadgets:NewTitleBar(name, parent)
	local title = CreateFrame("Frame", name .. "TitleBar", parent)
	title:EnableMouse()
	title:SetWidth(128)
	title:SetHeight(28)
	title:SetPoint("TOP", 0, 28)
	title:SetBackdrop({
		bgFile =   "interface/dialogframe/ui-dialogbox-background",
		edgeFile = "interface/dialogframe/ui-dialogbox-border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 5, bottom = 5 }
	})
	title:SetScript("OnMouseDown", function(self) self:GetParent():StartMoving() end)
	title:SetScript("OnMouseUp", function(self) self:GetParent():StopMovingOrSizing() end)
	
	title:SetClampedToScreen() -- The title is the only moving point of the main panel, we don't want it going offscreen
	
	return title
end

function Weadgets:NewCloseBtn(name, parent)
	local close = CreateFrame("Button", name .. "CloseButton", parent, "UIPanelCloseButton")
	close:SetWidth(30)
	close:SetHeight(30)
	close:SetPoint("TOPRIGHT", 22, 22)
	return close
end

function Weadgets:NewEditBox(name, parent, relative, point, width, offx, offy, onenter, defaulttxt)
	local box = CreateFrame("EditBox", name, parent)
	box:SetHeight(16)
	box:SetWidth(width)
	box:SetPoint(point, relative, offx, offy)
	box:SetAutoFocus(false)
	
	box.t = box:CreateTexture(name .. "Texture", "BACKGROUND")
	box.t:SetTexture("interface/common/common-input-border")
	box.t:SetPoint("LEFT", -6, -6)
	box.t:SetWidth(width+5)
	box.t:SetHeight(32)
	
	box:SetFontObject(ChatFontNormal)
	
	if onenter then box:SetScript("OnEnterPressed", onenter) end
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	if defaulttxt then
		box:SetText(defaulttxt)
		box:SetScript("OnEditFocusGained", function(self)
			if self:GetText() == defaulttxt then
				self:SetText("")
			else
				self:HighlightText()
			end
		end)
		box:SetScript("OnEditFocusLost", function(self)
			if self:GetText() == "" then
				self:SetText(defaulttxt)
			else
				self:HighlightText(0, 0)
			end
		end)
	end
	
	return box
end

function Weadgets:NewText(name, parent, point, txt)
	f = parent:CreateFontString(name, "ARTWORK", "GameFontNormal")
	f:SetPoint(point)
	f:SetText(txt)
	
	return f
end

function Weadgets:NewPanel(name)
	local panel = 	self:NewPanelBackground(name)
	local title = 	self:NewTitleBar(name, panel)
	local close = 	self:NewCloseBtn(name, panel)
	local titletxt = 	self:NewText(name .. "TitleBarText", title, "CENTER", name)
	
	function panel.Toggle(self)
		if panel:IsVisible() then
			panel:Hide()
		else
			panel:Show()
		end
	end
	
	function panel.Reset(self)
	
	end
	
	function panel.EnableFullScreen(self, fsframe, ontoggle, onshow, onhide)
		panel.FullScreen_Enabled = true
		panel.FullScreen_Frame = fsframe
		panel.OnFullScreenToggle = ontoggle
		panel.OnFullScreenHide = onhide
		panel.OnFullScreenShow = onshow
	end
	
	function panel.ToggleFullScreen(self)
		local fsframe = panel.FullScreen_Frame
		if not panel:IsVisible() then return end
		
		if fsframe:IsVisible() then
			fsframe:Hide()
			if panel.OnFullScreenHide then panel.OnFullScreenHide() end
		else
			fsframe:Show()
			if panel.OnFullScreenShow then panel.OnFullScreenShow() end
		end
		if panel.OnFullScreenToggle then panel.OnFullScreenToggle() end
		
	end
	
	tinsert(UISpecialFrames, name) -- closable with esc
	
	panel:Hide()
	
	return panel
end

function Weadgets:NewFullScreen(name, background)
	local frame = CreateFrame("Frame", name, UIParent)
	frame:SetAllPoints()
	frame:SetFrameStrata("FULLSCREEN")
	frame:SetWidth(UIParent:GetWidth())
	frame:SetHeight(UIParent:GetHeight())
	frame:Hide()
	
	frame.t = frame:CreateTexture(name .. "Texture", "BACKGROUND")
	frame.t:SetTexture(background, true)
	frame.t:SetTexCoord(0, 3, 0, 2)
	frame.t:SetAllPoints()
	frame.t:SetWidth(frame:GetWidth())
	frame.t:SetHeight(frame:GetHeight())
	
	
	return frame
end
