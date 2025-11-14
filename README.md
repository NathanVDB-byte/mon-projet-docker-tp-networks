# TP Multi-container Flask – MariaDB – Nginx

Ce projet met en œuvre une stack multi-conteneurs Docker pour déployer :
- Une base de données MariaDB,
- Une application Flask (Python) connectée à la base,
- Un reverse proxy Nginx exposé sur le port 80.

---

## Structure des réseaux

Deux réseaux Docker séparés :

- **backend_net** : communication entre l’application et la base de données (subnet : `172.31.0.0/24`).
- **frontend_net** : communication entre l’application et le proxy (subnet : `172.31.1.0/24`).

---

## Déploiement

Construire et lancer la stack :

docker-compose up --build -d


---

## Fichiers principaux

### compose.yml
'
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
'

---

### app/Dockerfile

Décrit la construction du conteneur Flask :

FROM python:3.11-slim

WORKDIR /app

COPY app.py /app/

RUN pip install flask pymysql

CMD ["python", "app.py"]


---

## Sécurisation de la base de données

Pour empêcher tout accès direct vers la base depuis la VM, un fichier d'initialisation `mariadb-init.sql` est placé dans le dossier `script` :

CREATE USER 'appuser'@'172.31.0.2' IDENTIFIED BY 'apppass';
GRANT ALL PRIVILEGES ON appdb.* TO 'appuser'@'172.31.0.2';
FLUSH PRIVILEGES;


Ce script est monté dans MariaDB et appliqué au premier lancement.

---
