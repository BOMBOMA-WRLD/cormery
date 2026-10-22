export const WORKSPACE_VIEWS=['workspace','products','opportunities','geography','scenarios','portfolios','schedule','chat','settings'] as const;
export type WorkspaceView=(typeof WORKSPACE_VIEWS)[number];
export interface NavigationItem{id:WorkspaceView;label:string;group:string;icon:string;description:string;}
