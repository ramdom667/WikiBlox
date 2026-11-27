-- WikiBlox : construction de l'étang de pêche (première version, volontairement simple)
-- À lancer en mode édition (barre de commande). Relançable : l'ancien étang est supprimé avant.
--
-- Tout est dans Workspace.WikiBloxPeche, loin de la carte (X = 1500, sol à Y = 20) :
--   ArriveePeche        : point d'arrivée (attribut Destination des portails)
--   EauPeche            : volume invisible de l'eau pêchable (tag WikiBloxEauPeche)
--   AirePeche           : volume invisible de l'activité, la canne est donnée dedans (tag WikiBloxAirePeche)
--   DeclencheurRetour…  : portail de retour vers le Nexus
--   FiletPeche          : sous l'île, ramène à l'arrivée en cas de chute
-- + la porte PorteMiniJeu1 du Nexus devient « Pêche » et mène ici.

local CollectionService = game:GetService("CollectionService")

local C = Vector3.new(1500, 20, 0) -- centre de l'île, Y = dessus du sol
local SOL = Color3.fromRGB(90, 150, 70)
local BOIS = Color3.fromRGB(125, 85, 50)
local OR = Color3.fromRGB(240, 190, 75)
local VIOLET = Color3.fromRGB(150, 85, 240)

local ancien = workspace:FindFirstChild("WikiBloxPeche")
if ancien then ancien:Destroy() end

local modele = Instance.new("Model")
modele.Name = "WikiBloxPeche"

local function bloc(parent, nom, taille, cf, couleur, matiere, props)
	local p = Instance.new("Part")
	p.Name = nom
	p.Anchored = true
	p.Size = taille
	p.CFrame = cf
	p.Color = couleur or Color3.new(1, 1, 1)
	p.Material = matiere or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props or {}) do p[k] = v end
	p.Parent = parent
	return p
end

local function invisible(parent, nom, taille, cf)
	return bloc(parent, nom, taille, cf, nil, nil, {
		Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false,
	})
end

local function pos(x, y, z) return CFrame.new(C + Vector3.new(x, y, z)) end

------------------------------------------------------------------
-- Sol de l'île autour de l'étang (île : X -90..90, Z -90..90 ; étang : X -36..36, Z -72..-12)
------------------------------------------------------------------
local sol = Instance.new("Model") sol.Name = "Sol" sol.Parent = modele
bloc(sol, "SolSud", Vector3.new(180, 10, 102), pos(0, -5, 39), SOL, Enum.Material.Grass)
bloc(sol, "SolNord", Vector3.new(180, 10, 18), pos(0, -5, -81), SOL, Enum.Material.Grass)
bloc(sol, "SolOuest", Vector3.new(54, 10, 60), pos(-63, -5, -42), SOL, Enum.Material.Grass)
bloc(sol, "SolEst", Vector3.new(54, 10, 60), pos(63, -5, -42), SOL, Enum.Material.Grass)
bloc(sol, "FondEtang", Vector3.new(72, 2, 60), pos(0, -9, -42), Color3.fromRGB(194, 178, 128), Enum.Material.Sand)

-- Eau (terrain) : de Y 12 à 20, au ras du sol
workspace.Terrain:FillBlock(pos(0, -4, -42), Vector3.new(72, 8, 60), Enum.Material.Water)

-- Volume pêchable (le serveur vérifie que le flotteur tombe dedans)
local eau = invisible(modele, "EauPeche", Vector3.new(72, 1, 60), pos(0, -0.5, -42))
CollectionService:AddTag(eau, "WikiBloxEauPeche")

------------------------------------------------------------------
-- Ponton en bois qui avance dans l'eau
------------------------------------------------------------------
local ponton = Instance.new("Model") ponton.Name = "Ponton" ponton.Parent = modele
bloc(ponton, "Plancher", Vector3.new(8, 1, 22), pos(0, 0.5, -22), BOIS, Enum.Material.WoodPlanks)
for _, x in ipairs({ -3.5, 3.5 }) do
	for _, z in ipairs({ -14, -22, -31 }) do
		bloc(ponton, "Pieu", Vector3.new(1, 10, 1), pos(x, -4, z), BOIS, Enum.Material.Wood)
	end
end

------------------------------------------------------------------
-- Arrivée, pancarte
------------------------------------------------------------------
invisible(modele, "ArriveePeche", Vector3.new(4, 1, 4), pos(0, 0.6, 60)) -- regarde vers -Z (l'étang)

local pancarte = bloc(modele, "Pancarte", Vector3.new(14, 4, 0.6), pos(-12, 4, 52), BOIS, Enum.Material.Wood)
bloc(modele, "PiedPancarte", Vector3.new(0.8, 4, 0.8), pos(-12, 1, 52), BOIS, Enum.Material.Wood)
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Back -- côté tourné vers l'arrivée... et vers l'étang : on met les deux faces
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = 40
gui.Parent = pancarte
local texte = Instance.new("TextLabel")
texte.Size = UDim2.fromScale(1, 1)
texte.BackgroundTransparency = 1
texte.Text = "ÉTANG DE PÊCHE\nApproche-toi de l'eau, maintiens le clic pour lancer"
texte.TextScaled = true
texte.Font = Enum.Font.FredokaOne
texte.TextColor3 = Color3.fromRGB(255, 240, 200)
texte.Parent = gui
local gui2 = gui:Clone()
gui2.Face = Enum.NormalId.Front
gui2.Parent = pancarte

------------------------------------------------------------------
-- Portail de retour vers le Nexus (loin de l'eau : la touche E sert aussi au moulinet)
------------------------------------------------------------------
local portail = Instance.new("Model") portail.Name = "PortailRetourPeche" portail.Parent = modele
for _, x in ipairs({ -5, 5 }) do
	bloc(portail, "Pilier", Vector3.new(1.5, 12, 1.5), pos(40 + x, 6, 70), BOIS, Enum.Material.Wood)
end
bloc(portail, "Linteau", Vector3.new(12, 1.5, 1.5), pos(40, 12.5, 70), OR, Enum.Material.Metal)
local declencheur = bloc(portail, "DeclencheurRetourPeche", Vector3.new(8.5, 10, 0.4), pos(40, 6, 70), VIOLET, Enum.Material.Neon, {
	Transparency = 0.4, CanCollide = false,
})
declencheur:SetAttribute("Destination", "ArriveeNexus")
declencheur:SetAttribute("Interaction", "Retour")
declencheur:SetAttribute("NomLieu", "WikiVerse")

------------------------------------------------------------------
-- Quelques arbres (décor minimal)
------------------------------------------------------------------
for i, p in ipairs({ Vector3.new(-70, 0, 20), Vector3.new(-55, 0, 70), Vector3.new(70, 0, 10), Vector3.new(75, 0, -80), Vector3.new(-75, 0, -80) }) do
	local arbre = Instance.new("Model") arbre.Name = "Arbre" .. i arbre.Parent = modele
	bloc(arbre, "Tronc", Vector3.new(2, 10, 2), pos(p.X, 5, p.Z), BOIS, Enum.Material.Wood)
	bloc(arbre, "Feuillage", Vector3.new(10, 10, 10), pos(p.X, 12, p.Z), Color3.fromRGB(60, 120, 55), Enum.Material.Grass, { Shape = Enum.PartType.Ball })
end

------------------------------------------------------------------
-- Volumes invisibles
------------------------------------------------------------------
local aire = invisible(modele, "AirePeche", Vector3.new(200, 80, 200), pos(0, 20, 0))
CollectionService:AddTag(aire, "WikiBloxAirePeche")

local filet = bloc(modele, "FiletPeche", Vector3.new(600, 2, 600), pos(0, -60, 0), nil, nil, {
	Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false,
})
filet:SetAttribute("Destination", "ArriveePeche")

modele.Parent = workspace

------------------------------------------------------------------
-- Porte « Mini-jeu 1 » du Nexus -> Pêche
------------------------------------------------------------------
local porte = workspace.WikiBloxNexus.PortesMiniJeux.PorteMiniJeu1
porte.Voile:SetAttribute("Destination", "ArriveePeche")
porte.Voile:SetAttribute("NomMiniJeu", "Pêche")
local renommes = {}
for _, d in ipairs(porte:GetDescendants()) do
	if d:IsA("TextLabel") then
		table.insert(renommes, d:GetFullName() .. " : " .. d.Text)
		if d.Text:find("1") or d.Text:lower():find("mini") then
			d.Text = "PÊCHE"
		end
	end
end

return "Étang construit. Textes de la porte : " .. table.concat(renommes, " | ")
