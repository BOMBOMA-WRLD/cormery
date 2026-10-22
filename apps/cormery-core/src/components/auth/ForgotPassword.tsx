'use client';

import { useState, type FormEvent } from 'react';
import { AuthShell, Field, FormMessage, EMAIL_PATTERN, GENERIC_ERROR, type AuthActionResult } from './Login';

export interface ForgotPasswordProps {
  onSubmit: (data: { email: string }) => Promise<AuthActionResult>;
  loginHref?: string;
}

export default function ForgotPassword({ onSubmit, loginHref }: ForgotPasswordProps) {
  const [email, setEmail] = useState('');
  const [error, setError] = useState<string | undefined>();
  const [formError, setFormError] = useState<string | null>(null);
  const [sent, setSent] = useState(false);
  const [pending, setPending] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (pending) return;

    if (!EMAIL_PATTERN.test(email.trim())) {
      setError('Adresse e-mail invalide.');
      return;
    }
    setError(undefined);
    setFormError(null);

    setPending(true);
    try {
      const result = await onSubmit({ email: email.trim() });
      // Message identique que le compte existe ou non (anti-énumération).
      if (result.ok) setSent(true);
      else setFormError(result.error);
    } catch {
      setFormError(GENERIC_ERROR);
    } finally {
      setPending(false);
    }
  }

  const footer = loginHref ? <a href={loginHref}>Retour à la connexion</a> : undefined;

  if (sent) {
    return (
      <AuthShell title="Mot de passe oublié" footer={footer}>
        <FormMessage kind="success">
          Si un compte correspond à cette adresse, un message de réinitialisation vient d'être envoyé.
        </FormMessage>
      </AuthShell>
    );
  }

  return (
    <AuthShell title="Mot de passe oublié" subtitle="Saisissez votre adresse e-mail pour recevoir un lien." footer={footer}>
      <form onSubmit={handleSubmit} noValidate>
        <Field label="Adresse e-mail" type="email" value={email} onChange={setEmail} error={error} autoComplete="email" disabled={pending} />
        {formError && <FormMessage kind="error">{formError}</FormMessage>}
        <button type="submit" className="cormery-auth__submit" disabled={pending}>
          {pending ? 'Envoi…' : 'Envoyer le lien'}
        </button>
      </form>
    </AuthShell>
  );
}