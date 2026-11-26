--!nonstrict
--[[ NovaUI — public entry point.
This is the only module that wires the others together; Core and Features receive
their dependencies through a context table, so there are no circular requires. ]]
local Players = game:GetService("Players")

local Core = script.Core
local Features = script.Features
local Components = script.Components

local Utilities = require(Core.Utilities)
local AnimationManager = require(Core.AnimationManager)
local ThemeManager = require(Core.ThemeManager)
local Icons = require(Core.Icons)
local Window = require(Core.Window)
local Tab = require(Core.Tab)
local Section = require(Core.Section)
local Search = require(Features.Search)
local ContextMenu = require(Features.ContextMenu)
local Notifications = require(Features.Notifications)
local Configuration = require(Features.Configuration)

local NovaUI = {
	Version = "0.1.0",
	Animations = AnimationManager,
}

local theme = ThemeManager.new(AnimationManager)
NovaUI.Theme = theme

-- Built-in themes: add a file to Themes/ and it is picked up automatically.
for _, module in script.Themes:GetChildren() do
	local definition = require(module) :: any
	theme:Register(definition.Name, definition.Colors)
end
theme:Set("Midnight Purple")

local components = {
	Button = require(Components.Button),
	Toggle = require(Components.Toggle),
	Slider = require(Components.Slider),
	Dropdown = require(Components.Dropdown),
	MultiDropdown = require(Components.MultiDropdown),
	Textbox = require(Components.Textbox),
	Keybind = require(Components.Keybind),
	ColorPicker = require(Components.ColorPicker),
	Label = require(Components.Label),
	Paragraph = require(Components.Paragraph),
	Divider = require(Components.Divider),
	ProgressBar = require(Components.ProgressBar),
}

local windows = {}
local defaultParent: Instance? = nil

local function makeGui(name: string, displayOrder: number, parent: Instance?)
	local target = parent or defaultParent
	if not target then
		local player = Players.LocalPlayer
		assert(player, "NovaUI must run in a LocalScript, or be given a Parent")
		target = player:WaitForChild("PlayerGui")
	end
	return Utilities.create("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder,
		Parent = target,
	})
end

local notifications = Notifications.new(Utilities, theme, AnimationManager, Icons, function()
	return makeGui("NovaUINotifications", 110)
end)

--[[ config: Title, Subtitle, Theme, Size (Vector2), MinSize (Vector2), Resizable,
Search, ToggleKey (KeyCode or false), Parent, ConfigName, Storage ]]
function NovaUI:CreateWindow(config: any?)
	local options = config or {}
	if options.Parent then
		defaultParent = options.Parent
	end
	if options.Theme then
		theme:Set(options.Theme)
	end
	local ctx: any = {
		utilities = Utilities,
		theme = theme,
		animations = AnimationManager,
		icons = Icons,
		tab = Tab,
		section = Section,
		search = Search,
		contextMenuClass = ContextMenu,
		components = components,
		config = Configuration.new(options.ConfigName or options.Title or "NovaUI", options.Storage),
	}
	local window = Window.new(ctx, options, makeGui("NovaUI", 100, options.Parent), function(closed)
		local index = table.find(windows, closed)
		if index then
			table.remove(windows, index)
		end
	end)
	window.Config = ctx.config
	window.ContextMenu = ctx.contextMenu
	table.insert(windows, window)
	return window
end

function NovaUI:Notify(options: any)
	return notifications:Notify(options or {})
end

function NovaUI:SetTheme(name: string): boolean
	return theme:Set(name)
end

function NovaUI:GetThemes(): { string }
	return theme:GetNames()
end

function NovaUI:RegisterTheme(name: string, colors: { [string]: any }, base: string?)
	theme:Register(name, colors, base)
end

function NovaUI:CustomizeTheme(overrides: { [string]: Color3 })
	theme:Customize(overrides)
end

-- Adds Section:Create<Name>(config). `module.new(ctx, section, config)` must return an Element.
function NovaUI:RegisterComponent(name: string, module: any)
	assert(string.match(name, "^%u%w*$"), "NovaUI: component names are PascalCase")
	assert(not components[name], "NovaUI: component already registered: " .. name)
	assert(type(module.new) == "function", "NovaUI: component needs new()")
	components[name] = module
end

-- Destroys every window and notification created by NovaUI.
function NovaUI:Destroy()
	for _, window in table.clone(windows) do
		window:Destroy()
	end
	notifications:Destroy()
	defaultParent = nil
end

NovaUI.Element = require(Core.Element) -- base class for custom components

return NovaUI
