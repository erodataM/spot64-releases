# Spot64 v0.1.0-beta.10

## Francais

Cette beta privee apporte une evolution importante de l'espace de travail
echiqueen et de sa fiabilite native.

### Nouveautes

- panneau moteur enrichi et reutilisable dans l'explorateur et l'analyse de
  partie, avec variantes plus lisibles et options de moteur ;
- annotations completes : commentaires, symboles echiqueens, variantes,
  promotion d'une ligne principale et suppression de lignes ;
- copie filtree de parties entre bases ;
- catalogue bilingue francais/anglais des ouvertures et variantes ECO ;
- arbre de coups enrichi des taux blanc/nulle/noir et d'un message explicite
  au-dela de la limite actuelle de 40 demi-coups ;
- echiquier redimensionnable partage entre l'explorateur et le detail d'une
  partie ;
- fiche partie plus lisible, cartes joueurs et premieres photos publiques ;
- liste de parties plus dense et adaptative, avec apercu des premiers coups
  lorsque la largeur le permet ;
- navigation amelioree : menu lateral rabattable, onglets debordants
  utilisables et commandes de partie qui restent stables ;
- import assiste d'une feuille de partie photographique, avec reconnaissance
  de la notation francaise et correction guidee.

### Stabilite et installation

- API native et Libase Store qualifies ensemble sur les arrets propres,
  redemarrages, ports occupes, processus enfants et acces reels aux donnees ;
- ecran de preparation au demarrage et retours de chargement plus clairs ;
- une mise a jour macOS reutilise le corpus deja verifie de 17 Gio et ne
  telecharge que l'application ;
- le corpus contient 11 157 455 parties, 612 590 joueurs et un index de
  positions sur 40 demi-coups.

### Limites connues

- cette beta macOS est reservee aux Mac Apple Silicon sous macOS 12 ou plus ;
- l'application est signee localement mais pas encore notarisee par Apple :
  macOS peut demander de confirmer son ouverture ;
- l'import d'une feuille manuscrite reste assiste : les propositions doivent
  etre relues avant l'enregistrement.

## English

This private beta is a substantial upgrade to the chess workspace and its
native runtime reliability.

### Highlights

- richer reusable engine panel for Explorer and game review, with clearer
  variations and engine options;
- complete annotations: comments, chess symbols, variations, main-line
  promotion and line deletion;
- filtered game copy between databases;
- bilingual French/English ECO opening and variation catalogue;
- opening tree with White/draw/Black rates and a clear message beyond the
  current 40-ply index;
- shared resizable board workspace in Explorer and game details;
- clearer game information, player cards and the first public player photos;
- denser adaptive game table with opening move previews when space allows;
- improved navigation with a collapsible sidebar, usable overflowing tabs and
  stable game controls;
- assisted scoresheet photo import with French notation recognition and a
  guided correction workflow.

### Reliability and installation

- the native API and Libase Store are jointly qualified for graceful stops,
  restarts, occupied ports, child processes and real data access;
- clearer startup readiness and loading feedback;
- macOS updates reuse the existing verified 17 GiB corpus and download only
  the application;
- the corpus contains 11,157,455 games, 612,590 players and a 40-ply position
  index.

### Known limitations

- this macOS beta requires Apple Silicon and macOS 12 or later;
- the app is locally signed but not yet Apple-notarized, so macOS may ask the
  tester to explicitly allow it;
- handwritten scoresheet import remains assisted and should be reviewed
  before saving.
