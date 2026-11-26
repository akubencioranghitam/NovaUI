local Element = require(script.Parent.Parent.Core.Element)
local ColorPicker = {}

function ColorPicker.new(ctx, section, config)
	local U, theme, anim = ctx.utilities, ctx.theme, ctx.animations
	local self = Element.new(ctx, section, config, "ColorPicker", { slot = 64 })
	local open = false
	local hue, saturation, brightness = 0, 0, 1
	local fromDrag = false

	local swatch = U.create("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(42, 28), Parent = self.slot }, { U.corner(9) })
	theme:Bind(U.create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = 0.5, Parent = swatch }), { Color = "Stroke" })

	local body = self:CreateBody()
	local square = U.create("TextButton", { Position = UDim2.fromOffset(13, 4), Size = UDim2.new(1, -26, 0, 100), Parent = body }, { U.corner(8) })
	local function overlay(color, rotation, from, to)
		U.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, Parent = square }, {
			U.corner(8),
			U.create("UIGradient", { Rotation = rotation, Transparency = NumberSequence.new(from, to) }),
		})
	end
	overlay(Color3.new(1, 1, 1), 0, 0, 1)
	overlay(Color3.new(0, 0, 0), 90, 1, 0)
	local function marker(parent)
		return U.create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, ZIndex = 3, Parent = parent }, {
			U.round(),
			U.create("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1) }),
		})
	end
	local squareMarker = marker(square)

	local hueBar = U.create("TextButton", { Position = UDim2.fromOffset(13, 114), Size = UDim2.new(1, -26, 0, 14), BackgroundColor3 = Color3.new(1, 1, 1), Parent = body }, { U.round() })
	local points = {}
	for i = 0, 6 do
		table.insert(points, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)))
	end
	U.create("UIGradient", { Color = ColorSequence.new(points), Parent = hueBar })
	local hueMarker = marker(hueBar)

	local hex = U.create("TextBox", { Position = UDim2.fromOffset(13, 138), Size = UDim2.new(1, -26, 0, 28), BackgroundTransparency = 0.9, TextSize = 12, Parent = body }, { U.corner(9) })
	theme:Bind(hex, { TextColor3 = "Text", BackgroundColor3 = "Surface" })

	local function paint(color)
		swatch.BackgroundColor3 = color
		square.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		squareMarker.Position = UDim2.fromScale(saturation, 1 - brightness)
		hueMarker.Position = UDim2.fromScale(hue, 0.5)
		hex.Text = "#" .. string.upper(color:ToHex())
	end

	self:UseValue({
		default = config.Default or Color3.fromRGB(139, 108, 255),
		normalize = function(value)
			return if typeof(value) == "Color3" then value else nil
		end,
		render = function(color)
			if not fromDrag then
				-- while dragging we keep our own HSV so hue survives black and white
				hue, saturation, brightness = color:ToHSV()
			end
			paint(color)
		end,
	})

	local function commit()
		fromDrag = true
		local color = Color3.fromHSV(hue, saturation, brightness)
		self:SetValue(color)
		paint(color)
		fromDrag = false
	end
	local function pick(target, apply)
		local function move(position)
			local size = target.AbsoluteSize
			if self.Enabled and size.X > 0 and size.Y > 0 then
				apply(
					math.clamp((position.X - target.AbsolutePosition.X) / size.X, 0, 1),
					math.clamp((position.Y - target.AbsolutePosition.Y) / size.Y, 0, 1)
				)
				commit()
			end
		end
		U.drag(self.maid, target, function(position)
			if not self.Enabled then
				return false
			end
			move(position)
			return true
		end, move)
	end
	pick(square, function(x, y)
		saturation, brightness = x, 1 - y
	end)
	pick(hueBar, function(x)
		hue = x
	end)

	self.maid:Add(hex.FocusLost:Connect(function()
		local code = string.match(hex.Text, "^%s*#?(%x%x%x%x%x%x)%s*$")
		if code and self.Enabled then
			self:SetValue(Color3.fromHex(code))
		end
		paint(self.Value)
	end))

	function self:SetOpen(state)
		open = state and self.Enabled
		if open then
			body.Visible = true
		end
		local tween = anim:Tween(body, { Size = UDim2.new(1, 0, 0, if open then 176 else 0) })
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
	self.maid:Add(swatch.Activated:Connect(function()
		self:SetOpen(not open)
	end))
	self.onEnabled = function(enabled)
		hex.TextEditable = enabled
		if not enabled then
			self:SetOpen(false)
		end
	end
	return self
end

return ColorPicker
