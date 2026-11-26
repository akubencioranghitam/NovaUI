local Element = require(script.Parent.Parent.Core.Element)
local Label = {}

function Label.new(ctx, section, config)
	if type(config) == "string" then
		config = { Text = config }
	end
	local self = Element.new(ctx, section, config, "Label", { flat = true })
	self:SetText(config.Text or config.Name or "Label")
	return self
end

return Label
