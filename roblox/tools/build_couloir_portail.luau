-- WikiBlox : couloir (style du lobby) + grande porte + « NexaVerse » des mini-jeux
-- À coller dans la barre de commande de Studio (mode édition). Relançable : il remplace l'ancienne version.
--
-- Crée dans Workspace :
--   WikiBloxCouloir : couloir qui part de la grande ouverture de la bibliothèque, avec la grande porte au bout
--   WikiBloxNexus   : île (le NexaVerse) flottante dans le ciel avec 6 portes de mini-jeux + portail de retour
--
-- Marqueurs utilisés par les scripts (WikiBloxTeleport.server / WikiBloxMonde.client) :
--   attribut Destination = "NomDePartie" : toucher cette partie téléporte vers cette partie
--   attribut MiniJeu = "MiniJeu1"...     : porte de mini-jeu (pour l'instant « Bientôt »)
--   attribut Charniere (Vector3) + Sens   : battant de porte qui s'ouvre quand on approche
--   tag WikiBloxFlottant / WikiBloxTourne : objets qui flottent / tournent (côté client)

local CHS = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
CHS:SetWaypoint("Avant couloir + Nexus")

for _, nom in ipairs({ "WikiBloxCouloir", "WikiBloxNexus" }) do
	local ancien = workspace:FindFirstChild(nom)
	if ancien then ancien:Destroy() end
end

local rng = Random.new(42)

------------------------------------------------------------------
-- Palette
------------------------------------------------------------------
local BOIS_FONCE = Color3.fromRGB(62, 40, 28)
local BOIS = Color3.fromRGB(105, 68, 42)
local BOIS_CLAIR = Color3.fromRGB(140, 95, 58)
local PIERRE = Color3.fromRGB(58, 52, 70)
local PIERRE_CLAIRE = Color3.fromRGB(88, 80, 104)
local OR = Color3.fromRGB(196, 156, 72)
local TAPIS = Color3.fromRGB(110, 28, 52)
local VIOLET = Color3.fromRGB(150, 95, 255)
local CHAUD = Color3.fromRGB(255, 196, 120)
local COULEURS_LIVRES = {
	Color3.fromRGB(140, 40, 40), Color3.fromRGB(40, 70, 130), Color3.fromRGB(45, 100, 60),
	Color3.fromRGB(150, 110, 40), Color3.fromRGB(90, 40, 110), Color3.fromRGB(30, 30, 35),
	Color3.fromRGB(170, 150, 120), Color3.fromRGB(120, 60, 30),
}

------------------------------------------------------------------
-- Outils
------------------------------------------------------------------
local function bloc(parent, nom, taille, cf, couleur, matiere, props)
	local p = Instance.new("Part")
	p.Name = nom
	p.Anchored = true
	p.Size = taille
	p.CFrame = cf
	p.Color = couleur
	p.Material = matiere or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in pairs(props) do p[k] = v end
	end
	p.Parent = parent
	return p
end

local function deco(p) -- partie purement décorative : ne gêne ni les joueurs ni les coups
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function modele(parent, nom)
	local m = Instance.new("Model")
	m.Name = nom
	m.Parent = parent
	return m
end

local function lumiere(parent, couleur, luminosite, portee)
	local l = Instance.new("PointLight")
	l.Color = couleur
	l.Brightness = luminosite
	l.Range = portee
	l.Shadows = false
	l.Parent = parent
	return l
end

local function texte(part, face, contenu, couleur, police, contour)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = 0
	g.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = contenu
	t.TextScaled = true
	t.Font = police or Enum.Font.Fantasy
	t.TextColor3 = couleur
	t.TextStrokeTransparency = contour and 0.2 or 1
	t.TextStrokeColor3 = Color3.fromRGB(20, 10, 30)
	t.Parent = g
	return t
end

local function etincelles(parent, couleur, taux)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(couleur)
	e.LightEmission = 1
	e.Rate = taux or 12
	e.Lifetime = NumberRange.new(1, 2)
	e.Speed = NumberRange.new(0.5, 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0.2, 1)
	e.Parent = parent
	return e
end

-- Anneau (cadre de portail) fait de petits blocs disposés en cercle, face vers -Z local
local function anneau(parent, centre, rayon, epaisseur, couleur, matiere, segments)
	segments = segments or 24
	local longueur = 2 * math.pi * rayon / segments * 1.08
	for i = 0, segments - 1 do
		local a = i / segments * math.pi * 2
		local cf = centre * CFrame.Angles(0, 0, a) * CFrame.new(0, rayon, 0)
		deco(bloc(parent, "Anneau", Vector3.new(longueur, epaisseur, epaisseur), cf, couleur, matiere))
	end
end

-- Livre posé à plat qui flotte (animé côté client)
local function livreFlottant(parent, cf, couleur)
	local m = modele(parent, "LivreFlottant")
	local couverture = deco(bloc(m, "Couverture", Vector3.new(1.6, 0.35, 2.2), cf, couleur, Enum.Material.Fabric))
	deco(bloc(m, "Pages", Vector3.new(1.45, 0.25, 2.05), cf * CFrame.new(0.06, 0, 0), Color3.fromRGB(255, 240, 210), Enum.Material.Neon))
	m.PrimaryPart = couverture
	CollectionService:AddTag(m, "WikiBloxFlottant")
	return m
end

------------------------------------------------------------------
-- 1) LE COULOIR
------------------------------------------------------------------
-- Il part de la grande ouverture de la bibliothèque (Spawn.PorteLinteau) et file vers +Z.
local linteau = workspace:FindFirstChild("Spawn") and workspace.Spawn:FindFirstChild("PorteLinteau")
local X0 = linteau and linteau.Position.X or -53
local Z0 = (linteau and linteau.Position.Z or -100.8) + 4.2 -- face extérieure du mur
local O = CFrame.new(X0, 0, Z0)
local function C(x, y, z) return O * CFrame.new(x, y, z) end

local L = 72      -- longueur
local DEMI = 14   -- demi-largeur extérieure
local H = 24      -- hauteur

local couloir = modele(workspace, "WikiBloxCouloir")
local structure = modele(couloir, "Structure")
local decor = modele(couloir, "Decor")

-- Couloir sobre, dans les mêmes matériaux que le lobby :
-- bois sombre, moulures, colonnes carrées, plâtre, liserés de marbre, lumière chaude cachée, grandes fenêtres
local LOBBY_MUR = Color3.fromRGB(52, 32, 20)
local LOBBY_MOULURE = Color3.fromRGB(112, 78, 44)
local LOBBY_CHAPITEAU = Color3.fromRGB(128, 96, 56)
local LOBBY_SOL = Color3.fromRGB(110, 72, 42)
local LOBBY_PLAFOND = Color3.fromRGB(38, 48, 56)
local LOBBY_MARBRE = Color3.fromRGB(176, 141, 74)
local LOBBY_VITRE = Color3.fromRGB(190, 215, 235)
local LOBBY_LUMIERE = Color3.fromRGB(255, 176, 104)
local LOBBY_APPLIQUE = Color3.fromRGB(255, 214, 150)

bloc(structure, "Sol", Vector3.new(DEMI * 2, 1, L + 1), C(0, -0.45, L / 2 - 0.5), LOBBY_SOL, Enum.Material.WoodPlanks)
deco(bloc(decor, "Allee", Vector3.new(7, 0.06, L), C(0, 0.03, L / 2), Color3.fromRGB(92, 58, 34), Enum.Material.WoodPlanks))
for _, x in ipairs({ -3.6, 3.6 }) do
	deco(bloc(decor, "AlleeBord", Vector3.new(0.3, 0.1, L), C(x, 0.05, L / 2), LOBBY_MARBRE, Enum.Material.Marble))
end
for _, cote in ipairs({ -1, 1 }) do
	deco(bloc(decor, "Bordure", Vector3.new(1.4, 0.12, L), C(cote * (DEMI - 1.7), 0.06, L / 2), LOBBY_MARBRE, Enum.Material.Marble))
end
bloc(structure, "Plafond", Vector3.new(DEMI * 2, 1, L + 1), C(0, H + 0.5, L / 2 - 0.5), LOBBY_PLAFOND, Enum.Material.Plaster)

-- Travées : mur bas en bois, grande fenêtre, mur haut, corniche, lumière chaude cachée
local PAS = 12
local BAS, HAUT = 5, 16 -- la fenêtre va de y = 5 à y = 16
for i = 0, L / PAS - 1 do
	local z0 = i * PAS
	local zc = z0 + PAS / 2
	for _, cote in ipairs({ -1, 1 }) do
		local x = cote * DEMI
		bloc(structure, "MurBas", Vector3.new(2, BAS, PAS), C(x, BAS / 2, zc), LOBBY_MUR, Enum.Material.Wood)
		bloc(structure, "MurHaut", Vector3.new(2, H - HAUT, PAS), C(x, HAUT + (H - HAUT) / 2, zc), LOBBY_MUR, Enum.Material.Wood)
		bloc(structure, "Vitre", Vector3.new(0.4, HAUT - BAS, PAS), C(x, (BAS + HAUT) / 2, zc), LOBBY_VITRE, Enum.Material.Glass, { Transparency = 0.45 })
		deco(bloc(decor, "Croisillon", Vector3.new(0.6, HAUT - BAS, 0.4), C(x, (BAS + HAUT) / 2, zc), LOBBY_MOULURE, Enum.Material.Wood))
		deco(bloc(decor, "Traverse", Vector3.new(0.6, 0.4, PAS - 2.6), C(x, (BAS + HAUT) / 2 + 1.5, zc), LOBBY_MOULURE, Enum.Material.Wood))
		deco(bloc(decor, "Appui", Vector3.new(3, 0.6, PAS - 2.6), C(x - cote * 0.3, BAS, zc), LOBBY_CHAPITEAU, Enum.Material.Wood))
		deco(bloc(decor, "LinteauFenetre", Vector3.new(2.8, 0.8, PAS - 2.6), C(x - cote * 0.2, HAUT, zc), LOBBY_MOULURE, Enum.Material.Wood))
		deco(bloc(decor, "Plinthe", Vector3.new(0.5, 0.8, PAS), C(x - cote * 1.2, 0.4, zc), LOBBY_MOULURE, Enum.Material.Wood))
		deco(bloc(decor, "Cimaise", Vector3.new(0.5, 0.5, PAS), C(x - cote * 1.2, BAS - 1.6, zc), LOBBY_MOULURE, Enum.Material.Wood))
		deco(bloc(decor, "Corniche", Vector3.new(1.4, 1.2, PAS), C(x - cote * 1.4, H - 0.6, zc), LOBBY_CHAPITEAU, Enum.Material.Wood))
	end
	deco(bloc(decor, "Poutre", Vector3.new(DEMI * 2 - 2, 1.2, 1.6), C(0, H - 0.6, z0), LOBBY_MOULURE, Enum.Material.Wood))
	local lum = deco(bloc(decor, "Lumiere", Vector3.new(1, 1, 1), C(0, H - 3, zc), LOBBY_LUMIERE, Enum.Material.SmoothPlastic, { Transparency = 1 }))
	lumiere(lum, LOBBY_LUMIERE, 0.6, 30)
end

-- Colonnes carrées (comme dans le lobby) + petites appliques chaudes
for i = 0, L / PAS - 1 do
	local z = i * PAS
	for _, cote in ipairs({ -1, 1 }) do
		local x = cote * (DEMI - 1.6)
		bloc(structure, "Colonne", Vector3.new(2.6, H, 2.6), C(x, H / 2, z), LOBBY_MUR, Enum.Material.Wood)
		deco(bloc(decor, "Socle", Vector3.new(3.4, 1.8, 3.4), C(x, 0.9, z), LOBBY_CHAPITEAU, Enum.Material.Wood))
		deco(bloc(decor, "Chapiteau", Vector3.new(3.4, 1.8, 3.4), C(x, H - 2.2, z), LOBBY_CHAPITEAU, Enum.Material.Wood))
		if z > 0 then
			deco(bloc(decor, "AppliqueSupport", Vector3.new(1.2, 0.3, 1.2), C(x - cote * 1.8, 9.3, z), LOBBY_MOULURE, Enum.Material.Wood))
			local applique = deco(bloc(decor, "Applique", Vector3.new(0.8, 1.2, 0.8), C(x - cote * 1.8, 10, z), LOBBY_APPLIQUE, Enum.Material.Neon, { Transparency = 0.2 }))
			lumiere(applique, LOBBY_APPLIQUE, 0.5, 14)
		end
	end
end

------------------------------------------------------------------
-- 2) LA GRANDE PORTE (au bout du couloir)
------------------------------------------------------------------
local porte = modele(couloir, "GrandePorte")
local OUV = 6     -- demi-largeur de l'ouverture
local HO = 16     -- hauteur de l'ouverture

-- Mur du fond, percé pour la porte
bloc(porte, "MurFondG", Vector3.new(DEMI - OUV, H, 2), C(-(DEMI + OUV) / 2, H / 2, L + 1), Color3.fromRGB(52, 32, 20), Enum.Material.Wood)
bloc(porte, "MurFondD", Vector3.new(DEMI - OUV, H, 2), C((DEMI + OUV) / 2, H / 2, L + 1), Color3.fromRGB(52, 32, 20), Enum.Material.Wood)
bloc(porte, "MurFondHaut", Vector3.new(OUV * 2, H - HO, 2), C(0, HO + (H - HO) / 2, L + 1), Color3.fromRGB(52, 32, 20), Enum.Material.Wood)

-- Encadrement monumental
for _, cote in ipairs({ -1, 1 }) do
	local x = cote * (OUV + 1.3)
	bloc(porte, "Colonne", Vector3.new(2.6, HO + 1, 2.4), C(x, (HO + 1) / 2, L - 0.6), PIERRE_CLAIRE, Enum.Material.Marble)
	deco(bloc(porte, "ColonneBase", Vector3.new(3.4, 1.4, 3), C(x, 0.7, L - 0.6), OR, Enum.Material.Metal))
	deco(bloc(porte, "ColonneTete", Vector3.new(3.4, 1, 3), C(x, HO + 0.6, L - 0.6), OR, Enum.Material.Metal))
	for k = 1, 3 do -- cannelures dorées
		deco(bloc(porte, "Cannelure", Vector3.new(0.25, HO - 2, 0.2), C(x + (k - 2) * 0.7, HO / 2 + 0.5, L - 1.85), OR, Enum.Material.Metal))
	end
	-- vasque de feu violet de chaque côté
	local vasque = deco(bloc(porte, "Vasque", Vector3.new(2.2, 1.2, 2.2), C(cote * (OUV + 5), 4.6, L - 2), OR, Enum.Material.Metal))
	deco(bloc(porte, "VasquePied", Vector3.new(0.8, 4, 0.8), C(cote * (OUV + 5), 2, L - 2), PIERRE, Enum.Material.Slate))
	local feu = Instance.new("Fire")
	feu.Color = VIOLET
	feu.SecondaryColor = Color3.fromRGB(80, 200, 255)
	feu.Heat = 6
	feu.Size = 4
	feu.Parent = vasque
	lumiere(vasque, VIOLET, 1.5, 16)
end
local fronton = deco(bloc(porte, "Fronton", Vector3.new(OUV * 2 + 6, 3.4, 3), C(0, HO + 2.8, L - 0.6), PIERRE_CLAIRE, Enum.Material.Marble))
deco(bloc(porte, "FrontonOr", Vector3.new(OUV * 2 + 6.4, 0.4, 3.2), C(0, HO + 1.2, L - 0.6), OR, Enum.Material.Metal))
deco(bloc(porte, "FrontonOrHaut", Vector3.new(OUV * 2 + 6.4, 0.4, 3.2), C(0, HO + 4.6, L - 0.6), OR, Enum.Material.Metal))
texte(fronton, Enum.NormalId.Front, "WikiVerse", Color3.fromRGB(255, 225, 150), Enum.Font.Fantasy, true)

-- Médaillon « W » au-dessus
local medaillon = deco(bloc(porte, "Medaillon", Vector3.new(0.6, 3.2, 3.2), C(0, HO + 6.4, L - 0.9) * CFrame.Angles(0, math.rad(90), 0), OR, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder }))
local coeur = deco(bloc(porte, "MedaillonCoeur", Vector3.new(0.7, 2.4, 2.4), medaillon.CFrame * CFrame.new(-0.05, 0, 0), VIOLET, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder }))
local plaqueW = deco(bloc(porte, "MedaillonW", Vector3.new(1.9, 1.9, 0.1), C(0, HO + 6.4, L - 1.35), VIOLET, Enum.Material.SmoothPlastic, { Transparency = 1 }))
texte(plaqueW, Enum.NormalId.Front, "W", Color3.new(1, 1, 1), Enum.Font.Fantasy, true)
lumiere(coeur, VIOLET, 2, 18)

-- Les deux battants (s'ouvrent vers l'intérieur du portail quand on approche)
local function battant(nom, charniereX, sens)
	local m = modele(porte, nom)
	local milieuX = charniereX + (charniereX < 0 and OUV / 2 or -OUV / 2)
	local z = L + 2.45
	local panneau = bloc(m, "Panneau", Vector3.new(OUV, HO, 0.8), C(milieuX, HO / 2, z), Color3.fromRGB(78, 38, 30), Enum.Material.WoodPlanks)
	-- cadre doré + croisillons
	deco(bloc(m, "CadreHaut", Vector3.new(OUV, 0.4, 0.95), C(milieuX, HO - 0.6, z), OR, Enum.Material.Metal))
	deco(bloc(m, "CadreBas", Vector3.new(OUV, 0.4, 0.95), C(milieuX, 0.6, z), OR, Enum.Material.Metal))
	deco(bloc(m, "CadreMilieu", Vector3.new(OUV, 0.3, 0.95), C(milieuX, HO * 0.55, z), OR, Enum.Material.Metal))
	deco(bloc(m, "CadreBord", Vector3.new(0.35, HO, 0.95), C(milieuX + (charniereX < 0 and OUV / 2 - 0.3 or -OUV / 2 + 0.3), HO / 2, z), OR, Enum.Material.Metal))
	-- losange lumineux
	deco(bloc(m, "Losange", Vector3.new(1.6, 1.6, 0.9), C(milieuX, HO * 0.75, z) * CFrame.Angles(0, 0, math.rad(45)), VIOLET, Enum.Material.Neon))
	deco(bloc(m, "LosangeOr", Vector3.new(2.1, 2.1, 0.85), C(milieuX, HO * 0.75, z) * CFrame.Angles(0, 0, math.rad(45)), OR, Enum.Material.Metal))
	-- grand anneau de poignée
	local px = charniereX < 0 and -0.9 or 0.9
	deco(bloc(m, "Poignee", Vector3.new(0.3, 1.6, 1.6), C(px, HO * 0.45, z - 0.55) * CFrame.Angles(0, math.rad(90), 0), OR, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder, Transparency = 0 }))
	deco(bloc(m, "PoigneeTrou", Vector3.new(0.35, 1.1, 1.1), C(px, HO * 0.45, z - 0.55) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(78, 38, 30), Enum.Material.WoodPlanks, { Shape = Enum.PartType.Cylinder }))
	-- clous
	for _, yy in ipairs({ 2, 5, 11, 14 }) do
		deco(bloc(m, "Clou", Vector3.new(0.4, 0.4, 0.9), C(milieuX, yy, z), OR, Enum.Material.Metal, { Shape = Enum.PartType.Ball }))
	end
	m.PrimaryPart = panneau
	m:SetAttribute("Charniere", Vector3.new((O * CFrame.new(charniereX, 0, z)).X, 0, (O * CFrame.new(charniereX, 0, z)).Z))
	m:SetAttribute("Sens", sens)
	m:SetAttribute("Angle", 100)
	CollectionService:AddTag(m, "WikiBloxBattant")
	return m
end
battant("BattantGauche", -OUV, -1)
battant("BattantDroit", OUV, 1)

-- Vestibule du portail (derrière les battants)
local vest = modele(porte, "Vestibule")
local ZV = L + 2
bloc(vest, "Sol", Vector3.new(OUV * 2 + 4, 1, 10), C(0, -0.45, ZV + 5), PIERRE, Enum.Material.Slate)
bloc(vest, "MurG", Vector3.new(1, HO + 2, 10), C(-(OUV + 2.5), (HO + 2) / 2, ZV + 5), PIERRE, Enum.Material.Slate)
bloc(vest, "MurD", Vector3.new(1, HO + 2, 10), C(OUV + 2.5, (HO + 2) / 2, ZV + 5), PIERRE, Enum.Material.Slate)
bloc(vest, "Plafond", Vector3.new(OUV * 2 + 6, 1, 10), C(0, HO + 2.5, ZV + 5), PIERRE, Enum.Material.Slate)
bloc(vest, "Fond", Vector3.new(OUV * 2 + 6, HO + 3, 1), C(0, (HO + 3) / 2, ZV + 10.5), Color3.fromRGB(20, 12, 35), Enum.Material.Slate)

-- Le portail tourbillonnant
local centrePortail = C(0, 8, ZV + 9.4)
anneau(vest, centrePortail, 7, 1, OR, Enum.Material.Metal, 28)
local voile = deco(bloc(vest, "Voile", Vector3.new(0.3, 13.4, 13.4), centrePortail * CFrame.Angles(0, math.rad(90), 0), VIOLET, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, Transparency = 0.35 }))
local tourbillon = modele(vest, "Tourbillon")
for k = 0, 5 do
	deco(bloc(tourbillon, "Bras", Vector3.new(11, 0.5, 0.2), centrePortail * CFrame.new(0, 0, -0.3) * CFrame.Angles(0, 0, k * math.pi / 6), Color3.fromRGB(210, 190, 255), Enum.Material.Neon, { Transparency = 0.4 }))
end
local coeurPortail = deco(bloc(tourbillon, "Coeur", Vector3.new(2.4, 2.4, 2.4), centrePortail * CFrame.new(0, 0, -0.4), Color3.new(1, 1, 1), Enum.Material.Neon, { Shape = Enum.PartType.Ball }))
tourbillon.PrimaryPart = coeurPortail
tourbillon:SetAttribute("Vitesse", 2.2)
tourbillon:SetAttribute("Axe", "Z")
CollectionService:AddTag(tourbillon, "WikiBloxTourne")
etincelles(voile, Color3.fromRGB(200, 170, 255), 25)
lumiere(voile, VIOLET, 3, 30)

-- Zone qui téléporte vers le Nexus
local declencheur = bloc(vest, "DeclencheurNexus", Vector3.new(OUV * 2, HO, 2), C(0, HO / 2, ZV + 6.5), VIOLET, Enum.Material.SmoothPlastic,
	{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = true })
declencheur:SetAttribute("Destination", "ArriveeNexus")
declencheur:SetAttribute("Interaction", "Entrer")
declencheur:SetAttribute("NomLieu", "WikiVerse")

-- Point d'arrivée quand on revient du Nexus (devant la porte, tourné vers la bibliothèque)
local arriveeC = bloc(couloir, "ArriveeCouloir", Vector3.new(4, 1, 4), CFrame.lookAt(C(0, 0.6, L - 12).Position, C(0, 0.6, 0).Position), VIOLET, Enum.Material.SmoothPlastic,
	{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })

------------------------------------------------------------------
-- 3) LE NEXUS : île flottante avec les portes des mini-jeux
------------------------------------------------------------------
local N = CFrame.new(X0, 400, 900)
local R = 60 -- rayon de l'île
local nexus = modele(workspace, "WikiBloxNexus")
local ile = modele(nexus, "Ile")
local decorN = modele(nexus, "Decor")
local function verticale(cf) return cf * CFrame.Angles(0, 0, math.rad(90)) end -- cylindre debout

-- Plateau + dessous rocheux
bloc(ile, "Plateau", Vector3.new(3, R * 2, R * 2), verticale(N * CFrame.new(0, -1.5, 0)), Color3.fromRGB(46, 40, 64), Enum.Material.Slate, { Shape = Enum.PartType.Cylinder })
deco(bloc(ile, "Bordure", Vector3.new(0.6, R * 2 + 1.2, R * 2 + 1.2), verticale(N * CFrame.new(0, -0.6, 0)), OR, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder }))
local rayons = { 56, 46, 34, 22, 11 }
for i, r in ipairs(rayons) do
	deco(bloc(ile, "Roche", Vector3.new(7, r * 2, r * 2), verticale(N * CFrame.new(0, -3 - i * 6, 0) * CFrame.Angles(0, i * 0.7, 0)), Color3.fromRGB(70 - i * 4, 58 - i * 3, 84 - i * 2), Enum.Material.Rock, { Shape = Enum.PartType.Cylinder }))
end
-- cristaux sous l'île
for i = 1, 10 do
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(8, 40)
	local h = rng:NextNumber(5, 12)
	local cristal = deco(bloc(decorN, "CristalDessous", Vector3.new(2, h, 2), N * CFrame.new(math.cos(a) * r, -10 - r * 0.5 - h / 2, math.sin(a) * r) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), a, rng:NextNumber(-0.3, 0.3)), Color3.fromRGB(130, 200, 255), Enum.Material.Neon, { Transparency = 0.2 }))
end

-- Rosace au sol (cercles lumineux)
deco(bloc(ile, "Rosace", Vector3.new(0.1, 34, 34), verticale(N * CFrame.new(0, 0.02, 0)), VIOLET, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, Transparency = 0.55 }))
deco(bloc(ile, "RosaceInt", Vector3.new(0.12, 31, 31), verticale(N * CFrame.new(0, 0.03, 0)), Color3.fromRGB(46, 40, 64), Enum.Material.Slate, { Shape = Enum.PartType.Cylinder }))
for k = 0, 7 do
	deco(bloc(ile, "Allee", Vector3.new(2, 0.08, 40), N * CFrame.Angles(0, k * math.pi / 4, 0) * CFrame.new(0, 0.04, 36), Color3.fromRGB(70, 60, 95), Enum.Material.Marble))
end

-- Balustrade autour de l'île
local NB = 48
for i = 0, NB - 1 do
	local a = i / NB * math.pi * 2
	local cf = N * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, R - 1.2)
	deco(bloc(decorN, "Balustre", Vector3.new(0.7, 3, 0.7), cf * CFrame.new(0, 1.5, 0), PIERRE_CLAIRE, Enum.Material.Marble))
	local longueur = 2 * math.pi * (R - 1.2) / NB + 0.3
	bloc(decorN, "Rampe", Vector3.new(longueur, 0.5, 0.9), N * CFrame.Angles(0, a + math.pi / NB, 0) * CFrame.new(0, 3.2, R - 1.2), OR, Enum.Material.Metal)
	-- mur invisible pour ne pas tomber
	bloc(decorN, "Garde", Vector3.new(longueur, 10, 1), N * CFrame.Angles(0, a + math.pi / NB, 0) * CFrame.new(0, 5, R - 1.2),
		Color3.new(), Enum.Material.SmoothPlastic, { Transparency = 1, CanQuery = false })
end

-- Centre : globe holographique de WikiBlox sur un piédestal
deco(bloc(decorN, "Piedestal", Vector3.new(3, 8, 8), verticale(N * CFrame.new(0, 1.5, 0)), PIERRE_CLAIRE, Enum.Material.Marble, { Shape = Enum.PartType.Cylinder }))
deco(bloc(decorN, "PiedestalOr", Vector3.new(0.4, 8.6, 8.6), verticale(N * CFrame.new(0, 3, 0)), OR, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder }))
local globe = modele(decorN, "Globe")
local sphere = deco(bloc(globe, "Sphere", Vector3.new(9, 9, 9), N * CFrame.new(0, 10, 0), Color3.fromRGB(120, 160, 255), Enum.Material.ForceField, { Shape = Enum.PartType.Ball }))
deco(bloc(globe, "Noyau", Vector3.new(4, 4, 4), N * CFrame.new(0, 10, 0), Color3.fromRGB(200, 180, 255), Enum.Material.Neon, { Shape = Enum.PartType.Ball, Transparency = 0.2 }))
for k = 0, 2 do
	anneau(globe, N * CFrame.new(0, 10, 0) * CFrame.Angles(k * math.pi / 3, k * 0.6, 0), 6.5, 0.3, OR, Enum.Material.Neon, 24)
end
globe.PrimaryPart = sphere
globe:SetAttribute("Vitesse", 0.6)
globe:SetAttribute("Axe", "Y")
CollectionService:AddTag(globe, "WikiBloxTourne")
lumiere(sphere, Color3.fromRGB(160, 140, 255), 2.5, 40)
etincelles(sphere, Color3.fromRGB(190, 210, 255), 15)
local titre = Instance.new("BillboardGui")
titre.Size = UDim2.fromScale(16, 4)
titre.StudsOffset = Vector3.new(0, 8, 0)
titre.LightInfluence = 0
titre.MaxDistance = 200
titre.Parent = sphere
local tt = Instance.new("TextLabel")
tt.Size = UDim2.fromScale(1, 1)
tt.BackgroundTransparency = 1
tt.Text = "WikiVerse"
tt.TextScaled = true
tt.Font = Enum.Font.Fantasy
tt.TextColor3 = Color3.fromRGB(255, 225, 150)
tt.TextStrokeTransparency = 0.2
tt.Parent = titre

-- Livres qui flottent autour du globe
for i = 1, 10 do
	local a = i / 10 * math.pi * 2
	livreFlottant(decorN, N * CFrame.Angles(0, a, 0) * CFrame.new(0, rng:NextNumber(6, 14), rng:NextNumber(12, 20)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), 0), COULEURS_LIVRES[rng:NextInteger(1, #COULEURS_LIVRES)])
end

-- Les 6 portes de mini-jeux (en arc de cercle, face au centre)
local COULEURS_PORTES = {
	Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 165, 60), Color3.fromRGB(240, 215, 80),
	Color3.fromRGB(90, 220, 120), Color3.fromRGB(80, 195, 255), Color3.fromRGB(220, 100, 255),
}
local portesJeux = modele(nexus, "PortesMiniJeux")
for i = 1, 6 do
	local angle = math.rad(75 - (i - 1) * 30) -- porte 1 à gauche quand on arrive
	local base = N * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, 46)
	local cf = CFrame.lookAt(base.Position, N.Position) -- l'avant de la porte regarde le centre
	local couleur = COULEURS_PORTES[i]
	local m = modele(portesJeux, "PorteMiniJeu" .. i)
	local function P(x, y, z) return cf * CFrame.new(x, y, z) end

	bloc(m, "Marche", Vector3.new(14, 1, 7), P(0, 0.5, 0.5), PIERRE_CLAIRE, Enum.Material.Marble)
	deco(bloc(m, "MarcheOr", Vector3.new(14.2, 0.2, 7.2), P(0, 1, 0.5), OR, Enum.Material.Metal))
	for _, cote in ipairs({ -1, 1 }) do
		bloc(m, "Montant", Vector3.new(2, 13, 2), P(cote * 5, 7.5, 1.5), PIERRE_CLAIRE, Enum.Material.Marble)
		deco(bloc(m, "MontantLueur", Vector3.new(0.3, 11, 2.1), P(cote * 4, 7.5, 1.5), couleur, Enum.Material.Neon))
		local torche = deco(bloc(m, "Torche", Vector3.new(0.8, 0.8, 0.8), P(cote * 6.8, 9, -0.2), OR, Enum.Material.Metal))
		local feu = Instance.new("Fire")
		feu.Color = couleur
		feu.SecondaryColor = Color3.new(1, 1, 1)
		feu.Size = 2
		feu.Heat = 4
		feu.Parent = torche
	end
	local linteauJ = bloc(m, "Linteau", Vector3.new(12, 2.6, 2.4), P(0, 15.3, 1.5), PIERRE_CLAIRE, Enum.Material.Marble)
	deco(bloc(m, "LinteauOr", Vector3.new(12.4, 0.3, 2.6), P(0, 14, 1.5), OR, Enum.Material.Metal))
	-- pointe décorative au-dessus
	deco(bloc(m, "Pointe", Vector3.new(3, 3, 1.4), P(0, 17.6, 1.5) * CFrame.Angles(0, 0, math.rad(45)), couleur, Enum.Material.Neon))
	deco(bloc(m, "PointeOr", Vector3.new(3.6, 3.6, 1.2), P(0, 17.6, 1.5) * CFrame.Angles(0, 0, math.rad(45)), OR, Enum.Material.Metal))

	-- voile lumineux (le « passage »)
	local voileJ = bloc(m, "Voile", Vector3.new(8, 12.4, 0.4), P(0, 7.4, 1.5), couleur, Enum.Material.Neon, { Transparency = 0.45, CanCollide = true })
	voileJ:SetAttribute("MiniJeu", "MiniJeu" .. i)
	voileJ:SetAttribute("NomMiniJeu", "Mini-jeu " .. i)
	etincelles(voileJ, couleur, 8)
	lumiere(voileJ, couleur, 1.6, 16)

	-- enseignes
	texte(linteauJ, Enum.NormalId.Front, "MINI-JEU " .. i, Color3.new(1, 1, 1), Enum.Font.Fantasy, true)
	local pancarte = deco(bloc(m, "Pancarte", Vector3.new(5, 1.6, 0.2), P(0, 3.2, 1.2), Color3.fromRGB(25, 20, 35), Enum.Material.SmoothPlastic))
	local tb = texte(pancarte, Enum.NormalId.Front, "BIENTÔT", couleur, Enum.Font.GothamBold, false)
	tb.Name = "Statut"
end

-- Portail de retour vers la bibliothèque (au sud de l'île)
local retour = modele(nexus, "PortailRetour")
local cfR = CFrame.lookAt((N * CFrame.new(0, 0, -50)).Position, N.Position)
local function PR(x, y, z) return cfR * CFrame.new(x, y, z) end
bloc(retour, "Marche", Vector3.new(16, 1, 8), PR(0, 0.5, 0.5), PIERRE_CLAIRE, Enum.Material.Marble)
local centreR = PR(0, 8.5, 1.5) * CFrame.Angles(0, math.pi, 0) -- face avant tournée vers le centre de l'île
anneau(retour, centreR, 6.5, 1, OR, Enum.Material.Metal, 26)
local voileR = deco(bloc(retour, "Voile", Vector3.new(0.3, 12.4, 12.4), centreR * CFrame.Angles(0, math.rad(90), 0), CHAUD, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, Transparency = 0.4 }))
etincelles(voileR, CHAUD, 15)
lumiere(voileR, CHAUD, 2, 22)
local tourR = modele(retour, "Tourbillon")
for k = 0, 5 do
	deco(bloc(tourR, "Bras", Vector3.new(10, 0.4, 0.2), PR(0, 8.5, 1.2) * CFrame.Angles(0, 0, k * math.pi / 6), Color3.fromRGB(255, 235, 200), Enum.Material.Neon, { Transparency = 0.4 }))
end
local coeurR = deco(bloc(tourR, "Coeur", Vector3.new(2, 2, 2), PR(0, 8.5, 1.1), Color3.new(1, 1, 1), Enum.Material.Neon, { Shape = Enum.PartType.Ball }))
tourR.PrimaryPart = coeurR
tourR:SetAttribute("Vitesse", -1.8)
tourR:SetAttribute("Axe", "Z")
CollectionService:AddTag(tourR, "WikiBloxTourne")
local enseigneR = deco(bloc(retour, "Enseigne", Vector3.new(12, 2, 0.3), PR(0, 17, 1.5), TAPIS, Enum.Material.Fabric))
texte(enseigneR, Enum.NormalId.Front, "↩ BIBLIOTHÈQUE", Color3.fromRGB(255, 225, 150), Enum.Font.Fantasy, true)
local declR = bloc(retour, "DeclencheurRetour", Vector3.new(10, 13, 2), PR(0, 7.5, 2.5), CHAUD, Enum.Material.SmoothPlastic,
	{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = true })
declR:SetAttribute("Destination", "ArriveeCouloir")
declR:SetAttribute("Interaction", "Entrer")
declR:SetAttribute("NomLieu", "Bibliothèque")

-- Point d'arrivée dans le Nexus (devant le portail de retour, tourné vers les portes)
bloc(nexus, "ArriveeNexus", Vector3.new(4, 1, 4), CFrame.lookAt((N * CFrame.new(0, 0.6, -38)).Position, (N * CFrame.new(0, 0.6, 0)).Position), VIOLET, Enum.Material.SmoothPlastic,
	{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })

-- Îlots flottants autour
for i = 1, 7 do
	local a = i / 7 * math.pi * 2 + 0.3
	local r = rng:NextNumber(85, 130)
	local ilot = modele(decorN, "Ilot")
	local cfI = N * CFrame.new(math.cos(a) * r, rng:NextNumber(-25, 25), math.sin(a) * r)
	local taille = rng:NextNumber(8, 16)
	local rocher = deco(bloc(ilot, "Rocher", Vector3.new(taille, taille * 0.6, taille), cfI * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color3.fromRGB(70, 60, 85), Enum.Material.Rock))
	deco(bloc(ilot, "Dessous", Vector3.new(taille * 0.6, taille * 0.7, taille * 0.6), cfI * CFrame.new(0, -taille * 0.55, 0) * CFrame.Angles(0, 0.5, 0.2), Color3.fromRGB(60, 50, 75), Enum.Material.Rock))
	for k = 1, 3 do
		local h = rng:NextNumber(3, 7)
		deco(bloc(ilot, "Cristal", Vector3.new(1.4, h, 1.4), cfI * CFrame.new(rng:NextNumber(-3, 3), taille * 0.3 + h / 2 - 0.5, rng:NextNumber(-3, 3)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)), COULEURS_PORTES[rng:NextInteger(1, 6)], Enum.Material.Neon, { Transparency = 0.15 }))
	end
	ilot.PrimaryPart = rocher
	CollectionService:AddTag(ilot, "WikiBloxFlottant")
end

-- Filet de sécurité : si on tombe de l'île, on revient à l'arrivée
local filet = bloc(nexus, "FiletSecurite", Vector3.new(800, 2, 800), N * CFrame.new(0, -120, 0), Color3.new(), Enum.Material.SmoothPlastic,
	{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = true })
filet:SetAttribute("Destination", "ArriveeNexus")

-- Pivot fixe des modèles animés (sinon, côté client, ils peuvent partir à l'origine du monde)
for _, tag in ipairs({ "WikiBloxTourne", "WikiBloxFlottant", "WikiBloxBattant" }) do
	for _, m in ipairs(CollectionService:GetTagged(tag)) do
		if m:IsA("Model") and m.PrimaryPart then m.WorldPivot = m.PrimaryPart.CFrame end
	end
end
CHS:SetWaypoint("Couloir + Nexus construits")
local n = 0
for _, d in ipairs(couloir:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
for _, d in ipairs(nexus:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
print("✅ Couloir, grande porte et Nexus construits (" .. n .. " pièces)")
