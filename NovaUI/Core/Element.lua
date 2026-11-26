--!nonstrict
-- Base class shared by every component: card layout, visibility, enabled state,
-- values, config flags, context menu and cleanup.
local Element = {}
Element.__index = Element

--[[ options:
	slot: width reserved on the right of the header
	flat: no card background (labels, dividers)
]]
function Element.new(ctx: any, section: any, config: any, kind: string, options: any?)
	options = options or {}
	local U, theme = ctx.utilities, ctx.theme
	local self = setmetatable({
		ctx = ctx,
		section = section,
		config = config,
		Type = kind,
		Name = config.Name or kind,
		Description = config.Description,
		Flag = config.Flag,
		Value = nil,
		Enabled = true,
		maid = U.maid(),
		listeners = {},
		visible = true,
		matches = true,
	}, Element)

	self.frame = U.create("Frame", {
		Name = self.Name,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = section:_nextOrder(),
		Parent = section.body,
	})

	self.card = U.create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = if options.flat then 1 else 0.91,
		Active = true,
		Parent = self.frame,
	}, { U.corner(12), U.list(0) })
	theme:Bind(self.card, { BackgroundColor3 = "Card" })
	if not options.flat then
		theme:Bind(U.create("UIStroke", { Transparency = 0.85, Parent = self.card }), { Color = "Stroke" })
		self.maid:Add(self.card.MouseEnter:Connect(function()
			if self.Enabled then
				ctx.animations:Tween(self.card, { BackgroundTransparency = 0.86 }, "Fast")
			end
		end))
		self.maid:Add(self.card.MouseLeave:Connect(function()
			ctx.animations:Tween(self.card, { BackgroundTransparency = 0.91 }, "Fast")
		end))
	end

	local slot = options.slot or 0
	self.header = U.create("Frame", { Size = UDim2.new(1, 0, 0, if options.flat then 24 else 44), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, Parent = self.card })
	local pad = if options.flat then 4 else 13
	local column = U.create("Frame", { Size = UDim2.new(1, -slot, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = self.header }, {
		U.list(3),
		U.padding(if options.flat then 4 else 14, 8, if options.flat then 4 else 14, pad),
	})
	local function line(order: number, size: number, colorKey: string, content: string)
		local label = U.create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = size,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = content,
			LayoutOrder = order,
			Parent = column,
		})
		theme:Bind(label, { TextColor3 = colorKey })
		return label
	end
	self.titleLabel = line(1, 13, "Text", self.Name)
	self.descriptionLabel = line(2, 11, "SubText", self.Description or "")
	self.descriptionLabel.Visible = self.Description ~= nil

	-- right-aligned area for the control; 28px tall, centered on a single-line header
	self.slot = U.create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(math.max(slot - 12, 0), 28), BackgroundTransparency = 1, Parent = self.header })

	-- covers the whole element while disabled so no input reaches the controls
	self.blocker = U.create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.45, Visible = false, ZIndex = 10, Parent = self.frame }, { U.corner(12) })
	theme:Bind(self.blocker, { BackgroundColor3 = "Background" })
	-- the blocker is sized from the card, because scale-sized children and AutomaticSize do not mix
	local function fitBlocker()
		self.blocker.Size = UDim2.new(1, 0, 0, self.card.AbsoluteSize.Y)
	end
	self.maid:Add(self.card:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBlocker))
	fitBlocker()
	return self
end

-- Expandable area under the header (dropdown lists, color picker).
function Element:CreateBody(): any
	local U = self.ctx.utilities
	local body = U.create("Frame", { Size = UDim2.new(1, 0, 0, 0), ClipsDescendants = true, BackgroundTransparency = 1, Visible = false, LayoutOrder = 2, Parent = self.card })
	return body
end

--[[ Turns the element into a value holder.
	spec.default    initial value (also used by "Reset to default")
	spec.normalize  (input) -> valid value, or nil to reject
	spec.render     (value, preset?) -> update visuals
	spec.equals     optional comparison
	spec.callback   config field fired on change (default "Callback")
]]
function Element:UseValue(spec: any)
	self.spec = spec
	local initial = spec.normalize(spec.default)
	local problem = nil
	if initial == nil then
		problem = `NovaUI: invalid Default for {self.Type} "{self.Name}"`
	elseif self.Flag and self.ctx.config.flags[self.Flag] then
		problem = `NovaUI: duplicate Flag "{self.Flag}"`
	end
	if problem then
		self:Destroy() -- do not leave a half-built card on screen
		error(problem, 0)
	end
	self.Value, self.Default = initial, initial
	spec.render(initial, nil)
	if self.Flag then
		self.ctx.config:Register(self.Flag, self)
	end
	self:AttachMenu(function()
		return {
			{
				Text = "Reset to default",
				Callback = function()
					self:SetValue(self.Default)
				end,
			},
		}
	end)
end

function Element:SetValue(value: any, silent: boolean?): boolean
	local spec = self.spec
	if self.destroyed or not spec then
		return false
	end
	local normalized = spec.normalize(value)
	if normalized == nil then
		return false
	end
	local same = if spec.equals then spec.equals(self.Value, normalized) else self.Value == normalized
	if same then
		return true
	end
	self.Value = normalized
	spec.render(normalized, "Smooth")
	if not silent then
		local U = self.ctx.utilities
		if spec.callback ~= false then
			U.fire(self.config[spec.callback or "Callback"], self:GetValue())
		end
		for listener in self.listeners do
			U.fire(listener, self:GetValue())
		end
	end
	return true
end

function Element:GetValue(): any
	-- tables are copied so callers cannot mutate internal state
	return if typeof(self.Value) == "table" then table.clone(self.Value) else self.Value
end

function Element:OnChanged(listener: (any) -> ()): () -> ()
	self.listeners[listener] = true
	return function()
		self.listeners[listener] = nil
	end
end

-- Right-click or touch long-press. Later calls add more items.
function Element:AttachMenu(items: () -> { any })
	if not self.menuProviders then
		self.menuProviders = {}
		self.ctx.contextMenu:Attach(self.maid, self.card, function()
			local all = {}
			if self.Enabled then
				for _, provider in self.menuProviders do
					for _, item in provider() do
						table.insert(all, item)
					end
				end
			end
			return all
		end)
	end
	table.insert(self.menuProviders, items)
end

function Element:SetText(text: string)
	self.Name = tostring(text)
	self.titleLabel.Text = self.Name
end

function Element:SetDescription(text: string?)
	self.Description = text
	self.descriptionLabel.Text = text or ""
	self.descriptionLabel.Visible = text ~= nil
end

function Element:_applyVisibility()
	self.frame.Visible = self.visible and self.matches
end

function Element:SetVisible(visible: boolean)
	self.visible = visible
	self:_applyVisibility()
end

function Element:SetEnabled(enabled: boolean)
	self.Enabled = enabled
	self.blocker.Visible = not enabled
	if self.onEnabled then
		self.onEnabled(enabled)
	end
end

function Element:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	if self.Flag then
		self.ctx.config:Unregister(self.Flag, self)
	end
	self.maid:Clean()
	table.clear(self.listeners)
	self.frame:Destroy()
	local index = table.find(self.section.elements, self)
	if index then
		table.remove(self.section.elements, index)
	end
end

return Element
