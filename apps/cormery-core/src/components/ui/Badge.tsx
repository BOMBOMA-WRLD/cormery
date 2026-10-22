// src/components/ui/Badge.tsx
import { forwardRef } from 'react';
import type { HTMLAttributes, ReactNode } from 'react';

/* -------------------------------------------------------------------------- */
/*                                   Types                                    */
/* -------------------------------------------------------------------------- */

export type BadgeVariant = 'emerald' | 'amber' | 'rose' | 'slate' | 'blue';
export type BadgeSize = 'sm' | 'md';

type SpanAttrs = Omit<HTMLAttributes<HTMLSpanElement>, 'children' | 'className'>;

interface CommonProps extends SpanAttrs {
  size?: BadgeSize;
  className?: string;
}

/**
 * Mode texte : affichage de statuts système (`variant`).
 */
export interface TextBadgeProps extends CommonProps {
  variant?: BadgeVariant;
  children: ReactNode;
  opportunityIndex?: undefined;
  opportunityAbsent?: undefined;
}

/**
 * Mode indice d'opportunité : échelle stricte 0–100.
 * - `null` → données indisponibles (NON converti en 0).
 * - `0`    → valeur nulle explicite (état distinct).
 * - `1–100` → bande de couleur conventionnelle.
 */
export interface OpportunityBadgeProps extends CommonProps {
  opportunityIndex: number | null;
  children?: undefined;
  opportunityAbsent?: undefined;
}

/**
 * Mode absence d'opportunité : état distinct de "données indisponibles".
 */
export interface AbsentOpportunityBadgeProps extends CommonProps {
  opportunityAbsent: true;
  children?: undefined;
  opportunityIndex?: undefined;
}

export type BadgeProps =
  | TextBadgeProps
  | OpportunityBadgeProps
  | AbsentOpportunityBadgeProps;

/* -------------------------------------------------------------------------- */
/*                                  Helpers                                   */
/* -------------------------------------------------------------------------- */

function cn(...classes: Array<string | false | null | undefined>): string {
  return classes.filter(Boolean).join(' ');
}

/* -------------------------------------------------------------------------- */
/*                                  Styles                                    */
/* -------------------------------------------------------------------------- */

const baseStyles =
  'inline-flex items-center justify-center gap-1 leading-none ' +
  'rounded-md border font-mono uppercase tracking-wider ' +
  'select-none whitespace-nowrap ' +
  'transition-colors duration-150';

const sizeStyles: Record<BadgeSize, string> = {
  sm: 'h-5 px-1.5 text-[10px]',
  md: 'h-6 px-2 text-[11px]',
};

/** Palette pour le mode texte (`variant`). */
const variantStyles: Record<BadgeVariant, string> = {
  emerald: 'bg-emerald-950/40 text-emerald-300 border-emerald-800/60',
  amber: 'bg-amber-950/40   text-amber-300   border-amber-800/60',
  rose: 'bg-rose-950/40    text-rose-300    border-rose-800/60',
  slate: 'bg-slate-900/60   text-slate-300   border-slate-700/60',
  blue: 'bg-blue-950/40    text-blue-300    border-blue-800/60',
};

/** État "données indisponibles" — bordure en pointillés, ton neutre. */
const missingDataStyles =
  'bg-slate-950/40 text-slate-400 border-slate-700/60 border-dashed';

/** État "absence d'opportunité" — distinct de "données indisponibles". */
const absentOpportunityStyles =
  'bg-slate-950/40 text-slate-500 border-slate-800/50 italic';

/* -------------------------------------------------------------------------- */
/*                     Résolution de l'indice d'opportunité                   */
/* -------------------------------------------------------------------------- */

interface OpportunityBand {
  className: string;
  /** Description sémantique utilisée dans `title`/`aria-label`. */
  description: string;
}

/**
 * Code couleur conventionnel strict, conforme à la charte
 * *Liquid Glass Carbon Blackout* :
 *   90–100 : émeraude (très forte)
 *   75–89  : lime    (forte)
 *   60–74  : ambre   (intéressante)
 *   40–59  : orange  (moyenne)
 *   20–39  : rouge   (faible)
 *   1–19   : rose    (très faible)
 *   0      : ardoise (valeur nulle **explicite**, distincte des données manquantes)
 */
function resolveOpportunityBand(index: number): OpportunityBand {
  if (index >= 90) {
    return {
      className: 'bg-emerald-950/40 text-emerald-300 border-emerald-800/60',
      description: 'Très forte opportunité',
    };
  }
  if (index >= 75) {
    return {
      className: 'bg-lime-950/40 text-lime-300 border-lime-800/60',
      description: 'Forte opportunité',
    };
  }
  if (index >= 60) {
    return {
      className: 'bg-amber-950/40 text-amber-300 border-amber-800/60',
      description: 'Opportunité intéressante',
    };
  }
  if (index >= 40) {
    return {
      className: 'bg-orange-950/40 text-orange-300 border-orange-800/60',
      description: 'Opportunité moyenne',
    };
  }
  if (index >= 20) {
    return {
      className: 'bg-red-950/40 text-red-300 border-red-800/60',
      description: 'Faible opportunité',
    };
  }
  if (index >= 1) {
    return {
      className: 'bg-rose-950/50 text-rose-300 border-rose-800/60',
      description: 'Très faible opportunité',
    };
  }
  return {
    className: 'bg-slate-900/60 text-slate-300 border-slate-700/60',
    description: 'Valeur nulle explicite',
  };
}

/**
 * Valide et borne l'indice sur [0, 100].
 * - `NaN` / `Infinity` → `null` (traité comme donnée indisponible).
 * - Hors-bornes → avertit en dev et clampe.
 * - Décimales → arrondies (l'indice est conceptuellement entier).
 */
function normalizeIndex(value: number): number | null {
  if (!Number.isFinite(value)) {
    if (process.env.NODE_ENV !== 'production') {
      // eslint-disable-next-line no-console
      console.warn(
        `[Badge] opportunityIndex invalide (${String(value)}). Rendu en mode "données indisponibles".`,
      );
    }
    return null;
  }
  if (value < 0 || value > 100) {
    if (process.env.NODE_ENV !== 'production') {
      // eslint-disable-next-line no-console
      console.warn(
        `[Badge] opportunityIndex hors bornes (${value}). Clampé sur [0, 100].`,
      );
    }
  }
  return Math.round(Math.max(0, Math.min(100, value)));
}

/* -------------------------------------------------------------------------- */
/*                                   Badge                                    */
/* -------------------------------------------------------------------------- */

export const Badge = forwardRef<HTMLSpanElement, BadgeProps>(function Badge(props, ref) {
  const { size = 'md', className } = props;

  /* -------- Mode indice d'opportunité -------- */
  if (props.opportunityIndex !== undefined) {
    const {
      opportunityIndex,
      children: _children,
      opportunityAbsent: _oa,
      ...attrs
    } = props;

    // Données indisponibles : NE JAMAIS convertir en zéro.
    if (opportunityIndex === null) {
      return (
        <span
          {...attrs}
          ref={ref}
          title="Données indisponibles"
          aria-label="Indice d'opportunité indisponible"
          className={cn(baseStyles, sizeStyles[size], missingDataStyles, className)}
        >
          N/D
        </span>
      );
    }

    const index = normalizeIndex(opportunityIndex);

    // Valeur non numérique → rendu comme donnée indisponible.
    if (index === null) {
      return (
        <span
          {...attrs}
          ref={ref}
          title="Données indisponibles"
          aria-label="Indice d'opportunité indisponible"
          className={cn(baseStyles, sizeStyles[size], missingDataStyles, className)}
        >
          N/D
        </span>
      );
    }

    const band = resolveOpportunityBand(index);

    return (
      <span
        {...attrs}
        ref={ref}
        title={`Indice d'opportunité : ${index}/100 — ${band.description}`}
        aria-label={`Indice d'opportunité : ${index} sur 100 — ${band.description}`}
        className={cn(baseStyles, sizeStyles[size], band.className, className)}
      >
        {index}
      </span>
    );
  }

  /* -------- Mode absence d'opportunité -------- */
  if (props.opportunityAbsent === true) {
    const {
      opportunityAbsent: _oa,
      opportunityIndex: _oi,
      children: _children,
      ...attrs
    } = props;

    return (
      <span
        {...attrs}
        ref={ref}
        title="Aucune opportunité"
        aria-label="Aucune opportunité"
        className={cn(
          baseStyles,
          sizeStyles[size],
          absentOpportunityStyles,
          className,
        )}
      >
        AUCUNE
      </span>
    );
  }

  /* -------- Mode texte (variant) -------- */
  const {
    variant = 'slate',
    children,
    opportunityIndex: _oi,
    opportunityAbsent: _oa,
    ...attrs
  } = props;

  return (
    <span
      {...attrs}
      ref={ref}
      className={cn(baseStyles, sizeStyles[size], variantStyles[variant], className)}
    >
      {children}
    </span>
  );
});

Badge.displayName = 'Badge';

export default Badge;