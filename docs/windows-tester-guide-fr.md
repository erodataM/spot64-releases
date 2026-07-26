# Tester Spot64 sous Windows

Ce guide concerne la beta Windows `v0.1.0-beta.9`.

## Avant de commencer

Il faut :

- Windows 10 ou Windows 11 en 64 bits ;
- une connexion Internet stable ;
- environ 20 Go d'espace disque libre ;
- prévoir plusieurs minutes pour le premier téléchargement.

L'application et son corpus fonctionnent ensuite localement. Le premier
installateur télécharge environ 5 Go d'archives vérifiées et installe une base
d'environ 10 Go.

## Installation

1. Télécharger
   [Spot64-Beta-Setup.exe](https://github.com/erodataM/spot64-releases/releases/download/v0.1.0-beta.9/Spot64-Beta-Setup.exe).
2. Fermer une éventuelle ancienne version de Libase ou Spot64.
3. Double-cliquer sur `Spot64-Beta-Setup.exe`.
4. Si Windows SmartScreen affiche **Windows a protégé votre ordinateur**,
   cliquer sur **Informations complémentaires**, puis
   **Exécuter quand même**.
5. Laisser la fenêtre d'installation ouverte. Lors d'une première
   installation, elle télécharge les six parties du corpus, vérifie leur
   intégrité, installe la base, puis installe l'application. Une mise à jour
   réutilise automatiquement le corpus déjà vérifié.
6. Une fois l'installation terminée, lancer **Libase** depuis le menu
   Démarrer.

Le téléchargement peut reprendre après une coupure. Il ne faut pas éteindre
ou mettre l'ordinateur en veille pendant la reconstruction finale de la base.

## Antivirus

Cette beta n'est pas encore signée avec un certificat commercial. SmartScreen
ou un antivirus comme Avast peut donc la considérer comme inconnue.

Commencer par autoriser explicitement `Spot64-Beta-Setup.exe` et le dossier :

```text
%LOCALAPPDATA%\Libase
```

Si Avast met un fichier en quarantaine, le restaurer et l'ajouter aux
exceptions. En dernier recours pour ce test privé, suspendre temporairement la
protection pendant l'installation, puis la réactiver immédiatement après.

## Vérification rapide

Au premier lancement :

1. attendre la fin de l'écran de préparation, qui peut prendre 10 à 20
   secondes ;
2. vérifier que l'application n'affiche plus **Offline** ;
3. ouvrir l'explorateur ;
4. vérifier que la base principale est disponible ;
5. rechercher un joueur et ouvrir une partie ;
6. jouer quelques coups dans l'explorateur pour vérifier l'arbre et la liste
   des parties.

La base de cette beta contient normalement :

- 11 157 455 parties ;
- 612 590 joueurs.

## En cas de problème

### L'application reste Offline

1. Attendre 30 secondes.
2. Fermer complètement Libase.
3. Vérifier dans le Gestionnaire des tâches qu'il ne reste plus de processus
   `desktop.exe` ou `libase-api.exe`.
4. Relancer Libase une fois.
5. Vérifier l'historique de quarantaine de l'antivirus.

### « Impossible de charger les bases »

Fermer l'application, autoriser le dossier `%LOCALAPPDATA%\Libase` dans
l'antivirus, puis relancer. Ne pas supprimer le corpus : il a déjà été
téléchargé et vérifié.

### Informations à envoyer pour le diagnostic

Transmettre :

- une capture du message affiché ;
- la version de Windows ;
- le nom de l'antivirus ;
- l'étape à laquelle le problème apparaît ;
- le texte exact d'une éventuelle erreur de l'installateur.
