-- WikiBlox : mini-jeu de pêche (côté joueur), façon Stardew Valley
--
-- Une barre verticale : le poisson monte et descend, le joueur maintient un bouton pour faire
-- monter son curseur (il retombe quand on relâche). Tant que le poisson est dans le curseur,
-- la jauge de prise se remplit ; sinon elle se vide. Jauge pleine = prise, jauge vide = perdu.
--
--   local MiniJeu = require(ReplicatedStorage.Shared.WikiBloxPecheMiniJeu)
--   local partie = MiniJeu.nouveau(screenGui, reglages, function(reussi) … end)
--   partie.appuye = true / false   -- mis à jour par le script qui gère les touches
--   partie:arreter()               -- arrêt sans résultat (canne rangée…)
--
-- reglages = WikiBloxPecheConfig.reglagesJeu(prise, mods) : { jeu = {…}, poisson = {…} }

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Style = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WikiBloxStyle"))
local C = Style.C
local new = Style.new

local MiniJeu = {}
MiniJeu.__index = MiniJeu

local HAUTEUR = 360 -- pixels de la barre
local VITESSE_MAX = 1.6 -- vitesse maximale du curseur (hauteurs de barre par seconde)

local VERT = Color3.fromRGB(90, 220, 120)
local ROUGE = Color3.fromRGB(235, 80, 80)

-- Petit poisson dessiné (corps arrondi + queue + œil)
local function dessinerPoisson(parent)
	local poisson = new("Frame", {
		Name = "Poisson",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(44, 26),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = parent,
	})
	new("Frame", {
		Name = "Queue",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.82, 0.5),
		Size = UDim2.fromOffset(16, 16),
		Rotation = 45,
		BackgroundColor3 = Color3.fromRGB(255, 150, 60),
		ZIndex = 5,
		Parent = poisson,
	}, { Style.coins(3), Style.contour(C.nuitFonce, 2) })
	new("Frame", {
		Name = "Corps",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.42, 0.5),
		Size = UDim2.fromOffset(32, 22),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 6,
		Parent = poisson,
	}, {
		Style.coins(UDim.new(1, 0)),
		Style.degrade(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 130, 50)),
		Style.contour(C.nuitFonce, 2),
	})
	new("Frame", {
		Name = "Oeil",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.25, 0.42),
		Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = C.nuitFonce,
		ZIndex = 7,
		Parent = poisson,
	}, { Style.coins(UDim.new(1, 0)) })
	return poisson
end

function MiniJeu.nouveau(gui, reglages, surFin)
	local self = setmetatable({}, MiniJeu)
	self.appuye = false
	self.termine = false
	self.surFin = surFin
	self.jeu = reglages.jeu
	self.poisson = reglages.poisson
	self.rng = Random.new()

	local jeu = self.jeu
	self.curseur = 0 -- bas du curseur (0 = bas de la barre)
	self.vitesse = 0
	self.position = 0.25 + self.rng:NextNumber() * 0.5 -- position du poisson
	self.cible = self.position
	self.minuteur = 0.6 -- petit répit au début
	self.progression = jeu.depart

	-- Interface
	local cadre = new("Frame", {
		Name = "MiniJeuPeche",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -60, 0.5, 0),
		Size = UDim2.fromOffset(150, HAUTEUR + 70),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = gui,
	}, { Style.coins(18), Style.degrade(C.nuitClair, C.nuit), Style.contour(C.or_, 3) })
	self.cadre = cadre

	local barre = new("Frame", {
		Name = "Barre",
		Position = UDim2.fromOffset(22, 20),
		Size = UDim2.fromOffset(62, HAUTEUR),
		BackgroundColor3 = Color3.fromRGB(40, 90, 140),
		ClipsDescendants = true,
		Parent = cadre,
	}, { Style.coins(10), Style.contour(C.orFonce, 2), Style.degrade(Color3.fromRGB(70, 150, 210), Color3.fromRGB(25, 60, 110)) })

	self.curseurUI = new("Frame", {
		Name = "Curseur",
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.new(1, 0, jeu.tailleCurseur, 0),
		BackgroundColor3 = VERT,
		BackgroundTransparency = 0.45,
		ZIndex = 3,
		Parent = barre,
	}, { Style.coins(8), Style.contour(Color3.fromRGB(200, 255, 210), 2) })

	self.poissonUI = dessinerPoisson(barre)

	local fondJauge = new("Frame", {
		Name = "Jauge",
		Position = UDim2.fromOffset(100, 20),
		Size = UDim2.fromOffset(26, HAUTEUR),
		BackgroundColor3 = C.nuitFonce,
		ClipsDescendants = true,
		Parent = cadre,
	}, { Style.coins(8), Style.contour(C.orFonce, 2) })
	self.jaugeUI = new("Frame", {
		Name = "Remplissage",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, self.progression),
		BackgroundColor3 = VERT,
		Parent = fondJauge,
	}, { Style.coins(8) })

	Style.texte({
		Position = UDim2.new(0, 8, 1, -44),
		Size = UDim2.new(1, -16, 0, 34),
		Text = "Maintiens E / clic",
		Font = Style.POLICE_TITRE,
		TextColor3 = C.orClair,
		Contour = C.nuitFonce,
		TailleMax = 18,
		Parent = cadre,
	})

	self.connexion = RunService.RenderStepped:Connect(function(dt)
		self:_pas(math.min(dt, 1 / 20))
	end)
	return self
end

function MiniJeu:_pas(dt)
	if self.termine then return end
	local jeu, p, rng = self.jeu, self.poisson, self.rng

	-- Poisson : change de cible de temps en temps, parfois avec un grand bond
	self.minuteur -= dt
	if self.minuteur <= 0 then
		if rng:NextNumber() < p.nervosite then
			self.cible = self.position > 0.5 and rng:NextNumber(0.03, 0.25) or rng:NextNumber(0.75, 0.97)
		else
			self.cible = math.clamp(self.position + rng:NextNumber(-0.35, 0.35), 0.05, 0.95)
		end
		self.minuteur = rng:NextNumber(p.changement[1], p.changement[2])
	end
	self.position += (self.cible - self.position) * math.min(1, p.vitesse * dt)
	self.position = math.clamp(self.position + rng:NextNumber(-1, 1) * p.tremblement, 0.03, 0.97)

	-- Curseur : monte quand on maintient, retombe sinon, rebondit en bas
	self.vitesse += (self.appuye and jeu.montee or -jeu.gravite) * dt
	self.vitesse = math.clamp(self.vitesse, -VITESSE_MAX, VITESSE_MAX)
	self.curseur += self.vitesse * dt
	local haut = 1 - jeu.tailleCurseur
	if self.curseur < 0 then
		self.curseur = 0
		self.vitesse = self.vitesse < -0.2 and -self.vitesse * 0.3 or 0
	elseif self.curseur > haut then
		self.curseur = haut
		self.vitesse = math.min(self.vitesse, 0)
	end

	-- Jauge
	local dedans = self.position >= self.curseur and self.position <= self.curseur + jeu.tailleCurseur
	self.progression += (dedans and jeu.remplissage or -jeu.vidage) * dt
	self.progression = math.clamp(self.progression, 0, 1)

	-- Affichage
	self.curseurUI.Position = UDim2.fromScale(0, 1 - self.curseur)
	self.curseurUI.BackgroundTransparency = dedans and 0.25 or 0.55
	self.poissonUI.Position = UDim2.fromScale(0.5, 1 - self.position)
	self.poissonUI.Rotation = dedans and 0 or math.sin(os.clock() * 30) * 12
	self.jaugeUI.Size = UDim2.fromScale(1, self.progression)
	self.jaugeUI.BackgroundColor3 = ROUGE:Lerp(VERT, self.progression)

	if self.progression >= 1 then
		self:_finir(true)
	elseif self.progression <= 0 then
		self:_finir(false)
	end
end

function MiniJeu:_finir(reussi)
	if self.termine then return end
	self:arreter()
	if self.surFin then
		task.spawn(self.surFin, reussi)
	end
end

function MiniJeu:arreter()
	self.termine = true
	if self.connexion then
		self.connexion:Disconnect()
		self.connexion = nil
	end
	if self.cadre then
		self.cadre:Destroy()
		self.cadre = nil
	end
end

return MiniJeu
