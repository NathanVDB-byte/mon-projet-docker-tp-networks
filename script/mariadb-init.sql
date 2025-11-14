CREATE USER 'utilisateurapp'@'172.31.0.2' IDENTIFIED BY 'apppassword';
GRANT ALL PRIVILEGES ON bdd.* TO 'utilisateurapp'@'172.31.0.2';
FLUSH PRIVILEGES;
