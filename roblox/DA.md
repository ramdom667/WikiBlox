# WikiBlox — Direction artistique des interfaces (HUD et écrans)

Toutes les interfaces du jeu (HUD, Booster, Collection, Boutique, et les futures : Quêtes, Codes, Récompenses, Classement…) suivent **la même DA**. Pour la respecter sans rien recopier, on utilise toujours les deux modules communs :

- `src/shared/WikiBloxStyle.luau` : couleurs, polices, fenêtres, boutons, cartes, effets ;
- `src/shared/WikiBloxHUD.luau` : la barre de boutons à gauche de l'écran.

## Thème : « bibliothèque magique »

Bleu nuit + or + parchemin, style cartoon Roblox (contours épais, coins arrondis, effet 3D, animations qui rebondissent).

## Couleurs (`Style.C`)

| Rôle | Nom | Couleur |
|---|---|---|
| Fond des fenêtres | `nuit` / `nuitClair` / `nuitFonce` | 26,31,54 / 46,55,92 / 14,17,32 |
| Bordures, titres, monnaie, bouton principal | `or_` / `orClair` / `orFonce` | 240,190,75 / 255,224,140 / 170,115,30 |
| Rubans-titres, panneaux d'info, cartes | `parchemin` / `parcheminFonce` | 248,238,214 / 222,200,160 |
| Texte sur parchemin | `encre` | 45,32,22 |
| Fermer, annuler, notification | `rouge` | 235,80,80 |
| Action secondaire (ex. « Ma collection ») | `bleu` | 80,165,255 |
| Acheter / réclamer (ex. bouton Boutique) | `vert` | 60,190,110 |
| Premium / Robux (ex. Pass VIP) | `violet` | 150,85,240 |

Sens des couleurs, à garder partout : **or = action principale / récompense**, **vert = acheter / réclamer**, **rouge = fermer / annuler / notification**, **bleu nuit = action neutre**, **violet = premium / Robux**.

Raretés (`Style.RARETES`), toujours ces couleurs et ce nombre d'étoiles :
commune gris ★, peu commune vert ★★, rare bleu ★★★, épique violet ★★★★, légendaire or ★★★★★.

## Polices

- Titres, boutons, chiffres : **FredokaOne** (`Style.POLICE_TITRE`), en blanc avec un **contour foncé** (couleur du bouton assombrie).
- Textes courants : **Gotham** (Medium / Bold).
- Titres de cartes et textes « livre » : **Merriweather** (`Style.POLICE_LIVRE`).
- Fredoka n'a pas le symbole ✕ : pour fermer, écrire un **X**.

## Composants (ne pas les refaire à la main)

| Besoin | À utiliser |
|---|---|
| Une nouvelle fenêtre | `Style.fenetre(gui, { titre = "BOUTIQUE" })` puis `Style.ouvrir(f)` / `Style.fermer(f)` (flou, fond sombre, pop) |
| Un bouton | `Style.bouton(parent, { texte = "ACHETER", couleur = ... })` (3D, s'enfonce au clic) |
| Un bouton dans la barre de gauche | `HUD.ajouterBouton({ id, icone, texte, couleur, ordre, raccourci }, rappel)` |
| Une notification sur un bouton du HUD | `HUD.pastille("Quetes", 3)` |
| Afficher une carte | `Style.carte(cadre, carte, { mention = "x3" })` / `Style.dos(cadre)` |
| Une icône | `Style.icone(cadre, "booster", { contour = couleur })` — ou `icone = "booster"` dans `Style.bouton` / `HUD.ajouterBouton` |
| Effets | `Style.halo`, `Style.brillance`, `Style.rayons` |

## Icônes : jamais d'emojis

Les icônes sont **dessinées** avec des formes (dans `Style.ICONES`), dans le même style que le reste : formes colorées, contour foncé, petits détails dorés.
Disponibles : `booster`, `collection`, `probabilites`, `loupe`, `chargement`, `alerte`, `boutique`, `piece`, `couronne`.
Pour un nouvel écran (boutique, quêtes, cadeau…), on **ajoute une nouvelle icône dans `Style.ICONES`** au lieu de mettre un emoji.

## Règles

1. **Une fenêtre = un sujet** : ruban-titre en haut, contenu au milieu, actions en bas, bouton rouge X en haut à droite. On cache le HUD (`HUD.afficher(false)`) quand une fenêtre est ouverte.
2. **Tout bouge un peu** : apparition avec rebond (`EasingStyle.Back`), survol = grossit, clic = s'enfonce. Rien d'agressif ni de trop long (0,15 à 0,4 s).
3. **Mobile d'abord** : boutons d'au moins 60–70 px, tailles en Scale + `UISizeConstraint`, rien sous le joystick (bas gauche) ni sous le bouton saut (bas droit).
4. **Barre de gauche : 4–5 boutons maximum.** Au-delà, regrouper dans un menu. Actuellement : Booster (B), Collection (C), Boutique (V).
5. Les nouvelles couleurs ou polices s'ajoutent **dans `WikiBloxStyle`**, jamais en dur dans un écran.
