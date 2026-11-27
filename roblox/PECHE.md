# Pêche

Activité infinie : on pêche des cartes (moins bonnes qu'en booster) et parfois un booster.

## Déroulé d'une partie

1. **Accès.** La porte « Pêche » du Nexus (`PorteMiniJeu1`) téléporte vers l'étang (`Workspace.WikiBloxPeche`). La canne est donnée en entrant dans l'aire de pêche et retirée en sortant.
2. **Lancer.** On maintient le clic (ou l'écran) : la jauge monte et descend. On relâche : plus la jauge est haute, plus le flotteur part loin. Le flotteur doit tomber dans l'eau.
3. **Attente.** Ça mord au bout de 3 à 8 secondes. Cliquer pendant l'attente remonte la ligne.
4. **Combat.** On maintient **E**, le clic, R2 ou le bouton tactile pour faire monter le curseur vert, qui retombe quand on relâche. Tant que le poisson est dans le curseur, la jauge de droite se remplit. Jauge pleine : prise. Jauge vide : le poisson s'échappe. Plus la prise est rare, plus le poisson est rapide et imprévisible.
5. **Prise.** Une carte est ajoutée à la collection via l'API (`POST /api/players/{id}/cards`). Un booster va directement dans le stock du joueur, et peut dépasser le maximum de 10.

## Qui fait quoi

| Script | Rôle |
|---|---|
| `shared/WikiBloxPecheConfig.luau` | **Tout l'équilibrage** : probabilités, plafonds, cannes, appâts, zones, difficulté du mini-jeu |
| `server/WikiBloxPeche.server.luau` | Décide de tout : point de chute, moment de la morsure, prise, anti-triche, distribution de la canne |
| `shared/WikiBloxPecheMiniJeu.luau` | Le mini-jeu (affichage et physique), côté joueur |
| `client/WikiBloxPeche.client.luau` | Lancer, flotteur, ligne, déclenchement du mini-jeu, affichage de la prise |
| `tools/build_etang_peche.luau` | Construit l'étang (barre de commande, mode édition) et ouvre la porte du Nexus |

Le joueur ne choisit jamais sa prise. Elle est tirée par le serveur au moment de la morsure. Un tricheur peut au mieux gagner tous les combats, jamais améliorer la rareté. Le serveur refuse aussi un combat gagné plus vite que possible.

## Probabilités

```
poids[prise] = POIDS_BASE[prise] × bonus de chaque modificateur actif (canne, appât, zone…)
proba[prise] = poids / somme des poids, puis PLAFONDS appliqués
```

| Prise | Base | Dans une zone `banc_rare` | Plafond |
|---|---|---|---|
| Commune | 69 % | 65,1 % | |
| Peu commune | 22 % | 20,7 % | |
| Rare | 6,5 % | 9,2 % | |
| Épique | 1,2 % | 2,3 % | 10 % |
| Légendaire | 0,3 % | 0,85 % | 3 % |
| Booster | 1 % | 1,9 % | 5 % |

Pour vérifier après un changement, dans la barre de commande :

```lua
local P = require(game.ReplicatedStorage.Shared.WikiBloxPecheConfig)
print(P.simuler(P.modificateurs({ zone = "banc_rare" }), 100000))
```

## Réussite du mini-jeu

Mesurée avec un joueur simulé plus ou moins rapide à réagir :

| | Commune | Rare | Épique | Légendaire |
|---|---|---|---|---|
| Joueur rapide | 100 % | 100 % | 87 % | 50 % |
| Joueur moyen | 100 % | 92 % | 77 % | 30 % |
| Joueur lent | 100 % | 75 % | 40 % | 12 % |

Les réglages se trouvent dans `Peche.DIFFICULTE` (le poisson) et `Peche.JEU_BASE` (le curseur et la jauge).

## Ajouter du contenu

- **Une canne** : une entrée dans `Peche.CANNES` avec sa portée, son temps d'attente, ses `effets.chance` (multiplicateurs par prise) et ses `effets.jeu` (ex. `tailleCurseur = 1.15`). Il faudra ensuite sauvegarder les cannes possédées et équipées (`WikiBloxInventaire`) et remplir l'attribut `CanneEquipee` du joueur, déjà lu par le serveur.
- **Un appât** : une entrée dans `Peche.APPATS`, lue par le serveur via l'attribut `AppatEquipe`.
- **Une zone spéciale** : une partie plate posée sur l'eau, avec le tag `WikiBloxZonePeche` et l'attribut `ZonePeche = "banc_rare"`, ou tout autre identifiant de `Peche.ZONES`. Le serveur la détecte déjà. Il reste à écrire l'apparition aléatoire des zones.
- **Un bonus temporaire** (événement, pass VIP…) : passer `extras = { { chance = { legendary = 2 } } }` à `Peche.modificateurs` côté serveur.
