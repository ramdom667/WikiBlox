-- WikiBlox : mise à jour du couloir (à lancer APRÈS build_couloir_portail.luau, barre de commande, mode édition)
--   1) Gravures « SENDOUK MOHAMED » dans le sol du couloir (+ losanges)
--   2) Portail v2 : colonnes et fronton en bois du lobby, double anneau doré lisse, gemmes,
--      cartes WikiBlox qui tournent dans le portail, cercle lumineux au sol, particules
local CHS = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
CHS:SetWaypoint("Avant gravures + portail v2")

local couloir = workspace.WikiBloxCouloir
local porte = couloir.GrandePorte
local vest = porte.Vestibule
local BOIS = Color3.fromRGB(52, 32, 20)
local OR = Color3.fromRGB(214, 172, 80)
local VIOLET = Color3.fromRGB(150, 95, 255)
local MARBRE = Color3.fromRGB(176, 141, 74)
local GRAVURE = Color3.fromRGB(60, 38, 18)

local function bloc(parent, nom, taille, cf, couleur, matiere, props)
	local p = Instance.new("Part")
	p.Name = nom
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = taille
	p.CFrame = cf
	p.Color = couleur
	p.Material = matiere or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then for k, v in pairs(props) do p[k] = v end end
	p.Parent = parent
	return p
end

------------------------------------------------------------------
-- 1) Gravures dans le sol
------------------------------------------------------------------
local ancien = couloir:FindFirstChild("Gravures", true)
if ancien then ancien:Destroy() end
local linteau = workspace.Spawn:FindFirstChild("PorteLinteau")
local O = CFrame.new(linteau.Position.X, 0, linteau.Position.Z + 4.2)
local function C(x, y, z) return O * CFrame.new(x, y, z) end
local g = Instance.new("Model")
g.Name = "Gravures"
g.Parent = couloir.Decor

local function graver(part, texte)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Top
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 60
	sg.LightInfluence = 1
	sg.Parent = part
	local cadre = Instance.new("Frame")
	cadre.AnchorPoint = Vector2.new(0.5, 0.5)
	cadre.Position = UDim2.fromScale(0.5, 0.5)
	cadre.Size = UDim2.new(1, -16, 1, -16)
	cadre.BackgroundTransparency = 1
	cadre.Parent = sg
	local trait = Instance.new("UIStroke")
	trait.Color = GRAVURE
	trait.Thickness = 3
	trait.Parent = cadre
	local t = Instance.new("TextLabel")
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.5)
	t.Size = UDim2.fromScale(0.9, 0.7)
	t.BackgroundTransparency = 1
	t.Text = texte
	t.TextScaled = true
	t.Font = Enum.Font.Antique
	t.TextColor3 = GRAVURE
	t.TextStrokeColor3 = Color3.fromRGB(220, 190, 130)
	t.TextStrokeTransparency = 0.75
	t.Parent = cadre
end
-- (la plaque est tournée de 90° pour que le texte se lise en marchant vers le portail)
for _, z in ipairs({ 12, 36, 60 }) do
	local p = bloc(g, "PlaqueNom", Vector3.new(2.4, 0.06, 6.4), C(0, 0.07, z) * CFrame.Angles(0, math.rad(90), 0), MARBRE, Enum.Material.Marble)
	graver(p, "SENDOUK MOHAMED")
end
for _, z in ipairs({ 24, 48 }) do
	bloc(g, "Losange", Vector3.new(2.4, 0.06, 2.4), C(0, 0.07, z) * CFrame.Angles(0, math.rad(45), 0), MARBRE, Enum.Material.Marble)
	bloc(g, "LosangeGrave", Vector3.new(1.4, 0.07, 1.4), C(0, 0.075, z) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(92, 64, 30), Enum.Material.Marble)
	bloc(g, "LosangeCoeur", Vector3.new(0.8, 0.08, 0.8), C(0, 0.08, z) * CFrame.Angles(0, math.rad(45), 0), MARBRE, Enum.Material.Marble)
end

------------------------------------------------------------------
-- 2) Portail v2
------------------------------------------------------------------
for _, p in ipairs(porte:GetChildren()) do
	if p:IsA("BasePart") then
		if p.Name == "Colonne" or p.Name == "Fronton" then
			p.Color = BOIS
			p.Material = Enum.Material.Wood
		end
		if p.Name == "Cannelure" or p.Name == "ColonneBase" or p.Name == "ColonneTete" or p.Name:find("FrontonOr") or p.Name == "Medaillon" then
			p.Color = OR
		end
	end
end
local sg = porte.Fronton:FindFirstChildWhichIsA("SurfaceGui", true)
if sg then
	local lbl = sg:FindFirstChildWhichIsA("TextLabel")
	lbl.TextColor3 = Color3.fromRGB(255, 214, 120)
	lbl.TextStrokeTransparency = 0.4
end

local voile = vest.Voile
local centre = CFrame.new(voile.Position)
for _, p in ipairs(vest:GetChildren()) do
	if p.Name == "Anneau" or p.Name == "AnneauFin" or p.Name == "Gemme" or p.Name == "FondPortail" or p.Name == "CercleSol" or p.Name == "CercleSolInt" or p.Name == "CartesOrbite" then
		p:Destroy()
	end
end
local function cercle(nom, rayon, ep, couleur, mat, seg, z, transparence)
	local long = 2 * math.pi * rayon / seg * 1.06
	for i = 0, seg - 1 do
		local a = i / seg * math.pi * 2
		bloc(vest, nom, Vector3.new(long, ep, ep), centre * CFrame.new(0, 0, z) * CFrame.Angles(0, 0, a) * CFrame.new(0, rayon, 0), couleur, mat, { Transparency = transparence or 0 })
	end
end
cercle("Anneau", 7.05, 0.9, OR, Enum.Material.Metal, 64, 0)
cercle("AnneauFin", 7.9, 0.35, OR, Enum.Material.Neon, 64, -0.1, 0.55)
for i = 0, 7 do
	local a = i / 8 * math.pi * 2
	bloc(vest, "Gemme", Vector3.new(0.9, 0.9, 0.9), centre * CFrame.new(0, 0, -0.5) * CFrame.Angles(0, 0, a) * CFrame.new(0, 7.05, 0) * CFrame.Angles(0, 0, math.rad(45)), VIOLET, Enum.Material.Neon)
end
bloc(vest, "FondPortail", Vector3.new(0.1, 13.6, 13.6), centre * CFrame.new(0, 0, 0.3) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(20, 8, 45), Enum.Material.Neon, { Shape = Enum.PartType.Cylinder })

-- Cartes WikiBlox (couleurs des raretés) qui tournent dans le portail
local cartes = Instance.new("Model")
cartes.Name = "CartesOrbite"
cartes.Parent = vest
local pivot = bloc(cartes, "Centre", Vector3.new(0.2, 0.2, 0.2), centre * CFrame.new(0, 0, -1.2), Color3.new(), Enum.Material.SmoothPlastic, { Transparency = 1 })
cartes.PrimaryPart = pivot
local RARETES = { Color3.fromRGB(180, 180, 190), Color3.fromRGB(80, 200, 120), Color3.fromRGB(80, 160, 255), Color3.fromRGB(190, 100, 255), Color3.fromRGB(255, 190, 60) }
for i = 0, 9 do
	local a = i / 10 * math.pi * 2
	local cf = centre * CFrame.new(0, 0, -1.2) * CFrame.Angles(0, 0, a) * CFrame.new(0, 5.1, 0) * CFrame.Angles(0, 0, math.rad(-8))
	local couleur = RARETES[i % #RARETES + 1]
	bloc(cartes, "CarteBord", Vector3.new(1.12, 1.54, 0.05), cf, couleur, Enum.Material.Neon)
	local face = bloc(cartes, "Carte", Vector3.new(0.98, 1.39, 0.06), cf * CFrame.new(0, 0, -0.02), Color3.fromRGB(245, 240, 230), Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = face
	local w = Instance.new("TextLabel")
	w.Size = UDim2.fromScale(1, 1)
	w.BackgroundTransparency = 1
	w.Text = "W"
	w.TextScaled = true
	w.Font = Enum.Font.Garamond
	w.TextColor3 = couleur
	w.Parent = gui
end
cartes:SetAttribute("Vitesse", 0.35)
cartes:SetAttribute("Axe", "Z")
cartes.WorldPivot = pivot.CFrame
CollectionService:AddTag(cartes, "WikiBloxTourne")

-- Cercle lumineux au sol devant le portail
local sol = CFrame.new(voile.Position.X, 0.07, voile.Position.Z - 3.5)
bloc(vest, "CercleSol", Vector3.new(0.06, 9, 9), sol * CFrame.Angles(0, 0, math.rad(90)), VIOLET, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, Transparency = 0.35 })
bloc(vest, "CercleSolInt", Vector3.new(0.08, 8.2, 8.2), sol * CFrame.new(0, 0.01, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 30, 55), Enum.Material.Slate, { Shape = Enum.PartType.Cylinder })

-- Particules qui sortent du portail vers le joueur
local e = voile:FindFirstChild("Aspiration") or Instance.new("ParticleEmitter")
e.Name = "Aspiration"
e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
e.Color = ColorSequence.new(Color3.fromRGB(220, 200, 255), VIOLET)
e.LightEmission = 1
e.Rate = 30
e.Lifetime = NumberRange.new(1.2, 2)
e.Speed = NumberRange.new(3, 6)
e.EmissionDirection = Enum.NormalId.Left
e.SpreadAngle = Vector2.new(25, 25)
e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
e.Transparency = NumberSequence.new(0.1, 1)
e.Parent = voile

-- Pivot fixe des modèles animés côté client
for _, tag in ipairs({ "WikiBloxTourne", "WikiBloxFlottant", "WikiBloxBattant" }) do
	for _, m in ipairs(CollectionService:GetTagged(tag)) do
		if m:IsA("Model") and m.PrimaryPart then m.WorldPivot = m.PrimaryPart.CFrame end
	end
end

CHS:SetWaypoint("Gravures + portail v2")
print("OK gravures + portail v2")
