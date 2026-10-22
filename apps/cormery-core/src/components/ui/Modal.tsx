// src/components/ui/Modal.tsx
import { useCallback, useEffect, useId, useRef } from 'react';
import type { ReactNode } from 'react';
import { createPortal } from 'react-dom';

/* -------------------------------------------------------------------------- */
/*                                   Types                                    */
/* -------------------------------------------------------------------------- */

export interface ModalProps {
  /** Contrôle l'affichage de la modale. */
  isOpen: boolean;
  /** Callback déclenché sur toute demande de fermeture (ESC, clic extérieur, bouton). */
  onClose: () => void;
  /** Titre optionnel affiché dans l'en-tête. */
  title?: string;
  /** Contenu du corps de la modale. */
  children: ReactNode;
  /** Pied de modale optionnel (actions). */
  footer?: ReactNode;
  /** Empêche la fermeture par clic extérieur (défaut : `false`). */
  disableBackdropClose?: boolean;
  /** Empêche la fermeture via ESC (défaut : `false`). */
  disableEscapeClose?: boolean;
  /** Classes additionnelles appliquées au panneau de la modale. */
  className?: string;
  /** Identifiant accessible ; généré automatiquement si absent. */
  id?: string;
}

/* -------------------------------------------------------------------------- */
/*                                  Helpers                                   */
/* -------------------------------------------------------------------------- */

function cn(...classes: Array<string | false | null | undefined>): string {
  return classes.filter(Boolean).join(' ');
}

const FOCUSABLE_SELECTOR =
  'a[href], button:not([disabled]), textarea:not([disabled]), ' +
  'input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])';

/* -------------------------------------------------------------------------- */
/*                                   Modal                                    */
/* -------------------------------------------------------------------------- */

export function Modal({
  isOpen,
  onClose,
  title,
  children,
  footer,
  disableBackdropClose = false,
  disableEscapeClose = false,
  className,
  id,
}: ModalProps) {
  const generatedId = useId();
  const dialogId = id ?? `modal-${generatedId}`;
  const titleId = `${dialogId}-title`;

  const panelRef = useRef<HTMLDivElement>(null);
  const previouslyFocusedRef = useRef<HTMLElement | null>(null);

  const requestClose = useCallback(() => {
    onClose();
  }, [onClose]);

  /* -------- Écouteur clavier (Escape) + lock scroll + focus trap -------- */
  useEffect(() => {
    if (!isOpen) return;

    // Mémorise l'élément actif pour restaurer le focus à la fermeture.
    previouslyFocusedRef.current =
      document.activeElement instanceof HTMLElement ? document.activeElement : null;

    // Verrouille le scroll du body pendant l'ouverture.
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';

    // Donne le focus au premier élément focusable du panneau.
    const focusFirst = () => {
      const panel = panelRef.current;
      if (!panel) return;
      const focusable = panel.querySelector<HTMLElement>(FOCUSABLE_SELECTOR);
      (focusable ?? panel).focus();
    };
    // Raccourci d'exécution après que le portail soit monté.
    const rafId = window.requestAnimationFrame(focusFirst);

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && !disableEscapeClose) {
        event.stopPropagation();
        requestClose();
        return;
      }

      // Focus trap : Tab/Shift+Tab restent confinés dans la modale.
      if (event.key === 'Tab') {
        const panel = panelRef.current;
        if (!panel) return;
        const focusables = Array.from(
          panel.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR),
        ).filter((el) => !el.hasAttribute('disabled') && el.offsetParent !== null);

        if (focusables.length === 0) {
          event.preventDefault();
          panel.focus();
          return;
        }

        const first = focusables[0]!;
        const last = focusables[focusables.length - 1]!;
        const active = document.activeElement as HTMLElement | null;

        if (!event.shiftKey && active === last) {
          event.preventDefault();
          first.focus();
        } else if (event.shiftKey && active === first) {
          event.preventDefault();
          last.focus();
        }
      }
    };

    document.addEventListener('keydown', handleKeyDown);

    return () => {
      document.removeEventListener('keydown', handleKeyDown);
      window.cancelAnimationFrame(rafId);
      document.body.style.overflow = previousOverflow;

      // Restaure le focus au déclencheur.
      const previous = previouslyFocusedRef.current;
      if (previous && document.body.contains(previous)) {
        previous.focus();
      }
    };
  }, [isOpen, disableEscapeClose, requestClose]);

  if (!isOpen) return null;

  const handleBackdropClick = () => {
    if (!disableBackdropClose) {
      requestClose();
    }
  };

  const handlePanelClick = (event: React.MouseEvent<HTMLDivElement>) => {
    // Empêche la propagation vers le backdrop (qui déclenche la fermeture).
    event.stopPropagation();
  };

  return createPortal(
    <div
      className={cn(
        'fixed inset-0 z-50 flex items-center justify-center p-4',
        // Fond carbone profond avec flou prononcé.
        'bg-[#090A0F]/80 backdrop-blur-lg',
        'animate-[fadeIn_120ms_ease-out]',
      )}
      onClick={handleBackdropClick}
      role="presentation"
    >
      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={title != null ? titleId : undefined}
        aria-label={title == null ? 'Boîte de dialogue' : undefined}
        tabIndex={-1}
        onClick={handlePanelClick}
        className={cn(
          // Panneau "Liquid Glass Carbon Blackout"
          'relative flex w-full max-w-lg flex-col',
          'max-h-[90vh] overflow-hidden rounded-xl',
          'bg-[#11131B]/95 backdrop-blur-md',
          'border border-[#1E2230]',
          'shadow-2xl shadow-black/70',
          'text-slate-200',
          'outline-none',
          className,
        )}
      >
        {/* Liseré supérieur : réfraction subtile */}
        <div
          className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-white/10 to-transparent"
          aria-hidden="true"
        />

        {title != null && (
          <header className="flex items-start justify-between gap-3 border-b border-[#1E2230] px-5 py-3.5">
            <h2
              id={titleId}
              className="truncate font-mono text-[11px] uppercase tracking-wider text-slate-200"
            >
              {title}
            </h2>

            <div className="flex shrink-0 items-center gap-3">
              <span
                className="hidden font-mono text-[10px] uppercase tracking-wider text-slate-500 sm:inline"
                aria-hidden="true"
              >
                [ESC]
              </span>
              <button
                type="button"
                onClick={requestClose}
                aria-label="Fermer la modale"
                className={cn(
                  'inline-flex h-6 w-6 items-center justify-center rounded-md',
                  'border border-transparent text-slate-500',
                  'transition-colors duration-150',
                  'hover:border-[#2A3044] hover:bg-[#161927] hover:text-slate-200',
                  'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-700/40',
                )}
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  className="h-3.5 w-3.5"
                  aria-hidden="true"
                >
                  <path d="M18 6 6 18" />
                  <path d="m6 6 12 12" />
                </svg>
              </button>
            </div>
          </header>
        )}

        <div className="min-h-0 flex-1 overflow-y-auto px-5 py-4 text-sm leading-relaxed text-slate-300">
          {children}
        </div>

        {footer != null && (
          <footer className="flex items-center justify-end gap-2 border-t border-[#1E2230] px-5 py-3">
            {footer}
          </footer>
        )}
      </div>
    </div>,
    document.body,
  );
}

Modal.displayName = 'Modal';

export default Modal;