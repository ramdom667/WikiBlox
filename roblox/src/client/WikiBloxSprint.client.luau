-- WikiBlox : course (Shift sur PC, bouton "Courir" sur mobile, L3 / X sur manette)
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local VITESSE_MARCHE = 16
local VITESSE_COURSE = 26
local FOV_MARCHE = 70
local FOV_COURSE = 80

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local humanoid = nil
local enCourse = false

local function appliquer()
	if humanoid then
		humanoid.WalkSpeed = enCourse and VITESSE_COURSE or VITESSE_MARCHE
	end
	TweenService:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = enCourse and FOV_COURSE or FOV_MARCHE,
	}):Play()
end

local function surAction(_, etat, input)
	if input.UserInputType == Enum.UserInputType.Touch then
		-- Mobile : un appui active / désactive la course
		if etat == Enum.UserInputState.Begin then
			enCourse = not enCourse
			appliquer()
		end
	else
		-- Clavier / manette : on court tant que la touche est maintenue
		if etat == Enum.UserInputState.Begin then
			enCourse = true
		elseif etat == Enum.UserInputState.End or etat == Enum.UserInputState.Cancel then
			enCourse = false
		end
		appliquer()
	end
	return Enum.ContextActionResult.Sink
end

local function surPersonnage(perso)
	humanoid = perso:WaitForChild("Humanoid")
	enCourse = false
	appliquer()
	humanoid.Died:Connect(function()
		enCourse = false
		appliquer()
	end)
end

if player.Character then surPersonnage(player.Character) end
player.CharacterAdded:Connect(surPersonnage)

ContextActionService:BindActionAtPriority("WikiBloxSprint", surAction, true, 2000,
	Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3, Enum.KeyCode.ButtonX)
ContextActionService:SetTitle("WikiBloxSprint", "Courir")
ContextActionService:SetPosition("WikiBloxSprint", UDim2.new(1, -170, 1, -150))
