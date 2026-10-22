// src/components/ui/Button.tsx
import { forwardRef } from 'react';
import type { ButtonHTMLAttributes, ReactNode } from 'react';

/* -------------------------------------------------------------------------- */
/*                                   Types                                    */
/* -------------------------------------------------------------------------- */

export type ButtonVariant = 'primary' | 'secondary' | 'outline' | 'ghost' | 'danger';
export type ButtonSize = 'sm' | 'md' | 'lg';

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  /** Style visuel du bouton. */
  variant?: ButtonVariant;
  /** Taille du bouton (impacte hauteur, padding et typographie). */
  size?: ButtonSize;
  /** Affiche un spinner et désactive l'interaction. */
  isLoading?: boolean;
  /** Icône affichée avant le libellé. */
  leftIcon?: ReactNode;
  /** Icône affichée après le libellé. */
  rightIcon?: ReactNode;
  /** Étire le bouton sur toute la largeur du parent. */
  fullWidth?: boolean;
  /** Force la police mono (libellés techniques / valeurs numériques). */
  mono?: boolean;
}

/* -------------------------------------------------------------------------- */
/*                                   Styles                                   */
/* -------------------------------------------------------------------------- */

const baseStyles =
  'relative inline-flex items-center justify-center ' +
  'font-medium select-none whitespace-nowrap ' +
  'rounded-md border transition-colors duration-150 ease-out ' +
  'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 ' +
  'focus-visible:ring-offset-[#0A0B10] ' +
  'disabled:cursor-not-allowed disabled:opacity-50 disabled:pointer-events-none';

const variantStyles: Record<ButtonVariant, string> = {
  primary:
    'bg-emerald-950/40 text-emerald-300 border-emerald-800/60 ' +
    'hover:bg-emerald-900/50 hover:border-emerald-700 hover:text-emerald-200 ' +
    'active:bg-emerald-900/70 ' +
    'focus-visible:ring-emerald-500/50 ' +
    'shadow-[0_1px_2px_rgba(0,0,0,0.45),inset_0_0_0_1px_rgba(16,185,129,0.04)]',

  secondary:
    'bg-[#11131B] text-slate-200 border-[#1E2230] ' +
    'hover:bg-[#161927] hover:border-[#262B3D] hover:text-slate-100 ' +
    'active:bg-[#0D0F16] ' +
    'focus-visible:ring-slate-500/40',

  outline:
    'bg-transparent text-slate-300 border-[#2A2F42] ' +
    'hover:bg-[#11131B] hover:border-[#3A4058] hover:text-white ' +
    'active:bg-[#0D0F16] ' +
    'focus-visible:ring-slate-500/40',

  ghost:
    'bg-transparent text-slate-300 border-transparent ' +
    'hover:bg-[#11131B] hover:text-white ' +
    'active:bg-[#0D0F16] ' +
    'focus-visible:ring-slate-500/40',

  danger:
    'bg-red-950/40 text-red-300 border-red-900/60 ' +
    'hover:bg-red-900/50 hover:border-red-800 hover:text-red-200 ' +
    'active:bg-red-900/70 ' +
    'focus-visible:ring-red-500/50',
};

const sizeStyles: Record<ButtonSize, string> = {
  sm: 'h-8 px-3 text-xs gap-1.5',
  md: 'h-10 px-4 text-sm gap-2',
  lg: 'h-12 px-6 text-base gap-2.5',
};

const spinnerSizeStyles: Record<ButtonSize, string> = {
  sm: 'h-3 w-3',
  md: 'h-4 w-4',
  lg: 'h-5 w-5',
};

/* -------------------------------------------------------------------------- */
/*                                  Helpers                                   */
/* -------------------------------------------------------------------------- */

function cn(...classes: Array<string | false | null | undefined>): string {
  return classes.filter(Boolean).join(' ');
}

/* -------------------------------------------------------------------------- */
/*                                  Spinner                                   */
/* -------------------------------------------------------------------------- */

interface SpinnerProps {
  className?: string;
}

function Spinner({ className }: SpinnerProps) {
  return (
    <svg
      className={cn('animate-spin', className)}
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
      focusable="false"
    >
      <circle
        cx="12"
        cy="12"
        r="10"
        stroke="currentColor"
        strokeWidth="3"
        className="opacity-25"
      />
      <path
        fill="currentColor"
        className="opacity-90"
        d="M4 12a8 8 0 0 1 8-8v3a5 5 0 0 0-5 5H4z"
      />
    </svg>
  );
}

/* -------------------------------------------------------------------------- */
/*                                  Button                                    */
/* -------------------------------------------------------------------------- */

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  {
    variant = 'secondary',
    size = 'md',
    isLoading = false,
    leftIcon,
    rightIcon,
    fullWidth = false,
    mono = false,
    disabled,
    className,
    children,
    type = 'button',
    ...rest
  },
  ref,
) {
  const isDisabled = disabled || isLoading;

  return (
    <button
      {...rest}
      ref={ref}
      type={type}
      disabled={isDisabled}
      aria-busy={isLoading || undefined}
      aria-disabled={isDisabled || undefined}
      data-loading={isLoading || undefined}
      data-variant={variant}
      className={cn(
        baseStyles,
        variantStyles[variant],
        sizeStyles[size],
        fullWidth && 'w-full',
        mono && 'font-mono tracking-tight',
        className,
      )}
    >
      {isLoading ? (
        <>
          <Spinner className={spinnerSizeStyles[size]} />
          {children != null && (
            <span className="inline-flex items-center">{children}</span>
          )}
          <span className="sr-only">Chargement en cours</span>
        </>
      ) : (
        <>
          {leftIcon != null && (
            <span className="inline-flex shrink-0 items-center" aria-hidden="true">
              {leftIcon}
            </span>
          )}
          {children != null && (
            <span className="inline-flex items-center">{children}</span>
          )}
          {rightIcon != null && (
            <span className="inline-flex shrink-0 items-center" aria-hidden="true">
              {rightIcon}
            </span>
          )}
        </>
      )}
    </button>
  );
});

Button.displayName = 'Button';

export default Button;