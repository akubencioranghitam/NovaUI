--!nonstrict
-- A collapsible card that hosts components. Component constructors come from ctx.components.
local Section = {}

-- Section:CreateToggle{...}, Section:CreateSlider{...}, etc. resolve through the registry,
-- so components registered later work without touching this file.
Section.__index = function(self, key)
	if Section[key] then
		return Section[key]
	end
	local name = type(key) == "string" and string.match(key, "^Create(%u%w*)$")
	local component = name and self.ctx.components[name]
	if component then
		return function(_, config)
			return self:Add(component, config)
		end
	end
	return nil
end

function Section.new(ctx: any, tab: any, config: any)
	if type(config) == "string" then
		config = { Name = config }
	end
	local U, theme = ctx.utilities, ctx.theme
	local self = setmetatable({
		ctx = ctx,
		tab = tab,
		Name = config.Name or "Section",
		Collapsed = config.Collapsed == true,
		elements = {},
		maid = U.maid(),
		order = 0,
		visible = true,
		matches = true,
		searching = false,
	}, Section)

	self.frame = U.create("Frame", {
		Name = self.Name,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = tab:_nextOrder(),
		Parent = tab.page,
	}, { U.list(7) })

	local header = U.create("TextButton", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = self.frame,
	})
	self.title = U.create("TextLabel", {
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.new(1, -30, 1, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = self.Name,
		Parent = header,
	})
	theme:Bind(self.title, { TextColor3 = "SubText" })
	local function chevron(name)
		local icon = ctx.icons.draw(U.create, theme, name, "SubText", header)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.new(1, -14, 0.5, 0)
		return icon
	end
	self.openIcon, self.closedIcon = chevron("chevron-down"), chevron("chevron-right")

	self.body = U.create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = self.frame,
	}, { U.list(7) })

	self.maid:Add(header.Activated:Connect(function()
		self:SetExpanded(self.Collapsed)
	end))
	self:_render()
	return self
end

function Section:Add(component: any, config: any): any
	assert(not self.destroyed, "NovaUI: section was destroyed")
	local element = component.new(self.ctx, self, config or {})
	table.insert(self.elements, element)
	return element
end

function Section:_nextOrder(): number
	self.order += 1
	return self.order
end

function Section:_render()
	local open = self.searching or not self.Collapsed
	self.body.Visible = open
	self.frame.Visible = self.visible and self.matches
	self.openIcon.Visible, self.closedIcon.Visible = open, not open
end

function Section:SetExpanded(expanded: boolean)
	self.Collapsed = not expanded
	self:_render()
end

function Section:SetText(text: string)
	self.Name = text
	self.title.Text = text
end

function Section:SetVisible(visible: boolean)
	self.visible = visible
	self:_render()
end

function Section:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	for _, element in table.clone(self.elements) do
		element:Destroy()
	end
	self.maid:Clean()
	self.frame:Destroy()
	local index = table.find(self.tab.sections, self)
	if index then
		table.remove(self.tab.sections, index)
	end
end

return Section
