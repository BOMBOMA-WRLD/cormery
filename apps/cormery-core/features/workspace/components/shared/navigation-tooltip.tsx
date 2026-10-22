import type {ReactNode} from 'react';
export function NavigationTooltip({label,children}:{label:string;children:ReactNode}){return <span className="navigation-tooltip" title={label}>{children}</span>;}
