import type {WorkspaceSpace} from '../../types/spaces.types';
export function SharedSpaces({spaces}:{spaces:WorkspaceSpace[]}){return <section className="space-subsection" aria-label="Espaces partagés"><h3>Espaces partagés</h3>{spaces.filter((space)=>space.kind==='shared').map((space)=><p key={space.id}>{space.name} — {space.available?'Accessible':'Permissions non connectées'}</p>)}</section>;}
