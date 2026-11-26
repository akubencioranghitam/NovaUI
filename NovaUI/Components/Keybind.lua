local UserInputService = game:GetService("UserInputService")
local Element = require(script.Parent.Parent.Core.Element)
local Keybind = {}

-- Callback fires when the bound key is pressed; ChangedCallback when the binding changes.
-- While listening: Escape cancels, Backspace clears (Enum.KeyCode.Unknown).
function Keybind.new(ctx, section, config)
	local U, theme = ctx.utilities, ctx.theme
	local self = Element.new(ctx, section, config, "Keybind", { slot = 112 })
	local listening = false
	local button = U.create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.9, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd, Parent = self.slot }, { U.corner(9) })
	theme:Bind(button, { BackgroundColor3 = "Surface", TextColor3 = "Text" })

	local function label(key)
		return if key == Enum.KeyCode.Unknown then "None" else key.Name
	end
	self:UseValue({
		default = config.Default or Enum.KeyCode.Unknown,
		callback = "ChangedCallback",
		normalize = function(value)
			if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
				return value
			end
			return nil
		end,
		render = function(value)
			button.Text = label(value)
		end,
	})

	local function stop()
		if listening then
			listening = false
			ctx.capturing = nil
			button.Text = label(self.Value)
		end
	end
	self.maid:Add(stop)
	self.maid:Add(button.Activated:Connect(function()
		if not self.Enabled or listening then
			return
		end
		if ctx.capturing then
			ctx.capturing() -- only one keybind listens at a time
		end
		listening = true
		ctx.capturing = stop
		button.Text = "Press a key…"
	end))
	self.maid:Add(UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if listening then
			local key = input.KeyCode
			-- defer so other handlers still see capturing for this key press
			task.defer(function()
				stop()
				if key == Enum.KeyCode.Backspace then
					self:SetValue(Enum.KeyCode.Unknown)
				elseif key ~= Enum.KeyCode.Escape then
					self:SetValue(key)
				end
			end)
		elseif not processed and not ctx.capturing and self.Enabled and self.Value ~= Enum.KeyCode.Unknown and input.KeyCode == self.Value then
			U.fire(config.Callback, self.Value)
		end
	end))
	self.onEnabled = function(enabled)
		if not enabled then
			stop()
		end
	end
	return self
end

return Keybind
