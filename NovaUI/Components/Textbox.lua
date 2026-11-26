local Element = require(script.Parent.Parent.Core.Element)
local Textbox = {}

-- Options: Default, Placeholder, Numeric, MaxLength. Value commits when focus is lost.
function Textbox.new(ctx, section, config)
	local U, theme, anim = ctx.utilities, ctx.theme, ctx.animations
	local self = Element.new(ctx, section, config, "Textbox", { slot = 162 })
	local holder = U.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.9, ClipsDescendants = true, Parent = self.slot }, { U.corner(9) })
	theme:Bind(holder, { BackgroundColor3 = "Surface" })
	local stroke = U.create("UIStroke", { Transparency = 1, Parent = holder })
	theme:Bind(stroke, { Color = "Accent" })
	local box = U.create("TextBox", { Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -18, 1, 0), BackgroundTransparency = 1, TextSize = 12, PlaceholderText = config.Placeholder or "Type here…", TextXAlignment = Enum.TextXAlignment.Left, ClipsDescendants = true, Parent = holder })
	theme:Bind(box, { TextColor3 = "Text", PlaceholderColor3 = "SubText" })

	self:UseValue({
		default = config.Default or "",
		normalize = function(value)
			if config.Numeric then
				if value == "" then
					return ""
				end
				local number = tonumber(value)
				-- rejects NaN and infinity as well as non-numbers
				if not number or number ~= number or math.abs(number) == math.huge then
					return nil
				end
				return tostring(value)
			end
			if type(value) ~= "string" then
				return nil
			end
			if config.MaxLength and (utf8.len(value) or 0) > config.MaxLength then
				return string.sub(value, 1, (utf8.offset(value, config.MaxLength + 1) or 1) - 1)
			end
			return value
		end,
		render = function(value)
			box.Text = value
		end,
	})
	self.maid:Add(box.Focused:Connect(function()
		anim:Tween(stroke, { Transparency = 0.15 }, "Fast")
	end))
	self.maid:Add(box.FocusLost:Connect(function()
		anim:Tween(stroke, { Transparency = 1 }, "Fast")
		if self.Enabled then
			self:SetValue(box.Text)
		end
		box.Text = self.Value -- revert rejected or truncated input
	end))
	self.onEnabled = function(enabled)
		box.TextEditable = enabled
		if not enabled then
			box:ReleaseFocus()
		end
	end
	return self
end

return Textbox
