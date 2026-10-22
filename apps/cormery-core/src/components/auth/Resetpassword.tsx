'use client';

import { useState, type FormEvent } from 'react';
import { AuthShell, Field, FormMessage, GENERIC_ERROR, type AuthActionResult } from './Login.js';

export interface ResetPasswordProps {
  /** Jeton extrait de l'URL par la page parente. Jamais stocké par ce composant. */
  token: string | null | undefined;
  onSubmit: (data: { token: string; password: string }) => Promise<AuthActionResult>;
  minPasswordLength?: number;
  loginHref?: string;
  forgotPasswordHref?: string;
}

export default function ResetPassword({
  token,
  onSubmit,
  minPasswordLength = 12,
  loginHref,
  forgotPasswordHref,
}: ResetPasswordProps) {
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [errors, setErrors] = useState<{ password?: string; confirm?: string }>({});
  const [formError, setFormError] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const [pending, setPending] = useState(false);

  if (!token) {
    return (
      <AuthShell
        title="Lien invalide"
        footer={forgotPasswordHref ? <a href={forgotPasswordHref}>Demander un nouveau lien</a> : undefined}
      >
        <FormMessage kind="error">Ce lien de réinitialisation est invalide ou incomplet.</FormMessage>
      </AuthShell>
    );
  }

  const footer = loginHref ? <a href={loginHref}>Retour à la connexion</a> : undefined;

  if (done) {
    return (
      <AuthShell title="Mot de passe modifié" footer={footer}>
        <FormMessage kind="success">Votre mot de passe a été modifié. Vous pouvez vous connecter.</FormMessage>
      </AuthShell>
    );
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (pending || !token) return;

    const next: typeof errors = {};
    if (password.length < minPasswordLength) next.password = `Au moins ${minPasswordLength} caractères.`;
    if (confirm !== password) next.confirm = 'Les mots de passe ne correspondent pas.';
    setErrors(next);
    setFormError(null);
    if (Object.keys(next).length > 0) return;

    setPending(true);
    try {
      const result = await onSubmit({ token, password });
      if (result.ok) setDone(true);
      else setFormError(result.error); // ex. lien expiré ou déjà utilisé, formulé par le parent
    } catch {
      setFormError(GENERIC_ERROR);
    } finally {
      setPending(false);
    }
  }

  return (
    <AuthShell title="Nouveau mot de passe" subtitle="Choisissez un nouveau mot de passe." footer={footer}>
      <form onSubmit={handleSubmit} noValidate>
        <Field label="Nouveau mot de passe" type="password" value={password} onChange={setPassword} error={errors.password} hint={`Au moins ${minPasswordLength} caractères.`} autoComplete="new-password" disabled={pending} />
        <Field label="Confirmer le mot de passe" type="password" value={confirm} onChange={setConfirm} error={errors.confirm} autoComplete="new-password" disabled={pending} />
        {formError && <FormMessage kind="error">{formError}</FormMessage>}
        <button type="submit" className="cormery-auth__submit" disabled={pending}>
          {pending ? 'Enregistrement…' : 'Modifier le mot de passe'}
        </button>
      </form>
    </AuthShell>
  );
}