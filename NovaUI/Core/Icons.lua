--!nonstrict
-- Asset-free line icons drawn from Frames on a 16x16 grid.
-- Shapes: { x, y, w, h, radius, outline? } or { line = { x1, y1, x2, y2 } }.
-- No rotation anywhere: ClipsDescendants has not reliably clipped rotated GuiObjects,
-- so diagonals are built from small dots.
local ICONS = {
	["layout-dashboard"] = { { 1, 1, 6, 8, 2 }, { 9, 1, 6, 5, 2 }, { 1, 11, 6, 4, 2 }, { 9, 8, 6, 7, 2 } },
	home = { { 3, 8, 10, 7, 2, true }, { line = { 1, 8, 8, 2 } }, { line = { 8, 2, 15, 8 } } },
	settings = { { 2, 2, 12, 12, 8, true }, { 6, 6, 4, 4, 4 } },
	sliders = { { 1, 4, 14, 2, 1 }, { 1, 11, 14, 2, 1 }, { 9, 2, 3, 6, 2 }, { 4, 9, 3, 6, 2 } },
	palette = { { 1, 1, 14, 14, 8, true }, { 4, 5, 3, 3, 3 }, { 9, 4, 3, 3, 3 }, { 9, 10, 3, 3, 3 } },
	user = { { 5, 1, 6, 6, 6, true }, { 2, 10, 12, 5, 5, true } },
	bell = { { 4, 2, 8, 10, 5, true }, { 2, 11, 12, 2, 1 }, { 6, 14, 4, 2, 1 } },
	chart = { { 2, 8, 3, 7, 1 }, { 7, 2, 3, 13, 1 }, { 12, 6, 3, 9, 1 } },
	folder = { { 1, 4, 14, 10, 3, true }, { 2, 2, 6, 3, 1 } },
	info = { { 1, 1, 14, 14, 8, true }, { 7, 7, 2, 5, 1 }, { 7, 4, 2, 2, 1 } },
	search = { { 2, 2, 9, 9, 8, true }, { line = { 10, 10, 14, 14 } } },
	minus = { { 3, 7, 10, 2, 1 } },
	maximize = { { 3, 3, 10, 10, 2, true } },
	close = { { line = { 4, 4, 12, 12 } }, { line = { 4, 12, 12, 4 } } },
	check = { { line = { 3, 8, 6, 11 } }, { line = { 6, 11, 13, 4 } } },
	["chevron-down"] = { { line = { 4, 6, 8, 10 } }, { line = { 8, 10, 12, 6 } } },
	["chevron-up"] = { { line = { 4, 10, 8, 6 } }, { line = { 8, 6, 12, 10 } } },
	["chevron-right"] = { { line = { 6, 4, 10, 8 } }, { line = { 10, 8, 6, 12 } } },
	warning = { { 7, 2, 2, 8, 1 }, { 7, 12, 2, 2, 1 } },
}

local Icons = {}

-- create: Utilities.create, theme: ThemeManager, colorKey: theme key or function(theme)
-- Returns a 16x16 Frame. SetColor(spec, preset) repaints it.
function Icons.draw(create: any, theme: any, name: string?, colorKey: any, parent: Instance)
	local root = create("Frame", { Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1, Parent = parent })
	local painted = {}
	local function paint(instance: Instance, property: string)
		theme:Bind(instance, { [property] = colorKey })
		table.insert(painted, { instance, property })
	end
	local shapes = ICONS[name or ""]
	if name and string.match(name, "^rbxasset") then
		paint(create("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = name, Parent = root }), "ImageColor3")
	elseif not shapes then -- unknown name: show its first letter
		local letter = string.upper(string.sub(name or "•", 1, 1))
		paint(create("TextLabel", { Size = UDim2.fromScale(1, 1), Text = letter, Font = Enum.Font.GothamBold, Parent = root }), "TextColor3")
	else
		local expanded = {}
		for _, s in shapes do
			if s.line then
				local x1, y1, x2, y2 = table.unpack(s.line)
				local steps = math.max(math.abs(x2 - x1), math.abs(y2 - y1))
				for i = 0, steps do
					table.insert(expanded, { x1 + (x2 - x1) * i / steps - 1, y1 + (y2 - y1) * i / steps - 1, 2, 2, 2 })
				end
			else
				table.insert(expanded, s)
			end
		end
		for _, s in expanded do
			local outline = s[6] == true
			local inset = if outline then 1 else 0 -- UIStroke draws outside the frame
			local part = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(s[1] + s[3] / 2, s[2] + s[4] / 2),
				Size = UDim2.fromOffset(s[3] - inset * 2, s[4] - inset * 2),
				BackgroundTransparency = if outline then 1 else 0,
				Parent = root,
			})
			create("UICorner", { CornerRadius = UDim.new(0, s[5]), Parent = part })
			if outline then
				paint(create("UIStroke", { Thickness = 1.5, Parent = part }), "Color")
			else
				paint(part, "BackgroundColor3")
			end
		end
	end
	local function setColor(spec: any, preset: string?)
		colorKey = spec
		for _, entry in painted do
			theme:Bind(entry[1], { [entry[2]] = spec })
			theme:Refresh(entry[1], preset)
		end
	end
	return root, setColor
end

return Icons
