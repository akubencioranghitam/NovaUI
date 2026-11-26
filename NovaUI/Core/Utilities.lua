--!nonstrict
-- Small shared helpers. Depends on nothing else in NovaUI.
local UserInputService = game:GetService("UserInputService")

local Utilities = {}

local DEFAULTS = {
	Frame = { BorderSizePixel = 0 },
	ScrollingFrame = { BorderSizePixel = 0, BackgroundTransparency = 1, ScrollBarThickness = 3 },
	TextLabel = { BorderSizePixel = 0, BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 13, Text = "" },
	TextButton = { BorderSizePixel = 0, AutoButtonColor = false, Font = Enum.Font.GothamMedium, TextSize = 13, Text = "" },
	TextBox = { BorderSizePixel = 0, Font = Enum.Font.GothamMedium, TextSize = 13, Text = "", ClearTextOnFocus = false },
}

function Utilities.create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance: any = Instance.new(className)
	for key, value in (DEFAULTS[className] or {}) :: any do
		instance[key] = value
	end
	local parent = nil
	for key, value in (props or {}) :: any do
		if key == "Parent" then
			parent = value
		else
			instance[key] = value
		end
	end
	for _, child in (children or {}) :: any do
		child.Parent = instance
	end
	instance.Parent = parent -- parent last so layout is computed once
	return instance
end

function Utilities.corner(radius: number?): any
	return Utilities.create("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function Utilities.round(): any
	return Utilities.create("UICorner", { CornerRadius = UDim.new(1, 0) })
end

function Utilities.padding(top: number, right: number?, bottom: number?, left: number?): any
	local r = right or top
	return Utilities.create("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, r),
		PaddingBottom = UDim.new(0, bottom or top),
		PaddingLeft = UDim.new(0, left or r),
	})
end

function Utilities.list(gap: number?, direction: Enum.FillDirection?): any
	return Utilities.create("UIListLayout", {
		Padding = UDim.new(0, gap or 0),
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

-- Collects connections, instances, threads and functions; Clean() releases them all.
local Maid = {}
Maid.__index = Maid

function Maid:Add(item: any): any
	if self.cleaned then
		Maid.release(item)
	else
		table.insert(self.items, item)
	end
	return item
end

function Maid.release(item: any)
	local kind = typeof(item)
	if kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "function" then
		item()
	elseif kind == "thread" then
		pcall(task.cancel, item) -- fails harmlessly if the thread is the running one
	elseif kind == "table" and item.Destroy then
		item:Destroy()
	end
end

function Maid:Clean()
	if self.cleaned then
		return
	end
	self.cleaned = true
	for i = #self.items, 1, -1 do
		Maid.release(self.items[i])
	end
	table.clear(self.items)
end

function Utilities.maid(): any
	return setmetatable({ items = {}, cleaned = false }, Maid)
end

-- Runs user code in its own thread so an error or yield never breaks the UI.
function Utilities.fire(callback: any, ...: any)
	if callback then
		task.spawn(callback, ...)
	end
end

function Utilities.isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- Mouse + touch dragging. Global connections only exist while a drag is active.
-- onStart(position) may return false to refuse the drag.
function Utilities.drag(maid: any, handle: GuiObject, onStart: ((Vector3) -> any)?, onMove: (Vector3, Vector3) -> (), onEnd: (() -> ())?)
	local active: any = nil
	local function stop()
		if not active then
			return
		end
		local drag = active
		active = nil
		drag.changed:Disconnect()
		drag.ended:Disconnect()
		for _, scroller in drag.scrollers do
			scroller.ScrollingEnabled = true
		end
		if onEnd then
			onEnd()
		end
	end
	maid:Add(stop)
	maid:Add(handle.InputBegan:Connect(function(input)
		if active or not Utilities.isPress(input) then
			return
		end
		local origin = input.Position
		if onStart and onStart(origin) == false then
			return
		end
		-- stop touch drags from also scrolling the page underneath
		local scrollers = {}
		local ancestor: any = handle.Parent
		while ancestor do
			if ancestor:IsA("ScrollingFrame") and ancestor.ScrollingEnabled then
				ancestor.ScrollingEnabled = false
				table.insert(scrollers, ancestor)
			end
			ancestor = ancestor.Parent
		end
		local isTouch = input.UserInputType == Enum.UserInputType.Touch
		active = {
			scrollers = scrollers,
			changed = UserInputService.InputChanged:Connect(function(moved)
				if (isTouch and moved == input) or (not isTouch and moved.UserInputType == Enum.UserInputType.MouseMovement) then
					onMove(moved.Position, moved.Position - origin)
				end
			end),
			ended = UserInputService.InputEnded:Connect(function(ended)
				if ended == input or (not isTouch and ended.UserInputType == Enum.UserInputType.MouseButton1) then
					stop()
				end
			end),
		}
	end))
end

return Utilities
