'use client';

import { useId, useState, type FormEvent, type ReactNode } from 'react';

/* ---------- Contrat UI (proposition, pas un contrat API) ---------- */
export type AuthActionResult = { ok: true } | { ok: false; error: string };

/** Même motif que la contrainte SQL ck_users_email_format. */
export const EMAIL_PATTERN = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;

export const GENERIC_ERROR = 'Une erreur est survenue. Veuillez réessayer.';

/* ---------- Briques partagées ---------- */
export function AuthShell({
  title,
  subtitle,
  children,
  footer,
}: {
  title: string;
  subtitle?: string;
  children: ReactNode;
  footer?: ReactNode;
}) {
  return (
    <main className="cormery-auth">
      <style>{authCss}</style>
      <section className="cormery-auth__card">
        <p className="cormery-auth__brand">CORMERY</p>
        <h1 className="cormery-auth__title">{title}</h1>
        {subtitle && <p className="cormery-auth__subtitle">{subtitle}</p>}
        {children}
        {footer && <div className="cormery-auth__footer">{footer}</div>}
      </section>
    </main>
  );
}

export function Field({
  label,
  value,
  onChange,
  type = 'text',
  error,
  hint,
  autoComplete,
  disabled,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  type?: 'text' | 'email' | 'password';
  error?: string;
  hint?: string;
  autoComplete?: string;
  disabled?: boolean;
}) {
  const id = useId();
  const [shown, setShown] = useState(false);
  const isPassword = type === 'password';
  const describedBy = error ? `${id}-err` : hint ? `${id}-hint` : undefined;

  return (
    <div className="cormery-auth__field">
      <label htmlFor={id}>{label}</label>
      <div className="cormery-auth__input">
        <input
          id={id}
          type={isPassword && shown ? 'text' : type}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          autoComplete={autoComplete}
          disabled={disabled}
          aria-invalid={error ? true : undefined}
          aria-describedby={describedBy}
        />
        {isPassword && (
          <button type="button" onClick={() => setShown((s) => !s)} aria-pressed={shown}>
            {shown ? 'Masquer' : 'Afficher'}
          </button>
        )}
      </div>
      {hint && !error && (
        <p id={`${id}-hint`} className="cormery-auth__hint">
          {hint}
        </p>
      )}
      {error && (
        <p id={`${id}-err`} className="cormery-auth__fielderr" role="alert">
          {error}
        </p>
      )}
    </div>
  );
}

export function FormMessage({ kind, children }: { kind: 'error' | 'success'; children: ReactNode }) {
  return (
    <p className={`cormery-auth__msg cormery-auth__msg--${kind}`} role={kind === 'error' ? 'alert' : 'status'}>
      {children}
    </p>
  );
}

/* ---------- Login ---------- */
export interface LoginCredentials {
  email: string;
  password: string;
}

export interface LoginProps {
  /** Fourni par le parent : appelle votre système d'authentification. */
  onSubmit: (credentials: LoginCredentials) => Promise<AuthActionResult>;
  /** Appelé après un succès (ex. navigation). */
  onSuccess?: () => void;
  forgotPasswordHref?: string;
  registerHref?: string;
}

export default function Login({ onSubmit, onSuccess, forgotPasswordHref, registerHref }: LoginProps) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [errors, setErrors] = useState<{ email?: string; password?: string }>({});
  const [formError, setFormError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (pending) return;

    const next: typeof errors = {};
    if (!EMAIL_PATTERN.test(email.trim())) next.email = 'Adresse e-mail invalide.';
    if (password === '') next.password = 'Le mot de passe est requis.';
    setErrors(next);
    setFormError(null);
    if (Object.keys(next).length > 0) return;

    setPending(true);
    try {
      const result = await onSubmit({ email: email.trim(), password });
      if (result.ok) onSuccess?.();
      else setFormError(result.error);
    } catch {
      setFormError(GENERIC_ERROR);
    } finally {
      setPending(false);
    }
  }

  return (
    <AuthShell
      title="Connexion"
      subtitle="Accédez à votre espace CORMERY."
      footer={
        <>
          {forgotPasswordHref && <a href={forgotPasswordHref}>Mot de passe oublié ?</a>}
          {registerHref && <a href={registerHref}>Créer un compte</a>}
        </>
      }
    >
      <form onSubmit={handleSubmit} noValidate>
        <Field label="Adresse e-mail" type="email" value={email} onChange={setEmail} error={errors.email} autoComplete="email" disabled={pending} />
        <Field label="Mot de passe" type="password" value={password} onChange={setPassword} error={errors.password} autoComplete="current-password" disabled={pending} />
        {formError && <FormMessage kind="error">{formError}</FormMessage>}
        <button type="submit" className="cormery-auth__submit" disabled={pending}>
          {pending ? 'Connexion…' : 'Se connecter'}
        </button>
      </form>
    </AuthShell>
  );
}

/* ---------- Styles partagés (valeurs provisoires, pas un design system validé) ---------- */
export const authCss = `
.cormery-auth { min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 24px;
  background: #0a0a0b; color: #ededed; font-family: system-ui, -apple-system, 'Segoe UI', sans-serif; }
.cormery-auth__card { width: 100%; max-width: 400px; padding: 32px 28px; border-radius: 24px;
  background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.12); backdrop-filter: blur(24px); }
.cormery-auth__brand { margin: 0 0 8px; font-size: 12px; font-weight: 600; letter-spacing: 0.4em; color: #a1a1a6; }
.cormery-auth__title { margin: 0 0 4px; font-size: 24px; font-weight: 600; }
.cormery-auth__subtitle { margin: 0 0 24px; font-size: 14px; color: #a1a1a6; }
.cormery-auth__field { margin-bottom: 16px; }
.cormery-auth__field label { display: block; margin-bottom: 6px; font-size: 13px; color: #d1d1d6; }
.cormery-auth__input { position: relative; display: flex; }
.cormery-auth__input input { flex: 1; width: 100%; padding: 11px 14px; font-size: 15px; color: #ededed;
  background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.16); border-radius: 12px; }
.cormery-auth__input input:focus-visible { outline: 2px solid #ededed; outline-offset: 1px; }
.cormery-auth__input input[aria-invalid="true"] { border-color: #ff6b6b; }
.cormery-auth__input input:disabled { opacity: 0.6; }
.cormery-auth__input button { position: absolute; right: 8px; top: 50%; transform: translateY(-50%); cursor: pointer;
  padding: 4px 8px; font-size: 12px; color: #a1a1a6; background: transparent; border: 0; border-radius: 8px; }
.cormery-auth__input button:focus-visible { outline: 2px solid #ededed; }
.cormery-auth__hint { margin: 6px 0 0; font-size: 12px; color: #8e8e93; }
.cormery-auth__fielderr { margin: 6px 0 0; font-size: 12px; color: #ff8a8a; }
.cormery-auth__msg { margin: 0 0 16px; padding: 10px 12px; font-size: 13px; border-radius: 12px; }
.cormery-auth__msg--error { color: #ffb3b3; background: rgba(255,107,107,0.12); border: 1px solid rgba(255,107,107,0.35); }
.cormery-auth__msg--success { color: #c8f0d0; background: rgba(80,200,120,0.12); border: 1px solid rgba(80,200,120,0.35); }
.cormery-auth__submit { width: 100%; cursor: pointer; padding: 12px; font-size: 15px; font-weight: 600; color: #0a0a0b;
  background: #ededed; border: 0; border-radius: 999px; }
.cormery-auth__submit:disabled { opacity: 0.6; cursor: not-allowed; }
.cormery-auth__submit:focus-visible { outline: 2px solid #ededed; outline-offset: 3px; }
.cormery-auth__footer { display: flex; justify-content: space-between; gap: 12px; margin-top: 20px; font-size: 13px; }
.cormery-auth__footer a { color: #a1a1a6; text-decoration: underline; }
.cormery-auth__footer a:focus-visible { outline: 2px solid #ededed; }
@media (prefers-reduced-motion: reduce) { .cormery-auth * { transition: none !important; animation: none !important; } }
`;