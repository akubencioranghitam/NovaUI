--!nonstrict
-- Sidebar button plus its scrollable page.
local Tab = {}
Tab.__index = Tab

function Tab.new(ctx: any, window: any, config: any)
	if type(config) == "string" then
		config = { Name = config }
	end
	local U, theme = ctx.utilities, ctx.theme
	local self = setmetatable({
		ctx = ctx,
		window = window,
		Name = config.Name or "Tab",
		sections = {},
		maid = U.maid(),
		order = 0,
		selected = false,
	}, Tab)

	self.button = U.create("TextButton", {
		Name = self.Name,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		LayoutOrder = #window.tabs + 1,
		Parent = window.tabList,
	}, { U.corner(10) })
	theme:Bind(self.button, { BackgroundColor3 = "CardHover" })

	self.indicator = U.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(3, 0),
		Parent = self.button,
	}, { U.round() })
	theme:Bind(self.indicator, { BackgroundColor3 = "Accent" })

	self.icon, self.setIconColor = ctx.icons.draw(U.create, theme, config.Icon or self.Name, "SubText", self.button)
	self.icon.AnchorPoint = Vector2.new(0, 0.5)

	self.label = U.create("TextLabel", {
		Position = UDim2.fromOffset(36, 0),
		Size = UDim2.new(1, -42, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = self.Name,
		Parent = self.button,
	})
	theme:Bind(self.label, {
		TextColor3 = function(t)
			return if self.selected then t.Text else t.SubText
		end,
	})

	self.page = U.create("ScrollingFrame", {
		Name = self.Name,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		Parent = window.pages,
	}, { U.list(12), U.padding(2, 12, 14, 2) })
	theme:Bind(self.page, { ScrollBarImageColor3 = "Accent" })

	self.maid:Add(self.button.Activated:Connect(function()
		self:Select()
	end))
	ctx.animations:Press(self.button)
	self:SetCompact(window.compact)
	return self
end

function Tab:_nextOrder(): number
	self.order += 1
	return self.order
end

function Tab:CreateSection(config: any): any
	assert(not self.destroyed, "NovaUI: tab was destroyed")
	local section = self.ctx.section.new(self.ctx, self, config)
	table.insert(self.sections, section)
	return section
end

function Tab:Select()
	if not self.destroyed then
		self.window:SelectTab(self)
	end
end

function Tab:_setSelected(selected: boolean)
	local anim, theme = self.ctx.animations, self.ctx.theme
	self.selected = selected
	self.page.Visible = selected
	theme:Refresh(self.label, "Smooth")
	self.setIconColor(if selected then "Text" else "SubText", "Smooth")
	anim:Tween(self.button, { BackgroundTransparency = if selected then 0.84 else 1 })
	anim:Tween(self.indicator, { Size = UDim2.fromOffset(3, if selected then 18 else 0) }, "Spring")
	if selected then
		self.page.Position = UDim2.fromOffset(0, 10)
		anim:Tween(self.page, { Position = UDim2.new() })
	end
end

function Tab:SetCompact(compact: boolean)
	self.label.Visible = not compact
	self.icon.Position = if compact then UDim2.new(0.5, -8, 0.5, 0) else UDim2.new(0, 12, 0.5, 0)
end

function Tab:SetText(text: string)
	self.Name = text
	self.label.Text = text
end

function Tab:SetVisible(visible: boolean)
	self.button.Visible = visible
	if not visible and self.selected then
		for _, other in self.window.tabs do
			if other ~= self and other.button.Visible then
				other:Select()
				return
			end
		end
		self:_setSelected(false)
		self.window.selected = nil
	end
end

function Tab:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	for _, section in table.clone(self.sections) do
		section:Destroy()
	end
	self.maid:Clean()
	self.button:Destroy()
	self.page:Destroy()
	self.window:_removeTab(self)
end

return Tab
