# TUTORIEL COMPLET

## Introduction

Ce tutoriel a pour but de guider les utilisateurs à travers le processus d'installation et de configuration d'un système complet sur un Raspberry Pi 3 utilisant le système d'exploitation Trixie ARM64. Ce système inclut Node-RED, PostgreSQL, et des scripts Python pour interagir avec ces services.

## Prérequis

Avant de commencer, assurez-vous d'avoir :

- Un Raspberry Pi 3 avec Trixie ARM64 installé.
- Un accès à Internet.
- Un accès SSH ou un terminal local sur le Raspberry Pi.

## Étapes d'installation

### 1. Cloner le dépôt

Commencez par cloner le dépôt contenant les scripts d'installation :

```bash
git clone https://github.com/votre-utilisateur/rpi3-trixie-installer.git
cd rpi3-trixie-installer
```

### 2. Exécuter le script d'installation

Le script principal d'installation gère l'exécution des autres scripts de configuration. Exécutez le script suivant :

```bash
cd scripts
sudo ./install.sh
```

### 3. Configuration de Node-RED

Le script `setup-nodered.sh` s'occupe de l'installation et de la configuration de Node-RED. Il installe également les dépendances nécessaires et configure le service systemd pour Node-RED.

### 4. Configuration de PostgreSQL

Le script `setup-postgresql.sh` installe PostgreSQL et crée les utilisateurs et bases de données nécessaires. Assurez-vous de suivre les instructions affichées pendant l'exécution de ce script.

### 5. Installation de Python

Le script `setup-python.sh` installe Python et les dépendances spécifiées dans `requirements.txt`. Cela configure également l'environnement Python pour le projet.

### 6. Vérification de l'installation

Après avoir exécuté tous les scripts, utilisez le script `verify-installation.sh` pour vérifier que tous les services (Node-RED, PostgreSQL, etc.) sont actifs et fonctionnent correctement :

```bash
sudo ./verify-installation.sh
```

## Utilisation de Node-RED

Une fois Node-RED installé, vous pouvez y accéder via votre navigateur à l'adresse suivante :

```
http://<adresse-ip-de-votre-raspberry-pi>:1880
```

Importez les flux depuis `flows.json` pour configurer rapidement votre environnement Node-RED.

## Scripts Python

Le fichier `main.py` dans le répertoire `python/src` contient le code principal de l'application Python. Vous pouvez l'exécuter avec la commande suivante :

```bash
python3 python/src/main.py
```

Assurez-vous que toutes les dépendances sont installées en exécutant :

```bash
pip install -r python/requirements.txt
```

## Résolution des problèmes

Si vous rencontrez des problèmes lors de l'installation ou de l'utilisation du système, consultez le fichier `TROUBLESHOOTING.md` dans le répertoire `docs` pour des conseils et des solutions aux problèmes courants.

## Conclusion

Ce tutoriel vous a guidé à travers le processus d'installation et de configuration d'un système complet sur un Raspberry Pi 3. Pour toute question ou contribution, n'hésitez pas à ouvrir une issue ou à soumettre une pull request sur le dépôt GitHub.