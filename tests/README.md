# Tests

| Dossier | Rôle |
|---|---|
| `unit/` | Tests unitaires transverses |
| `integration/` | Intégration entre packages / services |
| `contract/` | Contrats d’interface |
| `e2e/` | Playwright (config racine `playwright.config.ts`) |
| `load/` | Charge |
| `stress/` | Stress |
| `security/` | Tests de sécurité |
| `data-quality/` | Qualité des données |
| `ai-evaluation/` | Évaluation des modèles IA |

Les scripts `pnpm test` (turbo) et `npx playwright test` restent les process existants.
