# Projet administration sytème et réseau
Mise en place d'un système de gestion d’utilisateurs et de groupes, basé sur MySQL et sur un annuaire LDAP

## Liste des fonctionnalités développées:

- Les données concernant les utilisateurs et les groupes sont stockées dans un système d’information représenté par une base de données MySQL

- Les informations présentes dans l’annuaire LDAP sont automatiquement synchronisées sur le serveur de base de données

- Toute modification effectuée dans le système d’information est répliquée dans l’annuaire LDAP

- Les clients utilisent le serveur LDAP pour l’authentification et leur appartenance aux groupes

- Un utilisateur ne peut plus se connecter si sa date de fin de séjour est dépassée
