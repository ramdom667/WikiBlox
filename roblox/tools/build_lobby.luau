--[[
	WikiBlox - Générateur du décor du lobby (Workspace.WikiBloxLobby + ambiance Lighting)
	Ce fichier n'est PAS synchronisé par Rojo : c'est un outil.
	Usage : copier tout le fichier dans la Barre de commande de Roblox Studio, puis Exécuter.
	Relancer le script remplace l'ancien lobby. Ctrl+Z pour annuler.
	Les scripts du lobby sont dans src/client et src/server (synchronisés par Rojo).
]]

local CHS = game:GetService("ChangeHistoryService")
local Lighting = game:GetService("Lighting")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

CHS:SetWaypoint("Avant lobby WikiBlox")

-- Nettoyage d'une version précédente
local old = workspace:FindFirstChild("WikiBloxLobby")
if old then old:Destroy() end

local lobby = Instance.new("Model")
lobby.Name = "WikiBloxLobby"
lobby.Parent = workspace

-- Palette
local MARBLE = Color3.fromRGB(236, 232, 224)
local NAVY   = Color3.fromRGB(28, 34, 56)
local GOLD   = Color3.fromRGB(235, 188, 80)
local WOOD   = Color3.fromRGB(92, 58, 38)
local WOOD_D = Color3.fromRGB(66, 40, 26)
local CYAN   = Color3.fromRGB(90, 200, 255)

local M = Enum.Material

-- Utilitaires
local function make(class, props)
	local inst = Instance.new(class)
	local parent = props.Parent
	props.Parent = nil
	if inst:IsA("BasePart") then
		inst.Anchored = true
		inst.TopSurface = Enum.SurfaceType.Smooth
		inst.BottomSurface = Enum.SurfaceType.Smooth
	end
	for k, v in pairs(props) do inst[k] = v end
	inst.Parent = parent or lobby
	return inst
end

local UP = CFrame.Angles(0, 0, math.rad(90)) -- cylindre vertical

local function disk(name, diameter, height, y, color, material, parent, x, z)
	return make("Part", {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(x or 0, y, z or 0) * UP,
		Color = color,
		Material = material,
		Parent = parent,
	})
end

local function surfaceText(part, face, text, color, font)
	local gui = make("SurfaceGui", {
		Parent = part,
		Face = face,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 50,
	})
	return make("TextLabel", {
		Parent = gui,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		TextScaled = true,
		Text = text,
		TextColor3 = color,
		Font = font or Enum.Font.GothamBold,
	}), gui
end

------------------------------------------------------------------
-- Sol
------------------------------------------------------------------
disk("Sol", 120, 2, 0, MARBLE, M.Marble)
disk("AnneauOr", 52, 2.05, 0, GOLD, M.Neon)
disk("Centre", 48, 2.1, 0, NAVY, M.Slate)

------------------------------------------------------------------
-- Orbe du savoir + pages en orbite
------------------------------------------------------------------
local CENTER = Vector3.new(0, 14, 0)

disk("SocleOrbe", 14, 4, 3, NAVY, M.Slate)
disk("SocleOrbeLisere", 15, 0.4, 4.85, GOLD, M.Neon)

local orb = make("Part", {
	Name = "Orbe",
	Shape = Enum.PartType.Ball,
	Size = Vector3.new(7, 7, 7),
	CFrame = CFrame.new(CENTER),
	Color = Color3.fromRGB(120, 200, 255),
	Material = M.Neon,
	Transparency = 0.15,
	CanCollide = false,
})
make("PointLight", { Parent = orb, Color = Color3.fromRGB(140, 210, 255), Range = 30, Brightness = 3 })

make("Part", {
	Name = "Bulle",
	Shape = Enum.PartType.Ball,
	Size = Vector3.new(10, 10, 10),
	CFrame = CFrame.new(CENTER),
	Color = Color3.fromRGB(200, 230, 255),
	Material = M.Glass,
	Transparency = 0.7,
	CanCollide = false,
})

local pagesModel = make("Model", { Name = "Pages" })
local titres = { "Tour Eiffel", "Photosynthèse", "Jupiter", "Napoléon", "Tyrannosaure", "Mona Lisa", "Volcan", "Pharaon" }
for i, titre in ipairs(titres) do
	local a = (i / #titres) * math.pi * 2
	local pos = CENTER + Vector3.new(math.cos(a) * 9, 0, math.sin(a) * 9)
	local page = make("Part", {
		Name = "Page",
		Size = Vector3.new(2.4, 3.2, 0.1),
		CFrame = CFrame.lookAt(pos, CENTER),
		Color = Color3.fromRGB(250, 248, 240),
		Material = M.SmoothPlastic,
		CanCollide = false,
		Parent = pagesModel,
	})
	surfaceText(page, Enum.NormalId.Front, titre, NAVY, Enum.Font.Merriweather)
	surfaceText(page, Enum.NormalId.Back, titre, NAVY, Enum.Font.Merriweather)
end

------------------------------------------------------------------
-- Portail "JOUER" + panneau titre (au nord)
------------------------------------------------------------------
local portail = make("Model", { Name = "Portail" })
for _, x in ipairs({ -7.5, 7.5 }) do
	make("Part", { Name = "Pilier", Size = Vector3.new(3, 16, 3), CFrame = CFrame.new(x, 9, -48), Color = NAVY, Material = M.Slate, Parent = portail })
	make("Part", { Name = "PilierLisere", Size = Vector3.new(3.2, 0.4, 3.2), CFrame = CFrame.new(x, 2, -48), Color = GOLD, Material = M.Neon, Parent = portail })
end
local beam = make("Part", { Name = "Linteau", Size = Vector3.new(18, 3, 3), CFrame = CFrame.new(0, 18.5, -48), Color = NAVY, Material = M.Slate, Parent = portail })
surfaceText(beam, Enum.NormalId.Back, "JOUER", GOLD, Enum.Font.GothamBlack)

local plan = make("Part", {
	Name = "PortailJouer",
	Size = Vector3.new(12, 14, 0.4),
	CFrame = CFrame.new(0, 8, -48),
	Color = CYAN,
	Material = M.Neon,
	Transparency = 0.35,
	CanCollide = false,
	Parent = portail,
})
make("PointLight", { Parent = plan, Color = CYAN, Range = 20, Brightness = 2 })
make("ProximityPrompt", {
	Parent = plan,
	ActionText = "Jouer",
	ObjectText = "WikiBlox",
	HoldDuration = 0.3,
	MaxActivationDistance = 12,
})

-- Panneau titre
make("Part", { Name = "CadreTitre", Size = Vector3.new(41, 11, 0.8), CFrame = CFrame.new(0, 27, -50.3), Color = GOLD, Material = M.Neon })
local board = make("Part", { Name = "PanneauTitre", Size = Vector3.new(40, 10, 1), CFrame = CFrame.new(0, 27, -50), Color = NAVY, Material = M.SmoothPlastic })
local boardGui = make("SurfaceGui", { Parent = board, Face = Enum.NormalId.Back, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 50 })
local title = make("TextLabel", {
	Parent = boardGui,
	Size = UDim2.fromScale(1, 0.68),
	BackgroundTransparency = 1,
	TextScaled = true,
	Text = "WikiBlox",
	TextColor3 = GOLD,
	Font = Enum.Font.GothamBlack,
})
make("UIStroke", { Parent = title, Thickness = 4, Color = Color3.fromRGB(10, 12, 24) })
make("TextLabel", {
	Parent = boardGui,
	Position = UDim2.fromScale(0, 0.66),
	Size = UDim2.fromScale(1, 0.26),
	BackgroundTransparency = 1,
	TextScaled = true,
	Text = "Collectionne le savoir du monde",
	TextColor3 = Color3.fromRGB(235, 235, 245),
	Font = Enum.Font.Gotham,
})

------------------------------------------------------------------
-- Présentoirs de rareté
------------------------------------------------------------------
local raretesModel = make("Model", { Name = "Raretes" })
local raretes = {
	{ nom = "COMMUNE",    couleur = Color3.fromRGB(175, 175, 185), angle = 225 },
	{ nom = "RARE",       couleur = Color3.fromRGB(60, 140, 255),  angle = 135 },
	{ nom = "ÉPIQUE",     couleur = Color3.fromRGB(170, 80, 255),  angle = 315 },
	{ nom = "LÉGENDAIRE", couleur = Color3.fromRGB(255, 190, 40),  angle = 45 },
}

for _, r in ipairs(raretes) do
	local th = math.rad(r.angle)
	local x, z = math.sin(th) * 30, -math.cos(th) * 30
	local m = make("Model", { Name = r.nom, Parent = raretesModel })

	disk("Socle", 9, 4, 3, NAVY, M.Slate, m, x, z)
	disk("Lueur", 8, 0.4, 5.1, r.couleur, M.Neon, m, x, z)

	local card = make("Part", {
		Name = "Carte",
		Size = Vector3.new(4, 5.5, 0.25),
		CFrame = CFrame.new(x, 9.5, z),
		Color = r.couleur,
		Material = M.Neon,
		CanCollide = false,
		Parent = m,
	})
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = make("SurfaceGui", { Parent = card, Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 50 })
		local inner = make("Frame", {
			Parent = gui,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.86, 0.9),
			BackgroundColor3 = Color3.fromRGB(245, 242, 235),
			BorderSizePixel = 0,
		})
		make("UICorner", { Parent = inner, CornerRadius = UDim.new(0.06, 0) })
		make("TextLabel", {
			Parent = inner,
			Size = UDim2.fromScale(1, 0.7),
			BackgroundTransparency = 1,
			TextScaled = true,
			Text = "?",
			TextColor3 = r.couleur,
			Font = Enum.Font.GothamBlack,
		})
		make("TextLabel", {
			Parent = inner,
			Position = UDim2.fromScale(0.05, 0.72),
			Size = UDim2.fromScale(0.9, 0.2),
			BackgroundTransparency = 1,
			TextScaled = true,
			Text = r.nom,
			TextColor3 = NAVY,
			Font = Enum.Font.GothamBold,
		})
	end
	make("PointLight", { Parent = card, Color = r.couleur, Range = 14, Brightness = 2 })

	local bb = make("BillboardGui", { Parent = card, Size = UDim2.fromOffset(220, 50), StudsOffset = Vector3.new(0, 4.5, 0), MaxDistance = 80 })
	local lbl = make("TextLabel", {
		Parent = bb,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		TextScaled = true,
		Text = r.nom,
		TextColor3 = r.couleur,
		Font = Enum.Font.GothamBlack,
	})
	make("UIStroke", { Parent = lbl, Thickness = 2, Color = Color3.fromRGB(10, 12, 24) })

	if r.nom == "LÉGENDAIRE" then
		make("Sparkles", { Parent = card, SparkleColor = r.couleur })
	end
end

------------------------------------------------------------------
-- Bibliothèque circulaire
------------------------------------------------------------------
local biblio = make("Model", { Name = "Bibliotheque" })
local bookColors = {
	Color3.fromRGB(150, 40, 45), Color3.fromRGB(35, 70, 130), Color3.fromRGB(40, 100, 60),
	Color3.fromRGB(190, 140, 60), Color3.fromRGB(90, 50, 110), Color3.fromRGB(200, 195, 180),
	Color3.fromRGB(30, 30, 35), Color3.fromRGB(170, 85, 40),
}
local rng = Random.new(42)
local R = 57

for deg = 24, 336, 12 do
	local th = math.rad(deg)
	local pos = Vector3.new(math.sin(th) * R, 7, -math.cos(th) * R)
	local cf = CFrame.lookAt(pos, Vector3.new(0, 7, 0))

	make("Part", { Name = "Etagere", Size = Vector3.new(11.5, 12, 3), CFrame = cf, Color = WOOD, Material = M.Wood, Parent = biblio })
	make("Part", { Name = "Corniche", Size = Vector3.new(12, 0.8, 3.6), CFrame = cf * CFrame.new(0, 6.4, 0), Color = WOOD_D, Material = M.Wood, Parent = biblio })

	for _, ry in ipairs({ -5.2, -1.2, 2.8 }) do
		make("Part", { Name = "Planche", Size = Vector3.new(11.5, 0.3, 1.4), CFrame = cf * CFrame.new(0, ry, -2.2), Color = WOOD_D, Material = M.Wood, Parent = biblio })
		local x = -5.4
		while true do
			local w = rng:NextNumber(0.55, 0.85)
			if x + w > 5.4 then break end
			local h = rng:NextNumber(2.2, 3.2)
			make("Part", {
				Name = "Livre",
				Size = Vector3.new(w, h, 1.2),
				CFrame = cf * CFrame.new(x + w / 2, ry + 0.15 + h / 2, -2.1),
				Color = bookColors[rng:NextInteger(1, #bookColors)],
				Material = M.SmoothPlastic,
				CanCollide = false,
				Parent = biblio,
			})
			x += w + 0.03
		end
	end
end

------------------------------------------------------------------
-- Lampadaires
------------------------------------------------------------------
local lampes = make("Model", { Name = "Lampadaires" })
for _, deg in ipairs({ 30, 90, 150, 210, 270, 330 }) do
	local th = math.rad(deg)
	local x, z = math.sin(th) * 42, -math.cos(th) * 42
	disk("Base", 2.2, 0.6, 1.3, NAVY, M.Slate, lampes, x, z)
	disk("Poteau", 0.7, 10, 6, NAVY, M.Metal, lampes, x, z)
	local ball = make("Part", {
		Name = "Globe",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.8, 1.8, 1.8),
		CFrame = CFrame.new(x, 11.6, z),
		Color = Color3.fromRGB(255, 210, 150),
		Material = M.Neon,
		CanCollide = false,
		Parent = lampes,
	})
	make("PointLight", { Parent = ball, Color = Color3.fromRGB(255, 200, 140), Range = 22, Brightness = 1.5 })
end

------------------------------------------------------------------
-- Point d'apparition (au sud, face au portail)
------------------------------------------------------------------
disk("SpawnLisere", 12, 0.9, 1.45, GOLD, M.Neon, nil, 0, 42)
make("SpawnLocation", {
	Name = "SpawnLobby",
	Size = Vector3.new(10, 1, 10),
	CFrame = CFrame.new(0, 1.5, 42),
	Color = NAVY,
	Material = M.Slate,
	Neutral = true,
	Duration = 0,
})

------------------------------------------------------------------
-- Ambiance
------------------------------------------------------------------
Lighting.ClockTime = 17.6
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(70, 70, 90)
Lighting.OutdoorAmbient = Color3.fromRGB(110, 100, 130)

local function effect(class, name, props)
	local e = Lighting:FindFirstChild(name)
	if e then e:Destroy() end
	props.Name = name
	props.Parent = Lighting
	return make(class, props)
end

effect("Atmosphere", "WikiBloxAtmosphere", {
	Density = 0.35,
	Color = Color3.fromRGB(199, 170, 210),
	Decay = Color3.fromRGB(90, 80, 130),
	Glare = 0.3,
	Haze = 1.5,
})
effect("BloomEffect", "WikiBloxBloom", { Intensity = 0.6, Size = 30, Threshold = 1.2 })
effect("ColorCorrectionEffect", "WikiBloxCouleurs", { Saturation = 0.1, Contrast = 0.05 })

------------------------------------------------------------------
-- Les scripts (animations, portail, sprint) sont gérés par Rojo dans src/.
-- On supprime d'éventuelles anciennes copies collées à la main dans Studio.
------------------------------------------------------------------
for _, parent in ipairs({ StarterPlayerScripts, ServerScriptService }) do
	for _, nom in ipairs({ "WikiBloxLobbyAnim", "WikiBloxPortail", "WikiBloxSprint" }) do
		local s = parent:FindFirstChild(nom)
		if s then s:Destroy() end
	end
end

-- Désactive l'ancien point d'apparition par défaut pour que les joueurs arrivent dans le lobby
local defaultSpawn = workspace:FindFirstChild("SpawnLocation")
if defaultSpawn and defaultSpawn:IsA("SpawnLocation") then defaultSpawn.Enabled = false end

game:GetService("Selection"):Set({ lobby })
CHS:SetWaypoint("Lobby WikiBlox créé")
print("✅ Lobby WikiBlox créé !")
