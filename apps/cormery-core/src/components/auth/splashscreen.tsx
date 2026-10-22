'use client';

import { useEffect, useState } from 'react';

export type SplashStatus = 'loading' | 'ready' | 'error';

export interface SplashScreenProps {
  /** État fourni par le parent ; le splash ne le déduit jamais seul. */
  status?: SplashStatus;
  /** Durée minimale d'affichage, pour éviter un flash. */
  minDurationMs?: number;
  /** Appelé une fois le splash masqué (status 'ready' + durée minimale écoulée). */
  onComplete?: () => void;
  /** Appelé au clic sur « Réessayer » (état 'error'). */
  onRetry?: () => void;
  errorMessage?: string;
}

const FADE_OUT_MS = 400;

export default function SplashScreen({
  status = 'loading',
  minDurationMs = 1200,
  onComplete,
  onRetry,
  errorMessage = 'Impossible de démarrer CORMERY pour le moment.',
}: SplashScreenProps) {
  const [minElapsed, setMinElapsed] = useState(false);
  const [leaving, setLeaving] = useState(false);
  const [hidden, setHidden] = useState(false);

  useEffect(() => {
    const timer = setTimeout(() => setMinElapsed(true), minDurationMs);
    return () => clearTimeout(timer);
  }, [minDurationMs]);

  useEffect(() => {
    if (status !== 'ready' || !minElapsed) return;
    setLeaving(true);
    const timer = setTimeout(() => {
      setHidden(true);
      onComplete?.();
    }, FADE_OUT_MS);
    return () => clearTimeout(timer);
  }, [status, minElapsed, onComplete]);

  if (hidden) return null;

  const isError = status === 'error';

  return (
    <div
      className={`cormery-splash${leaving ? ' cormery-splash--leaving' : ''}`}
      role="status"
      aria-live="polite"
      aria-busy={!isError}
    >
      <style>{css}</style>

      <svg className="cormery-globe" viewBox="0 0 200 200" aria-hidden="true">
        <defs>
          <radialGradient id="cormery-glow" cx="50%" cy="40%" r="60%">
            <stop offset="0%" stopColor="rgba(255,255,255,0.14)" />
            <stop offset="100%" stopColor="rgba(255,255,255,0.02)" />
          </radialGradient>
        </defs>
        <circle cx="100" cy="100" r="90" fill="url(#cormery-glow)" stroke="rgba(255,255,255,0.18)" />
        <g className="cormery-globe__lines" fill="none" stroke="rgba(255,255,255,0.14)">
          <ellipse cx="100" cy="100" rx="90" ry="30" />
          <ellipse cx="100" cy="100" rx="90" ry="60" />
          <ellipse cx="100" cy="100" rx="30" ry="90" />
          <ellipse cx="100" cy="100" rx="60" ry="90" />
          <line x1="10" y1="100" x2="190" y2="100" />
        </g>
      </svg>

      <h1 className="cormery-splash__title">CORMERY</h1>

      {isError ? (
        <div className="cormery-splash__error">
          <p>{errorMessage}</p>
          {onRetry && (
            <button type="button" onClick={onRetry}>
              Réessayer
            </button>
          )}
        </div>
      ) : (
        <>
          <p className="cormery-splash__label">Chargement…</p>
          <div className="cormery-splash__bar" aria-hidden="true">
            <span />
          </div>
        </>
      )}
    </div>
  );
}

const css = `
.cormery-splash {
  position: fixed; inset: 0; z-index: 9999;
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: 20px; background: #0a0a0b; color: #ededed;
  font-family: system-ui, -apple-system, 'Segoe UI', sans-serif;
  opacity: 1; transition: opacity ${FADE_OUT_MS}ms ease;
}
.cormery-splash--leaving { opacity: 0; }
.cormery-globe { width: 160px; height: 160px; filter: drop-shadow(0 0 40px rgba(255,255,255,0.06)); }
.cormery-globe__lines { transform-origin: 100px 100px; animation: cormery-spin 24s linear infinite; }
.cormery-splash__title { margin: 0; font-size: 20px; font-weight: 600; letter-spacing: 0.4em; padding-left: 0.4em; }
.cormery-splash__label { margin: 0; font-size: 13px; color: #a1a1a6; }
.cormery-splash__bar {
  width: 160px; height: 2px; overflow: hidden; border-radius: 2px;
  background: rgba(255,255,255,0.1);
}
.cormery-splash__bar span {
  display: block; width: 40%; height: 100%; border-radius: 2px;
  background: rgba(255,255,255,0.7); animation: cormery-slide 1.4s ease-in-out infinite;
}
.cormery-splash__error {
  display: flex; flex-direction: column; align-items: center; gap: 12px;
  padding: 16px 20px; max-width: 320px; text-align: center; font-size: 14px;
  background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.14);
  border-radius: 16px; backdrop-filter: blur(20px);
}
.cormery-splash__error p { margin: 0; color: #d1d1d6; }
.cormery-splash__error button {
  cursor: pointer; padding: 8px 18px; border-radius: 999px; font-size: 13px;
  color: #ededed; background: rgba(255,255,255,0.1); border: 1px solid rgba(255,255,255,0.2);
}
.cormery-splash__error button:focus-visible { outline: 2px solid #ededed; outline-offset: 2px; }
@keyframes cormery-spin { to { transform: rotate(360deg); } }
@keyframes cormery-slide { 0% { transform: translateX(-100%); } 100% { transform: translateX(250%); } }
@media (prefers-reduced-motion: reduce) {
  .cormery-globe__lines, .cormery-splash__bar span { animation: none; }
  .cormery-splash { transition: none; }
}
`;