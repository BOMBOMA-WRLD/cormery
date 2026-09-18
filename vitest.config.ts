import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true, // Permet d'utiliser describe, test, expect sans les importer
    environment: 'node', // Environnement d'exécution (Node.js)
    include: ['src/**/*.spec.ts', 'src/**/*.test.ts'], // Pattern de détection des tests
    coverage: {
      provider: 'v8', // Génération du rapport de couverture de code
    },
  },
});
