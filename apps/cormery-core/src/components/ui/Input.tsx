// src/components/ui/Input.tsx
import { forwardRef, useId } from 'react';
import type { InputHTMLAttributes, ReactNode } from 'react';

/* -------------------------------------------------------------------------- */
/*                                   Types                                    */
/* -------------------------------------------------------------------------- */

export interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  /** Libellé affiché au-dessus du champ (mono, uppercase, taille réduite). */
  label?: string;
  /** Message d'erreur affiché sous le champ. Prioritaire sur `hint`. */
  error?: string;
  /** Texte d'aide affiché sous le champ en l'absence d'erreur. */
  hint?: string;
  /** Icône optionnelle à gauche du champ de saisie. */
  leftIcon?: ReactNode;
  /** Icône optionnelle à droite du champ de saisie. */
  rightIcon?: ReactNode;
  /** Classe appliquée au wrapper externe (utile pour `w-full`, marges, etc.). */
  containerClassName?: string;
}

/* -------------------------------------------------------------------------- */
/*                                  Helpers                                   */
/* -------------------------------------------------------------------------- */

function cn(...classes: Array<string | false | null | undefined>): string {
  return classes.filter(Boolean).join(' ');
}

/* -------------------------------------------------------------------------- */
/*                               Styles Tailwind                              */
/* -------------------------------------------------------------------------- */

const baseInputStyles =
  'w-full bg-[#11131B] text-slate-100 placeholder:text-slate-500 ' +
  'border rounded-md transition-colors duration-150 ease-out ' +
  'focus:outline-none ' +
  'disabled:cursor-not-allowed disabled:opacity-60 disabled:bg-[#0D0F16] ' +
  'read-only:text-slate-400';

const sizeStyles = 'h-10 px-3 text-sm';

const iconPaddingStyles = {
  none: '',
  left: 'pl-10',
  right: 'pr-10',
  both: 'pl-10 pr-10',
} as const;

const stateStyles = {
  default:
    'border-[#1E2230] ' +
    'hover:border-[#2A3044] ' +
    'focus:border-emerald-700/70 focus:ring-1 focus:ring-emerald-700/40 ' +
    'focus:shadow-[0_0_0_1px_rgba(16,185,129,0.15)]',
  error:
    'border-red-900/70 text-red-50 ' +
    'hover:border-red-800/80 ' +
    'focus:border-red-700 focus:ring-1 focus:ring-red-700/40 ' +
    'focus:shadow-[0_0_0_1px_rgba(239,68,68,0.15)]',
} as const;

/* -------------------------------------------------------------------------- */
/*                                  Input                                     */
/* -------------------------------------------------------------------------- */

export const Input = forwardRef<HTMLInputElement, InputProps>(function Input(
  {
    id,
    label,
    error,
    hint,
    leftIcon,
    rightIcon,
    containerClassName,
    className,
    disabled,
    readOnly,
    'aria-describedby': ariaDescribedBy,
    'aria-invalid': ariaInvalid,
    ...rest
  },
  ref,
) {
  const generatedId = useId();
  const inputId = id ?? `input-${generatedId}`;
  const errorId = `${inputId}-error`;
  const hintId = `${inputId}-hint`;

  const hasError = Boolean(error);
  const helperId = hasError ? errorId : hint ? hintId : undefined;

  const describedBy = [ariaDescribedBy, helperId].filter(Boolean).join(' ') || undefined;

  const paddingKey: keyof typeof iconPaddingStyles = leftIcon
    ? rightIcon
      ? 'both'
      : 'left'
    : rightIcon
      ? 'right'
      : 'none';

  return (
    <div className={cn('flex flex-col gap-1.5', containerClassName)}>
      {label != null && (
        <label
          htmlFor={inputId}
          className="font-mono text-[11px] uppercase tracking-wider text-slate-400 select-none"
        >
          {label}
        </label>
      )}

      <div className="relative">
        {leftIcon != null && (
          <span
            className="pointer-events-none absolute inset-y-0 left-0 flex w-9 items-center justify-center text-slate-500"
            aria-hidden="true"
          >
            {leftIcon}
          </span>
        )}

        <input
          {...rest}
          ref={ref}
          id={inputId}
          disabled={disabled}
          readOnly={readOnly}
          aria-invalid={hasError ? true : ariaInvalid}
          aria-describedby={describedBy}
          className={cn(
            baseInputStyles,
            sizeStyles,
            iconPaddingStyles[paddingKey],
            hasError ? stateStyles.error : stateStyles.default,
            className,
          )}
        />

        {rightIcon != null && (
          <span
            className="pointer-events-none absolute inset-y-0 right-0 flex w-9 items-center justify-center text-slate-500"
            aria-hidden="true"
          >
            {rightIcon}
          </span>
        )}
      </div>

      {hasError ? (
        <p
          id={errorId}
          role="alert"
          className="font-mono text-[11px] leading-relaxed text-red-400"
        >
          {error}
        </p>
      ) : hint ? (
        <p
          id={hintId}
          className="font-mono text-[11px] leading-relaxed text-slate-500"
        >
          {hint}
        </p>
      ) : null}
    </div>
  );
});

Input.displayName = 'Input';

export default Input;