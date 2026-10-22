import {useState} from 'react';
import type {WorkspaceSpace} from '../../types/spaces.types';
import {SpaceMenu} from './space-menu';import {SpaceSwitcher} from './space-switcher';
export function NavSpaces({activeSpace,spaces,onSelectSpace,onCreateSpace}:{activeSpace:WorkspaceSpace;spaces:WorkspaceSpace[];onSelectSpace:(space:WorkspaceSpace)=>void;onCreateSpace:()=>void}){const[open,setOpen]=useState(false);return <div className="space-switcher"><SpaceSwitcher activeSpace={activeSpace} open={open} onToggle={()=>setOpen((v)=>!v)}/>{open&&<SpaceMenu spaces={spaces} activeSpaceId={activeSpace.id} onSelect={(space)=>{onSelectSpace(space);setOpen(false);}} onCreate={()=>{setOpen(false);onCreateSpace();}}/>}</div>;}
