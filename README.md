# TP Multi-container Flask – MariaDB – Nginx

Ce projet met en œuvre une stack multi-conteneurs Docker pour déployer :
- Une base de données MariaDB,
- Une application Flask (Python) connectée à la base,
- Un reverse proxy Nginx exposé sur le port 80.

---

## Structure des réseaux

Deux réseaux Docker séparés :

- **backend_net** : communication entre l’application et la base de données (subnet : `172.31.0.0/24`).
  
  <img width="696" height="958" alt="image" src="https://github.com/user-attachments/assets/49202b9b-c515-4f00-8541-4323fb359ecc" />

- **frontend_net** : communication entre l’application et le proxy (subnet : `172.31.1.0/24`).
  
  <img width="686" height="760" alt="image" src="https://github.com/user-attachments/assets/b7405b48-fba5-40cb-9732-ade6238be810" />


---

## Fichiers principaux

### compose.yml
```yaml
Définit les services (db, app, proxy) et configure les réseaux et sous-réseaux personnalisés.

Extrait exemple :

version: '3.9'

networks:
  backend_net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.31.0.0/24
  frontend_net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.31.1.0/24

services:
  db:
    image: mariadb:latest
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: appdb
    volumes:
      - ./script/mariadb-init.sql:/docker-entrypoint-initdb.d/mariadb-init.sql
    networks:
      backend_net:
        ipv4_address: 172.31.0.3
    restart: unless-stopped

  app:
    build: ./app
    environment:
      DB_HOST: db
      DB_USER: appuser
      DB_PASS: apppass
      DB_NAME: appdb
    networks:
      backend_net:
        ipv4_address: 172.31.0.2
    restart: unless-stopped

  proxy:
    image: nginx:latest
    volumes:
      - ./proxy/nginx.conf:/etc/nginx/conf.d/default.conf:ro
    ports:
      - "80:80"
    networks:
      backend_net:
        ipv4_address: 172.31.0.4
      frontend_net:
    restart: unless-stopped
```
### Pourquoi des IP fixes pour les conteneurs
Pour garantir une sécurité maximale lors de la connexion à la base de données, une IP fixe est attribuée aux conteneurs.
Cette méthode évite toute incohérence liée au changement d'adresse IP à chaque redémarrage ou reconstruction des conteneurs.

L'utilisateur MariaDB créé dans le script SQL (fichier mariadb-init.sql) est ainsi limité à cette IP unique :
  - 172.31.0.3

Avantage : Si l'app obtenait une IP différente, elle n'aurait plus accès à la base en raison de la restriction sur l'adresse IP spécifiée.

Maintenabilité : L'affectation d'une IP fixe via Docker Compose (grâce à l'option ipv4_address dans chaque service) garantit que l'environnement reste stable, reproductible et sécurisé.

Ainsi, on s'assures que seul le conteneur souhaité puisse ouvrir une connexion à la BDD, tout en évitant des bugs difficiles à diagnostiquer liés à de potentielles fluctuations d’adresses suite à des redémarrages ou des mises à jour de la stack.​

---

### app/Dockerfile

Décrit la construction du conteneur Flask :
```py
FROM python:3.11-slim

WORKDIR /app

COPY app.py /app/

RUN pip install flask pymysql

CMD ["python", "app.py"]
```

---

## Sécurisation de la base de données

Pour empêcher tout accès direct vers la base depuis la VM, un fichier d'initialisation `mariadb-init.sql` est placé dans le dossier `script` :
```sql
CREATE USER 'appuser'@'172.31.0.2' IDENTIFIED BY 'apppass';
GRANT ALL PRIVILEGES ON appdb.* TO 'appuser'@'172.31.0.2';
FLUSH PRIVILEGES;
```

Ce script est monté dans MariaDB et appliqué au premier lancement.

- Cette configuration signifie que toutes les tentatives de connexion depuis une autre IP (autre conteneur ou depuis la VM Docker elle-même) seront refusées par MariaDB.

- La sécurité est ainsi garantie au niveau de la base et du réseau Docker.

- Il est également possible d'utiliser le nom du service au lieu de l'IP, mais pour Docker Compose et la prévisibilité réseau, le plus fiable reste l'IP fixe.

**À retenir :**  
Seul le conteneur app aura accès à la base, indépendamment des credentials. Toute autre machine ou conteneur du réseau backend_net se verra refuser la connexion.

---

## Déploiement

Construire et lancer la stack :
```
docker-compose up --build -d
```
Vérifier que les conteneurs sont bien lancés :
```
docker ps -a
```
### Gestion via interface web, Portainer :

Personnellement, j'utilise un conteneur qui permet de manager depuis une interface web (Portainer) :

<img width="1858" height="559" alt="image" src="https://github.com/user-attachments/assets/d06e7b5c-8628-42f6-a9f5-7144c13ac9fa" />

---

## BONUS : Bloquer l'accès à la base de données pour tous sauf l'app

Pour renforcer la sécurité et garantir que seule l'application ait accès à la base de données MariaDB, plusieurs mesures sont mises en place :

- Dans le fichier d'initialisation SQL (script/mariadb-init.sql), la création de l'utilisateur de la base se fait en spécifiant l'IP fixe du conteneur applicatif (par exemple 172.31.0.2) :

## Test du bonus

Je verifie que l'application est accessible depuis l'IP de la VM Docker :

<img width="446" height="143" alt="image" src="https://github.com/user-attachments/assets/67caa1d0-a6db-4d0f-8b0f-afc700b7034f" />

Je verifie l’accès à la base de données via la page web /health :

<img width="414" height="166" alt="image" src="https://github.com/user-attachments/assets/bae3b743-a4db-4473-9cac-fe9940277279" />

Ensuite je me connecte au conteneur (via Portainer) pour tester en CLI :

<img width="1490" height="431" alt="image" src="https://github.com/user-attachments/assets/956822d3-95b1-4a46-a337-25e7448fdd75" />

Execution des commandes suivantes :
```
apt update
apt install mariadb-client
```
Pour ma part c'est deja effectué en off :

<img width="706" height="228" alt="image" src="https://github.com/user-attachments/assets/9d208663-ee4c-43c8-af1a-8930c23c99d0" />

Test de la connexion à MariaDB depuis le conteneur app :
```bash
mysql -h 172.31.0.3 -u appuser -papppass
```
La connexion s'effectue correctement :

<img width="791" height="197" alt="image" src="https://github.com/user-attachments/assets/61ea5eba-0ed3-4d31-98c2-105da161adba" />



---

### Test depuis la VM hôte Docker
Effectue la même commande depuis la VM :
```bash
mysql -h 172.31.0.3 -u appuser -papppass
```
La connexion est refusée comme attendu :

<img width="937" height="115" alt="image" src="https://github.com/user-attachments/assets/d7454eed-8671-48d0-98d6-5930add08848" />







