local Element = require(script.Parent.Parent.Core.Element)
local Slider = {}

-- Snap to the nearest step, clamp, and trim floating point noise.
function Slider.snap(value, min, max, step)
	local snapped = min + math.floor((value - min) / step + 0.5) * step
	snapped = math.floor(snapped * 1e6 + 0.5) / 1e6
	return math.clamp(snapped, min, max)
end

function Slider.new(ctx, section, config)
	local U, theme, anim = ctx.utilities, ctx.theme, ctx.animations
	local min, max, step = config.Min or 0, config.Max or 100, config.Increment or 1
	assert(max > min and step > 0, "NovaUI: Slider needs Max > Min and Increment > 0")
	local suffix = config.Suffix or ""
	local self = Element.new(ctx, section, config, "Slider", { slot = 86 })

	-- type an exact value with the keyboard
	local box = U.create("TextBox", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.9, TextSize = 12, ClipsDescendants = true, Parent = self.slot }, { U.corner(9) })
	theme:Bind(box, { TextColor3 = "Text", BackgroundColor3 = "Surface" })

	local hit = U.create("TextButton", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = 2, Parent = self.card })
	local rail = U.create("Frame", { Position = UDim2.new(0, 14, 0, 6), Size = UDim2.new(1, -28, 0, 6), Parent = hit }, { U.round() })
	theme:Bind(rail, { BackgroundColor3 = "Track" })
	local fill = U.create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = rail }, { U.round() })
	theme:Bind(U.create("UIGradient", { Parent = fill }), {
		Color = function(t)
			return ColorSequence.new(t.Accent, t.Accent2)
		end,
	})
	local knob = U.create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(14, 14), ZIndex = 2, Parent = rail }, { U.round() })
	theme:Bind(knob, { BackgroundColor3 = "OnAccent" })

	local dragging = false
	local function render(value, preset)
		local alpha = (value - min) / (max - min)
		box.Text = tostring(value) .. suffix
		if preset and not dragging then
			anim:Tween(fill, { Size = UDim2.fromScale(alpha, 1) }, preset)
			anim:Tween(knob, { Position = UDim2.fromScale(alpha, 0.5) }, preset)
		else
			fill.Size = UDim2.fromScale(alpha, 1)
			knob.Position = UDim2.fromScale(alpha, 0.5)
		end
	end
	self:UseValue({
		default = config.Default or min,
		normalize = function(value)
			-- value ~= value rejects NaN
			if type(value) ~= "number" or value ~= value then
				return nil
			end
			return Slider.snap(value, min, max, step)
		end,
		render = render,
	})

	local function fromPointer(position)
		if self.Enabled and rail.AbsoluteSize.X > 0 then
			local alpha = math.clamp((position.X - rail.AbsolutePosition.X) / rail.AbsoluteSize.X, 0, 1)
			self:SetValue(min + alpha * (max - min))
		end
	end
	U.drag(self.maid, hit, function(position)
		if not self.Enabled then
			return false
		end
		dragging = true
		anim:Tween(knob, { Size = UDim2.fromOffset(18, 18) }, "Fast")
		fromPointer(position)
		return true
	end, fromPointer, function()
		dragging = false
		anim:Tween(knob, { Size = UDim2.fromOffset(14, 14) }, "Spring")
	end)
	self.maid:Add(box.FocusLost:Connect(function()
		local typed = tonumber(string.match(box.Text, "^%s*([%-%+]?[%d%.]+)"))
		if typed and self.Enabled then
			self:SetValue(typed)
		end
		render(self.Value)
	end))
	self.onEnabled = function(enabled)
		box.TextEditable = enabled
	end
	return self
end

return Slider
