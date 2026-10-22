import type {ReactNode} from 'react';
export function SidebarSection({label,collapsed,children}:{label:string;collapsed:boolean;children:ReactNode}){return <section className="nav-group" aria-label={label}><h2 className="nav-group-title">{collapsed?'':label}</h2>{children}</section>;}
