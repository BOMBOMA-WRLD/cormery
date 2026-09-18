import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true, // Permet d'utiliser describe, test, expect sans les importer
    environment: 'node', // Environnement d'exécution (Node.js)
    include: [
      'src/**/*.spec.ts',
      'src/**/*.test.ts',
      'tests/unit/**/*.spec.ts',
      'tests/unit/**/*.test.ts',
      'packages/**/*.spec.ts',
      'packages/**/*.test.ts',
    ],
    coverage: {
      provider: 'v8', // Génération du rapport de couverture de code
    },
  },
});
