# 📤 Guide de Push sur GitHub

## Étape 1 : Créer un repo GitHub vide

1. Aller sur https://github.com/new
2. Mettre comme nom : `scriptserveur`
3. **Important** : Cocher "Public" (pour que tes copains puissent le cloner)
4. Nepas initialiser avec README, .gitignore ou License (on a déjà les nôtres)
5. Cliquer "Create repository"

---

## Étape 2 : Ajouter l'origin et pousser

```bash
cd /home/kazy/Documents/scriptserveur

# Ajouter l'origin GitHub (remplacer USERNAME par ton username GitHub)
git remote add origin https://github.com/USERNAME/scriptserveur.git

# Vérifier que ça s'est bien ajouté
git remote -v

# Renommer la branche en 'main' (version moderne)
git branch -m master main

# Pousser le code
git push -u origin main
```

---

## Étape 3 : Partager le lien avec tes copains

Donne-leur ce lien :

```
👉 https://github.com/[USERNAME]/scriptserveur
```

Et l'instruction de démarrage rapide :

```bash
git clone https://github.com/[USERNAME]/scriptserveur.git
cd scriptserveur
sudo ./install-meshcore-nodered-mosquitto.sh
```

---

## Authentification SSH GitHub (optionnel mais recommandé)

Si tu veux éviter de saisir ton token à chaque push :

```bash
# 1. Générer une clé SSH
ssh-keygen -t ed25519 -C "nivek@users.noreply.github.com"
# → Appuyer sur ENTER 3 fois pour accepter les defaults

# 2. Copier la clé publique
cat ~/.ssh/id_ed25519.pub

# 3. L'ajouter à GitHub :
#    - Aller sur https://github.com/settings/keys
#    - "New SSH key"
#    - Coller le contenu

# 4. Tester
ssh -T git@github.com
# → Vous devriez voir "Hi USERNAME! You've successfully authenticated..."

# 5. Changer l'origin en SSH (optionnel)
git remote set-url origin git@github.com:USERNAME/scriptserveur.git
```

---

## Updates futures

Pour mettre à jour le repo quand tu fais des changements :

```bash
# 1. Faire tes changements localement

# 2. Ajouter et commiter
git add -A
git commit -m "Description de tes changements"

# 3. Pousser
git push origin main
```

---

## Si ça dit "permission denied"

```bash
# Option 1 : Utiliser HTTPS avec token
# https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token

# Option 2 : Configurer SSH (voir section au-dessus)

# Option 3 : Vérifier ta config Git
git config -l
git config user.name "Nivek"
git config user.email "nivek@users.noreply.github.com"
```

---

**Après le push, les copains pourront cloner facilement ! 🚀**
