--!nonstrict
-- Window chrome: drag, resize, minimize, maximize, close, sidebar, search box.
-- Everything it needs arrives through ctx, so it requires no sibling modules.
local UserInputService = game:GetService("UserInputService")

local Window = {}
Window.__index = Window

local TOPBAR = 54
local MARGIN = 8

function Window.new(ctx: any, config: any, gui: ScreenGui, onDestroy: (any) -> ())
	local U, theme, anim = ctx.utilities, ctx.theme, ctx.animations
	local size = config.Size or Vector2.new(680, 460)
	local self = setmetatable({
		ctx = ctx,
		gui = gui,
		tabs = {},
		maid = U.maid(),
		desired = size,
		size = size,
		minSize = config.MinSize or Vector2.new(420, 300),
		position = nil, -- top-left offset, set by first _fit
		minimized = false,
		maximized = false,
		compact = false,
		visible = true,
		onDestroy = onDestroy,
	}, Window)
	ctx.window = self
	self.maid:Add(gui)

	self.holder = U.create("Frame", { Name = "Holder", BackgroundTransparency = 1, Parent = gui })
	self.scale = U.create("UIScale", { Scale = 0.94, Parent = self.holder })

	-- soft glow: three stacked translucent rounded rects (no image assets)
	for i = 1, 3 do
		local halo = U.create("Frame", {
			Position = UDim2.fromOffset(-i * 5, -i * 5 + 4),
			Size = UDim2.new(1, i * 10, 1, i * 10),
			BackgroundTransparency = 0.86 + i * 0.035,
			ZIndex = 0,
			Parent = self.holder,
		}, { U.corner(18 + i * 5) })
		theme:Bind(halo, { BackgroundColor3 = "Glow1" })
	end

	local main = U.create("Frame", {
		Name = "Main",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.04,
		ClipsDescendants = true,
		Active = true,
		ZIndex = 1,
		Parent = self.holder,
	}, { U.corner(18) })
	local backdrop = U.create("UIGradient", { Rotation = 35, Parent = main })
	theme:Bind(backdrop, {
		Color = function(t)
			return ColorSequence.new(t.Background, t.Background2)
		end,
	})
	theme:Bind(U.create("UIStroke", { Transparency = 0.72, Thickness = 1, Parent = main }), { Color = "Stroke" })

	-- ambient light: concentric faint circles approximate a radial gradient
	local function blob(position: UDim2, diameter: number, key: string)
		for i = 1, 6 do
			local d = diameter * (1 - (i - 1) * 0.14)
			local circle = U.create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = position,
				Size = UDim2.fromOffset(d, d),
				BackgroundTransparency = 0.965,
				ZIndex = 0,
				Parent = main,
			}, { U.round() })
			theme:Bind(circle, { BackgroundColor3 = key })
		end
	end
	blob(UDim2.new(1, -150, 0, 145), 270, "Glow1")
	blob(UDim2.new(0, 175, 1, -135), 250, "Glow2")

	local topbar = U.create("Frame", { Name = "TopBar", Size = UDim2.new(1, 0, 0, TOPBAR), BackgroundTransparency = 1, Active = true, ZIndex = 2, Parent = main })

	local orb = U.create("Frame", { Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = Color3.new(1, 1, 1), Parent = topbar }, { U.round() })
	theme:Bind(U.create("UIGradient", { Rotation = 45, Parent = orb }), {
		Color = function(t)
			return ColorSequence.new(t.Accent, t.Accent2)
		end,
	})

	local function text(props: any, colorKey: string)
		props.TextXAlignment = Enum.TextXAlignment.Left
		props.TextTruncate = Enum.TextTruncate.AtEnd
		props.Parent = topbar
		local label = U.create("TextLabel", props)
		theme:Bind(label, { TextColor3 = colorKey })
		return label
	end
	self.title = text({ Font = Enum.Font.GothamBold, TextSize = 15, Text = config.Title or "NovaUI" }, "Text")
	self.subtitle = text({ TextSize = 11, Text = config.Subtitle or "" }, "SubText")

	local controls = U.create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 12),
		Size = UDim2.fromOffset(98, 30),
		BackgroundTransparency = 1,
		Parent = topbar,
	}, { U.list(4, Enum.FillDirection.Horizontal) })
	local function control(icon: string, order: number, hoverKey: string, action: () -> ())
		local button = U.create("TextButton", { Name = icon, Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, LayoutOrder = order, Parent = controls }, { U.round() })
		theme:Bind(button, { BackgroundColor3 = hoverKey })
		local glyph = ctx.icons.draw(U.create, theme, icon, "Text", button)
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.Position = UDim2.fromScale(0.5, 0.5)
		self.maid:Add(button.MouseEnter:Connect(function()
			anim:Tween(button, { BackgroundTransparency = 0.78 }, "Fast")
		end))
		self.maid:Add(button.MouseLeave:Connect(function()
			anim:Tween(button, { BackgroundTransparency = 1 }, "Fast")
		end))
		self.maid:Add(button.Activated:Connect(action))
		anim:Press(button, nil, 0.9)
	end
	control("minus", 1, "CardHover", function()
		self:Minimize()
	end)
	control("maximize", 2, "CardHover", function()
		self:Maximize()
	end)
	control("close", 3, "Error", function()
		self:Close()
	end)

	self.searchHolder = U.create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -116, 0, 12), Size = UDim2.fromOffset(170, 30), BackgroundTransparency = 0.9, Visible = config.Search ~= false, Parent = topbar }, { U.round() })
	theme:Bind(self.searchHolder, { BackgroundColor3 = "Surface" })
	local magnifier = ctx.icons.draw(U.create, theme, "search", "SubText", self.searchHolder)
	magnifier.Position = UDim2.fromOffset(10, 7)
	self.searchBox = U.create("TextBox", { Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -40, 1, 0), BackgroundTransparency = 1, PlaceholderText = "Search", TextXAlignment = Enum.TextXAlignment.Left, ClipsDescendants = true, Parent = self.searchHolder })
	theme:Bind(self.searchBox, { TextColor3 = "Text", PlaceholderColor3 = "SubText" })
	self.maid:Add(self.searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		ctx.search.apply(self, self.searchBox.Text)
	end))

	self.body = U.create("Frame", { Position = UDim2.fromOffset(0, TOPBAR), Size = UDim2.new(1, 0, 1, -TOPBAR), BackgroundTransparency = 1, ZIndex = 2, Parent = main })
	self.sidebar = U.create("Frame", { Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 0.91, Parent = self.body }, { U.corner(14) })
	theme:Bind(self.sidebar, { BackgroundColor3 = "Surface" })
	theme:Bind(U.create("UIStroke", { Transparency = 0.84, Parent = self.sidebar }), { Color = "Stroke" })
	self.tabList = U.create("ScrollingFrame", { Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0, Parent = self.sidebar }, { U.list(4), U.padding(7) })
	self.pages = U.create("Frame", { BackgroundTransparency = 1, ClipsDescendants = true, Parent = self.body })
	self.empty = U.create("TextLabel", { Size = UDim2.new(1, 0, 0, 80), Text = "No matching controls", Visible = false, Parent = self.pages })
	theme:Bind(self.empty, { TextColor3 = "SubText" })

	local handle = U.create("TextButton", { Name = "Resize", AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, Visible = config.Resizable ~= false, ZIndex = 5, Parent = main })
	for i = 1, 2 do
		local grip = U.create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(9 + i * 3, 9 + i * 3), Size = UDim2.fromOffset(14 - i * 5, 1), Rotation = -45, BackgroundTransparency = 0.4, Parent = handle })
		theme:Bind(grip, { BackgroundColor3 = "SubText" })
	end
	self.resizeHandle = handle
	self.resizable = config.Resizable ~= false

	ctx.overlay = U.create("Frame", { Name = "Overlay", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20, Parent = gui })
	ctx.contextMenu = ctx.contextMenuClass.new(ctx)
	self.maid:Add(ctx.contextMenu)

	local startPosition, startSize
	local function inside(target: GuiObject, point: Vector3)
		local corner, extent = target.AbsolutePosition, target.AbsoluteSize
		return target.Visible and point.X >= corner.X and point.X <= corner.X + extent.X and point.Y >= corner.Y and point.Y <= corner.Y + extent.Y
	end
	U.drag(self.maid, topbar, function(point)
		-- selecting search text or pressing a window button must not move the window
		if self.maximized or inside(self.searchHolder, point) or inside(controls, point) then
			return false
		end
		startPosition = self.position
		return true
	end, function(_, delta)
		self.moved = true
		self.position = startPosition + Vector2.new(delta.X, delta.Y)
		self:_apply()
	end)
	U.drag(self.maid, handle, function()
		if self.maximized or self.minimized then
			return false
		end
		startSize = self.size
		self.moved = true -- keep the top-left corner fixed while resizing
		return true
	end, function(_, delta)
		local viewport = gui.AbsoluteSize
		local limit = viewport - self.position - Vector2.new(MARGIN, MARGIN)
		local function clampAxis(value, low, high)
			return math.clamp(value, math.min(low, high), math.max(high, 0))
		end
		self.desired = Vector2.new(
			clampAxis(startSize.X + delta.X, self.minSize.X, limit.X),
			clampAxis(startSize.Y + delta.Y, self.minSize.Y, limit.Y)
		)
		self:_fit()
	end)

	self.maid:Add(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_fit()
	end))
	local toggleKey = if config.ToggleKey == nil then Enum.KeyCode.RightShift else config.ToggleKey
	self.maid:Add(UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and toggleKey and input.KeyCode == toggleKey and not ctx.capturing then
			self:SetVisible(not self.visible)
		end
	end))

	self:_fit()
	anim:Tween(self.scale, { Scale = 1 }, "Spring")
	return self
end

-- Recalculate size for the current screen, keeping the window on screen.
function Window:_fit()
	local viewport = self.gui.AbsoluteSize
	if viewport.X < 1 or viewport.Y < 1 then
		viewport = Vector2.new(1280, 720) -- not laid out yet
	end
	local available = viewport - Vector2.new(MARGIN * 2, MARGIN * 2)
	local wanted = if self.maximized then available else self.desired
	self.size = Vector2.new(math.min(wanted.X, available.X), math.min(wanted.Y, available.Y))
	if self.maximized then
		self.position = Vector2.new(MARGIN, MARGIN)
	elseif not self.position or not self.moved then
		self.position = (viewport - self.size) / 2
	end
	self:_apply()
end

function Window:_apply(preset: string?)
	local viewport = self.gui.AbsoluteSize
	local width, height = self.size.X, if self.minimized then TOPBAR else self.size.Y
	if viewport.X >= 1 and viewport.Y >= 1 then
		-- at least 80px of the title bar stays reachable
		self.position = Vector2.new(
			math.clamp(self.position.X, math.min(80 - width, 0), math.max(viewport.X - 80, 0)),
			math.clamp(self.position.Y, 0, math.max(viewport.Y - TOPBAR, 0))
		)
	end
	local goal = { Position = UDim2.fromOffset(self.position.X, self.position.Y), Size = UDim2.fromOffset(width, height) }
	if preset then
		self.ctx.animations:Tween(self.holder, goal, preset)
	else
		self.holder.Position, self.holder.Size = goal.Position, goal.Size
	end

	local compact = width < 540
	self.compact = compact
	local sidebar = if compact then 50 else 150
	self.sidebar.Size = UDim2.new(0, sidebar, 1, -10)
	self.pages.Position = UDim2.fromOffset(sidebar + 20, 0)
	self.pages.Size = UDim2.new(1, -(sidebar + 22), 1, -4)
	for _, tab in self.tabs do
		tab:SetCompact(compact)
	end
	local searchWidth = if self.searchHolder.Visible then math.clamp(width - 270, 80, 170) else 0
	self.searchHolder.Size = UDim2.fromOffset(searchWidth, 30)
	local textWidth = math.max(width - 48 - 126 - searchWidth, 0)
	local hasSubtitle = self.subtitle.Text ~= "" and not compact
	self.subtitle.Visible = hasSubtitle
	self.title.Position = UDim2.fromOffset(48, if hasSubtitle then 11 else 17)
	self.title.Size = UDim2.fromOffset(textWidth, 20)
	self.subtitle.Position = UDim2.fromOffset(48, 29)
	self.subtitle.Size = UDim2.fromOffset(textWidth, 15)
end

function Window:CreateTab(config: any): any
	assert(not self.destroyed, "NovaUI: window was destroyed")
	local tab = self.ctx.tab.new(self.ctx, self, config)
	table.insert(self.tabs, tab)
	if not self.selected then
		self:SelectTab(tab)
	end
	return tab
end

function Window:SelectTab(tab: any)
	if self.selected == tab or tab.destroyed then
		return
	end
	self.ctx.contextMenu:Close()
	if self.selected then
		self.selected:_setSelected(false)
	end
	self.selected = tab
	tab:_setSelected(true)
end

function Window:_removeTab(tab: any)
	local index = table.find(self.tabs, tab)
	if index then
		table.remove(self.tabs, index)
	end
	if self.selected == tab then
		self.selected = nil
		if self.tabs[1] and not self.destroyed then
			self:SelectTab(self.tabs[1])
		end
	end
end

function Window:Minimize(state: boolean?)
	local target = if state == nil then not self.minimized else state
	if target == self.minimized then
		return
	end
	self.minimized = target
	self.ctx.contextMenu:Close()
	self.body.Visible = not target
	self.resizeHandle.Visible = self.resizable and not target
	self.moved = true
	self:_apply("Smooth")
end

function Window:Maximize(state: boolean?)
	local target = if state == nil then not self.maximized else state
	if target == self.maximized then
		return
	end
	self:Minimize(false)
	if target then
		self.restore = { position = self.position, moved = self.moved }
	end
	self.maximized = target
	if not target then
		self.position, self.moved = self.restore.position, true
	end
	self:_fit()
end

function Window:SetVisible(visible: boolean)
	self.visible = visible
	self.ctx.contextMenu:Close()
	self.gui.Enabled = visible
end

function Window:SetTitle(title: string, subtitle: string?)
	self.title.Text = title
	if subtitle then
		self.subtitle.Text = subtitle
	end
	self:_apply()
end

function Window:Search(query: string)
	self.searchBox.Text = query
	self.ctx.search.apply(self, query)
end

-- Animated destroy, used by the close button.
function Window:Close()
	if self.closing or self.destroyed then
		return
	end
	self.closing = true
	local anim = self.ctx.animations
	anim:Tween(self.scale, { Scale = 0.9 }, "Fast")
	task.delay(anim:Duration("Fast"), function()
		self:Destroy()
	end)
end

function Window:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	for _, tab in table.clone(self.tabs) do
		tab:Destroy()
	end
	self.maid:Clean()
	self.onDestroy(self)
end

return Window
