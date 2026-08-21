# INDEX — Manifestes de fichiers CORMERY

**Total : 168 fichiers** répartis sur 4 manifestes.

| Manifeste | Périmètre | Nombre de fichiers |
|---|---|---|
| `00-file-manifest-shared.md` | Socle partagé (types, migrations SQL, config racine) | 18 |
| `C-file-manifest.md` | Lot C — Réseau + Setup + BDD + VENUS (Mistral) | 54 |
| `B-file-manifest.md` | Lot B — Agents IA + Sécurité + OPTIMUS + Réconciliateur (DeepSeek) | 64 |
| `A-file-manifest.md` | Lot A — Frontend + API Gateway (ChatGPT) | 32 |

## Pourquoi 168 et pas 200

J'ai calibré cette liste sur une V1 de production réaliste — chaque fichier
a une raison d'exister et un prompt actionnable. Gonfler artificiellement
à 200 aurait signifié ajouter des fichiers sans valeur réelle (ex:
sur-découper un module cohérent en 5 fichiers au lieu de 2 juste pour le
chiffre).

**Si vous voulez atteindre ~200 fichiers de façon justifiée**, les
extensions naturelles sont :
- Un fichier de test dédié par composant qui n'en a pas encore (environ
  +15 fichiers, ex: tests manquants sur les migrations SQL, les
  connecteurs VENUS individuels)
- Storybook / fichiers de documentation de composants pour chaque
  composant frontend (+13 fichiers, un par composant de
  `A-file-manifest.md`)
- Scripts de rollback SQL dédiés (un par migration, +10 fichiers)

Je peux générer ces extensions sur demande — dites-moi laquelle vous
intéresse.

## Ordre de production recommandé

1. **Socle partagé** (18 fichiers) — bloque tout le reste, à produire en
   premier
2. **Lot C** (schéma DB en particulier) — bloque les Lots A et B pour tout
   ce qui touche au stockage
3. **Lot B et Lot A** peuvent ensuite être menés en parallèle une fois le
   schéma stabilisé, en respectant strictement `00-master-coordination.md`
