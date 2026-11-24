-- WikiBlox : écran de collection (inventaire du joueur)
--
-- Utilise ReplicatedStorage.WikiBloxRemotes.MaCollection (créé par src/server/WikiBloxBoosters.server.luau) :
--   MaCollection:InvokeServer() -> { success, collection } (collection = nil si aucun booster ouvert)
--   collection = {
--     summary = { unique_cards, total_copies, by_rarity = { [rareté] = { unique, copies } } },
--     cards   = { { product_id, title, description, rarity, copies, total_views, page_url, ... } },
--   }
--
-- Le joueur ouvre l'écran avec le bouton "Collection" (à gauche de l'écran, sous "Booster").
-- Style commun : src/shared/WikiBloxStyle.luau

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("WikiBloxRemotes")
local collectionRemote = remotes:WaitForChild("MaCollection")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Style = require(Shared:WaitForChild("WikiBloxStyle"))
local HUD = require(Shared:WaitForChild("WikiBloxHUD"))

local C = Style.C
local new, tween, texte = Style.new, Style.tween, Style.texte

-- Filtres affichés, de la plus rare à la moins rare (comme le tri de l'API)
local FILTRES = { "legendary", "epic", "rare", "uncommon", "common" }

local function formaterNombre(n)
	local s = tostring(math.floor(tonumber(n) or 0))
	local avecEspaces = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1 ")))
	return (string.gsub(avecEspaces, "^ ", ""))
end

local function pluriel(n, singulier, plurielTexte)
	return ("%s %s"):format(formaterNombre(n), n > 1 and plurielTexte or singulier)
end

------------------------------------------------------------------
-- Fenêtre
------------------------------------------------------------------
local gui = new("ScreenGui", {
	Name = "WikiBloxCollectionUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 2, -- au-dessus de l'écran de booster
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local F = Style.fenetre(gui, {
	titre = "MA COLLECTION",
	taille = UDim2.fromScale(0.92, 0.86),
	max = Vector2.new(1000, 660),
})
local contenu = F.contenu

-- En-tête : résumé + barre de progression par rareté, recherche à droite
local resume = texte({
	Name = "Resume",
	Position = UDim2.fromScale(0, 0.03),
	Size = UDim2.fromScale(0.56, 0.055),
	Text = "",
	Font = Style.POLICE_TITRE,
	TextColor3 = C.blanc,
	Contour = C.nuitFonce,
	TextXAlignment = Enum.TextXAlignment.Left,
	TailleMax = 24,
	Parent = contenu,
})
local barreProgression = new("Frame", {
	Name = "Progression",
	Position = UDim2.fromScale(0, 0.1),
	Size = UDim2.fromScale(0.56, 0.035),
	BackgroundColor3 = C.nuitFonce,
	ClipsDescendants = true,
	Parent = contenu,
}, {
	Style.coins(UDim.new(1, 0)),
	Style.contour(C.orFonce, 1.5, 0.3),
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder }),
})

local cadreRecherche = new("Frame", {
	Name = "Recherche",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0.03),
	Size = UDim2.fromScale(0.36, 0.1),
	BackgroundColor3 = C.parchemin,
	Parent = contenu,
}, {
	Style.coins(UDim.new(1, 0)),
	Style.contour(C.orFonce, 2.5),
	new("UISizeConstraint", { MaxSize = Vector2.new(340, 50) }),
})
Style.icone(new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 14, 0.5, 0),
	Size = UDim2.fromScale(0.56, 0.56),
	SizeConstraint = Enum.SizeConstraint.RelativeYY,
	BackgroundTransparency = 1,
	Parent = cadreRecherche,
}), "loupe", { contour = C.orFonce })
local recherche = new("TextBox", {
	Position = UDim2.new(0, 44, 0.18, 0),
	Size = UDim2.new(1, -60, 0.64, 0),
	BackgroundTransparency = 1,
	PlaceholderText = "Rechercher une carte…",
	PlaceholderColor3 = Color3.fromRGB(150, 130, 100),
	Text = "",
	ClearTextOnFocus = false,
	Font = Enum.Font.GothamMedium,
	TextColor3 = C.encre,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = cadreRecherche,
}, { new("UITextSizeConstraint", { MaxTextSize = 20 }) })

-- Onglets « marque-pages » par rareté
local barreFiltres = new("Frame", {
	Name = "Filtres",
	Position = UDim2.fromScale(0, 0.175),
	Size = UDim2.fromScale(1, 0.075),
	BackgroundTransparency = 1,
	Parent = contenu,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}),
})

-- Grille des cartes
local grille = new("ScrollingFrame", {
	Name = "Grille",
	Position = UDim2.fromScale(0, 0.28),
	Size = UDim2.fromScale(1, 0.72),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 7,
	ScrollBarImageColor3 = C.or_,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = contenu,
}, {
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(126, 180),
		CellPadding = UDim2.fromOffset(14, 16),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
	new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }),
})

-- Message / état vide
local vide = new("Frame", {
	Name = "Vide",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.62),
	Size = UDim2.fromScale(0.7, 0.4),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = contenu,
})
local videIcone = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.fromScale(0.34, 0.34),
	SizeConstraint = Enum.SizeConstraint.RelativeYY,
	BackgroundTransparency = 1,
	Parent = vide,
})
local videTexte = texte({
	Position = UDim2.fromScale(0, 0.38),
	Size = UDim2.fromScale(1, 0.25),
	Text = "",
	Font = Style.POLICE_TITRE,
	TextColor3 = C.blanc,
	Contour = C.nuitFonce,
	TailleMax = 26,
	Parent = vide,
})
local boutonPremierBooster = Style.bouton(vide, {
	nom = "PremierBooster",
	texte = "Ouvrir un booster",
	icone = "booster",
	couleur = C.or_,
	ancre = Vector2.new(0.5, 0),
	position = UDim2.fromScale(0.5, 0.7),
	taille = UDim2.fromScale(0.5, 0.26),
	max = Vector2.new(280, 58),
	tailleTexte = 24,
})

local function afficherVide(icone, message, couleur, avecBouton)
	videIcone:ClearAllChildren()
	Style.icone(videIcone, icone, { contour = C.nuitFonce, epaisseur = 3 })
	videTexte.Text = message
	videTexte.TextColor3 = couleur or C.blanc
	boutonPremierBooster.Parent.Visible = avecBouton == true
	vide.Visible = true
end

------------------------------------------------------------------
-- Détail d'une carte
------------------------------------------------------------------
local detail = new("Frame", {
	Name = "Detail",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Active = true, -- bloque les clics vers la grille en dessous
	Visible = false,
	ZIndex = 20,
	Parent = F.fenetre,
}, { Style.coins(22), Style.degrade(C.nuitClair, C.nuitFonce) })
local echelleDetail = new("UIScale", { Parent = detail })

local boutonRetour = Style.bouton(detail, {
	nom = "Retour",
	texte = "← Retour",
	couleur = C.nuitClair,
	position = UDim2.fromOffset(22, 22),
	taille = UDim2.fromOffset(140, 46),
	tailleTexte = 22,
})
boutonRetour.Parent.ZIndex = 21

local zoneGrandeCarte = new("Frame", {
	Name = "ZoneCarte",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.25, 0.55),
	Size = UDim2.fromScale(0.4, 0.74),
	BackgroundTransparency = 1,
	ZIndex = 21,
	Parent = detail,
}, { new("UIAspectRatioConstraint", { AspectRatio = 0.7 }) })

local parchemin = new("Frame", {
	Name = "Infos",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -26, 0.55, 0),
	Size = UDim2.fromScale(0.5, 0.78),
	BackgroundColor3 = Color3.new(1, 1, 1),
	ZIndex = 24, -- au-dessus des rayons de la grande carte
	Parent = detail,
}, {
	Style.coins(16),
	Style.degrade(C.parchemin, C.parcheminFonce),
	Style.contour(C.orFonce, 3),
	new("UIPadding", {
		PaddingTop = UDim.new(0, 20), PaddingBottom = UDim.new(0, 16),
		PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 22),
	}),
})
local infos = new("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = C.orFonce,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 22,
	Parent = parchemin,
}, { new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12) }) })

local detailTitre = texte({
	LayoutOrder = 1,
	Size = UDim2.new(1, -8, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	TextScaled = false,
	TextSize = 30,
	Text = "",
	Font = Style.POLICE_LIVRE,
	TextColor3 = C.encre,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 23,
	Parent = infos,
})
local pastilleRarete = new("Frame", {
	LayoutOrder = 2,
	Size = UDim2.fromOffset(200, 30),
	BackgroundColor3 = Color3.new(1, 1, 1),
	ZIndex = 23,
	Parent = infos,
}, { Style.coins(UDim.new(1, 0)) })
local degradePastille = Style.degrade(C.or_, C.orFonce)
degradePastille.Parent = pastilleRarete
local textePastille = texte({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.9, 0.7),
	Text = "",
	Font = Style.POLICE_TITRE,
	TextColor3 = C.blanc,
	Contour = C.encre,
	ContourEpaisseur = 1.5,
	ZIndex = 24,
	Parent = pastilleRarete,
})
-- séparateur doré
new("Frame", {
	LayoutOrder = 3,
	Size = UDim2.new(1, -8, 0, 2),
	BackgroundColor3 = C.orFonce,
	BackgroundTransparency = 0.4,
	BorderSizePixel = 0,
	ZIndex = 23,
	Parent = infos,
})
local detailDescription = texte({
	LayoutOrder = 4,
	Size = UDim2.new(1, -8, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	TextScaled = false,
	TextSize = 18,
	Text = "",
	Font = Enum.Font.Gotham,
	TextColor3 = C.encre,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 23,
	Parent = infos,
})
local rangeeStats = new("Frame", {
	LayoutOrder = 5,
	Size = UDim2.new(1, -8, 0, 54),
	BackgroundTransparency = 1,
	ZIndex = 23,
	Parent = infos,
}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })

local function creerStat(ordre, libelle)
	local cadre = new("Frame", {
		LayoutOrder = ordre,
		Size = UDim2.new(0.5, -5, 1, 0),
		BackgroundColor3 = C.encre,
		BackgroundTransparency = 0.88,
		ZIndex = 23,
		Parent = rangeeStats,
	}, { Style.coins(12), Style.contour(C.orFonce, 1.5, 0.3) })
	texte({
		Position = UDim2.fromScale(0.06, 0.1),
		Size = UDim2.fromScale(0.88, 0.38),
		Text = libelle,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(120, 95, 60),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 24,
		Parent = cadre,
	})
	return texte({
		Position = UDim2.fromScale(0.06, 0.45),
		Size = UDim2.fromScale(0.88, 0.48),
		Text = "",
		Font = Style.POLICE_TITRE,
		TextColor3 = C.encre,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 24,
		Parent = cadre,
	})
end
local statExemplaires = creerStat(1, "EXEMPLAIRES")
local statVues = creerStat(2, "VUES WIKIPÉDIA")

-- Lien Wikipédia : Roblox ne peut pas ouvrir de lien externe, on l'affiche pour qu'il puisse être copié
local cadreLien = new("Frame", {
	LayoutOrder = 6,
	Size = UDim2.new(1, -8, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = C.nuit,
	BackgroundTransparency = 0.1,
	ZIndex = 23,
	Parent = infos,
}, {
	Style.coins(10),
	new("UIPadding", {
		PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
	}),
})
local detailLien = new("TextBox", {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	TextEditable = false,
	ClearTextOnFocus = false,
	TextWrapped = true,
	TextSize = 15,
	Font = Enum.Font.GothamMedium,
	TextColor3 = Color3.fromRGB(150, 200, 255),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
	ZIndex = 24,
	Parent = cadreLien,
})

local function afficherDetail(carte)
	local r = Style.rarete(carte.rarity)
	zoneGrandeCarte:ClearAllChildren()
	new("UIAspectRatioConstraint", { AspectRatio = 0.7, Parent = zoneGrandeCarte })
	Style.halo(zoneGrandeCarte, r.couleur, carte.rarity == "legendary" and 14 or 9)
	if carte.rarity == "legendary" then
		Style.rayons(zoneGrandeCarte, r.clair, 12, 520)
	end
	local cadre = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 22,
		Parent = zoneGrandeCarte,
	})
	Style.carte(cadre, carte, { mention = "x" .. formaterNombre(carte.copies or 1) })

	detailTitre.Text = carte.title or "?"
	textePastille.Text = string.rep("★", r.etoiles) .. "  " .. r.nom
	degradePastille.Color = ColorSequence.new(Style.eclaircir(r.couleur, 0.2), r.couleur)
	textePastille:FindFirstChildOfClass("UIStroke").Color = Style.assombrir(r.couleur, 0.55)
	detailDescription.Text = (carte.description and carte.description ~= "") and carte.description or "Pas de description."
	statExemplaires.Text = formaterNombre(carte.copies or 1)
	statVues.Text = formaterNombre(carte.total_views or 0)
	detailLien.Text = carte.page_url and carte.page_url or ""
	cadreLien.Visible = carte.page_url ~= nil
	infos.CanvasPosition = Vector2.zero

	detail.Visible = true
	echelleDetail.Scale = 0.85
	tween(echelleDetail, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

boutonRetour.Activated:Connect(function()
	detail.Visible = false
end)

------------------------------------------------------------------
-- Données et affichage de la grille
------------------------------------------------------------------
local collection = nil   -- dernière collection reçue (nil = aucune carte)
local filtre = nil       -- rareté sélectionnée (nil = toutes)
local texteRecherche = ""
local boutonsFiltres = {}

local function cartesFiltrees()
	local liste = {}
	if not collection then return liste end
	for _, carte in ipairs(collection.cards or {}) do
		local okRarete = (filtre == nil) or (carte.rarity == filtre)
		local okRecherche = texteRecherche == ""
			or string.find(string.lower(carte.title or ""), texteRecherche, 1, true) ~= nil
		if okRarete and okRecherche then
			table.insert(liste, carte)
		end
	end
	return liste
end

local function viderGrille()
	for _, enfant in ipairs(grille:GetChildren()) do
		if enfant:IsA("GuiObject") then enfant:Destroy() end
	end
end

local function rafraichirGrille()
	viderGrille()
	local liste = cartesFiltrees()
	if #liste == 0 then
		if not collection or #(collection.cards or {}) == 0 then
			afficherVide("collection", "Ta collection est vide.\nOuvre ton premier booster !", C.blanc, true)
		else
			afficherVide("loupe", "Aucune carte ne correspond.", C.parcheminFonce, false)
		end
		return
	end
	vide.Visible = false

	for i, carte in ipairs(liste) do
		local case = new("TextButton", {
			Name = "Carte",
			LayoutOrder = i,
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Parent = grille,
		})
		local echelle = new("UIScale", { Parent = case })
		Style.carte(case, carte, { mention = "x" .. formaterNombre(carte.copies or 1) })
		case.MouseEnter:Connect(function()
			tween(echelle, 0.15, { Scale = 1.07 }, Enum.EasingStyle.Back)
			tween(case, 0.15, { Rotation = 2 })
		end)
		case.MouseLeave:Connect(function()
			tween(echelle, 0.15, { Scale = 1 })
			tween(case, 0.15, { Rotation = 0 })
		end)
		case.Activated:Connect(function()
			afficherDetail(carte)
		end)
		-- apparition en cascade (seulement les premières, pour rester fluide)
		if i <= 24 then
			echelle.Scale = 0.5
			task.delay(i * 0.025, function()
				tween(echelle, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			end)
		end
	end
	grille.CanvasPosition = Vector2.zero
end

local function majProgression()
	barreProgression:ClearAllChildren()
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = barreProgression })
	new("UIStroke", { Color = C.orFonce, Thickness = 1.5, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = barreProgression })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Parent = barreProgression })
	local s = collection and collection.summary
	local total = s and s.unique_cards or 0
	if total <= 0 then return end
	for i, id in ipairs(Style.ORDRE) do
		local n = s.by_rarity and s.by_rarity[id] and s.by_rarity[id].unique or 0
		if n > 0 then
			local segment = new("Frame", {
				LayoutOrder = i,
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				Parent = barreProgression,
			}, { Style.degrade(Style.rarete(id).clair, Style.rarete(id).couleur) })
			tween(segment, 0.6, { Size = UDim2.fromScale(n / total, 1) })
		end
	end
end

local function majFiltres()
	local parRarete = collection and collection.summary and collection.summary.by_rarity or {}
	for id, b in pairs(boutonsFiltres) do
		local selectionne = (id == "toutes" and filtre == nil) or id == filtre
		local nombre
		if id == "toutes" then
			nombre = collection and collection.summary and collection.summary.unique_cards or 0
		else
			nombre = parRarete[id] and parRarete[id].unique or 0
		end
		local r = id ~= "toutes" and Style.rarete(id) or nil
		local couleur = r and r.couleur or C.or_
		b.label.Text = (r and r.nom or "TOUTES") .. "  " .. tostring(nombre)
		b.bouton.BackgroundColor3 = selectionne and couleur or C.nuitFonce
		b.label.TextColor3 = selectionne and C.blanc or couleur
		b.labelContour.Enabled = selectionne
		b.labelContour.Color = Style.assombrir(couleur, 0.55)
		b.contour.Color = couleur
		b.contour.Thickness = selectionne and 3 or 1.5
		tween(b.echelle, 0.2, { Scale = selectionne and 1.06 or 1 }, Enum.EasingStyle.Back)
	end
end

local function creerFiltre(id, ordre)
	local bouton = new("TextButton", {
		Name = "Filtre_" .. id,
		LayoutOrder = ordre,
		Size = UDim2.new(1 / 6, -7, 1, 0),
		BackgroundColor3 = C.nuitFonce,
		AutoButtonColor = false,
		Text = "",
		Parent = barreFiltres,
	}, { Style.coins(UDim.new(1, 0)) })
	local contour = Style.contour(C.or_, 1.5)
	contour.Parent = bouton
	local label = texte({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -14, 0.6, 0),
		Text = "",
		Font = Style.POLICE_TITRE,
		TailleMax = 17,
		Contour = C.nuitFonce,
		ContourEpaisseur = 1.5,
		Parent = bouton,
	})
	local echelle = new("UIScale", { Parent = bouton })
	bouton.Activated:Connect(function()
		filtre = (id ~= "toutes") and id or nil
		majFiltres()
		rafraichirGrille()
	end)
	boutonsFiltres[id] = {
		bouton = bouton,
		label = label,
		labelContour = label:FindFirstChildOfClass("UIStroke"),
		contour = contour,
		echelle = echelle,
	}
end

creerFiltre("toutes", 0)
for i, id in ipairs(FILTRES) do
	creerFiltre(id, i)
end

recherche:GetPropertyChangedSignal("Text"):Connect(function()
	texteRecherche = string.lower(recherche.Text)
	rafraichirGrille()
end)

------------------------------------------------------------------
-- Chargement depuis le serveur
------------------------------------------------------------------
local enChargement = false


local function chargerCollection()
	if enChargement then return end
	enChargement = true
	viderGrille()
	afficherVide("chargement", "Chargement de ta collection…", C.parcheminFonce, false)

	local erreur = nil
	for _ = 1, 3 do
		local ok, resultat = pcall(function()
			return collectionRemote:InvokeServer()
		end)
		if ok and type(resultat) == "table" and resultat.success then
			collection = resultat.collection
			erreur = nil
			break
		end
		erreur = (ok and type(resultat) == "table" and resultat.error) or "Collection indisponible"
		if erreur ~= "Patiente un instant" then break end
		task.wait(3) -- le serveur limite à un appel toutes les 3 secondes (ex. juste après un booster)
	end

	enChargement = false
	if erreur then
		afficherVide("alerte", erreur .. ", réessaie plus tard.", C.rouge, false)
		return
	end

	local s = collection and collection.summary
	if s then
		resume.Text = ("%s · %s"):format(
			pluriel(s.unique_cards or 0, "carte unique", "cartes uniques"),
			pluriel(s.total_copies or 0, "exemplaire", "exemplaires"))
	else
		resume.Text = "0 carte"
	end
	majProgression()
	majFiltres()
	rafraichirGrille()
end

------------------------------------------------------------------
-- Ouvrir / fermer
------------------------------------------------------------------
local function ouvrirEcran()
	if F.fond.Visible then return end
	HUD.afficher(false)
	detail.Visible = false
	Style.ouvrir(F)
	task.spawn(chargerCollection) -- toujours à jour (nouvelles cartes après un booster)
end

local function fermerEcran(apres)
	Style.fermer(F, function()
		HUD.afficher(true)
		if apres then apres() end
	end)
end

HUD.ajouterBouton({
	id = "Collection",
	icone = "collection",
	texte = "COLLECTION",
	couleur = C.bleu,
	ordre = 2,
	raccourci = Enum.KeyCode.C,
}, ouvrirEcran)
F.fermer.Activated:Connect(function()
	fermerEcran()
end)
boutonPremierBooster.Activated:Connect(function()
	fermerEcran(function()
		HUD.declencher("Booster")
	end)
end)
majFiltres()
