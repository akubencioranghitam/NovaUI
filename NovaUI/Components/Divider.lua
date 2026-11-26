local Element = require(script.Parent.Parent.Core.Element)
local Divider = {}

-- Thin separator, optionally with a caption (Text).
function Divider.new(ctx, section, config)
	local U, theme = ctx.utilities, ctx.theme
	local self = Element.new(ctx, section, config, "Divider", { flat = true })
	self.header.Visible = false
	local holder = U.create("Frame", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, LayoutOrder = 2, Parent = self.card })
	local line = U.create("Frame", { Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.new(1, -8, 0, 1), BackgroundTransparency = 0.82, Parent = holder })
	theme:Bind(line, { BackgroundColor3 = "Stroke" })
	local caption = U.create("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0, TextSize = 10, Parent = holder }, { U.padding(0, 8), U.round() })
	theme:Bind(caption, { TextColor3 = "SubText", BackgroundColor3 = "Background2" })

	function self:SetText(text)
		self.Name = text or ""
		caption.Text = self.Name
		caption.Visible = self.Name ~= ""
	end
	self:SetText(config.Text)
	return self
end

return Divider
