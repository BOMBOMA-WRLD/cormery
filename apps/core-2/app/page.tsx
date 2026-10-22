const workspaces = [
  ['workspace', 'Workspace'],
  ['products', 'Produits'],
  ['opportunities', 'Opportunités'],
  ['markets', 'Marchés'],
  ['scenarios', 'Scénarios'],
  ['actions', 'Actions'],
  ['settings', 'Paramètres'],
] as const;

export default function HomePage() {
  return (
    <main>
      <h1>Cormery Core</h1>
      <nav aria-label="Navigation principale">
        {workspaces.map(([href, label]) => (
          <a key={href} href={`/${href}`}>
            {label}
          </a>
        ))}
      </nav>
    </main>
  );
}
