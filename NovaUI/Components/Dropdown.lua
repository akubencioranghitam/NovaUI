local Element = require(script.Parent.Parent.Core.Element)
local Dropdown = {}

local ROW, MAX_ROWS = 32, 5

-- Shared builder. With multi = true the value is a list kept in option order.
function Dropdown.build(ctx, section, config, multi)
	local U, theme, anim = ctx.utilities, ctx.theme, ctx.animations
	local self = Element.new(ctx, section, config, if multi then "MultiDropdown" else "Dropdown", { slot = 150 })
	local options = table.clone(config.Options or {})
	local open = false
	local rows = {}
	local NONE = "" -- single dropdown with nothing selected

	local trigger = U.create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.9, Parent = self.slot }, { U.corner(9) })
	theme:Bind(trigger, { BackgroundColor3 = "Surface" })
	local current = U.create("TextLabel", { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -36, 1, 0), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = trigger })
	theme:Bind(current, { TextColor3 = "Text" })
	local function chevron(name)
		local icon = ctx.icons.draw(U.create, theme, name, "SubText", trigger)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.new(1, -14, 0.5, 0)
		return icon
	end
	local closedIcon, openIcon = chevron("chevron-down"), chevron("chevron-up")
	openIcon.Visible = false

	local body = self:CreateBody()
	local scroller = U.create("ScrollingFrame", { Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -16, 1, -8), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = body }, { U.list(2) })
	theme:Bind(scroller, { ScrollBarImageColor3 = "Accent" })

	local function selected(option)
		if multi then
			return table.find(self.Value or {}, option) ~= nil
		end
		return self.Value == option
	end
	local function paint(preset)
		for option, row in rows do
			local on = selected(option)
			row.check.Visible = on
			if preset then
				anim:Tween(row.button, { BackgroundTransparency = if on then 0.8 else 1 }, preset)
			else
				row.button.BackgroundTransparency = if on then 0.8 else 1
			end
		end
	end
	local function render(value, preset)
		local text = if multi then table.concat(value, ", ") else value
		current.Text = if text == NONE then (config.Placeholder or "Select…") else text
		self.Value = value
		paint(preset)
	end

	local function height()
		return math.min(#options, MAX_ROWS) * (ROW + 2) + 8
	end
	function self:SetOpen(state)
		open = state and self.Enabled and #options > 0
		if open then
			body.Visible = true
		end
		openIcon.Visible, closedIcon.Visible = open, not open
		local tween = anim:Tween(body, { Size = UDim2.new(1, 0, 0, if open then height() else 0) })
		if not open then
			if tween then
				tween.Completed:Once(function()
					body.Visible = open
				end)
			else
				body.Visible = false
			end
		end
	end

	local rowMaid
	local function rebuild()
		if rowMaid then
			rowMaid:Clean()
		end
		rowMaid = U.maid()
		table.clear(rows)
		for index, option in options do
			local button = rowMaid:Add(U.create("TextButton", { Size = UDim2.new(1, -6, 0, ROW), BackgroundTransparency = 1, LayoutOrder = index, Parent = scroller }, { U.corner(8) }))
			theme:Bind(button, { BackgroundColor3 = "CardHover" })
			local label = U.create("TextLabel", { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -38, 1, 0), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = option, Parent = button })
			theme:Bind(label, { TextColor3 = "Text" })
			local check = ctx.icons.draw(U.create, theme, "check", "Accent2", button)
			check.AnchorPoint = Vector2.new(0.5, 0.5)
			check.Position = UDim2.new(1, -14, 0.5, 0)
			rows[option] = { button = button, check = check }
			rowMaid:Add(button.Activated:Connect(function()
				if not self.Enabled then
					return
				end
				if multi then
					local nextValue = table.clone(self.Value)
					local at = table.find(nextValue, option)
					if at then
						table.remove(nextValue, at)
					else
						table.insert(nextValue, option)
					end
					self:SetValue(nextValue)
				else
					self:SetValue(option)
					self:SetOpen(false)
				end
			end))
		end
		paint()
	end
	self.maid:Add(function()
		if rowMaid then
			rowMaid:Clean()
		end
	end)
	rebuild()

	local function normalize(value)
		if multi then
			if type(value) ~= "table" then
				return nil
			end
			local result = {}
			for _, option in options do
				if table.find(value, option) then
					table.insert(result, option)
				end
			end
			return result
		end
		if value == NONE or table.find(options, value) then
			return value
		end
		return nil
	end
	local default = config.Default
	if default == nil then
		default = if multi then {} else NONE
	end
	self:UseValue({
		default = default,
		normalize = normalize,
		render = render,
		equals = if multi
			then function(a, b)
				return table.concat(a, "\0") == table.concat(b, "\0") and #a == #b
			end
			else nil,
	})

	-- Replace the option list; selections that no longer exist are dropped.
	function self:SetOptions(newOptions)
		options = table.clone(newOptions)
		rebuild()
		local kept = normalize(self.Value)
		self:SetValue(if kept == nil then NONE else kept)
		paint()
		if open then
			self:SetOpen(true)
		end
	end
	self.maid:Add(trigger.Activated:Connect(function()
		self:SetOpen(not open)
	end))
	self.onEnabled = function(enabled)
		if not enabled then
			self:SetOpen(false)
		end
	end
	return self
end

function Dropdown.new(ctx, section, config)
	return Dropdown.build(ctx, section, config, false)
end

return Dropdown
