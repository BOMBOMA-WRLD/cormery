import {useSyncExternalStore} from 'react';
import type {ContextFilterValues} from '../types/context-panel.types';
import type {WorkspaceView} from '../types/navigation.types';
interface UIState{activeView:WorkspaceView;filters:ContextFilterValues;}
let state:UIState={activeView:'workspace',filters:{}};const listeners=new Set<()=>void>();
function subscribe(listener:()=>void){listeners.add(listener);return()=>{listeners.delete(listener);};}function getSnapshot(){return state;}function update(next:Partial<UIState>){state={...state,...next};listeners.forEach((listener)=>listener());}
export const workspaceUIStore={setActiveView(activeView:WorkspaceView){update({activeView});},setFilter(id:string,value:string|boolean){update({filters:{...state.filters,[id]:value}});},clearFilters(){update({filters:{}});}};
export function useWorkspaceUIState(){return useSyncExternalStore(subscribe,getSnapshot,getSnapshot);}
