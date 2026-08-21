import type { ReactNode } from 'react';

export const metadata = {
  title: 'Cormery Core',
  description: 'Espace de pilotage Cormery',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="fr">
      <body>{children}</body>
    </html>
  );
}
