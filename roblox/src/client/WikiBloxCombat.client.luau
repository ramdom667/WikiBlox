-- WikiBlox : coups de poing (F, clic gauche, R2 manette, bouton "Frapper" sur mobile)
-- Combo gauche / droite, animation jouée tout de suite chez soi, dégâts décidés par le serveur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Anim = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WikiBloxAnimations"))
local dossier = ReplicatedStorage:WaitForChild("WikiBloxCombat")
local frapper = dossier:WaitForChild("Frapper")
local effets = dossier:WaitForChild("Effets")

local RECHARGE = 0.45

local player = Players.LocalPlayer
local dernier = 0
local prochainBras = "droit"

local function frappe()
	if os.clock() - dernier < RECHARGE then return end
	local perso = player.Character
	local hum = perso and perso:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	dernier = os.clock()

	local bras = prochainBras
	prochainBras = (bras == "droit") and "gauche" or "droit"
	Anim.coup(perso, bras)
	frapper:FireServer(bras)
end

ContextActionService:BindAction("WikiBloxFrapper", function(_, etat)
	if etat == Enum.UserInputState.Begin then frappe() end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
ContextActionService:SetTitle("WikiBloxFrapper", "Frapper")
ContextActionService:SetPosition("WikiBloxFrapper", UDim2.new(1, -170, 1, -230))

-- Clic gauche (sauf quand on clique sur un bouton de l'interface)
UserInputService.InputBegan:Connect(function(input, dejaTraite)
	if not dejaTraite and input.UserInputType == Enum.UserInputType.MouseButton1 then
		frappe()
	end
end)

-- Effets envoyés par le serveur : coups et saltos des autres joueurs, impacts de tout le monde
effets.OnClientEvent:Connect(function(genre, a, b)
	if genre == "coup" then
		Anim.coup(a, b)
	elseif genre == "salto" and a then
		Anim.salto(a)
		local hrp = a:FindFirstChild("HumanoidRootPart")
		local hum = a:FindFirstChildOfClass("Humanoid")
		if hrp and hum then
			Anim.onde(hrp.Position - Vector3.new(0, hum.HipHeight + hrp.Size.Y / 2, 0))
		end
	elseif genre == "impact" then
		Anim.impact(a, b)
	end
end)
