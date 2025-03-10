#!/bin/bash

# Configuration
REPO_OWNER="To37oT"  # L'utilisateur reste le même
BRANCH="main"  # La branche du dépôt (par défaut "main")
BASE_URL="https://raw.githubusercontent.com"

# Liste des dépôts à traiter
REPOS_LIST=("3DN" "2DN")  # Remplace ces valeurs par tes dépôts réels

# Fonction pour récupérer l'extension d'image à partir du type MIME
get_image_extension() {
  MIME_TYPE=$1
  case "$MIME_TYPE" in
    image/jpeg) echo "jpg" ;;
    image/png) echo "png" ;;
    image/gif) echo "gif" ;;
    image/bmp) echo "bmp" ;;
    image/webp) echo "webp" ;;
    image/svg+xml) echo "svg" ;;
    *) echo "unknown" ;;
  esac
}

# Parcourir chaque dépôt dans le tableau REPOS_LIST
for REPO_NAME in "${REPOS_LIST[@]}"; do
  # Vérifier si le dépôt est déjà cloné
  if [ ! -d "$REPO_NAME" ]; then
    echo "Clonage du dépôt $REPO_NAME..."
    git clone "https://github.com/$REPO_OWNER/$REPO_NAME.git"
  else
    echo "Le dépôt $REPO_NAME existe déjà, passage à l'étape suivante."
  fi

  # Dossier local du dépôt
  LOCAL_DIR="$REPO_NAME"
  
  # Créer le répertoire images_sauv à la racine du dépôt
  mkdir -p "$LOCAL_DIR/images_sauv"

  # URL de l'API GitHub pour récupérer la liste des fichiers dans le dépôt
  GITHUB_API="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents"

  # Récupérer la liste des fichiers .md dans le dépôt GitHub
  echo "Récupération des fichiers dans le dépôt $REPO_NAME..."
  FILES=$(curl -s "$GITHUB_API" | grep -oP '"path": "\K[^"]+\.md')

  # Parcourir chaque fichier .md
  for FILE in $FILES; do
    echo "Traitement du fichier: $FILE"

    # Créer un répertoire pour chaque fichier .md dans images_sauv
    MD_NAME=$(basename "$FILE" .md)
    MD_DIR="$LOCAL_DIR/images_sauv/$MD_NAME"
    mkdir -p "$MD_DIR"  # Créer un sous-dossier pour chaque fichier .md dans "images_sauv"

    # Récupérer le contenu du fichier .md depuis GitHub
    FILE_CONTENT=$(curl -s "$BASE_URL/$REPO_OWNER/$REPO_NAME/$BRANCH/$FILE")

    # Extraire les liens vers les images du contenu Markdown (les liens img src)
    IMAGE_URLS=$(echo "$FILE_CONTENT" | grep -oP '!\[.*\]\(\K[^)]+')

    # Télécharger les images
    for IMAGE_URL in $IMAGE_URLS; do
      # Afficher l'URL de l'image pour le débogage
      echo "URL de l'image: $IMAGE_URL"

      # Extraire le nom de l'image depuis l'URL (sans l'extension)
      IMAGE_NAME=$(basename "$IMAGE_URL")

      # Si l'URL ne contient pas d'extension, on va essayer de détecter le type MIME
      if [[ ! "$IMAGE_NAME" =~ \. ]]; then
        # Récupérer le type MIME de l'image en envoyant une requête HEAD
        MIME_TYPE=$(curl -sI "$IMAGE_URL" | grep -i "Content-Type" | awk -F': ' '{print $2}' | tr -d '\r')

        # Déterminer l'extension d'image à partir du type MIME
        IMAGE_EXTENSION=$(get_image_extension "$MIME_TYPE")

        # Si l'extension est inconnue, on ajoute une extension par défaut (png)
        if [[ "$IMAGE_EXTENSION" == "unknown" ]]; then
          IMAGE_EXTENSION="png"
        fi

        IMAGE_NAME="$IMAGE_NAME.$IMAGE_EXTENSION"
      fi

      # Créer un chemin local avec le nom de l'image et son extension, dans le répertoire de ce fichier .md
      IMAGE_PATH="$MD_DIR/$IMAGE_NAME"

      # Vérifier si l'image existe déjà avant de la télécharger
      if [[ ! -f "$IMAGE_PATH" ]]; then
        # Télécharger l'image en suivant les redirections avec l'option -L
        echo "Téléchargement de l'image: $IMAGE_URL"
        curl -s -L -o "$IMAGE_PATH" "$IMAGE_URL"

        # Vérifier si l'image a bien été téléchargée
        if [[ ! -s "$IMAGE_PATH" ]]; then
          echo "Erreur lors du téléchargement ou fichier vide: $IMAGE_PATH"
        fi
      else
        echo "L'image $IMAGE_NAME existe déjà, saut du téléchargement."
      fi
    done
  done

done

echo "Téléchargement terminé pour tous les dépôts."

# Attendre que l'utilisateur appuie sur une touche avant de fermer
echo "Exécution terminée. Appuyez sur une touche pour fermer."
read -n 1 -s  # Attend qu'une touche soit pressée sans afficher de caractère