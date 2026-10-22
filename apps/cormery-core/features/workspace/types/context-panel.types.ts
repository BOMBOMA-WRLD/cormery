import type {WorkspaceView} from './navigation.types';
export type ContextFilterKind='search'|'text'|'number'|'select'|'toggle';
export interface ContextFilterOption{label:string;value:string;}
export interface ContextFilterDefinition{id:string;label:string;kind:ContextFilterKind;placeholder?:string;options?:ContextFilterOption[];description?:string;available?:boolean;}
export type ContextFilterValues=Partial<Record<string,string|boolean>>;
export type ContextFiltersByView=Partial<Record<WorkspaceView,ContextFilterDefinition[]>>;
