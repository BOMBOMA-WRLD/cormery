export type SpaceKind='global'|'personal'|'organization'|'shared'|'recent';
export interface WorkspaceSpace{id:string;name:string;kind:SpaceKind;available:boolean;description:string;}
