-- WikiBlox : écran d'ouverture de booster (côté joueur)
--
-- Utilise ReplicatedStorage.WikiBloxRemotes, créé par src/server/WikiBloxBoosters.server.luau :
--   OuvrirBooster:InvokeServer("standard") -> { success, booster } ou { success = false, error }
--   ProbaBoosters:InvokeServer()           -> { success, boosters }
--
-- Le joueur ouvre l'écran avec le bouton "Booster" (à gauche de l'écran)
-- ou en s'approchant du booster géant au centre du lobby (touche E).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("WikiBloxRemotes")
local ouvrirRemote = remotes:WaitForChild("OuvrirBooster")
local probaRemote = remotes:WaitForChild("ProbaBoosters")

local TYPE_BOOSTER = "standard"

------------------------------------------------------------------
-- Style
------------------------------------------------------------------
local RARETES = {
	common    = { nom = "COMMUNE",     couleur = Color3.fromRGB(175, 175, 185) },
	uncommon  = { nom = "PEU COMMUNE", couleur = Color3.fromRGB(80, 200, 120) },
	rare      = { nom = "RARE",        couleur = Color3.fromRGB(60, 140, 255) },
	epic      = { nom = "ÉPIQUE",      couleur = Color3.fromRGB(170, 80, 255) },
	legendary = { nom = "LÉGENDAIRE",  couleur = Color3.fromRGB(255, 190, 40) },
}
local ORDRE_RARETES = { "common", "uncommon", "rare", "epic", "legendary" }

local NAVY = Color3.fromRGB(28, 34, 56)
local NAVY_CLAIR = Color3.fromRGB(44, 52, 82)
local GOLD = Color3.fromRGB(235, 188, 80)
local BLANC = Color3.fromRGB(245, 242, 235)
local ROUGE = Color3.fromRGB(255, 110, 110)

local function infoRarete(id)
	return RARETES[id] or RARETES.common
end

local function hex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

local function new(class, props, enfants)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then inst[k] = v end
	end
	for _, enfant in ipairs(enfants or {}) do
		enfant.Parent = inst
	end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end

local function coins(rayon)
	return new("UICorner", { CornerRadius = UDim.new(0, rayon or 12) })
end

local function texte(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or BLANC
	props.TextScaled = props.TextScaled ~= false
	props.TextWrapped = true
	return new("TextLabel", props)
end

local function bouton(props, couleur, couleurTexte)
	props.BackgroundColor3 = couleur
	props.AutoButtonColor = true
	props.Font = props.Font or Enum.Font.GothamBlack
	props.TextColor3 = couleurTexte or NAVY
	props.TextScaled = true
	return new("TextButton", props, { coins(12), new("UIPadding", {
		PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0),
		PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
	}) })
end

------------------------------------------------------------------
-- Interface
------------------------------------------------------------------
local gui = new("ScreenGui", {
	Name = "WikiBloxBoosterUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Bouton du HUD : voir src/shared/WikiBloxHUD (ajouté plus bas, une fois ouvrirEcran défini)
local HUD = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WikiBloxHUD"))

-- Fond assombri + fenêtre
local fond = new("Frame", {
	Name = "Fond",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.35,
	Visible = false,
	Parent = gui,
})

local fenetre = new("Frame", {
	Name = "Fenetre",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.92, 0.82),
	BackgroundColor3 = NAVY,
	Parent = fond,
}, {
	coins(18),
	new("UIStroke", { Thickness = 3, Color = GOLD }),
	new("UISizeConstraint", { MaxSize = Vector2.new(960, 600) }),
})

local titre = texte({
	Name = "Titre",
	Position = UDim2.fromScale(0.05, 0.03),
	Size = UDim2.fromScale(0.9, 0.1),
	Text = "Booster Standard",
	TextColor3 = GOLD,
	Font = Enum.Font.GothamBlack,
	Parent = fenetre,
})

local sousTitre = texte({
	Name = "SousTitre",
	Position = UDim2.fromScale(0.05, 0.13),
	Size = UDim2.fromScale(0.9, 0.06),
	Text = "5 cartes Wikipédia · la dernière est au minimum rare",
	Font = Enum.Font.Gotham,
	Parent = fenetre,
})

local boutonFermer = bouton({
	Name = "Fermer",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(44, 44),
	Text = "✕",
	Parent = fenetre,
}, NAVY_CLAIR, BLANC)

-- Zone des cartes
local zoneCartes = new("Frame", {
	Name = "Cartes",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.22),
	Size = UDim2.fromScale(0.94, 0.5),
	BackgroundTransparency = 1,
	Parent = fenetre,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0.015, 0),
	}),
})

local statut = texte({
	Name = "Statut",
	Position = UDim2.fromScale(0.05, 0.74),
	Size = UDim2.fromScale(0.9, 0.07),
	Text = "",
	Parent = fenetre,
})

local boutonOuvrir = bouton({
	Name = "Ouvrir",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.84),
	Size = UDim2.fromScale(0.34, 0.12),
	Text = "OUVRIR",
	Parent = fenetre,
}, GOLD)
new("UISizeConstraint", { MaxSize = Vector2.new(280, 70), Parent = boutonOuvrir })

local boutonProba = bouton({
	Name = "Probabilites",
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.fromScale(0.03, 0.86),
	Size = UDim2.fromScale(0.2, 0.08),
	Text = "Probabilités",
	Font = Enum.Font.GothamBold,
	Parent = fenetre,
}, NAVY_CLAIR, BLANC)
new("UISizeConstraint", { MaxSize = Vector2.new(180, 46), Parent = boutonProba })

-- Panneau des probabilités (par-dessus la fenêtre)
local panneauProba = new("Frame", {
	Name = "PanneauProba",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.8, 0.8),
	BackgroundColor3 = NAVY_CLAIR,
	Visible = false,
	ZIndex = 10,
	Parent = fenetre,
}, { coins(14), new("UIStroke", { Thickness = 2, Color = GOLD }) })

texte({
	Position = UDim2.fromScale(0.05, 0.03),
	Size = UDim2.fromScale(0.75, 0.12),
	Text = "Probabilités",
	TextColor3 = GOLD,
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 11,
	Parent = panneauProba,
})

local fermerProba = bouton({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(40, 40),
	Text = "✕",
	ZIndex = 11,
	Parent = panneauProba,
}, NAVY, BLANC)

local listeProba = new("ScrollingFrame", {
	Position = UDim2.fromScale(0.05, 0.18),
	Size = UDim2.fromScale(0.9, 0.78),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 11,
	Parent = panneauProba,
})

local texteProba = new("TextLabel", {
	Size = UDim2.new(1, -10, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	RichText = true,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Font = Enum.Font.Gotham,
	TextSize = 18,
	TextColor3 = BLANC,
	Text = "Chargement…",
	ZIndex = 11,
	Parent = listeProba,
})

------------------------------------------------------------------
-- Cartes
------------------------------------------------------------------
local function creerCarte(carte, index)
	local r = infoRarete(carte.rarity)

	local cadre = new("Frame", {
		Name = "Carte" .. index,
		LayoutOrder = index,
		Size = UDim2.fromScale(0.18, 1),
		BackgroundTransparency = 1,
		Parent = zoneCartes,
	}, { new("UIAspectRatioConstraint", { AspectRatio = 0.68 }) })

	-- "face" se rétrécit puis s'élargit pour l'effet de retournement
	local face = new("Frame", {
		Name = "Face",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = cadre,
	})

	-- Dos de la carte
	local dos = new("Frame", {
		Name = "Dos",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = NAVY_CLAIR,
		Parent = face,
	}, { coins(10), new("UIStroke", { Thickness = 3, Color = GOLD }) })
	texte({ Size = UDim2.fromScale(1, 1), Text = "?", TextColor3 = GOLD, Font = Enum.Font.GothamBlack, Parent = dos })

	-- Recto
	local recto = new("Frame", {
		Name = "Recto",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLANC,
		Visible = false,
		Parent = face,
	}, { coins(10) })
	local contour = new("UIStroke", { Thickness = 4, Color = r.couleur, Parent = recto })

	local bandeau = new("Frame", {
		Size = UDim2.fromScale(1, 0.14),
		BackgroundColor3 = r.couleur,
		Parent = recto,
	}, { coins(10) })
	texte({
		Size = UDim2.fromScale(1, 1),
		Text = r.nom,
		TextColor3 = NAVY,
		Font = Enum.Font.GothamBlack,
		Parent = bandeau,
	}, nil)

	-- Visuel : initiale du titre (Roblox ne peut pas afficher les images Wikipédia)
	local medaillon = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.18),
		Size = UDim2.fromScale(0.52, 0.52),
		BackgroundColor3 = r.couleur,
		Parent = recto,
	}, { new("UIAspectRatioConstraint", { AspectRatio = 1 }), new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local titreCarte = (type(carte.title) == "string" and carte.title ~= "") and carte.title or "?"
	local okInitiale, code = pcall(utf8.codepoint, titreCarte, 1)
	local initiale = okInitiale and string.upper(utf8.char(code)) or "?"
	texte({ Size = UDim2.fromScale(1, 1), Text = initiale, TextColor3 = BLANC, Font = Enum.Font.GothamBlack, Parent = medaillon })

	texte({
		Position = UDim2.fromScale(0.06, 0.6),
		Size = UDim2.fromScale(0.88, 0.17),
		Text = carte.title or "?",
		TextColor3 = NAVY,
		Font = Enum.Font.Merriweather,
		Parent = recto,
	})

	local mention = carte.is_new and "NOUVELLE !" or ("x" .. tostring(carte.copies_owned or 1))
	texte({
		Position = UDim2.fromScale(0.06, 0.8),
		Size = UDim2.fromScale(0.88, 0.12),
		Text = mention,
		TextColor3 = carte.is_new and Color3.fromRGB(210, 140, 20) or Color3.fromRGB(110, 110, 125),
		Font = Enum.Font.GothamBlack,
		Parent = recto,
	})

	return { face = face, dos = dos, recto = recto, contour = contour, rarete = carte.rarity }
end

local function retourner(c, duree)
	local demi = TweenInfo.new(duree / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local t1 = TweenService:Create(c.face, demi, { Size = UDim2.fromScale(0, 1) })
	t1:Play()
	t1.Completed:Wait()
	c.dos.Visible = false
	c.recto.Visible = true
	local t2 = TweenService:Create(c.face, TweenInfo.new(duree / 2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(1, 1),
	})
	t2:Play()
	t2.Completed:Wait()
end

local function briller(c)
	-- Effet pour les cartes épiques et légendaires
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true)
	TweenService:Create(c.contour, info, { Thickness = 10 }):Play()
end

local function viderCartes()
	for _, enfant in ipairs(zoneCartes:GetChildren()) do
		if enfant:IsA("Frame") then enfant:Destroy() end
	end
end

------------------------------------------------------------------
-- Ouverture
------------------------------------------------------------------
local occupe = false

local function afficherStatut(message, couleur)
	statut.Text = message
	statut.TextColor3 = couleur or BLANC
end

local function ouvrirBooster()
	if occupe then return end
	occupe = true
	boutonOuvrir.Active = false
	boutonOuvrir.AutoButtonColor = false
	boutonOuvrir.BackgroundColor3 = Color3.fromRGB(120, 110, 90)
	boutonOuvrir.Text = "…"
	viderCartes()
	afficherStatut("Ouverture du booster…")

	local ok, resultat = pcall(function()
		return ouvrirRemote:InvokeServer(TYPE_BOOSTER)
	end)

	if not ok or type(resultat) ~= "table" or not resultat.success then
		local message = (ok and type(resultat) == "table" and resultat.error) or "Ouverture impossible, réessaie plus tard"
		afficherStatut(message, ROUGE)
	else
		local booster = resultat.booster
		local cartes = {}
		for i, carte in ipairs(booster.cards or {}) do
			cartes[i] = creerCarte(carte, i)
		end
		afficherStatut("")

		for i, c in ipairs(cartes) do
			local derniere = (i == #cartes)
			task.wait(derniere and 0.8 or 0.3)
			retourner(c, derniere and 0.7 or 0.4)
			if c.rarete == "epic" or c.rarete == "legendary" then
				briller(c)
			end
		end

		local meilleure = infoRarete(booster.best_rarity)
		local nouvelles = booster.new_cards or 0
		local resume = ("Meilleure carte : <font color=\"%s\">%s</font>"):format(hex(meilleure.couleur), meilleure.nom)
		if nouvelles > 0 then
			resume ..= ("  ·  %d nouvelle%s carte%s !"):format(nouvelles, nouvelles > 1 and "s" or "", nouvelles > 1 and "s" or "")
		end
		statut.RichText = true
		afficherStatut(resume)
	end

	boutonOuvrir.Text = "OUVRIR"
	boutonOuvrir.BackgroundColor3 = GOLD
	boutonOuvrir.AutoButtonColor = true
	boutonOuvrir.Active = true
	occupe = false
end

------------------------------------------------------------------
-- Probabilités
------------------------------------------------------------------
local probaChargees = false

local function formaterProba(booster)
	local lignes = {}
	if booster.description then
		table.insert(lignes, booster.description)
		table.insert(lignes, "")
	end
	for _, slot in ipairs(booster.slots or {}) do
		table.insert(lignes, ("<b>%s</b>"):format(slot.label or ("%d carte(s)"):format(slot.count or 1)))
		for _, id in ipairs(ORDRE_RARETES) do
			local pourcent = slot.odds_percent and slot.odds_percent[id]
			if pourcent then
				local r = infoRarete(id)
				table.insert(lignes, ("   <font color=\"%s\"><b>%s</b></font> : %s %%"):format(hex(r.couleur), r.nom, tostring(pourcent)))
			end
		end
		table.insert(lignes, "")
	end
	return table.concat(lignes, "\n")
end

local function afficherProba()
	panneauProba.Visible = true
	if probaChargees then return end
	texteProba.Text = "Chargement…"
	local ok, resultat = pcall(function()
		return probaRemote:InvokeServer()
	end)
	if ok and type(resultat) == "table" and resultat.success and resultat.boosters and resultat.boosters[TYPE_BOOSTER] then
		local booster = resultat.boosters[TYPE_BOOSTER]
		if booster.name then titre.Text = booster.name end
		texteProba.Text = formaterProba(booster)
		probaChargees = true
	else
		texteProba.Text = "Probabilités indisponibles pour le moment."
	end
end

------------------------------------------------------------------
-- Ouvrir / fermer l'écran
------------------------------------------------------------------
local function ouvrirEcran()
	fond.Visible = true
	HUD.afficher(false)
	panneauProba.Visible = false
	if not occupe then
		viderCartes()
		statut.RichText = false
		afficherStatut("")
	end
end

local function fermerEcran()
	fond.Visible = false
	HUD.afficher(true)
end

HUD.ajouterBouton({
	id = "Booster",
	icone = "📦",
	texte = "BOOSTER",
	couleur = GOLD,
	ordre = 1,
	raccourci = Enum.KeyCode.B,
	pulse = true,
}, ouvrirEcran)
boutonFermer.Activated:Connect(fermerEcran)
boutonOuvrir.Activated:Connect(function()
	task.spawn(ouvrirBooster)
end)
boutonProba.Activated:Connect(function()
	task.spawn(afficherProba)
end)
fermerProba.Activated:Connect(function()
	panneauProba.Visible = false
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
