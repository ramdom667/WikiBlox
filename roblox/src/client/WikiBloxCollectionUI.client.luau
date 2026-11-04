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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("WikiBloxRemotes")
local collectionRemote = remotes:WaitForChild("MaCollection")

------------------------------------------------------------------
-- Style (identique à l'écran de booster)
------------------------------------------------------------------
local RARETES = {
	common    = { nom = "COMMUNE",     couleur = Color3.fromRGB(175, 175, 185) },
	uncommon  = { nom = "PEU COMMUNE", couleur = Color3.fromRGB(80, 200, 120) },
	rare      = { nom = "RARE",        couleur = Color3.fromRGB(60, 140, 255) },
	epic      = { nom = "ÉPIQUE",      couleur = Color3.fromRGB(170, 80, 255) },
	legendary = { nom = "LÉGENDAIRE",  couleur = Color3.fromRGB(255, 190, 40) },
}
-- Filtres affichés, de la plus rare à la moins rare (comme le tri de l'API)
local FILTRES = { "legendary", "epic", "rare", "uncommon", "common" }

local NAVY = Color3.fromRGB(28, 34, 56)
local NAVY_CLAIR = Color3.fromRGB(44, 52, 82)
local GOLD = Color3.fromRGB(235, 188, 80)
local BLANC = Color3.fromRGB(245, 242, 235)
local GRIS = Color3.fromRGB(110, 110, 125)
local ROUGE = Color3.fromRGB(255, 110, 110)

local function infoRarete(id)
	return RARETES[id] or RARETES.common
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
	if props.TextScaled == nil then props.TextScaled = true end
	props.TextWrapped = true
	return new("TextLabel", props)
end

local function bouton(props, couleur, couleurTexte)
	props.BackgroundColor3 = couleur
	props.AutoButtonColor = true
	props.Font = props.Font or Enum.Font.GothamBlack
	props.TextColor3 = couleurTexte or NAVY
	props.TextScaled = true
	return new("TextButton", props, { coins(10), new("UIPadding", {
		PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0),
		PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
	}) })
end

local function initialeDe(titre)
	titre = (type(titre) == "string" and titre ~= "") and titre or "?"
	local ok, code = pcall(utf8.codepoint, titre, 1)
	return ok and string.upper(utf8.char(code)) or "?"
end

local function formaterNombre(n)
	local s = tostring(math.floor(tonumber(n) or 0))
	local avecEspaces = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1 ")))
	return (string.gsub(avecEspaces, "^ ", ""))
end

local function pluriel(n, singulier, plurielTexte)
	return ("%s %s"):format(formaterNombre(n), n > 1 and plurielTexte or singulier)
end

------------------------------------------------------------------
-- Interface
------------------------------------------------------------------
local gui = new("ScreenGui", {
	Name = "WikiBloxCollectionUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 2, -- au-dessus de l'écran de booster
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Bouton permanent, sous le bouton "Booster"
local boutonHud = bouton({
	Name = "BoutonCollection",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.5, 64),
	Size = UDim2.fromOffset(150, 52),
	Text = "📚 Collection",
	Parent = gui,
}, GOLD)
new("UIStroke", { Thickness = 2, Color = NAVY, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = boutonHud })

local fond = new("Frame", {
	Name = "Fond",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.35,
	Active = true, -- bloque les clics vers ce qu'il y a derrière
	Visible = false,
	Parent = gui,
})

local fenetre = new("Frame", {
	Name = "Fenetre",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.92, 0.86),
	BackgroundColor3 = NAVY,
	Parent = fond,
}, {
	coins(18),
	new("UIStroke", { Thickness = 3, Color = GOLD }),
	new("UISizeConstraint", { MaxSize = Vector2.new(1000, 680) }),
})

texte({
	Name = "Titre",
	Position = UDim2.fromScale(0.04, 0.03),
	Size = UDim2.fromScale(0.5, 0.08),
	Text = "Ma collection",
	TextColor3 = GOLD,
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = fenetre,
})

local resume = texte({
	Name = "Resume",
	Position = UDim2.fromScale(0.04, 0.115),
	Size = UDim2.fromScale(0.5, 0.05),
	Text = "",
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = fenetre,
})

local recherche = new("TextBox", {
	Name = "Recherche",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(0.96, 0, 0.11, 0),
	Size = UDim2.fromScale(0.34, 0.06),
	BackgroundColor3 = NAVY_CLAIR,
	PlaceholderText = "🔍 Rechercher une carte…",
	PlaceholderColor3 = Color3.fromRGB(150, 155, 175),
	Text = "",
	ClearTextOnFocus = false,
	Font = Enum.Font.Gotham,
	TextColor3 = BLANC,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = fenetre,
}, { coins(8), new("UIPadding", {
	PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
	PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0),
}) })

local boutonFermer = bouton({
	Name = "Fermer",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(44, 44),
	Text = "✕",
	Parent = fenetre,
}, NAVY_CLAIR, BLANC)

-- Barre de filtres par rareté
local barreFiltres = new("Frame", {
	Name = "Filtres",
	Position = UDim2.fromScale(0.04, 0.19),
	Size = UDim2.fromScale(0.92, 0.065),
	BackgroundTransparency = 1,
	Parent = fenetre,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}),
})

-- Grille des cartes
local grille = new("ScrollingFrame", {
	Name = "Grille",
	Position = UDim2.fromScale(0.04, 0.28),
	Size = UDim2.fromScale(0.92, 0.69),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = fenetre,
}, {
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(124, 176),
		CellPadding = UDim2.fromOffset(12, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }),
})

local message = texte({
	Name = "Message",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.6),
	Size = UDim2.fromScale(0.8, 0.08),
	Text = "",
	Font = Enum.Font.Gotham,
	Parent = fenetre,
})

------------------------------------------------------------------
-- Visuel d'une carte (utilisé dans la grille et dans le détail)
------------------------------------------------------------------
local function dessinerCarte(conteneur, carte)
	local r = infoRarete(carte.rarity)

	local bandeau = new("Frame", {
		Size = UDim2.fromScale(1, 0.14),
		BackgroundColor3 = r.couleur,
		Parent = conteneur,
	}, { coins(10) })
	texte({ Size = UDim2.fromScale(1, 1), Text = r.nom, TextColor3 = NAVY, Font = Enum.Font.GothamBlack, Parent = bandeau })

	local medaillon = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.19),
		Size = UDim2.fromScale(0.56, 0.56),
		BackgroundColor3 = r.couleur,
		Parent = conteneur,
	}, { new("UIAspectRatioConstraint", { AspectRatio = 1 }), new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	texte({ Size = UDim2.fromScale(1, 1), Text = initialeDe(carte.title), Font = Enum.Font.GothamBlack, Parent = medaillon })

	texte({
		Position = UDim2.fromScale(0.06, 0.62),
		Size = UDim2.fromScale(0.88, 0.2),
		Text = carte.title or "?",
		TextColor3 = NAVY,
		Font = Enum.Font.Merriweather,
		Parent = conteneur,
	})
	texte({
		Position = UDim2.fromScale(0.06, 0.84),
		Size = UDim2.fromScale(0.88, 0.11),
		Text = "x" .. formaterNombre(carte.copies or 1),
		TextColor3 = GRIS,
		Font = Enum.Font.GothamBlack,
		Parent = conteneur,
	})
end

------------------------------------------------------------------
-- Détail d'une carte
------------------------------------------------------------------
local detail = new("Frame", {
	Name = "Detail",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = NAVY,
	Active = true, -- bloque les clics vers la grille en dessous
	Visible = false,
	ZIndex = 20,
	Parent = fenetre,
}, { coins(18) })

local boutonRetour = bouton({
	Name = "Retour",
	Position = UDim2.new(0, 14, 0, 12),
	Size = UDim2.fromOffset(130, 42),
	Text = "← Retour",
	Font = Enum.Font.GothamBold,
	Parent = detail,
}, NAVY_CLAIR, BLANC)

local grandeCarte = new("Frame", {
	Name = "Carte",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromScale(0.05, 0.55),
	Size = UDim2.fromScale(0.3, 0.75),
	BackgroundColor3 = BLANC,
	Parent = detail,
}, { coins(14), new("UIAspectRatioConstraint", { AspectRatio = 0.68 }) })
local contourGrandeCarte = new("UIStroke", { Thickness = 5, Parent = grandeCarte })

local infos = new("Frame", {
	Name = "Infos",
	Position = UDim2.fromScale(0.4, 0.15),
	Size = UDim2.fromScale(0.55, 0.8),
	BackgroundTransparency = 1,
	Parent = detail,
}, {
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
})

local detailTitre = texte({
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0.16, 0),
	Text = "",
	TextColor3 = GOLD,
	Font = Enum.Font.Merriweather,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = infos,
})
local detailRarete = texte({
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0.07, 0),
	Text = "",
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = infos,
})
local detailDescription = texte({
	LayoutOrder = 3,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	TextScaled = false,
	TextSize = 18,
	Text = "",
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Parent = infos,
})
local detailStats = texte({
	LayoutOrder = 4,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	TextScaled = false,
	TextSize = 18,
	RichText = true,
	Text = "",
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Parent = infos,
})
-- Lien Wikipédia : Roblox ne peut pas ouvrir de lien externe, on l'affiche pour qu'il puisse être copié
local detailLien = new("TextBox", {
	LayoutOrder = 5,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	TextEditable = false,
	ClearTextOnFocus = false,
	TextWrapped = true,
	TextSize = 15,
	Font = Enum.Font.Gotham,
	TextColor3 = Color3.fromRGB(140, 190, 255),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
	Parent = infos,
})

local function afficherDetail(carte)
	local r = infoRarete(carte.rarity)
	for _, enfant in ipairs(grandeCarte:GetChildren()) do
		if not enfant:IsA("UICorner") and not enfant:IsA("UIAspectRatioConstraint") and not enfant:IsA("UIStroke") then
			enfant:Destroy()
		end
	end
	dessinerCarte(grandeCarte, carte)
	contourGrandeCarte.Color = r.couleur

	detailTitre.Text = carte.title or "?"
	detailRarete.Text = r.nom
	detailRarete.TextColor3 = r.couleur
	detailDescription.Text = (carte.description and carte.description ~= "") and carte.description or "Pas de description."
	detailStats.Text = ("<b>Exemplaires :</b> %s\n<b>Vues Wikipédia :</b> %s"):format(
		formaterNombre(carte.copies or 1), formaterNombre(carte.total_views or 0))
	detailLien.Text = carte.page_url or ""
	detailLien.Visible = carte.page_url ~= nil
	detail.Visible = true
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

local function rafraichirGrille()
	for _, enfant in ipairs(grille:GetChildren()) do
		if enfant:IsA("GuiObject") then enfant:Destroy() end
	end

	local liste = cartesFiltrees()
	if #liste == 0 then
		if not collection or #(collection.cards or {}) == 0 then
			message.Text = "Tu n'as encore aucune carte.\nOuvre ton premier booster !"
		else
			message.Text = "Aucune carte ne correspond."
		end
		message.TextColor3 = BLANC
		message.Visible = true
		return
	end
	message.Visible = false

	for i, carte in ipairs(liste) do
		local r = infoRarete(carte.rarity)
		local case = new("TextButton", {
			Name = "Carte",
			LayoutOrder = i,
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = BLANC,
			Parent = grille,
		}, { coins(10), new("UIStroke", { Thickness = 3, Color = r.couleur, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
		dessinerCarte(case, carte)
		case.Activated:Connect(function()
			afficherDetail(carte)
		end)
	end
	grille.CanvasPosition = Vector2.zero
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
		local nom = id == "toutes" and "TOUTES" or infoRarete(id).nom
		b.Text = ("%s (%d)"):format(nom, nombre)
		local couleur = id == "toutes" and GOLD or infoRarete(id).couleur
		b.BackgroundColor3 = selectionne and couleur or NAVY_CLAIR
		b.TextColor3 = selectionne and NAVY or couleur
	end
end

local function creerFiltre(id, ordre)
	local b = bouton({
		Name = "Filtre_" .. id,
		LayoutOrder = ordre,
		Size = UDim2.new(1 / 6, -7, 1, 0),
		Text = "",
		Font = Enum.Font.GothamBold,
		Parent = barreFiltres,
	}, NAVY_CLAIR, BLANC)
	b.Activated:Connect(function()
		filtre = (id ~= "toutes") and id or nil
		majFiltres()
		rafraichirGrille()
	end)
	boutonsFiltres[id] = b
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
	message.Text = "Chargement de ta collection…"
	message.TextColor3 = BLANC
	message.Visible = true
	for _, enfant in ipairs(grille:GetChildren()) do
		if enfant:IsA("GuiObject") then enfant:Destroy() end
	end

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
		message.Text = erreur .. ", réessaie plus tard."
		message.TextColor3 = ROUGE
		message.Visible = true
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
	majFiltres()
	rafraichirGrille()
end

------------------------------------------------------------------
-- Ouvrir / fermer
------------------------------------------------------------------
-- Cache le bouton de l'autre écran pendant que celui-ci est ouvert
local function afficherAutreBouton(visible)
	local autre = player.PlayerGui:FindFirstChild("WikiBloxBoosterUI")
	local b = autre and autre:FindFirstChild("BoutonBooster")
	if b then b.Visible = visible end
end

local function ouvrirEcran()
	fond.Visible = true
	boutonHud.Visible = false
	afficherAutreBouton(false)
	detail.Visible = false
	task.spawn(chargerCollection) -- toujours à jour (nouvelles cartes après un booster)
end

local function fermerEcran()
	fond.Visible = false
	boutonHud.Visible = true
	afficherAutreBouton(true)
end

boutonHud.Activated:Connect(ouvrirEcran)
boutonFermer.Activated:Connect(fermerEcran)
majFiltres()
