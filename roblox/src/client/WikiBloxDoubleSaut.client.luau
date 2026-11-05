-- WikiBlox : double saut, avec salto et onde d'air sous les pieds
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Anim = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WikiBloxAnimations"))
local combat = ReplicatedStorage:WaitForChild("WikiBloxCombat", 10)
local saltoRemote = combat and combat:WaitForChild("Salto", 5)

local SAUTS_EN_L_AIR = 1   -- sauts en plus du saut normal (2 = triple saut)
local PUISSANCE = 50       -- vitesse vers le haut du saut en l'air

local player = Players.LocalPlayer
local humanoid, racine
local sautsRestants = 0
local dernierSaut = 0

local function surPersonnage(perso)
	humanoid = perso:WaitForChild("Humanoid")
	racine = perso:WaitForChild("HumanoidRootPart")
	sautsRestants = SAUTS_EN_L_AIR
	humanoid.StateChanged:Connect(function(_, etat)
		if etat == Enum.HumanoidStateType.Landed then
			sautsRestants = SAUTS_EN_L_AIR -- on recharge en touchant le sol
		end
	end)
end
if player.Character then surPersonnage(player.Character) end
player.CharacterAdded:Connect(surPersonnage)

-- JumpRequest marche sur PC (espace), mobile (bouton saut) et manette
UserInputService.JumpRequest:Connect(function()
	if not humanoid or humanoid.Health <= 0 then return end
	if os.clock() - dernierSaut < 0.25 then return end -- évite de tout griller d'un coup
	dernierSaut = os.clock()

	local etat = humanoid:GetState()
	local enLAir = etat == Enum.HumanoidStateType.Freefall or etat == Enum.HumanoidStateType.Jumping
	if enLAir and sautsRestants > 0 then
		sautsRestants -= 1
		local v = racine.AssemblyLinearVelocity
		racine.AssemblyLinearVelocity = Vector3.new(v.X, PUISSANCE, v.Z)
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

		-- Animation : salto + onde d'air, et on prévient le serveur pour que les autres la voient
		Anim.salto(player.Character)
		Anim.onde(racine.Position - Vector3.new(0, humanoid.HipHeight + racine.Size.Y / 2, 0))
		if saltoRemote then
			saltoRemote:FireServer()
		end
	end
end)
