# Spot64 v0.1.0-beta.11

> Retiree / Withdrawn: cette version restait incapable d'afficher certaines
> parties longues. Utilisez la beta 12 ou une version plus recente.
>
> This release could still fail to render some long games. Use beta 12 or a
> newer release.

## Francais

Cette version corrige un blocage de la beta 10 :

- l'ouverture du detail d'une partie depuis l'Explorateur ou une base
  n'affiche plus un ecran noir ;
- la navigation entre les ecrans standards et les onglets de parties conserve
  correctement l'etat et le cache de chaque onglet ;
- un test navigateur reproduit desormais ce parcours exact pour prevenir toute
  regression.

Cette mise a jour reutilise le corpus deja installe. Elle ne telecharge que
l'application.

## English

This release fixes a beta 10 blocker:

- opening a game detail from Explorer or a database no longer produces a blank
  black screen;
- navigation between regular screens and cached game tabs now preserves each
  tab's state correctly;
- a browser regression test now covers this exact route transition.

This update reuses the corpus already installed and downloads only the
application.
