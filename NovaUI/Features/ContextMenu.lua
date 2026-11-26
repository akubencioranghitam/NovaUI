--!nonstrict
-- One floating menu per window. Opened by right-click or touch long-press.
local UserInputService = game:GetService("UserInputService")

local ContextMenu = {}
ContextMenu.__index = ContextMenu

local WIDTH, ROW = 176, 32

function ContextMenu.new(ctx: any)
	return setmetatable({ ctx = ctx, current = nil }, ContextMenu)
end

-- items: { { Text = string, Callback = function?, Disabled = boolean? } }
-- position: screen-space point (Vector2 or Vector3)
function ContextMenu:Open(position: any, items: { any })
	self:Close()
	if #items == 0 then
		return
	end
	local U, theme = self.ctx.utilities, self.ctx.theme
	local overlay = self.ctx.overlay
	local maid = U.maid()
	self.current = maid

	local catcher = maid:Add(U.create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = overlay }))
	maid:Add(catcher.Activated:Connect(function()
		self:Close()
	end))

	local height = #items * ROW + 10
	local origin, bounds = overlay.AbsolutePosition, overlay.AbsoluteSize
	local x = math.clamp(position.X - origin.X, 4, math.max(bounds.X - WIDTH - 4, 4))
	local y = math.clamp(position.Y - origin.Y, 4, math.max(bounds.Y - height - 4, 4))
	local menu = maid:Add(U.create("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(WIDTH, height), BackgroundTransparency = 0.03, Active = true, ZIndex = 2, Parent = overlay }, { U.corner(11), U.list(0), U.padding(5) }))
	theme:Bind(menu, { BackgroundColor3 = "Background2" })
	theme:Bind(U.create("UIStroke", { Transparency = 0.68, Parent = menu }), { Color = "Stroke" })
	local scale = U.create("UIScale", { Scale = 0.92, Parent = menu })
	self.ctx.animations:Tween(scale, { Scale = 1 }, "Fast")

	for index, item in items do
		local button = U.create("TextButton", { Size = UDim2.new(1, 0, 0, ROW), BackgroundTransparency = 1, Text = item.Text or "Action", TextSize = 12, TextTransparency = if item.Disabled then 0.55 else 0, LayoutOrder = index, Parent = menu }, { U.corner(8) })
		theme:Bind(button, { TextColor3 = "Text", BackgroundColor3 = "CardHover" })
		if not item.Disabled then
			maid:Add(button.MouseEnter:Connect(function()
				button.BackgroundTransparency = 0.82
			end))
			maid:Add(button.MouseLeave:Connect(function()
				button.BackgroundTransparency = 1
			end))
			maid:Add(button.Activated:Connect(function()
				self:Close()
				U.fire(item.Callback)
			end))
		end
	end
	maid:Add(UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape then
			self:Close()
		end
	end))
end

-- getItems is called at open time. Connections are owned by `maid`.
function ContextMenu:Attach(maid: any, target: GuiObject, getItems: () -> { any })
	maid:Add(target.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:Open(input.Position, getItems())
		end
	end))
	maid:Add(target.TouchLongPress:Connect(function(positions, state)
		if state == Enum.UserInputState.Begin and positions[1] then
			self:Open(positions[1], getItems())
		end
	end))
end

function ContextMenu:Close()
	local current = self.current
	if current then
		self.current = nil
		current:Clean()
	end
end

function ContextMenu:Destroy()
	self:Close()
end

return ContextMenu
