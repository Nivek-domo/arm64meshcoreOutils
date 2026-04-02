# TROUBLESHOOTING.md

# Guide de dépannage pour l'installation et l'utilisation du projet Raspberry Pi 3 Trixie

Ce document fournit des conseils et des solutions aux problèmes courants que vous pourriez rencontrer lors de l'installation ou de l'utilisation du projet sur un Raspberry Pi 3 avec Trixie ARM64.

## Problèmes d'installation

### 1. Erreurs lors de l'exécution du script d'installation

- **Vérifiez les permissions** : Assurez-vous d'exécuter le script avec des privilèges sudo. Utilisez `sudo ./install.sh`.
- **Dépendances manquantes** : Si le script échoue en raison de dépendances manquantes, vérifiez que toutes les dépendances sont installées. Consultez le fichier `requirements.txt` pour les dépendances Python et le fichier `package.json` pour les dépendances Node-RED.

### 2. Node-RED ne démarre pas

- **Vérifiez le service Node-RED** : Utilisez `systemctl status nodered` pour vérifier l'état du service. Si le service ne démarre pas, consultez les logs avec `journalctl -u nodered -n 100`.
- **Configuration incorrecte** : Assurez-vous que le fichier `settings.js` est correctement configuré et que toutes les dépendances nécessaires sont installées.

### 3. Problèmes de connexion à PostgreSQL

- **Vérifiez le service PostgreSQL** : Utilisez `systemctl status postgresql` pour vérifier si le service est actif.
- **Identifiants incorrects** : Assurez-vous que les identifiants de connexion (nom d'utilisateur et mot de passe) sont corrects. Vous pouvez tester la connexion avec la commande suivante :
  ```
  PGPASSWORD='motdepassefort' psql -h localhost -U vpnuser -d vpndb
  ```

## Problèmes d'utilisation

### 1. Node-RED ne répond pas

- **Vérifiez l'interface web** : Accédez à `http://localhost:1880` dans votre navigateur. Si l'interface ne se charge pas, vérifiez que le service Node-RED est en cours d'exécution.
- **Ressources système** : Assurez-vous que votre Raspberry Pi dispose de suffisamment de ressources (CPU, RAM) pour exécuter Node-RED.

### 2. Erreurs dans les flux Node-RED

- **Vérifiez les logs de Node-RED** : Les erreurs dans les flux peuvent être identifiées dans les logs. Utilisez `journalctl -u nodered -f` pour afficher les logs en temps réel.
- **Configuration des nœuds** : Assurez-vous que tous les nœuds utilisés dans vos flux sont correctement configurés et que toutes les dépendances sont installées.

## Autres conseils

- **Mise à jour du système** : Assurez-vous que votre système d'exploitation est à jour. Utilisez `sudo apt-get update` et `sudo apt-get upgrade`.
- **Documentation** : Consultez le fichier `TUTORIEL_COMPLET.md` pour des instructions détaillées sur l'utilisation et la configuration du projet.

Si vous rencontrez des problèmes qui ne sont pas couverts dans ce document, n'hésitez pas à ouvrir une issue sur le dépôt GitHub du projet pour obtenir de l'aide.