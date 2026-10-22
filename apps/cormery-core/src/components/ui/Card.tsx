// src/components/ui/Card.tsx
import type { HTMLAttributes, ReactNode } from 'react';

/* -------------------------------------------------------------------------- */
/*                                   Types                                    */
/* -------------------------------------------------------------------------- */

export interface CardProps extends HTMLAttributes<HTMLDivElement> {
  /** Contenu principal de la carte. */
  children: ReactNode;
  /** Titre affiché en en-tête (mono, uppercase). */
  title?: string;
  /** Sous-titre explicatif affiché sous le titre. */
  subtitle?: string;
  /** Élément placé à droite de l'en-tête (badge, bouton, filtre…). */
  headerAction?: ReactNode;
  /** Pied de carte optionnel, séparé par une bordure discrète. */
  footer?: ReactNode;
  /** Désactive le padding du corps (utile pour tables/graphs full-bleed). */
  noPadding?: boolean;
  /** Classes additionnelles appliquées au conteneur racine. */
  className?: string;
}

/* -------------------------------------------------------------------------- */
/*                                  Helpers                                   */
/* -------------------------------------------------------------------------- */

function cn(...classes: Array<string | false | null | undefined>): string {
  return classes.filter(Boolean).join(' ');
}

/* -------------------------------------------------------------------------- */
/*                                   Card                                     */
/* -------------------------------------------------------------------------- */

export function Card({
  children,
  title,
  subtitle,
  headerAction,
  footer,
  noPadding = false,
  className,
  ...rest
}: CardProps) {
  const hasHeader = title != null || subtitle != null || headerAction != null;

  return (
    <div
      {...rest}
      className={cn(
        // Base "Liquid Glass Carbon Blackout"
        'relative overflow-hidden rounded-xl',
        'bg-[#11131B]/80 backdrop-blur-md',
        'border border-[#1E2230]',
        'shadow-2xl shadow-black/60',
        'text-slate-200',
        className,
      )}
    >
      {/* Liseré supérieur : suggère la réfraction du verre */}
      <div
        className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-white/10 to-transparent"
        aria-hidden="true"
      />

      {hasHeader && (
        <div className="flex items-start justify-between gap-3 border-b border-[#1E2230] px-5 py-3.5">
          <div className="min-w-0">
            {title != null && (
              <h3 className="truncate font-mono text-[11px] uppercase tracking-wider text-slate-200">
                {title}
              </h3>
            )}
            {subtitle != null && (
              <p className="mt-0.5 text-xs leading-relaxed text-slate-500">
                {subtitle}
              </p>
            )}
          </div>

          {headerAction != null && (
            <div className="flex shrink-0 items-center">{headerAction}</div>
          )}
        </div>
      )}

      <div className={cn(!noPadding && 'p-5')}>{children}</div>

      {footer != null && (
        <div className="border-t border-[#1E2230] px-5 py-3">{footer}</div>
      )}
    </div>
  );
}

Card.displayName = 'Card';

export default Card;