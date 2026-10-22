'use client';

import { useState, type FormEvent } from 'react';
import { AuthShell, Field, FormMessage, EMAIL_PATTERN, GENERIC_ERROR, type AuthActionResult } from './Login.js';

export interface RegisterData {
  email: string;
  username: string;
  organizationName: string;
  password: string;
}

export interface RegisterProps {
  onSubmit: (data: RegisterData) => Promise<AuthActionResult>;
  onSuccess?: () => void;
  /** Recommandation par défaut : 12. À aligner sur la politique validée. */
  minPasswordLength?: number;
  successMessage?: string;
  loginHref?: string;
}

type Errors = Partial<Record<'email' | 'username' | 'organizationName' | 'password' | 'confirm', string>>;

export default function Register({
  onSubmit,
  onSuccess,
  minPasswordLength = 12,
  successMessage = 'Votre compte a été créé.',
  loginHref,
}: RegisterProps) {
  const [email, setEmail] = useState('');
  const [username, setUsername] = useState('');
  const [organizationName, setOrganizationName] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [errors, setErrors] = useState<Errors>({});
  const [formError, setFormError] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const [pending, setPending] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (pending) return;

    const next: Errors = {};
    if (!EMAIL_PATTERN.test(email.trim())) next.email = 'Adresse e-mail invalide.';
    if (username.trim().length < 3) next.username = "Le nom d'utilisateur doit contenir au moins 3 caractères.";
    if (organizationName.trim().length < 2) next.organizationName = "Indiquez le nom de l'organisation.";
    if (password.length < minPasswordLength) next.password = `Au moins ${minPasswordLength} caractères.`;
    if (confirm !== password) next.confirm = 'Les mots de passe ne correspondent pas.';
    setErrors(next);
    setFormError(null);
    if (Object.keys(next).length > 0) return;

    setPending(true);
    try {
      const result = await onSubmit({
        email: email.trim(),
        username: username.trim(),
        organizationName: organizationName.trim(),
        password,
      });
      if (result.ok) {
        setDone(true);
        onSuccess?.();
      } else {
        setFormError(result.error);
      }
    } catch {
      setFormError(GENERIC_ERROR);
    } finally {
      setPending(false);
    }
  }

  const footer = loginHref ? <a href={loginHref}>Déjà un compte ? Se connecter</a> : undefined;

  if (done) {
    return (
      <AuthShell title="Inscription" footer={footer}>
        <FormMessage kind="success">{successMessage}</FormMessage>
      </AuthShell>
    );
  }

  return (
    <AuthShell title="Inscription" subtitle="Créez votre espace CORMERY." footer={footer}>
      <form onSubmit={handleSubmit} noValidate>
        <Field label="Adresse e-mail" type="email" value={email} onChange={setEmail} error={errors.email} autoComplete="email" disabled={pending} />
        <Field label="Nom d'utilisateur" value={username} onChange={setUsername} error={errors.username} autoComplete="username" disabled={pending} />
        <Field label="Organisation" value={organizationName} onChange={setOrganizationName} error={errors.organizationName} autoComplete="organization" disabled={pending} />
        <Field label="Mot de passe" type="password" value={password} onChange={setPassword} error={errors.password} hint={`Au moins ${minPasswordLength} caractères.`} autoComplete="new-password" disabled={pending} />
        <Field label="Confirmer le mot de passe" type="password" value={confirm} onChange={setConfirm} error={errors.confirm} autoComplete="new-password" disabled={pending} />
        {formError && <FormMessage kind="error">{formError}</FormMessage>}
        <button type="submit" className="cormery-auth__submit" disabled={pending}>
          {pending ? 'Création…' : 'Créer mon compte'}
        </button>
      </form>
    </AuthShell>
  );
}