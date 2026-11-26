--!nocheck
-- NovaUI loadstring entry point.
-- Loads the existing modules from this repository while emulating the small
-- ModuleScript tree expected by the original init.lua.

local OWNER = "akubencioranghitam"
local REPOSITORY = "NovaUI"
local BRANCH = "main"
local ROOT_PATH = "NovaUI"

local BASE_URL = "https://raw.githubusercontent.com/" .. OWNER .. "/" .. REPOSITORY .. "/" .. BRANCH .. "/" .. ROOT_PATH .. "/"

local MODULES = {
    "Core/AnimationManager.lua",
    "Core/Element.lua",
    "Core/Icons.lua",
    "Core/Section.lua",
    "Core/Tab.lua",
    "Core/ThemeManager.lua",
    "Core/Utilities.lua",
    "Core/Window.lua",

    "Features/Configuration.lua",
    "Features/ContextMenu.lua",
    "Features/Notifications.lua",
    "Features/Search.lua",

    "Components/Button.lua",
    "Components/ColorPicker.lua",
    "Components/Divider.lua",
    "Components/Dropdown.lua",
    "Components/Keybind.lua",
    "Components/Label.lua",
    "Components/MultiDropdown.lua",
    "Components/Paragraph.lua",
    "Components/ProgressBar.lua",
    "Components/Slider.lua",
    "Components/Textbox.lua",
    "Components/Toggle.lua",

    "Themes/Aurora.lua",
    "Themes/CyberBlue.lua",
    "Themes/Lavender.lua",
    "Themes/MidnightPurple.lua",
    "Themes/Obsidian.lua",
    "Themes/RoseQuartz.lua",
}

local globalEnvironment = getfenv(0)
local sourceCache = {}
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
        local result = {}
        for _, child in pairs(self.__children) do
            table.insert(result, child)
        end
        return result
    end

    return setmetatable(node, {
        __index = function(self, key)
            local child = rawget(self, "__children")[key]
            if child ~= nil then
                return child
            end
            return nil
        end,
    })
end

local root = newNode("NovaUI", nil, false, nil)

local function addModule(relativePath)
    local parts = {}
    for part in string.gmatch(relativePath, "[^/]+") do
        table.insert(parts, part)
    end

    local parent = root
    local accumulated = ""

    for index, part in ipairs(parts) do
        accumulated = accumulated == "" and part or (accumulated .. "/" .. part)
        local isFile = index == #parts
        local name = isFile and string.gsub(part, "%.lua$", "") or part
        local child = parent.__children[name]

        if not child then
            child = newNode(name, parent, isFile, isFile and (ROOT_PATH .. "/" .. accumulated) or nil)
            parent.__children[name] = child
        end

        parent = child
    end
end

for _, path in ipairs(MODULES) do
    addModule(path)
end

local function moduleRequire(module)
    assert(type(module) == "table" and module.__isModule, "NovaUI: invalid module passed to require")

    if moduleCache[module] ~= nil then
        if moduleCache[module] == true then
            error("NovaUI: circular module dependency at " .. module.__path, 2)
        end
        return moduleCache[module]
    end

    moduleCache[module] = true

    local source = sourceCache[module.__path]
    if not source then
        local url = BASE_URL .. string.gsub(module.__path, " ", "%%20")
        local ok, result = pcall(function()
            return game:HttpGet(url)
        end)
        if not ok or type(result) ~= "string" or result == "" then
            moduleCache[module] = nil
            error("NovaUI: failed to download " .. module.__path .. ": " .. tostring(result), 2)
        end
        source = result
        sourceCache[module.__path] = source
    end

    local chunk, compileError = loadstring(source, "@NovaUI/" .. module.__path)
    if not chunk then
        moduleCache[module] = nil
        error("NovaUI: compile error in " .. module.__path .. ": " .. tostring(compileError), 2)
    end

    local environment = setmetatable({
        script = module,
        require = moduleRequire,
    }, {
        __index = globalEnvironment,
    })

    setfenv(chunk, environment)

    local ok, result = pcall(chunk)
    if not ok then
        moduleCache[module] = nil
        error("NovaUI: error while loading " .. module.__path .. ": " .. tostring(result), 2)
    end

    moduleCache[module] = result
    return result
end

-- Execute the original public entry point with the virtual NovaUI folder as script.
local initUrl = BASE_URL .. "init.lua"
local initSource = game:HttpGet(initUrl)
assert(type(initSource) == "string" and initSource ~= "", "NovaUI: could not download init.lua")

local initChunk, initError = loadstring(initSource, "@NovaUI/init.lua")
assert(initChunk, "NovaUI: init.lua compile error: " .. tostring(initError))

local initEnvironment = setmetatable({
    script = root,
    require = moduleRequire,
}, {
    __index = globalEnvironment,
})

setfenv(initChunk, initEnvironment)

local ok, NovaUI = pcall(initChunk)
assert(ok, "NovaUI: initialization failed: " .. tostring(NovaUI))
assert(type(NovaUI) == "table", "NovaUI: init.lua did not return the library table")

return NovaUI
