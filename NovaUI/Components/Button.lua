local Element = require(script.Parent.Parent.Core.Element)
local Button = {}

function Button.new(ctx, section, config)
	local U, theme, anim = ctx.utilities, ctx.theme, ctx.animations
	local self = Element.new(ctx, section, config, "Button", { slot = 112 })
	local button = U.create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = self.slot }, { U.corner(14) })
	theme:Bind(U.create("UIGradient", { Parent = button }), {
		Color = function(t)
			return ColorSequence.new(t.Accent, t.Accent2)
		end,
	})
	-- separate label: a UIGradient on the button would also tint its own text
	local label = U.create("TextLabel", { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold, TextSize = 12, Text = config.ButtonText or "Run", TextTruncate = Enum.TextTruncate.AtEnd, Parent = button })
	theme:Bind(label, { TextColor3 = "OnAccent" })
	anim:Press(button, nil, 0.93)

	function self:Press()
		if self.Enabled and not self.destroyed then
			U.fire(config.Callback)
		end
	end
	function self:SetButtonText(text)
		label.Text = text
	end
	self.maid:Add(button.Activated:Connect(function()
		self:Press()
	end))
	return self
end

return Button
