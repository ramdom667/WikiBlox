--[[
	WikiBlox - Booster géant au centre du dôme + lumières adoucies
	Ce fichier n'est PAS synchronisé par Rojo : c'est un outil.
	Usage : copier tout le fichier dans la Barre de commande de Roblox Studio, puis Exécuter.
	Relancer le script remplace l'ancien booster. Ctrl+Z pour annuler.

	- Workspace.WikiBloxLobby.BoosterGeant : paquet de booster posé sur le socle central
	  (l'animation est dans src/client/WikiBloxLobbyAnim, l'ouverture dans src/client/WikiBloxBoosterUI)
	- L'orbe est remontée au-dessus du booster
	- Lumières du centre adoucies (anneau néon, lumière de l'orbe, bloom)
]]

local CHS = game:GetService("ChangeHistoryService")
local Lighting = game:GetService("Lighting")
CHS:SetWaypoint("Avant booster géant")

local lobby = workspace:WaitForChild("WikiBloxLobby")
for _, nom in ipairs({ "BoosterGeant", "BoosterGeantCollision" }) do
	local ancien = lobby:FindFirstChild(nom)
	if ancien then ancien:Destroy() end
end

local NAVY = Color3.fromRGB(28, 34, 56)
local GOLD = Color3.fromRGB(235, 188, 80)
local VIOLET = Color3.fromRGB(88, 60, 170)
local VIOLET_FONCE = Color3.fromRGB(40, 28, 92)
local BLANC = Color3.fromRGB(245, 242, 235)
local RARETES = {
	Color3.fromRGB(175, 175, 185), Color3.fromRGB(80, 200, 120), Color3.fromRGB(60, 140, 255),
	Color3.fromRGB(170, 80, 255), Color3.fromRGB(255, 190, 40),
}

------------------------------------------------------------------
-- Position : sur le socle central
------------------------------------------------------------------
local socle = lobby:FindFirstChild("SocleOrbe")
local lisere = lobby:FindFirstChild("SocleOrbeLisere")
local centre = socle and Vector3.new(socle.Position.X, 0, socle.Position.Z) or Vector3.zero
local dessus = 6
for _, p in ipairs({ socle, lisere }) do
	if p then
		-- cylindres couchés : l'axe du cylindre (hauteur) est Size.X
		dessus = math.max(dessus, p.Position.Y + p.Size.X / 2)
	end
end

local L, H, P = 9.5, 13.5, 1.6 -- largeur, hauteur, épaisseur du paquet
local cy = dessus + 0.9 + H / 2
local cadre = CFrame.new(centre.X, cy, centre.Z)

local model = Instance.new("Model")
model.Name = "BoosterGeant"

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	p.Parent = model
	return p
end

local paquet = part({
	Name = "Paquet",
	Size = Vector3.new(L, H, P),
	CFrame = cadre,
	Color = VIOLET,
	Material = Enum.Material.Foil,
})
model.PrimaryPart = paquet

-- Bords sertis en haut et en bas, avec des petites dents
for _, sens in ipairs({ 1, -1 }) do
	part({
		Name = "Sertissage",
		Size = Vector3.new(L + 0.1, 0.45, P * 0.55),
		CFrame = cadre * CFrame.new(0, sens * (H / 2 + 0.22), 0),
		Color = GOLD,
		Material = Enum.Material.Metal,
	})
	for i = 0, 7 do
		part({
			Name = "Dent",
			Size = Vector3.new(L / 8 * 0.62, 0.3, P * 0.45),
			CFrame = cadre * CFrame.new(-L / 2 + L / 16 + i * L / 8, sens * (H / 2 + 0.58), 0),
			Color = GOLD,
			Material = Enum.Material.Metal,
		})
	end
end

-- Liserés dorés sur les côtés
for _, sens in ipairs({ 1, -1 }) do
	part({
		Name = "Bord",
		Size = Vector3.new(0.14, H, P + 0.04),
		CFrame = cadre * CFrame.new(sens * L / 2, 0, 0),
		Color = GOLD,
		Material = Enum.Material.Metal,
	})
end

-- Collision fixe (le paquet tourne côté client, la collision reste immobile)
local collision = part({
	Name = "Collision",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(H + 1.4, L + 0.6, L + 0.6),
	CFrame = CFrame.new(centre.X, cy, centre.Z) * CFrame.Angles(0, 0, math.rad(90)),
	Transparency = 1,
	CanCollide = true,
})
collision.CastShadow = false
collision.Name = "BoosterGeantCollision"
collision.Parent = lobby -- hors du modèle : elle ne bouge pas avec l'animation

-- Halo doux
local lumiere = Instance.new("PointLight")
lumiere.Color = Color3.fromRGB(170, 140, 255)
lumiere.Brightness = 1
lumiere.Range = 18
lumiere.Parent = paquet

------------------------------------------------------------------
-- Visuel du paquet (recto et verso)
------------------------------------------------------------------
local function new(class, props, enfants)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then inst[k] = v end
	end
	for _, e in ipairs(enfants or {}) do e.Parent = inst end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end

local function texte(props)
	props.BackgroundTransparency = 1
	props.TextScaled = true
	props.TextWrapped = true
	props.TextColor3 = props.TextColor3 or BLANC
	props.Font = props.Font or Enum.Font.GothamBlack
	return new("TextLabel", props)
end

for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
	local gui = new("SurfaceGui", {
		Face = face,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 60,
		LightInfluence = 0.4,
		Parent = paquet,
	})
	local fond = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = gui,
	}, {
		new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(VIOLET, VIOLET_FONCE),
		}),
	})

	texte({
		Position = UDim2.fromScale(0.08, 0.05),
		Size = UDim2.fromScale(0.84, 0.12),
		Text = "WikiBlox",
		TextColor3 = GOLD,
		Parent = fond,
	}, nil)

	local medaillon = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.fromScale(0.62, 0.62),
		BackgroundColor3 = NAVY,
		Parent = fond,
	}, {
		new("UIAspectRatioConstraint", { AspectRatio = 1 }),
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIStroke", { Thickness = 10, Color = GOLD }),
	})
	texte({ Size = UDim2.fromScale(1, 1), Text = "W", TextColor3 = GOLD, Parent = medaillon })

	texte({
		Position = UDim2.fromScale(0.05, 0.66),
		Size = UDim2.fromScale(0.9, 0.12),
		Text = "BOOSTER",
		Parent = fond,
	})
	texte({
		Position = UDim2.fromScale(0.1, 0.785),
		Size = UDim2.fromScale(0.8, 0.055),
		Text = "5 cartes Wikipédia",
		Font = Enum.Font.GothamBold,
		Parent = fond,
	})

	-- Bande des 5 raretés
	local bande = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.875),
		Size = UDim2.fromScale(0.7, 0.035),
		BackgroundTransparency = 1,
		Parent = fond,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0.02, 0),
		}),
	})
	for _, couleur in ipairs(RARETES) do
		new("Frame", {
			Size = UDim2.fromScale(0.184, 1),
			BackgroundColor3 = couleur,
			BorderSizePixel = 0,
			Parent = bande,
		}, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	end
end

model.Parent = lobby

------------------------------------------------------------------
-- L'orbe et sa bulle passent au-dessus du booster
------------------------------------------------------------------
local hautOrbe = cy + H / 2 + 0.9 + 4.5
for _, nom in ipairs({ "Orbe", "Bulle" }) do
	local p = lobby:FindFirstChild(nom)
	if p then
		p.CFrame = CFrame.new(centre.X, hautOrbe, centre.Z)
	end
end

------------------------------------------------------------------
-- Lumières du centre adoucies
------------------------------------------------------------------
if lisere then
	lisere.Color = Color3.fromRGB(150, 115, 45) -- néon moins éclatant
end
local anneau = lobby:FindFirstChild("AnneauOr")
if anneau then
	anneau.Color = Color3.fromRGB(185, 145, 60)
end
local orbe = lobby:FindFirstChild("Orbe")
if orbe then
	orbe.Transparency = 0.3
	local l = orbe:FindFirstChildWhichIsA("PointLight")
	if l then
		l.Brightness = 1.5
		l.Range = 22
	end
end
local bloom = Lighting:FindFirstChild("WikiBloxBloom")
if bloom then
	-- le Bloom par défaut de Roblox est déjà présent : on réduit le nôtre pour ne pas doubler l'effet
	bloom.Intensity = 0.25
	bloom.Threshold = 1.6
end

CHS:SetWaypoint("Booster géant ajouté")
print("✅ Booster géant ajouté au centre du dôme")
