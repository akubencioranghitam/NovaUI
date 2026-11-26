--!nonstrict
--[[ Saves the values of components that have a `Flag`.

Roblox client scripts have no file system, so the default storage lives in memory
(lasts until the player leaves). For persistence, pass an adapter to SetStorage:
	{ read = (key) -> string?, write = (key, data), delete = (key), list = (prefix) -> {string} }
Adapter functions may yield and may error; errors are returned to the caller.
]]
local HttpService = game:GetService("HttpService")

local Configuration = {}
Configuration.__index = Configuration

local VERSION = 1

local function memoryStorage()
	local data = {}
	return {
		read = function(key)
			return data[key]
		end,
		write = function(key, value)
			data[key] = value
		end,
		delete = function(key)
			data[key] = nil
		end,
		list = function(prefix)
			local keys = {}
			for key in data do
				if string.sub(key, 1, #prefix) == prefix then
					table.insert(keys, key)
				end
			end
			return keys
		end,
	}
end

-- shared by every window so saved profiles survive re-creating a window
local sharedMemory = memoryStorage()

function Configuration.new(namespace: string, storage: any?)
	return setmetatable({ prefix = namespace .. "/", storage = storage or sharedMemory, flags = {} }, Configuration)
end

function Configuration:SetStorage(storage: any)
	for _, name in { "read", "write", "delete", "list" } do
		assert(type(storage[name]) == "function", "NovaUI: storage adapter needs " .. name)
	end
	self.storage = storage
end

function Configuration:Register(flag: string, element: any)
	assert(not self.flags[flag], `NovaUI: duplicate Flag "{flag}"`)
	self.flags[flag] = element
end

function Configuration:Unregister(flag: string, element: any)
	if self.flags[flag] == element then
		self.flags[flag] = nil
	end
end

function Configuration:Get(flag: string): any
	local element = self.flags[flag]
	return element and element:GetValue()
end

local function encode(value)
	if typeof(value) == "Color3" then
		return { __type = "Color3", value = value:ToHex() }
	elseif typeof(value) == "EnumItem" then
		return { __type = "KeyCode", value = value.Name }
	end
	return value
end

local function decode(value)
	if type(value) ~= "table" or value.__type == nil then
		return true, value
	end
	if value.__type == "Color3" then
		return pcall(Color3.fromHex, value.value)
	elseif value.__type == "KeyCode" then
		return pcall(function()
			return (Enum.KeyCode :: any)[value.value]
		end)
	end
	return false, nil
end

function Configuration:Export(): string
	local values = {}
	for flag, element in self.flags do
		-- progress bars show state; they are not user settings
		if element.Type ~= "ProgressBar" then
			values[flag] = encode(element:GetValue())
		end
	end
	return HttpService:JSONEncode({ version = VERSION, values = values })
end

-- Treats `json` as untrusted: unknown flags are ignored and each component validates its value.
-- Returns (success, appliedCountOrError)
function Configuration:Import(json: string): (boolean, any)
	local ok, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if not ok or type(data) ~= "table" or type(data.values) ~= "table" then
		return false, "not a NovaUI configuration"
	end
	if data.version ~= VERSION then
		return false, "unsupported configuration version"
	end
	local applied = 0
	for flag, raw in data.values do
		local element = self.flags[flag]
		if element and element.Type ~= "ProgressBar" then
			local decoded, value = decode(raw)
			if decoded and element:SetValue(value) then
				applied += 1
			end
		end
	end
	return true, applied
end

local function checkName(name)
	return type(name) == "string" and #name <= 40 and string.match(name, "^[%w _%-]+$") ~= nil
end

function Configuration:Save(name: string?): (boolean, string?)
	local profile = name or "default"
	if not checkName(profile) then
		return false, "profile names use letters, numbers, spaces, - and _ (max 40)"
	end
	local ok, err = pcall(function()
		self.storage.write(self.prefix .. profile, self:Export())
	end)
	return ok, if ok then nil else tostring(err)
end

function Configuration:Load(name: string?): (boolean, any)
	local profile = name or "default"
	if not checkName(profile) then
		return false, "invalid profile name"
	end
	local ok, data = pcall(function()
		return self.storage.read(self.prefix .. profile)
	end)
	if not ok then
		return false, tostring(data)
	end
	if type(data) ~= "string" then
		return false, "profile not found"
	end
	return self:Import(data)
end

function Configuration:Delete(name: string): (boolean, string?)
	if not checkName(name) then
		return false, "invalid profile name"
	end
	local ok, err = pcall(function()
		self.storage.delete(self.prefix .. name)
	end)
	return ok, if ok then nil else tostring(err)
end

-- Returns sorted profile names; on adapter failure returns {} and the error.
function Configuration:List(): ({ string }, string?)
	local ok, keys = pcall(function()
		return self.storage.list(self.prefix)
	end)
	if not ok then
		return {}, tostring(keys)
	end
	local names = {}
	for _, key in keys do
		table.insert(names, string.sub(key, #self.prefix + 1))
	end
	table.sort(names)
	return names
end

return Configuration
