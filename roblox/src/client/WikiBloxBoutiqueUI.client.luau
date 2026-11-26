-- WikiBlox : écran Boutique (bouton « Boutique » dans la barre de gauche, touche V)
--
-- Pour l'instant aucune monnaie n'existe dans le jeu : les offres sont affichées avec
-- le bouton « BIENTÔT » grisé. Quand l'économie sera prête, il suffira de :
--   1. mettre disponible = true sur l'offre,
--   2. brancher acheter(offre) sur un RemoteFunction serveur (jamais de prix vérifié côté client),
--   3. pour une offre en Robux : MarketplaceService:PromptProductPurchase / PromptGamePassPurchase.
--
-- Style commun : src/shared/WikiBloxStyle.luau — règles : roblox/DA.md

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Style = require(Shared:WaitForChild("WikiBloxStyle"))
local HUD = require(Shared:WaitForChild("WikiBloxHUD"))

local C = Style.C
local new, tween, texte = Style.new, Style.tween, Style.texte

------------------------------------------------------------------
-- Offres (à modifier ici)
------------------------------------------------------------------
-- monnaie : "pieces" (monnaie du jeu) ou "robux"
-- couleur : or = boosters, violet = premium (voir DA.md)
local OFFRES = {
	{
		id = "Booster1",
		titre = "1 BOOSTER",
		description = "5 cartes Wikipédia au hasard.",
		icone = "booster",
		couleur = C.or_,
		prix = 100,
		monnaie = "pieces",
		disponible = false,
	},
	{
		id = "Booster5",
		titre = "5 BOOSTERS",
		description = "25 cartes, plus de chances d'en avoir une rare.",
		icone = "booster",
		quantite = "x5",
		couleur = C.or_,
		prix = 450,
		monnaie = "pieces",
		etiquette = "-10 %",
		disponible = false,
	},
	{
		id = "Booster10",
		titre = "10 BOOSTERS",
		description = "50 cartes et une carte épique garantie.",
		icone = "booster",
		quantite = "x10",
		couleur = C.or_,
		prix = 800,
		monnaie = "pieces",
		etiquette = "MEILLEUR PRIX",
		disponible = false,
	},
	{
		id = "PassVIP",
		titre = "PASS VIP",
		description = "Boosters 2 fois plus rapides et un titre doré.",
		icone = "couronne",
		couleur = C.violet,
		prix = 199,
		monnaie = "robux",
		etiquette = "PREMIUM",
		disponible = false,
	},
}

local function formaterNombre(n)
	local s = tostring(math.floor(tonumber(n) or 0))
	local avecEspaces = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1 ")))
	return (string.gsub(avecEspaces, "^ ", ""))
end

------------------------------------------------------------------
-- Fenêtre
------------------------------------------------------------------
local gui = new("ScreenGui", {
	Name = "WikiBloxBoutiqueUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 2,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local F = Style.fenetre(gui, {
	titre = "BOUTIQUE",
	taille = UDim2.fromScale(0.92, 0.82),
	max = Vector2.new(1000, 600),
})
local contenu = F.contenu

-- Bandeau d'annonce en parchemin
local annonce = new("Frame", {
	Name = "Annonce",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.new(1, -20, 0, 44),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Parent = contenu,
}, {
	Style.coins(UDim.new(1, 0)),
	Style.degrade(C.parchemin, C.parcheminFonce),
	Style.contour(C.orFonce, 2.5),
})
local iconeAnnonce = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.5, 0),
	Size = UDim2.fromScale(0.8, 0.8),
	SizeConstraint = Enum.SizeConstraint.RelativeYY,
	BackgroundTransparency = 1,
	ZIndex = 2,
	Parent = annonce,
})
Style.icone(iconeAnnonce, "piece", { contour = C.orFonce, epaisseur = 2 })
texte({
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 56, 0.5, 0),
	Size = UDim2.new(1, -70, 0.56, 0),
	Text = "Les achats arrivent bientôt : gagne des pièces en jouant pour débloquer des boosters !",
	Font = Style.POLICE,
	TextColor3 = C.encre,
	TextXAlignment = Enum.TextXAlignment.Left,
	TailleMax = 18,
	ZIndex = 2,
	Parent = annonce,
})

-- Rangée d'offres (défile horizontalement sur petit écran)
local rangee = new("ScrollingFrame", {
	Name = "Offres",
	Position = UDim2.fromOffset(0, 60),
	Size = UDim2.new(1, 0, 1, -64),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollingDirection = Enum.ScrollingDirection.X,
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	CanvasSize = UDim2.new(),
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = C.or_,
	ElasticBehavior = Enum.ElasticBehavior.Never,
	Parent = contenu,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 18),
	}),
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 26),
		PaddingBottom = UDim.new(0, 12),
	}),
})

local cartesOffres = {} -- { echelle } pour l'animation d'apparition

local function acheter(offre)
	-- Pas encore d'économie : rien à faire (le bouton est grisé).
	-- Plus tard : remotes.Acheter:InvokeServer(offre.id)
end

local function creerOffre(offre, ordre)
	local accent = offre.couleur
	local fonce = Style.assombrir(accent, 0.55)

	local emplacement = new("Frame", {
		Name = offre.id,
		LayoutOrder = ordre,
		ZIndex = 20 - ordre, -- l'étiquette d'une offre passe devant l'offre suivante
		Size = UDim2.new(0, 205, 1, -40), -- hauteur de la rangée moins les marges
		BackgroundTransparency = 1,
		Parent = rangee,
	}, { new("UISizeConstraint", { MaxSize = Vector2.new(205, 400) }) })
	local echelle = new("UIScale", { Parent = emplacement })

	local carte = new("Frame", {
		Name = "Carte",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = emplacement,
	}, {
		Style.coins(18),
		Style.degrade(C.parchemin, C.parcheminFonce),
		Style.contour(accent, 4),
	})
	-- filet intérieur
	new("Frame", {
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(1, -10, 1, -10),
		BackgroundTransparency = 1,
		Parent = carte,
	}, { Style.coins(14), Style.contour(accent, 1.2, 0.45) })

	-- bandeau-titre coloré
	local bandeau = new("Frame", {
		Name = "Bandeau",
		Size = UDim2.fromScale(1, 0.14),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Parent = carte,
	}, { Style.coins(18), Style.degrade(Style.eclaircir(accent, 0.25), accent) })
	-- coins du bas du bandeau bien droits
	new("Frame", {
		Position = UDim2.fromScale(0, 0.6),
		Size = UDim2.fromScale(1, 0.4),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = bandeau,
	})
	texte({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(1, -20, 0.62, 0),
		Text = offre.titre,
		Font = Style.POLICE_TITRE,
		TextColor3 = C.blanc,
		Contour = fonce,
		ContourEpaisseur = 2.5,
		TailleMax = 26,
		ZIndex = 3,
		Parent = bandeau,
	})

	-- vitrine : halo + icône dessinée qui flotte
	local vitrine = new("Frame", {
		Name = "Vitrine",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.17),
		Size = UDim2.new(1, -24, 0.36, 0),
		BackgroundColor3 = C.nuit,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = carte,
	}, {
		Style.coins(14),
		Style.degrade(C.nuitClair, C.nuitFonce),
		Style.contour(Style.assombrir(accent, 0.3), 2),
	})
	Style.rayons(vitrine, accent, 8, 300)
	local socle = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = vitrine,
	})
	local icone = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = socle,
	})
	Style.icone(icone, offre.icone, { contour = Style.assombrir(accent, 0.6), epaisseur = 2.5 })
	-- flotte doucement (décalé selon l'offre)
	task.delay(ordre * 0.25, function()
		game:GetService("TweenService"):Create(icone,
			TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = UDim2.fromScale(0.5, 0.42), Rotation = 6 }):Play()
	end)
	if offre.quantite then
		texte({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -8, 1, -4),
			Size = UDim2.fromOffset(64, 36),
			Text = offre.quantite,
			Font = Style.POLICE_TITRE,
			TextColor3 = C.orClair,
			Contour = C.nuitFonce,
			ContourEpaisseur = 3,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 6,
			Parent = vitrine,
		})
	end

	-- description
	texte({
		Name = "Description",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.new(1, -24, 0.12, 0),
		Text = offre.description,
		Font = Style.POLICE_LIVRE,
		TextColor3 = C.encre,
		TailleMax = 15,
		ZIndex = 2,
		Parent = carte,
	})

	-- prix : pièce dessinée (ou pastille R$) + montant
	local prix = new("Frame", {
		Name = "Prix",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.685),
		Size = UDim2.new(1, -40, 0.1, 0),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = carte,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local symbole = new("Frame", {
		LayoutOrder = 1,
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = prix,
	})
	if offre.monnaie == "robux" then
		local pastille = new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 3,
			Parent = symbole,
		}, {
			Style.coins(8),
			Style.degrade(Color3.fromRGB(110, 215, 130), Color3.fromRGB(40, 150, 75)),
			Style.contour(Color3.fromRGB(25, 90, 45), 2),
		})
		texte({
			Size = UDim2.fromScale(1, 1),
			Text = "R$",
			Font = Style.POLICE_TITRE,
			TextColor3 = C.blanc,
			ZIndex = 4,
			Parent = pastille,
		})
	else
		Style.icone(symbole, "piece", { contour = C.orFonce, epaisseur = 2 })
	end
	texte({
		LayoutOrder = 2,
		Size = UDim2.fromScale(0.5, 1),
		Text = formaterNombre(offre.prix),
		Font = Style.POLICE_TITRE,
		TextColor3 = C.encre,
		TextXAlignment = Enum.TextXAlignment.Left,
		TailleMax = 28,
		ZIndex = 3,
		Parent = prix,
	})

	-- bouton d'achat (vert = acheter, violet = Robux) ; grisé « BIENTÔT » tant que pas disponible
	local couleurBouton = offre.monnaie == "robux" and C.violet or C.vert
	local bouton, labelBouton = Style.bouton(carte, {
		nom = "Acheter",
		texte = offre.disponible and "ACHETER" or "BIENTÔT",
		couleur = couleurBouton,
		ancre = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 0.97, -5),
		taille = UDim2.new(1, -32, 0.14, 0),
		tailleTexte = 24,
	})
	Style.activerBouton(bouton, offre.disponible == true)
	bouton.Activated:Connect(function()
		if bouton.Active then acheter(offre) end
	end)

	-- étiquette en biais (promo / premium)
	if offre.etiquette then
		local premium = offre.monnaie == "robux"
		local hautEtiquette = premium and Color3.fromRGB(200, 160, 255) or Color3.fromRGB(255, 120, 115)
		local basEtiquette = premium and C.violet or C.rouge
		local etiquette = new("Frame", {
			Name = "Etiquette",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 8, 0, -8),
			Size = UDim2.fromOffset(0, 28),
			AutomaticSize = Enum.AutomaticSize.X,
			Rotation = 10,
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 8,
			Parent = emplacement,
		}, {
			Style.coins(UDim.new(1, 0)),
			Style.degrade(hautEtiquette, basEtiquette),
			Style.contour(C.blanc, 2.5),
			new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
		})
		texte({
			Size = UDim2.fromOffset(0, 28),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = offre.etiquette,
			Font = Style.POLICE_TITRE,
			TextScaled = false,
			TextWrapped = false,
			TextSize = 17,
			TextColor3 = C.blanc,
			Contour = Style.assombrir(basEtiquette, 0.55),
			ZIndex = 9,
			Parent = etiquette,
		})
		-- petit balancement pour attirer l'œil
		game:GetService("TweenService"):Create(etiquette,
			TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Rotation = 4 }):Play()
	end

	-- survol : la carte grossit un peu
	local zone = new("TextButton", {
		Name = "Survol",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 1,
		Parent = carte,
	})
	zone.MouseEnter:Connect(function()
		tween(echelle, 0.15, { Scale = 1.04 }, Enum.EasingStyle.Back)
	end)
	zone.MouseLeave:Connect(function()
		tween(echelle, 0.15, { Scale = 1 })
	end)
	bouton.MouseEnter:Connect(function()
		tween(echelle, 0.15, { Scale = 1.04 }, Enum.EasingStyle.Back)
	end)

	table.insert(cartesOffres, echelle)
	return emplacement
end

for i, offre in ipairs(OFFRES) do
	creerOffre(offre, i)
end

------------------------------------------------------------------
-- Ouvrir / fermer
------------------------------------------------------------------
local function ouvrirEcran()
	if F.fond.Visible then return end
	HUD.afficher(false)
	Style.ouvrir(F)
	-- les offres apparaissent en cascade
	for i, echelle in ipairs(cartesOffres) do
		echelle.Scale = 0
		task.delay(0.12 + i * 0.07, function()
			tween(echelle, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end
end

local function fermerEcran()
	Style.fermer(F, function()
		HUD.afficher(true)
	end)
end

HUD.ajouterBouton({
	id = "Boutique",
	icone = "boutique",
	texte = "BOUTIQUE",
	couleur = C.vert,
	ordre = 3,
	raccourci = Enum.KeyCode.V,
}, ouvrirEcran)
F.fermer.Activated:Connect(fermerEcran)
