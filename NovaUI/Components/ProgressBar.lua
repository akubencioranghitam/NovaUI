local Element = require(script.Parent.Parent.Core.Element)
local ProgressBar = {}

function ProgressBar.new(ctx, section, config)
	local U, theme, anim = ctx.utilities, ctx.theme, ctx.animations
	local max = config.Max or 100
	assert(max > 0, "NovaUI: ProgressBar needs Max > 0")
	local self = Element.new(ctx, section, config, "ProgressBar", { slot = 66 })
	local percent = U.create("TextLabel", { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right, Parent = self.slot })
	theme:Bind(percent, { TextColor3 = "Text" })
	local holder = U.create("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = 2, Parent = self.card })
	local rail = U.create("Frame", { Position = UDim2.fromOffset(13, 0), Size = UDim2.new(1, -26, 0, 6), Parent = holder }, { U.round() })
	theme:Bind(rail, { BackgroundColor3 = "Track" })
	local fill = U.create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = rail }, { U.round() })
	theme:Bind(U.create("UIGradient", { Parent = fill }), {
		Color = function(t)
			return ColorSequence.new(t.Accent, t.Accent2)
		end,
	})
	self:UseValue({
		default = config.Default or 0,
		normalize = function(value)
			if type(value) ~= "number" or value ~= value then
				return nil
			end
			return math.clamp(value, 0, max)
		end,
		render = function(value, preset)
			percent.Text = `{math.floor(value / max * 100 + 0.5)}%`
			if preset then
				anim:Tween(fill, { Size = UDim2.fromScale(value / max, 1) }, "Slow")
			else
				fill.Size = UDim2.fromScale(value / max, 1)
			end
		end,
	})
	return self
end

return ProgressBar
