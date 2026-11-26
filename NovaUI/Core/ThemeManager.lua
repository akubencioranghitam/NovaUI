--!nonstrict
-- Holds the active palette and repaints every bound instance when it changes.
local ThemeManager = {}
ThemeManager.__index = ThemeManager

local SHARED = {
	Text = Color3.fromRGB(244, 242, 255),
	OnAccent = Color3.fromRGB(255, 255, 255),
	Success = Color3.fromRGB(82, 214, 158),
	Warning = Color3.fromRGB(246, 190, 92),
	Error = Color3.fromRGB(242, 104, 128),
	Info = Color3.fromRGB(102, 174, 255),
}

local REQUIRED = { "Background", "Background2", "Surface", "Card", "CardHover", "Stroke", "SubText", "Accent", "Accent2", "Track", "Glow1", "Glow2" }

-- animations: AnimationManager (injected to keep this module dependency-free)
function ThemeManager.new(animations: any)
	return setmetatable({
		animations = animations,
		themes = {},
		current = nil,
		name = nil,
		bindings = {}, -- [instance] = { [property] = key | function(theme) }
		listeners = {},
	}, ThemeManager)
end

-- A theme may be partial if `base` names an already registered theme.
function ThemeManager:Register(name: string, palette: { [string]: any }, base: string?)
	local theme = table.clone(SHARED)
	if base then
		assert(self.themes[base], "NovaUI: unknown base theme " .. base)
		theme = table.clone(self.themes[base])
	end
	for key, value in palette do
		theme[key] = value
	end
	for _, key in REQUIRED do
		assert(typeof(theme[key]) == "Color3", `NovaUI: theme "{name}" is missing color "{key}"`)
	end
	self.themes[name] = theme
end

function ThemeManager:GetNames(): { string }
	local names = {}
	for name in self.themes do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function ThemeManager:Resolve(spec: any): any
	if type(spec) == "function" then
		return spec(self.current)
	end
	return self.current[spec]
end

function ThemeManager:Bind(instance: Instance, properties: { [string]: any })
	local bound = self.bindings[instance]
	if not bound then
		bound = {}
		self.bindings[instance] = bound
		instance.Destroying:Connect(function()
			self.bindings[instance] = nil
		end)
	end
	for property, spec in properties do
		bound[property] = spec
		if self.current then
			(instance :: any)[property] = self:Resolve(spec)
		end
	end
	return instance
end

-- Re-evaluate one instance after the state its binding function reads has changed.
function ThemeManager:Refresh(instance: Instance, preset: string?)
	local goal, instant = {}, {}
	for property, spec in self.bindings[instance] or {} do
		local value = self:Resolve(spec)
		if typeof(value) == "ColorSequence" or typeof(value) == "NumberSequence" then
			instant[property] = value -- sequences cannot be tweened
		else
			goal[property] = value
		end
	end
	for property, value in instant do
		(instance :: any)[property] = value
	end
	if next(goal) then
		if preset then
			self.animations:Tween(instance, goal, preset)
		else
			for property, value in goal do
				(instance :: any)[property] = value
			end
		end
	end
end

function ThemeManager:Set(name: string): boolean
	local theme = self.themes[name]
	if not theme then
		warn("NovaUI: unknown theme " .. tostring(name))
		return false
	end
	local animate = self.current ~= nil
	self.current, self.name = table.clone(theme), name
	self:_repaint(animate)
	return true
end

-- Override individual colors of the active theme (does not alter the registered theme).
function ThemeManager:Customize(overrides: { [string]: Color3 })
	for key, value in overrides do
		if self.current[key] and typeof(value) == "Color3" then
			self.current[key] = value
		end
	end
	self:_repaint(true)
end

function ThemeManager:_repaint(animate: boolean)
	for instance in self.bindings do
		self:Refresh(instance, if animate then "Smooth" else nil)
	end
	for listener in self.listeners do
		task.spawn(listener, self.name, self.current)
	end
end

function ThemeManager:OnChanged(listener: (string, any) -> ()): () -> ()
	self.listeners[listener] = true
	return function()
		self.listeners[listener] = nil
	end
end

return ThemeManager
