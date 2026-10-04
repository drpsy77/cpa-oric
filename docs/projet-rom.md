# Projet « CP/A ROM » — ROM dédiée à l'exécution autonome

À lire avec `docs/architecture.md` (contrat d'interface commun avec la version disquette).

## But

Une ROM de 16 Ko qui remplace la ROM BASIC de l'Atmos et sert à **exécuter un programme
autonome** : un jeu ou une application écrits pour CP/A, chargés depuis une **cassette** (ou le
lecteur de cassettes émulé du LOCI), ou intégrés directement dans la ROM comme une **cartouche
dédiée** (par exemple un traitement de texte). Pas de disque : ni fichiers, ni commandes `.COM`.

Le même programme doit tourner sur les deux versions tant qu'il n'utilise pas de fichiers :
même table BIOS, mêmes fonctions BDOS (console, graphisme 115, son 116), chargement en `$0500`.

## État actuel de la ROM (`build/cpa.rom`)

Construite par `build.sh` à partir des sources communes, sans `-DDISK`. Elle occupe
`$C000-$E19C` environ (8,6 Ko) : **près de 7,5 Ko libres**.

Elle contient : BIOS (console, clavier, IRQ, reprise après plantage, test de la RAM), menus,
graphisme SPLIT (BDOS 115, sauf GSAVE/GLOAD), son (BDOS 116), CCP avec HELP (interne, en anglais),
VER, CLS, MEM, DUMP, POKE, GO, SPLIT, TEXT, GCLS, commandes graphiques, ECHO, PAUSE. Les
fonctions fichiers du BDOS renvoient `$FF`, DIR répond « No disk in the ROM version. ».

Essai : Oricutron avec `ORIC_ROM=cpa` (copier `build/cpa.rom` dans `roms/cpa.rom`) ; sur le
matériel, le LOCI permet de choisir le fichier ROM (le Cumulus ne remplace pas la ROM).

## À faire (proposition à valider)

1. **Cassette** (BIOS) : lecture et écriture au format standard de l'Oric, pour que les fichiers
   `.TAP` (produits sur PC, lus par le LOCI) fonctionnent :
   - charger un programme en `$0500` (ou à l'adresse de son en-tête) et le lancer ;
   - commandes `CLOAD "NOM"` / `CSAVE "NOM" adr fin` ; éventuellement lancement automatique ;
   - outil PC pour fabriquer un `.TAP` à partir d'un `.COM`.
2. **Démarrage dédié** : option de construction pour qu'une ROM lance directement son
   application (cartouche), ou charge la première cassette, sans passer par le prompt.
3. **Cartouche** : intégrer un programme dans les ~7 Ko libres (lequel ? un éditeur de texte
   allégé, un jeu…), assemblé pour tourner depuis la ROM ou recopié en RAM au démarrage.
4. **Aide** : HELP de la ROM en français, plus court que HELP.COM.

## Questions ouvertes

- Format cassette exact à reprendre de la ROM Atmos (en-tête, vitesse) et routines à réécrire
  (la ROM BASIC n'est plus là).
- Quel programme mettre en cartouche en premier.
- Faut-il garder le moniteur (DUMP/POKE/GO) dans une ROM orientée utilisateur final ?

## Contraintes

- Les 16 Ko de la ROM, moins les vecteurs du 6502 en `$FFFA`.
- Le contrat d'interface (`docs/architecture.md`) est partagé : une modification du BIOS ou du
  BDOS commun profite aux deux versions, mais ne doit pas casser la version disquette
  (`./build.sh` construit toujours les deux et contrôle les tailles).
