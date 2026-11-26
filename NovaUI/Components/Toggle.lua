local Element = require(script.Parent.Parent.Core.Element)
local Toggle = {}

function Toggle.new(ctx, section, config)
	local U, theme, anim = ctx.utilities, ctx.theme, ctx.animations
	local self = Element.new(ctx, section, config, "Toggle", { slot = 64 })
	local on = false
	local track = U.create("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(42, 24), Parent = self.slot }, { U.round() })
	theme:Bind(track, {
		BackgroundColor3 = function(t)
			return if on then t.Accent else t.Track
		end,
	})
	local knob = U.create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(18, 18), Parent = track }, { U.round() })
	theme:Bind(knob, { BackgroundColor3 = "OnAccent" })

	self:UseValue({
		default = config.Default == true,
		normalize = function(value)
			if type(value) == "boolean" then
				return value
			end
			return nil
		end,
		render = function(value, preset)
			on = value
			local goal = { Position = UDim2.new(0, if value then 21 else 3, 0.5, 0) }
			if preset then
				anim:Tween(knob, goal, "Spring")
			else
				knob.Position = goal.Position
			end
			theme:Refresh(track, preset)
		end,
	})
	self.maid:Add(track.Activated:Connect(function()
		if self.Enabled then
			self:SetValue(not self.Value)
		end
	end))
	return self
end

return Toggle
