-- WikiBlox : écran d'ouverture de booster (côté joueur)
--
-- Utilise ReplicatedStorage.WikiBloxRemotes, créé par src/server/WikiBloxBoosters.server.luau :
--   OuvrirBooster:InvokeServer("standard") -> { success, booster } ou { success = false, error }
--   ProbaBoosters:InvokeServer()           -> { success, boosters }
--
-- Le joueur ouvre l'écran avec le bouton "Booster" (à gauche de l'écran)
-- ou en s'approchant du booster géant au centre du lobby (touche E).
-- Style commun : src/shared/WikiBloxStyle.luau

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("WikiBloxRemotes")
local ouvrirRemote = remotes:WaitForChild("OuvrirBooster")
local probaRemote = remotes:WaitForChild("ProbaBoosters")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Style = require(Shared:WaitForChild("WikiBloxStyle"))
local HUD = require(Shared:WaitForChild("WikiBloxHUD"))

local C = Style.C
local new, tween, texte = Style.new, Style.tween, Style.texte

local TYPE_BOOSTER = "standard"

local function hex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

------------------------------------------------------------------
-- Fenêtre
------------------------------------------------------------------
local gui = new("ScreenGui", {
	Name = "WikiBloxBoosterUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local F = Style.fenetre(gui, {
	titre = "BOOSTER STANDARD",
	taille = UDim2.fromScale(0.92, 0.84),
	max = Vector2.new(980, 620),
})
local contenu = F.contenu

texte({
	Name = "SousTitre",
	Position = UDim2.fromScale(0.1, 0.02),
	Size = UDim2.fromScale(0.8, 0.06),
	Text = "5 cartes Wikipédia · la dernière est au minimum rare",
	Font = Enum.Font.GothamMedium,
	TextColor3 = C.parcheminFonce,
	TailleMax = 20,
	Parent = contenu,
})

-- Scène : le paquet, puis les cartes
local scene = new("Frame", {
	Name = "Scene",
	Position = UDim2.fromScale(0, 0.1),
	Size = UDim2.fromScale(1, 0.64),
	BackgroundTransparency = 1,
	Parent = contenu,
})

local zoneCartes = new("Frame", {
	Name = "Cartes",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 2,
	Parent = scene,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0.02, 0),
	}),
})

local statut = texte({
	Name = "Statut",
	Position = UDim2.fromScale(0.05, 0.76),
	Size = UDim2.fromScale(0.9, 0.07),
	Text = "",
	RichText = true,
	Font = Style.POLICE_TITRE,
	Contour = C.nuitFonce,
	TailleMax = 26,
	Parent = contenu,
})

local boutonOuvrir, texteOuvrir = Style.bouton(contenu, {
	nom = "Ouvrir",
	texte = "OUVRIR",
	couleur = C.or_,
	ancre = Vector2.new(0.5, 0),
	position = UDim2.fromScale(0.5, 0.855),
	taille = UDim2.fromScale(0.32, 0.12),
	max = Vector2.new(280, 66),
	tailleTexte = 32,
})
local boutonProba = Style.bouton(contenu, {
	nom = "Probabilites",
	texte = "Probabilités",
	icone = "probabilites",
	couleur = C.nuitClair,
	position = UDim2.fromScale(0, 0.875),
	taille = UDim2.fromScale(0.24, 0.09),
	max = Vector2.new(210, 48),
	tailleTexte = 20,
})
local boutonCollection = Style.bouton(contenu, {
	nom = "VoirCollection",
	texte = "Ma collection",
	icone = "collection",
	couleur = C.bleu,
	ancre = Vector2.new(1, 0),
	position = UDim2.fromScale(1, 0.875),
	taille = UDim2.fromScale(0.24, 0.09),
	max = Vector2.new(210, 48),
	tailleTexte = 20,
})

------------------------------------------------------------------
-- Le paquet de booster
------------------------------------------------------------------
local socle = new("Frame", {
	Name = "Socle",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 0.92),
	BackgroundTransparency = 1,
	ZIndex = 3,
	Parent = scene,
}, { new("UIAspectRatioConstraint", { AspectRatio = 0.72 }) })

local halo = Style.halo(socle, Color3.fromRGB(190, 130, 255), 14)
local paquet = new("Frame", {
	Name = "Paquet",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	ZIndex = 3,
	Parent = socle,
}, {
	Style.coins(16),
	Style.degrade(Color3.fromRGB(140, 85, 235), Color3.fromRGB(55, 28, 120), 160),
})
local echellePaquet = new("UIScale", { Parent = paquet })
new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Parent = paquet,
}, { Style.coins(16), new("UIStroke", { Color = C.or_, Thickness = 5 }) })
-- dents dorées en haut et en bas (le paquet se déchire là)
for _, y in ipairs({ 0, 1 }) do
	for i = 0, 9 do
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale((i + 0.5) / 10, y),
			Size = UDim2.fromScale(0.09, 0.065),
			Rotation = 45,
			BackgroundColor3 = C.or_,
			Parent = paquet,
		}, { new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	end
end
-- reflet diagonal
new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.25, 0.5),
	Size = UDim2.fromScale(0.12, 0.86),
	Rotation = 0,
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.88,
	BorderSizePixel = 0,
	Parent = paquet,
})
texte({
	Position = UDim2.fromScale(0.08, 0.09),
	Size = UDim2.fromScale(0.84, 0.1),
	Text = "WIKIBLOX",
	Font = Style.POLICE_TITRE,
	TextColor3 = C.orClair,
	Contour = Color3.fromRGB(40, 15, 80),
	ContourEpaisseur = 2.5,
	Parent = paquet,
})
local emblemePaquet = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Parent = paquet,
}, {
	new("UIAspectRatioConstraint", { AspectRatio = 1 }),
	Style.coins(UDim.new(1, 0)),
	Style.degrade(C.orClair, C.orFonce, 135),
	new("UIStroke", { Color = Color3.fromRGB(40, 15, 80), Thickness = 3 }),
})
texte({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.6, 0.6),
	Text = "W",
	Font = Style.POLICE_TITRE,
	TextColor3 = Color3.fromRGB(70, 30, 130),
	Parent = emblemePaquet,
})
texte({
	Position = UDim2.fromScale(0.08, 0.7),
	Size = UDim2.fromScale(0.84, 0.09),
	Text = "BOOSTER",
	Font = Style.POLICE_TITRE,
	TextColor3 = C.blanc,
	Contour = Color3.fromRGB(40, 15, 80),
	ContourEpaisseur = 2.5,
	Parent = paquet,
})
texte({
	Position = UDim2.fromScale(0.1, 0.8),
	Size = UDim2.fromScale(0.8, 0.05),
	Text = "5 CARTES WIKIPÉDIA",
	Font = Enum.Font.GothamBold,
	TextColor3 = C.orClair,
	Parent = paquet,
})
-- bande des raretés
for i, id in ipairs(Style.ORDRE) do
	new("Frame", {
		Position = UDim2.fromScale(0.1 + (i - 1) * 0.16, 0.875),
		Size = UDim2.fromScale(0.15, 0.025),
		BackgroundColor3 = Style.rarete(id).couleur,
		BorderSizePixel = 0,
		Parent = paquet,
	}, { Style.coins(4) })
end

-- le paquet flotte doucement
TweenService:Create(paquet, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
	Position = UDim2.fromScale(0.5, 0.46),
}):Play()

local function remettrePaquet()
	socle.Visible = true
	paquet.Rotation = 0
	echellePaquet.Scale = 0.7
	tween(echellePaquet, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

local secousse = false
local function secouerPaquet()
	secousse = true
	task.spawn(function()
		local force = 4
		while secousse do
			tween(paquet, 0.05, { Rotation = force })
			task.wait(0.05)
			tween(paquet, 0.05, { Rotation = -force })
			task.wait(0.05)
			force = math.min(force + 0.6, 10)
		end
		tween(paquet, 0.1, { Rotation = 0 })
	end)
end

local flash = new("Frame", {
	Name = "Flash",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	ZIndex = 50,
	Parent = F.fenetre,
}, { Style.coins(22) })
local function faireFlash(couleur, force)
	flash.BackgroundColor3 = couleur or Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1 - (force or 0.7)
	tween(flash, 0.5, { BackgroundTransparency = 1 })
end

local function dechirerPaquet()
	secousse = false
	faireFlash(Color3.new(1, 1, 1), 0.8)
	tween(paquet, 0.3, { Rotation = 12 })
	local t = tween(echellePaquet, 0.3, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	t.Completed:Wait()
	socle.Visible = false
end

------------------------------------------------------------------
-- Cartes
------------------------------------------------------------------
local annonce = texte({
	Name = "Annonce",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.12),
	Size = UDim2.fromScale(0.7, 0.2),
	Text = "",
	Font = Style.POLICE_TITRE,
	TextColor3 = C.orClair,
	Contour = C.orFonce,
	ContourEpaisseur = 4,
	Visible = false,
	ZIndex = 40,
	Parent = scene,
})
local echelleAnnonce = new("UIScale", { Parent = annonce })

local function annoncer(message, couleur)
	annonce.Text = message
	annonce.TextColor3 = Style.eclaircir(couleur, 0.4)
	annonce:FindFirstChildOfClass("UIStroke").Color = Style.assombrir(couleur, 0.4)
	annonce.TextTransparency = 0
	annonce.Visible = true
	echelleAnnonce.Scale = 0.2
	tween(echelleAnnonce, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(1.6, function()
		tween(annonce, 0.4, { TextTransparency = 1 })
		task.wait(0.45)
		annonce.Visible = false
	end)
end

local function creerCarte(carte, index)
	local r = Style.rarete(carte.rarity)
	local emplacement = new("Frame", {
		Name = "Carte" .. index,
		LayoutOrder = index,
		Size = UDim2.fromScale(0.17, 0.92),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = zoneCartes,
	}, { new("UIAspectRatioConstraint", { AspectRatio = 0.7 }) })
	local echelle = new("UIScale", { Scale = 0, Parent = emplacement })

	-- « face » se rétrécit puis s'élargit pour l'effet de retournement
	local face = new("Frame", {
		Name = "Face",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = emplacement,
	})
	local dos = Style.dos(face)
	local mention = carte.is_new and "NOUVELLE !" or ("x" .. tostring(carte.copies_owned or 1))
	local recto = Style.carte(face, carte, { mention = mention, nouvelle = carte.is_new == true })
	recto.Visible = false

	return { emplacement = emplacement, echelle = echelle, face = face, dos = dos, recto = recto, rarete = carte.rarity, r = r }
end

local function distribuer(cartes)
	for i, c in ipairs(cartes) do
		c.emplacement.Rotation = (i - (#cartes + 1) / 2) * 6
		tween(c.echelle, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(c.emplacement, 0.4, { Rotation = 0 }, Enum.EasingStyle.Back)
		task.wait(0.08)
	end
	task.wait(0.3)
end

local function retourner(c, duree)
	local t1 = tween(c.face, duree / 2, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	t1.Completed:Wait()
	c.dos.Visible = false
	c.recto.Visible = true
	local t2 = tween(c.face, duree / 2, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Back)
	t2.Completed:Wait()
end

local function celebrer(c)
	local id = c.rarete
	if id == "rare" or id == "epic" or id == "legendary" then
		Style.halo(c.emplacement, c.r.couleur, id == "rare" and 6 or 10)
		c.echelle.Scale = 1.15
		tween(c.echelle, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	if id == "epic" then
		faireFlash(c.r.couleur, 0.35)
		annoncer("ÉPIQUE !", c.r.couleur)
	elseif id == "legendary" then
		-- rayons derrière la carte (dans la scène, sous les cartes)
		local rayons = Style.rayons(scene, c.r.clair, 12, 520)
		local centre = c.emplacement.AbsolutePosition + c.emplacement.AbsoluteSize / 2 - scene.AbsolutePosition
		rayons.Position = UDim2.fromOffset(centre.X, centre.Y)
		rayons.ZIndex = 1
		faireFlash(c.r.clair, 0.75)
		annoncer("★ LÉGENDAIRE ! ★", c.r.couleur)
	end
end

local function viderCartes()
	for _, enfant in ipairs(zoneCartes:GetChildren()) do
		if enfant:IsA("GuiObject") then enfant:Destroy() end
	end
	for _, enfant in ipairs(scene:GetChildren()) do
		if enfant.Name == "Rayons" then enfant:Destroy() end
	end
end

------------------------------------------------------------------
-- Ouverture
------------------------------------------------------------------
local occupe = false
local dejaOuvert = false

local function afficherStatut(message, couleur)
	statut.Text = message
	statut.TextColor3 = couleur or C.blanc
end

local function ouvrirBooster()
	if occupe then return end
	occupe = true
	Style.activerBouton(boutonOuvrir, false)
	texteOuvrir.Text = "…"
	if dejaOuvert then
		viderCartes()
		remettrePaquet()
		task.wait(0.35)
	end
	afficherStatut("Ouverture du booster…", C.parcheminFonce)
	secouerPaquet()

	local ok, resultat = pcall(function()
		return ouvrirRemote:InvokeServer(TYPE_BOOSTER)
	end)

	if not ok or type(resultat) ~= "table" or not resultat.success then
		secousse = false
		local message = (ok and type(resultat) == "table" and resultat.error) or "Ouverture impossible, réessaie plus tard"
		afficherStatut(message, C.rouge)
	else
		local booster = resultat.booster
		dechirerPaquet()
		afficherStatut("")
		local cartes = {}
		for i, carte in ipairs(booster.cards or {}) do
			cartes[i] = creerCarte(carte, i)
		end
		distribuer(cartes)

		for i, c in ipairs(cartes) do
			local derniere = (i == #cartes)
			task.wait(derniere and 0.6 or 0.15)
			if derniere then
				-- petit suspense sur la dernière carte
				tween(c.echelle, 0.5, { Scale = 1.12 }, Enum.EasingStyle.Sine)
				task.wait(0.5)
				tween(c.echelle, 0.2, { Scale = 1 })
			end
			retourner(c, derniere and 0.6 or 0.36)
			celebrer(c)
		end

		local meilleure = Style.rarete(booster.best_rarity)
		local nouvelles = booster.new_cards or 0
		local resume = ("Meilleure carte : <font color=\"%s\">%s</font>"):format(hex(meilleure.couleur), meilleure.nom)
		if nouvelles > 0 then
			resume ..= ("  ·  <font color=\"%s\">%d nouvelle%s !</font>"):format(hex(C.orClair), nouvelles, nouvelles > 1 and "s" or "")
		end
		afficherStatut(resume)
		dejaOuvert = true
	end

	texteOuvrir.Text = dejaOuvert and "OUVRIR ENCORE" or "OUVRIR"
	Style.activerBouton(boutonOuvrir, true)
	occupe = false
end

------------------------------------------------------------------
-- Probabilités (barres colorées)
------------------------------------------------------------------
local panneauProba = new("Frame", {
	Name = "PanneauProba",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.72, 0.86),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Visible = false,
	ZIndex = 30,
	Parent = F.fenetre,
}, {
	Style.coins(18),
	Style.degrade(C.nuitClair, C.nuitFonce),
	Style.contour(C.or_, 3),
})
local echelleProba = new("UIScale", { Parent = panneauProba })
texte({
	Position = UDim2.fromScale(0.06, 0.04),
	Size = UDim2.fromScale(0.7, 0.1),
	Text = "Probabilités",
	Font = Style.POLICE_TITRE,
	TextColor3 = C.orClair,
	Contour = C.nuitFonce,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 31,
	Parent = panneauProba,
})
local fermerProba = Style.bouton(panneauProba, {
	nom = "FermerProba",
	texte = "X",
	couleur = C.rouge,
	ancre = Vector2.new(1, 0),
	position = UDim2.new(1, -16, 0, 14),
	taille = UDim2.fromOffset(44, 40),
	tailleTexte = 22,
	police = Enum.Font.GothamBlack,
})
fermerProba.Parent.ZIndex = 31
local listeProba = new("ScrollingFrame", {
	Position = UDim2.fromScale(0.06, 0.17),
	Size = UDim2.fromScale(0.88, 0.79),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = C.or_,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 31,
	Parent = panneauProba,
}, { new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }) })

local function ligneTexte(ordre, contenuTexte, couleur, taille, police)
	return texte({
		LayoutOrder = ordre,
		Size = UDim2.new(1, -10, 0, taille or 24),
		Text = contenuTexte,
		TextScaled = false,
		TextSize = taille or 18,
		Font = police or Enum.Font.GothamMedium,
		TextColor3 = couleur or C.blanc,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 32,
		Parent = listeProba,
	})
end

local function remplirProba(booster)
	for _, enfant in ipairs(listeProba:GetChildren()) do
		if enfant:IsA("GuiObject") then enfant:Destroy() end
	end
	local ordre = 0
	local function suivant() ordre += 1 return ordre end
	if booster.description then
		local d = ligneTexte(suivant(), booster.description, C.parcheminFonce, 16)
		d.TextWrapped = true
		d.AutomaticSize = Enum.AutomaticSize.Y
	end
	for _, slot in ipairs(booster.slots or {}) do
		ligneTexte(suivant(), slot.label or ("%d carte(s)"):format(slot.count or 1), C.orClair, 20, Style.POLICE_TITRE)
		for _, id in ipairs(Style.ORDRE) do
			local pourcent = slot.odds_percent and tonumber(slot.odds_percent[id])
			if pourcent then
				local r = Style.rarete(id)
				local ligne = new("Frame", {
					LayoutOrder = suivant(),
					Size = UDim2.new(1, -10, 0, 28),
					BackgroundTransparency = 1,
					ZIndex = 32,
					Parent = listeProba,
				})
				texte({
					Size = UDim2.fromScale(0.3, 1),
					Text = string.rep("★", r.etoiles) .. " " .. r.nom,
					Font = Style.POLICE_TITRE,
					TextColor3 = r.couleur,
					TextXAlignment = Enum.TextXAlignment.Left,
					TailleMax = 17,
					ZIndex = 32,
					Parent = ligne,
				})
				local fondBarre = new("Frame", {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0.32, 0.5),
					Size = UDim2.fromScale(0.5, 0.55),
					BackgroundColor3 = C.nuitFonce,
					ZIndex = 32,
					Parent = ligne,
				}, { Style.coins(UDim.new(1, 0)) })
				local barre = new("Frame", {
					Size = UDim2.fromScale(0, 1),
					BackgroundColor3 = Color3.new(1, 1, 1),
					ZIndex = 33,
					Parent = fondBarre,
				}, { Style.coins(UDim.new(1, 0)), Style.degrade(r.clair, r.couleur, 0) })
				tween(barre, 0.6, { Size = UDim2.fromScale(math.clamp(pourcent / 100, 0.02, 1), 1) })
				texte({
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromScale(0.16, 1),
					Text = tostring(pourcent) .. " %",
					Font = Style.POLICE_TITRE,
					TextColor3 = C.blanc,
					TextXAlignment = Enum.TextXAlignment.Right,
					TailleMax = 18,
					ZIndex = 32,
					Parent = ligne,
				})
			end
		end
	end
end

local probaChargees = false
local function afficherProba()
	panneauProba.Visible = true
	echelleProba.Scale = 0.7
	tween(echelleProba, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	if probaChargees then return end
	for _, enfant in ipairs(listeProba:GetChildren()) do
		if enfant:IsA("GuiObject") then enfant:Destroy() end
	end
	ligneTexte(1, "Chargement…")
	local ok, resultat = pcall(function()
		return probaRemote:InvokeServer()
	end)
	if ok and type(resultat) == "table" and resultat.success and resultat.boosters and resultat.boosters[TYPE_BOOSTER] then
		local booster = resultat.boosters[TYPE_BOOSTER]
		if booster.name then F.titre.Text = string.upper(booster.name) end
		remplirProba(booster)
		probaChargees = true
	else
		for _, enfant in ipairs(listeProba:GetChildren()) do
			if enfant:IsA("GuiObject") then enfant:Destroy() end
		end
		ligneTexte(1, "Probabilités indisponibles pour le moment.", C.rouge)
	end
end

------------------------------------------------------------------
-- Ouvrir / fermer l'écran
------------------------------------------------------------------
local function ouvrirEcran()
	if F.fond.Visible then return end
	HUD.afficher(false)
	panneauProba.Visible = false
	if not occupe then
		viderCartes()
		remettrePaquet()
		dejaOuvert = false
		texteOuvrir.Text = "OUVRIR"
		afficherStatut("Clique sur OUVRIR pour déchirer le paquet !", C.parcheminFonce)
	end
	Style.ouvrir(F)
end

local function fermerEcran(apres)
	Style.fermer(F, function()
		HUD.afficher(true)
		if apres then apres() end
	end)
end

HUD.ajouterBouton({
	id = "Booster",
	icone = "booster",
	texte = "BOOSTER",
	couleur = C.or_,
	ordre = 1,
	raccourci = Enum.KeyCode.B,
	pulse = true,
}, ouvrirEcran)

F.fermer.Activated:Connect(function()
	fermerEcran()
end)
boutonOuvrir.Activated:Connect(function()
	if boutonOuvrir.Active then task.spawn(ouvrirBooster) end
end)
boutonProba.Activated:Connect(function()
	task.spawn(afficherProba)
end)
fermerProba.Activated:Connect(function()
	panneauProba.Visible = false
end)
boutonCollection.Activated:Connect(function()
	if occupe then return end
	fermerEcran(function()
		HUD.declencher("Collection")
	end)
end)

-- Interaction avec le booster géant au centre du lobby (ou le socle s'il n'y en a pas).
-- L'invite est créée côté client : elle n'est visible que pour ce joueur.
task.spawn(function()
	local lobby = workspace:WaitForChild("WikiBloxLobby", 30)
	if not lobby then return end
	local booster = lobby:WaitForChild("BoosterGeant", 10)
	local support = (booster and booster:WaitForChild("Paquet", 10)) or lobby:FindFirstChild("SocleOrbe")
	if not support then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PromptBooster"
	prompt.ActionText = "Ouvrir un booster"
	prompt.ObjectText = "Booster WikiBlox"
	prompt.MaxActivationDistance = 20
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0.2
	prompt.Parent = support
	prompt.Triggered:Connect(ouvrirEcran)
end)
