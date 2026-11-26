--!nocheck
-- NovaUI loadstring bootstrap. The original init.lua remains unchanged.
local OWNER = "akubencioranghitam"
local REPOSITORY = "NovaUI"
local BRANCH = "main"
local ROOT_PATH = "NovaUI"
local BASE_URL = "https://raw.githubusercontent.com/" .. OWNER .. "/" .. REPOSITORY .. "/" .. BRANCH .. "/" .. ROOT_PATH .. "/"

local MODULES = {
    "Core/AnimationManager.lua", "Core/Element.lua", "Core/Icons.lua",
    "Core/Section.lua", "Core/Tab.lua", "Core/ThemeManager.lua",
    "Core/Utilities.lua", "Core/Window.lua",
    "Features/Configuration.lua", "Features/ContextMenu.lua",
    "Features/Notifications.lua", "Features/Search.lua",
    "Components/Button.lua", "Components/ColorPicker.lua",
    "Components/Divider.lua", "Components/Dropdown.lua",
    "Components/Keybind.lua", "Components/Label.lua",
    "Components/MultiDropdown.lua", "Components/Paragraph.lua",
    "Components/ProgressBar.lua", "Components/Slider.lua",
    "Components/Textbox.lua", "Components/Toggle.lua",
    "Themes/Aurora.lua", "Themes/CyberBlue.lua", "Themes/Lavender.lua",
    "Themes/MidnightPurple.lua", "Themes/Obsidian.lua", "Themes/RoseQuartz.lua",
}

local globalEnvironment = getfenv(0)
local moduleCache = {}

local function newNode(name, parent, isModule, path)
    local node = {
        Name = name,
        Parent = parent,
        __children = {},
        __isModule = isModule == true,
        __path = path,
    }

    function node:GetChildren()
        local children = {}
        for _, child in pairs(self.__children) do
            table.insert(children, child)
        end
        return children
    end

    return setmetatable(node, {
        __index = function(self, key)
            return rawget(self, "__children")[key]
        end,
    })
end

local root = newNode("NovaUI", nil, false, nil)

for _, relativePath in ipairs(MODULES) do
    local parent = root
    local accumulated = {}
    for part in string.gmatch(relativePath, "[^/]+") do
        table.insert(accumulated, part)
        local isFile = #accumulated == 2
        local name = isFile and string.gsub(part, "%.lua$", "") or part
        local child = parent.__children[name]
        if not child then
            child = newNode(name, parent, isFile, isFile and table.concat(accumulated, "/") or nil)
            parent.__children[name] = child
        end
        parent = child
    end
end

local function moduleRequire(module)
    assert(type(module) == "table" and module.__isModule, "NovaUI: invalid module passed to require")
    if moduleCache[module] ~= nil then
        if moduleCache[module] == true then
            error("NovaUI: circular dependency at " .. tostring(module.__path), 2)
        end
        return moduleCache[module]
    end

    moduleCache[module] = true
    local url = BASE_URL .. module.__path
    local ok, source = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok or type(source) ~= "string" or source == "" then
        moduleCache[module] = nil
        error("NovaUI: download failed for " .. module.__path .. ": " .. tostring(source), 2)
    end

    local chunk, compileError = loadstring(source, "@NovaUI/" .. module.__path)
    if not chunk then
        moduleCache[module] = nil
        error("NovaUI: compile failed for " .. module.__path .. ": " .. tostring(compileError), 2)
    end

    setfenv(chunk, setmetatable({
        script = module,
        require = moduleRequire,
    }, { __index = globalEnvironment }))

    local ran, result = pcall(chunk)
    if not ran then
        moduleCache[module] = nil
        error("NovaUI: module error in " .. module.__path .. ": " .. tostring(result), 2)
    end

    moduleCache[module] = result
    return result
end

local ok, initSource = pcall(function()
    return game:HttpGet(BASE_URL .. "init.lua")
end)
assert(ok and type(initSource) == "string" and initSource ~= "", "NovaUI: could not download original init.lua: " .. tostring(initSource))

local initChunk, compileError = loadstring(initSource, "@NovaUI/init.lua")
assert(initChunk, "NovaUI: init.lua compile failed: " .. tostring(compileError))
setfenv(initChunk, setmetatable({
    script = root,
    require = moduleRequire,
}, { __index = globalEnvironment }))

local NovaUI = initChunk()

assert(type(NovaUI) == "table", "NovaUI did not return a table")

return NovaUI
