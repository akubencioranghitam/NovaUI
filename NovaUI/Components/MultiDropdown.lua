-- Multi-select variant. Value is an array of option strings, in option order.
local Dropdown = require(script.Parent.Dropdown)
local MultiDropdown = {}

function MultiDropdown.new(ctx, section, config)
	return Dropdown.build(ctx, section, config, true)
end

return MultiDropdown
