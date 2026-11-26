local Element = require(script.Parent.Parent.Core.Element)
local Paragraph = {}

-- Title + wrapped body text. SetText changes the body; SetTitle changes the heading.
function Paragraph.new(ctx, section, config)
	local self = Element.new(ctx, section, config, "Paragraph")
	self.titleLabel.Font = Enum.Font.GothamBold
	self.titleLabel.Text = config.Title or config.Name or "Paragraph"
	self.Name = self.titleLabel.Text
	self:SetDescription(config.Text or "")

	function self:SetTitle(title)
		self.Name = title
		self.titleLabel.Text = title
	end
	function self:SetText(text)
		self:SetDescription(text)
	end
	return self
end

return Paragraph
