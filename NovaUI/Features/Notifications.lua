--!nonstrict
-- Toast stack in the bottom-right corner. Dependencies are injected.
local Notifications = {}
Notifications.__index = Notifications

local MAX_VISIBLE = 5
local TYPES = {
	Success = "check",
	Warning = "warning",
	Error = "close",
	Information = "info",
	Info = "info",
}
local COLORS = { Success = "Success", Warning = "Warning", Error = "Error", Information = "Info", Info = "Info" }

-- makeGui: () -> ScreenGui, called lazily on first use
function Notifications.new(utilities: any, theme: any, animations: any, icons: any, makeGui: () -> any)
	return setmetatable({ U = utilities, theme = theme, anim = animations, icons = icons, makeGui = makeGui, active = {} }, Notifications)
end

function Notifications:_container()
	if self.container and self.gui.Parent then
		return self.container
	end
	local U = self.U
	self.gui = self.makeGui()
	self.container = U.create("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12), Size = UDim2.new(1, -24, 1, -24), BackgroundTransparency = 1, Parent = self.gui }, {
		U.create("UISizeConstraint", { MaxSize = Vector2.new(320, 100000) }),
	})
	local layout = U.list(9)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = self.container
	return self.container
end

-- options: Title, Description, Type, Duration (seconds; 0 stays until dismissed)
function Notifications:Notify(options: any)
	local U, theme, anim = self.U, self.theme, self.anim
	local kind = if TYPES[options.Type] then options.Type else "Information"
	local colorKey = COLORS[kind]
	local duration = options.Duration or 4
	local container = self:_container()
	while #self.active >= MAX_VISIBLE do
		self.active[1]:Destroy()
	end
	local maid = U.maid()
	self.order = (self.order or 0) + 1

	-- the list layout positions `wrapper`, so the slide animation moves `card` inside it
	local wrapper = maid:Add(U.create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = self.order, Parent = container }))
	local card = U.create("TextButton", { Position = UDim2.new(1, 40, 0, 0), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 0.05, Parent = wrapper }, { U.corner(13), U.list(0) })
	theme:Bind(card, { BackgroundColor3 = "Background2" })
	theme:Bind(U.create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = 0.7, Parent = card }), { Color = "Stroke" })

	local content = U.create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, Parent = card }, { U.padding(12, 14, 12, 50), U.list(3) })
	local function text(order, size, font, key, value)
		local label = U.create("TextLabel", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = size, Font = font, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Text = value, LayoutOrder = order, Parent = content })
		theme:Bind(label, { TextColor3 = key })
		return label
	end
	local title = text(1, 13, Enum.Font.GothamBold, "Text", tostring(options.Title or kind))
	local description = text(2, 11, Enum.Font.GothamMedium, "SubText", tostring(options.Description or ""))
	description.Visible = description.Text ~= ""

	-- badge sits above the card and slides with it
	local overlay = U.create("Frame", { Size = UDim2.new(0, 50, 0, 0), BackgroundTransparency = 1, ZIndex = 2, Parent = wrapper })
	local badgeHolder = U.create("Frame", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 0.8, Parent = overlay }, { U.round() })
	theme:Bind(badgeHolder, { BackgroundColor3 = colorKey })
	local icon = self.icons.draw(U.create, theme, TYPES[kind], colorKey, badgeHolder)
	icon.Position = UDim2.fromOffset(6, 6)
	overlay.Position = card.Position

	local barHolder = U.create("Frame", { Size = UDim2.new(1, 0, 0, 5), BackgroundTransparency = 1, LayoutOrder = 2, Visible = duration > 0, Parent = card })
	local bar = U.create("Frame", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 0, 2), Parent = barHolder }, { U.round() })
	theme:Bind(bar, { BackgroundColor3 = colorKey })

	local handle = {}
	local dismissed = false
	function handle:Destroy()
		if dismissed and maid.cleaned then
			return
		end
		dismissed = true
		maid:Clean()
	end
	maid:Add(function()
		local index = table.find(self.active, handle)
		if index then
			table.remove(self.active, index)
		end
	end)
	function handle.Dismiss()
		if dismissed then
			return
		end
		dismissed = true
		anim:Tween(card, { Position = UDim2.new(1, 40, 0, 0) }, "Smooth")
		anim:Tween(overlay, { Position = UDim2.new(1, 40, 0, 0) }, "Smooth")
		maid:Add(task.delay(anim:Duration("Smooth"), function()
			maid:Clean()
		end))
	end
	function handle:SetText(newTitle: string, newDescription: string?)
		title.Text = newTitle
		if newDescription then
			description.Text = newDescription
			description.Visible = newDescription ~= ""
		end
	end
	table.insert(self.active, handle)

	maid:Add(card.Activated:Connect(handle.Dismiss))
	anim:Tween(card, { Position = UDim2.new() }, "Spring")
	anim:Tween(overlay, { Position = UDim2.new() }, "Spring")
	if duration > 0 then
		-- the countdown bar is information, so it runs even with animations disabled
		local TweenService = game:GetService("TweenService")
		local countdown = TweenService:Create(bar, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.fromOffset(0, 2) })
		countdown:Play()
		maid:Add(function()
			countdown:Cancel()
		end)
		maid:Add(task.delay(duration, handle.Dismiss))
	end
	return handle
end

function Notifications:Clear()
	for _, handle in table.clone(self.active) do
		handle:Destroy()
	end
end

function Notifications:Destroy()
	self:Clear()
	if self.gui then
		self.gui:Destroy()
		self.gui, self.container = nil, nil
	end
end

return Notifications
