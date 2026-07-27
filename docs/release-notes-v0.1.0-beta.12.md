# Spot64 v0.1.0-beta.12

## Francais

Cette version remplace la beta 11, qui n'est pas recommandee.

### Correctifs

- le detail d'une partie s'ouvre maintenant correctement, y compris pour les
  parties longues issues du corpus reel ;
- le calcul de l'etat d'edition d'une partie est desormais lineaire au lieu de
  grossir de maniere exponentielle avec le nombre de demi-coups ;
- la transition entre l'Explorateur et les onglets de parties conserve un
  proprietaire de cache stable ;
- la matrice navigateur couvre les vues desktop, intermediaire et mobile.

### Validation

- ouverture visuelle de Lagno, Kateryna - Lu Shanglei (116 demi-coups) depuis
  le corpus complet de 11 157 455 parties ;
- 582 tests frontend, 251 tests d'artefacts natifs, 34 tests Rust et 168 tests
  navigateur valides ;
- le corpus existant est reutilise : cette mise a jour telecharge uniquement
  l'application.

La beta 12 contient egalement toutes les nouveautes de la beta 10 : moteur dans
l'Explorateur, annotations et variantes completes, copie filtree entre bases,
catalogue ECO bilingue, arbre enrichi, echiquiers redimensionnables, fiches
parties et listes adaptatives, navigation par onglets et import assiste de
feuilles de partie.

## English

This release supersedes beta 11, which is not recommended.

### Fixes

- game details now render correctly, including long games from the real
  corpus;
- game edit-state calculation is now linear instead of growing exponentially
  with the number of plies;
- transitions between Explorer and game tabs keep a stable cache owner;
- the browser matrix covers desktop, intermediate and mobile layouts.

### Qualification

- visually opened Lagno, Kateryna - Lu Shanglei (116 plies) from the complete
  11,157,455-game corpus;
- 582 frontend tests, 251 native artifact tests, 34 Rust tests and 168 browser
  tests passed;
- the existing corpus is reused, so this update downloads the application
  only.

Beta 12 also includes every beta 10 highlight: Explorer engine panel, complete
annotations and variations, filtered database copy, bilingual ECO catalogue,
enhanced opening tree, resizable boards, adaptive game details and lists,
browser-like tabs and assisted scoresheet photo import.
