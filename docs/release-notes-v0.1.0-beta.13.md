# Spot64 v0.1.0-beta.13

## Francais

Cette beta poursuit le travail d'ergonomie et de fiabilite engage dans la
beta 12. Le corpus verifie de 11 157 455 parties est reutilise lors d'une mise
a jour.

### Nouveautes

- les filtres et listes de parties sont maintenant partages entre
  l'Explorateur et la gestion des bases, avec un mode centre sur les coups ;
- les onglets se reordonnent par glisser-deposer, se reduisent et defilent
  comme dans un navigateur ;
- les listes utilisent une pagination coherente, y compris sur les grands
  nombres de pages ;
- l'arbre affiche les resultats blancs, nuls et noirs dans une barre compacte ;
- les variantes du moteur sont plus lisibles et leurs coups sont interactifs ;
- la profondeur de review d'une partie peut monter jusqu'a 26 ;
- les 500 premiers joueurs sont pagines et jusqu'a 415 portraits libres,
  compresses et attribues sont affiches dans les listes et fiches joueur ;
- les portraits peuvent etre agrandis avec leur source, et le cadrage de
  Shirov utilise maintenant une detection de visage verifiee ;
- la gestion des connecteurs prepare plusieurs comptes rattaches a un meme
  joueur.

### Correctifs

- choisir une ouverture applique maintenant reellement sa position dans
  l'Explorateur ;
- les resultats deja charges d'un onglet restent en cache pendant la navigation ;
- jouer un coup ne provoque plus plusieurs rechargements de la liste ;
- le moteur demarre des la premiere ouverture de son panneau ;
- le manifeste de securite des connecteurs est bien inclus dans l'application ;
- les apercus de coups, chargeurs, colonnes et commandes d'echiquier ont ete
  harmonises.

### Validation

- 630 tests frontend, 253 tests d'artefacts natifs et 34 tests Rust valides ;
- typecheck et build de production valides ;
- application et DMG Apple Silicon signes localement et verifies ;
- cette beta reste privee et non notarisee par Apple.

## English

This beta continues the usability and reliability work introduced in beta 12.
Updates reuse the verified 11,157,455-game corpus.

### Highlights

- game filters and lists are now shared between Explorer and database
  management, including a move-focused display mode;
- tabs can be reordered by drag and drop, shrink and scroll like browser tabs;
- lists use consistent pagination, including very large page counts;
- the opening tree displays white, draw and black outcomes in a compact bar;
- engine variations are clearer and their moves are interactive;
- game review depth can be increased to 26;
- the top 500 players are paginated, with up to 415 licensed, compressed and
  attributed portraits in player lists and profiles;
- portraits can be enlarged with their source, and Shirov now uses a verified
  face-aware crop;
- connector management prepares multiple accounts attached to one player.

### Fixes

- selecting an opening now reliably applies its position in Explorer;
- loaded tab results remain cached while navigating elsewhere;
- playing a move no longer reloads the game list multiple times;
- the engine starts the first time its panel is expanded;
- the connector security policy is included in the packaged application;
- move previews, loaders, columns and board controls were made consistent.

### Qualification

- 630 frontend tests, 253 native artifact tests and 34 Rust tests passed;
- typecheck and production build passed;
- Apple Silicon application and DMG were locally signed and verified;
- this private beta remains unsigned by an Apple Developer certificate and is
  not notarized.
