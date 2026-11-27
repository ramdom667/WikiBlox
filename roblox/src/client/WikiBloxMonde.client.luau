-- WikiBlox : effets du couloir et du Nexus (côté joueur)
--   * fondu à l'écran pendant les téléportations + nom du lieu
--   * petits messages (« Mini-jeu 1 arrive bientôt ! »)
--   * battants de la grande porte qui s'ouvrent quand on approche
--   * livres / îlots qui flottent, portails et globe qui tournent
--   * ambiance de nuit étoilée quand on est dans le Nexus

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("WikiBloxMonde", 15)

local HAUTEUR_NEXUS = 250 -- au-dessus de cette hauteur, on est dans le Nexus
local NOMS_LIEUX = {
	ArriveeNexus = "WikiVerse",
	ArriveeCouloir = "LA BIBLIOTHÈQUE",
	ArriveeParcours = "Le Parcours",
	ArriveeEtang = "L'Etang"
}

------------------------------------------------------------------
-- Interface : fondu + messages
------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "WikiBloxMonde"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Parent = player:WaitForChild("PlayerGui")

local voile = Instance.new("Frame")
voile.Size = UDim2.fromScale(1, 1)
voile.BackgroundColor3 = Color3.fromRGB(14, 8, 28)
voile.BackgroundTransparency = 1
voile.BorderSizePixel = 0
voile.Active = false
voile.Parent = gui

local titreLieu = Instance.new("TextLabel")
titreLieu.AnchorPoint = Vector2.new(0.5, 0.5)
titreLieu.Position = UDim2.fromScale(0.5, 0.45)
titreLieu.Size = UDim2.fromScale(0.6, 0.12)
titreLieu.BackgroundTransparency = 1
titreLieu.Font = Enum.Font.Fantasy
titreLieu.TextScaled = true
titreLieu.TextColor3 = Color3.fromRGB(255, 225, 150)
titreLieu.TextStrokeColor3 = Color3.fromRGB(60, 30, 90)
titreLieu.TextTransparency = 1
titreLieu.TextStrokeTransparency = 1
titreLieu.Text = ""
titreLieu.Parent = gui

local message = Instance.new("TextLabel")
message.AnchorPoint = Vector2.new(0.5, 0)
message.Position = UDim2.new(0.5, 0, 0, -60)
message.Size = UDim2.fromOffset(420, 46)
message.BackgroundColor3 = Color3.fromRGB(25, 18, 45)
message.BackgroundTransparency = 0.1
message.Font = Enum.Font.GothamBold
message.TextSize = 18
message.TextColor3 = Color3.new(1, 1, 1)
message.Text = ""
message.Parent = gui
Instance.new("UICorner", message).CornerRadius = UDim.new(0, 12)
local contour = Instance.new("UIStroke", message)
contour.Color = Color3.fromRGB(196, 156, 72)
contour.Thickness = 2
contour.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local function tween(objet, duree, props, style)
	local t = TweenService:Create(objet, TweenInfo.new(duree, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local numeroMessage = 0
local function afficherMessage(txt)
	numeroMessage += 1
	local n = numeroMessage
	message.Text = txt
	tween(message, 0.35, { Position = UDim2.new(0.5, 0, 0, 70) }, Enum.EasingStyle.Back)
	task.delay(2.6, function()
		if n == numeroMessage then
			tween(message, 0.3, { Position = UDim2.new(0.5, 0, 0, -60) })
		end
	end)
end

local function fondu(duree, nomDestination)
	tween(voile, duree, { BackgroundTransparency = 0 }, Enum.EasingStyle.Sine)
	task.delay(duree + 0.15, function()
		local lieu = NOMS_LIEUX[nomDestination]
		if lieu then
			titreLieu.Text = lieu
			titreLieu.TextTransparency = 1
			tween(titreLieu, 0.3, { TextTransparency = 0, TextStrokeTransparency = 0.3 })
		end
		task.wait(0.5)
		tween(voile, 0.7, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
		task.wait(0.8)
		tween(titreLieu, 0.6, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
end

if remote then
	remote.OnClientEvent:Connect(function(genre, a, b)
		if genre == "fondu" then
			fondu(a or 0.4, b)
		elseif genre == "message" then
			afficherMessage(a)
		end
	end)
end

------------------------------------------------------------------
-- Battants de porte : s'ouvrent quand on approche, se referment quand on s'éloigne
------------------------------------------------------------------
local battants = {} -- [modele] = { ferme, charniere, angle, ouverture (NumberValue), ouvert }

local function ajouterBattant(m)
	if not m:IsA("Model") or battants[m] then return end
	local c = m:GetAttribute("Charniere")
	if typeof(c) ~= "Vector3" then return end
	local ferme = m:GetPivot()
	local charniere = CFrame.new(c.X, ferme.Y, c.Z)
	local valeur = Instance.new("NumberValue")
	local info = {
		ferme = ferme,
		charniere = charniere,
		angle = math.rad((m:GetAttribute("Angle") or 100) * (m:GetAttribute("Sens") or 1)),
		ouverture = valeur,
		ouvert = false,
	}
	valeur.Changed:Connect(function(v)
		m:PivotTo(info.charniere * CFrame.Angles(0, info.angle * v, 0) * info.charniere:Inverse() * info.ferme)
	end)
	battants[m] = info
end
for _, m in ipairs(CollectionService:GetTagged("WikiBloxBattant")) do ajouterBattant(m) end
CollectionService:GetInstanceAddedSignal("WikiBloxBattant"):Connect(ajouterBattant)

------------------------------------------------------------------
-- Objets qui flottent et qui tournent
------------------------------------------------------------------
local flottants = {} -- [modele] = { base, phase, amplitude, vitesse }
local tournants = {} -- [modele] = { base, vitesse, axe }

local function ajouterFlottant(m)
	if flottants[m] then return end
	local ok, base = pcall(function() return m:GetPivot() end)
	if not ok then return end
	flottants[m] = {
		base = base,
		phase = math.random() * math.pi * 2,
		amplitude = 0.4 + math.random() * 0.6,
		vitesse = 0.8 + math.random() * 0.6,
	}
end
local function ajouterTournant(m)
	if tournants[m] then return end
	local ok, base = pcall(function() return m:GetPivot() end)
	if not ok then return end
	tournants[m] = { base = base, vitesse = m:GetAttribute("Vitesse") or 1, axe = m:GetAttribute("Axe") or "Y" }
end
for _, m in ipairs(CollectionService:GetTagged("WikiBloxFlottant")) do ajouterFlottant(m) end
for _, m in ipairs(CollectionService:GetTagged("WikiBloxTourne")) do ajouterTournant(m) end
CollectionService:GetInstanceAddedSignal("WikiBloxFlottant"):Connect(ajouterFlottant)
CollectionService:GetInstanceAddedSignal("WikiBloxTourne"):Connect(ajouterTournant)

local DISTANCE_ANIM = 300 -- on n'anime que ce qui est proche (économise le téléphone)

RunService.RenderStepped:Connect(function()
	local perso = player.Character
	local racine = perso and perso:FindFirstChild("HumanoidRootPart")
	if not racine then return end
	local ici = racine.Position
	local t = os.clock()

	for m, f in pairs(flottants) do
		if not m.Parent then
			flottants[m] = nil
		elseif (f.base.Position - ici).Magnitude < DISTANCE_ANIM then
			m:PivotTo(f.base * CFrame.new(0, math.sin(t * f.vitesse + f.phase) * f.amplitude, 0)
				* CFrame.Angles(0, math.sin(t * 0.3 + f.phase) * 0.4, 0))
		end
	end
	for m, r in pairs(tournants) do
		if not m.Parent then
			tournants[m] = nil
		elseif (r.base.Position - ici).Magnitude < DISTANCE_ANIM then
			local a = t * r.vitesse
			local rot = r.axe == "Z" and CFrame.Angles(0, 0, a) or r.axe == "X" and CFrame.Angles(a, 0, 0) or CFrame.Angles(0, a, 0)
			m:PivotTo(r.base * rot)
		end
	end
end)

------------------------------------------------------------------
-- Boucle lente : ouverture des portes + ambiance du Nexus
------------------------------------------------------------------
local ambianceNormale = nil
local dansNexus = false

local function appliquerAmbiance(nexus)
	if nexus then
		ambianceNormale = {
			ClockTime = Lighting.ClockTime,
			Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			Brightness = Lighting.Brightness,
			FogColor = Lighting.FogColor,
			FogEnd = Lighting.FogEnd,
		}
		Lighting.ClockTime = 0
		Lighting.Ambient = Color3.fromRGB(70, 60, 110)
		Lighting.OutdoorAmbient = Color3.fromRGB(100, 85, 150)
		Lighting.Brightness = 1.5
		Lighting.FogColor = Color3.fromRGB(30, 20, 60)
		Lighting.FogEnd = 1500
	elseif ambianceNormale then
		for k, v in pairs(ambianceNormale) do
			Lighting[k] = v
		end
	end
end

task.spawn(function()
	while true do
		task.wait(0.2)
		local perso = player.Character
		local racine = perso and perso:FindFirstChild("HumanoidRootPart")
		if racine then
			local ici = racine.Position
			for m, info in pairs(battants) do
				if not m.Parent then
					battants[m] = nil
				else
					local proche = (Vector3.new(info.charniere.X, ici.Y, info.charniere.Z) - ici).Magnitude < 22
					if proche ~= info.ouvert then
						info.ouvert = proche
						tween(info.ouverture, proche and 1.1 or 0.9, { Value = proche and 1 or 0 },
							proche and Enum.EasingStyle.Back or Enum.EasingStyle.Quad)
					end
				end
			end

			local nexus = ici.Y > HAUTEUR_NEXUS
			if nexus ~= dansNexus then
				dansNexus = nexus
				appliquerAmbiance(nexus)
			end
		end
	end
end)
