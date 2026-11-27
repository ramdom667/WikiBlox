-- WikiBlox : configuration de la pêche (partagée serveur / client)
--
-- Tout l'équilibrage est ici : probabilités, cannes, appâts, zones, difficulté du mini-jeu.
-- Pour ajouter une canne, un appât ou un type de zone : ajouter une entrée, sans toucher au calcul.
--
-- Calcul des probabilités :
--   poids[prise] = POIDS_BASE[prise] × bonus[prise] de chaque modificateur actif (canne, appât, zone…)
--   proba[prise] = poids[prise] / somme des poids, puis plafonds (PLAFONDS) appliqués
--
--   local Peche = require(ReplicatedStorage.Shared.WikiBloxPecheConfig)
--   local mods = Peche.modificateurs({ canne = "bois", appat = nil, zone = nil })
--   Peche.probabilites(mods)  -> { common = 69, …, booster = 1 } (en %)
--   Peche.tirer(mods)         -> "rare" (tirage côté SERVEUR uniquement)
--   Peche.simuler(mods, 100000) -> % observés (vérification dans Studio)

local Peche = {}

-- Prises possibles, de la plus courante à la plus précieuse
Peche.PRISES = { "common", "uncommon", "rare", "epic", "legendary", "booster" }

Peche.POIDS_BASE = {
	common = 69,
	uncommon = 22,
	rare = 6.5,
	epic = 1.2,
	legendary = 0.3,
	booster = 1,
}

-- Probabilité maximale (en %) après tous les bonus, pour que l'empilement ne casse pas l'équilibre
Peche.PLAFONDS = {
	epic = 10,
	legendary = 3,
	booster = 5,
}

------------------------------------------------------------------
-- Équipement et zones. effets.chance = multiplicateurs de poids par prise.
-- effets.jeu = réglages du mini-jeu (voir Peche.JEU_BASE) multipliés par la valeur donnée.
------------------------------------------------------------------
Peche.CANNES = {
	bois = {
		nom = "Canne en bois",
		portee = { min = 10, max = 42 }, -- distance du lancer (studs), selon la charge
		attente = 1, -- multiplicateur du temps avant la morsure (0.8 = 20 % plus rapide)
		effets = { chance = {}, jeu = {} },
	},
	-- exemple pour plus tard :
	-- bambou = { nom = "Canne en bambou", portee = { min = 10, max = 55 }, attente = 0.85,
	--            effets = { chance = { rare = 1.2 }, jeu = { tailleCurseur = 1.15 } } },
}
Peche.CANNE_DEFAUT = "bois"

Peche.APPATS = {
	-- exemple pour plus tard :
	-- ver = { nom = "Ver de terre", effets = { chance = { uncommon = 1.3, rare = 1.2 } } },
}

-- Zones spéciales (parties taguées WikiBloxZonePeche avec l'attribut ZonePeche = identifiant)
Peche.ZONES = {
	banc_rare = {
		nom = "Banc scintillant",
		effets = { chance = { rare = 1.5, epic = 2, legendary = 3, booster = 2 } },
	},
}

------------------------------------------------------------------
-- Mini-jeu (valeurs en fraction de la hauteur de la barre, par seconde)
------------------------------------------------------------------
Peche.JEU_BASE = {
	tailleCurseur = 0.26, -- hauteur du curseur
	montee = 2.6, -- accélération vers le haut quand on maintient
	gravite = 2.2, -- accélération vers le bas quand on relâche
	remplissage = 0.24, -- progression gagnée par seconde quand le poisson est dans le curseur
	vidage = 0.17, -- progression perdue par seconde sinon
	depart = 0.3, -- progression au début du combat
}

-- Comportement du poisson selon la prise : plus c'est rare, plus c'est rapide et imprévisible
--   vitesse : rapidité à rejoindre sa cible ; changement : secondes entre deux cibles (min, max)
--   nervosite : chance d'un grand bond à chaque changement ; tremblement : agitation permanente
-- Réussite mesurée avec un joueur simulé (rapide / moyen / lent) :
--   commune 100 %, rare 75-100 %, épique 40-87 %, légendaire 12-50 %
Peche.DIFFICULTE = {
	common = { vitesse = 1.6, changement = { 1.2, 2.2 }, nervosite = 0.1, tremblement = 0.01 },
	uncommon = { vitesse = 2.0, changement = { 1.0, 1.9 }, nervosite = 0.2, tremblement = 0.015 },
	rare = { vitesse = 2.4, changement = { 0.9, 1.6 }, nervosite = 0.3, tremblement = 0.02 },
	epic = { vitesse = 2.8, changement = { 0.7, 1.3 }, nervosite = 0.4, tremblement = 0.025 },
	legendary = { vitesse = 3.2, changement = { 0.6, 1.1 }, nervosite = 0.5, tremblement = 0.03 },
	booster = { vitesse = 2.8, changement = { 0.7, 1.3 }, nervosite = 0.4, tremblement = 0.025 },
}

Peche.ATTENTE = { min = 3, max = 8 } -- secondes avant que ça morde (× attente de la canne)
Peche.DUREE_MAX_COMBAT = 60 -- au-delà, la prise s'échappe

------------------------------------------------------------------
-- Calculs
------------------------------------------------------------------

-- Liste des modificateurs actifs à partir des identifiants équipés
function Peche.modificateurs(equipement)
	equipement = equipement or {}
	local liste = {}
	local canne = Peche.CANNES[equipement.canne or Peche.CANNE_DEFAUT]
	if canne then table.insert(liste, canne.effets) end
	local appat = equipement.appat and Peche.APPATS[equipement.appat]
	if appat then table.insert(liste, appat.effets) end
	local zone = equipement.zone and Peche.ZONES[equipement.zone]
	if zone then table.insert(liste, zone.effets) end
	for _, extra in ipairs(equipement.extras or {}) do -- ex. bonus d'événement, pass VIP…
		table.insert(liste, extra)
	end
	return liste
end

-- Probabilités en % de chaque prise
function Peche.probabilites(mods)
	local poids, total = {}, 0
	for _, prise in ipairs(Peche.PRISES) do
		local p = Peche.POIDS_BASE[prise] or 0
		for _, effets in ipairs(mods or {}) do
			p *= (effets.chance and effets.chance[prise]) or 1
		end
		poids[prise] = p
		total += p
	end
	local probas = {}
	for _, prise in ipairs(Peche.PRISES) do
		probas[prise] = total > 0 and 100 * poids[prise] / total or 0
	end

	-- Plafonds : l'excédent est redistribué aux prises non plafonnées, au prorata
	local excedent, libre = 0, 0
	for _, prise in ipairs(Peche.PRISES) do
		local plafond = Peche.PLAFONDS[prise]
		if plafond and probas[prise] > plafond then
			excedent += probas[prise] - plafond
			probas[prise] = plafond
		elseif not plafond then
			libre += probas[prise]
		end
	end
	if excedent > 0 and libre > 0 then
		for _, prise in ipairs(Peche.PRISES) do
			if not Peche.PLAFONDS[prise] then
				probas[prise] += excedent * probas[prise] / libre
			end
		end
	end
	return probas
end

function Peche.tirer(mods, rng)
	rng = rng or Random.new()
	local probas = Peche.probabilites(mods)
	local x = rng:NextNumber() * 100
	local cumul = 0
	for _, prise in ipairs(Peche.PRISES) do
		cumul += probas[prise]
		if x < cumul then return prise end
	end
	return Peche.PRISES[1]
end

function Peche.simuler(mods, n)
	local rng = Random.new()
	local compte = {}
	for _ = 1, n do
		local p = Peche.tirer(mods, rng)
		compte[p] = (compte[p] or 0) + 1
	end
	local res = {}
	for _, prise in ipairs(Peche.PRISES) do
		res[prise] = 100 * (compte[prise] or 0) / n
	end
	return res
end

-- Réglages du mini-jeu pour une prise donnée (poisson + bonus de l'équipement)
function Peche.reglagesJeu(prise, mods)
	local jeu = table.clone(Peche.JEU_BASE)
	for _, effets in ipairs(mods or {}) do
		for cle, mult in pairs(effets.jeu or {}) do
			if jeu[cle] then jeu[cle] *= mult end
		end
	end
	jeu.tailleCurseur = math.clamp(jeu.tailleCurseur, 0.1, 0.6)
	return { jeu = jeu, poisson = Peche.DIFFICULTE[prise] or Peche.DIFFICULTE.common }
end

-- Durée minimale d'un combat gagné (le poisson toujours dans le curseur) : sert d'anti-triche
function Peche.dureeMinimale(reglages)
	local j = reglages.jeu
	return (1 - j.depart) / j.remplissage
end

return Peche
