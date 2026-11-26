--!nonstrict
-- Single place for motion. Set Speed, or Enabled = false for reduced motion.
local TweenService = game:GetService("TweenService")

local AnimationManager = { Enabled = true, Speed = 1 }

AnimationManager.Presets = {
	Fast = { 0.12, Enum.EasingStyle.Quad },
	Smooth = { 0.24, Enum.EasingStyle.Quint },
	Slow = { 0.4, Enum.EasingStyle.Quint },
	Spring = { 0.34, Enum.EasingStyle.Back },
}

function AnimationManager:Duration(preset: string?): number
	if not self.Enabled then
		return 0
	end
	return self.Presets[preset or "Smooth"][1] / math.max(self.Speed, 0.01)
end

function AnimationManager:Tween(instance: Instance, goal: { [string]: any }, preset: string?): Tween?
	local duration = self:Duration(preset)
	if duration == 0 then
		for key, value in goal do
			(instance :: any)[key] = value
		end
		return nil
	end
	local style = self.Presets[preset or "Smooth"][2]
	local tween = TweenService:Create(instance, TweenInfo.new(duration, style, Enum.EasingDirection.Out), goal)
	tween:Play()
	return tween
end

-- Shrinks a little while held. Adds one UIScale to the target.
function AnimationManager:Press(button: GuiButton, target: GuiObject?, amount: number?)
	local scale = Instance.new("UIScale")
	scale.Parent = target or button
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self:Tween(scale, { Scale = amount or 0.97 }, "Fast")
		end
	end)
	local function release()
		self:Tween(scale, { Scale = 1 }, "Spring")
	end
	button.InputEnded:Connect(release)
	button.MouseLeave:Connect(release)
end

return AnimationManager
