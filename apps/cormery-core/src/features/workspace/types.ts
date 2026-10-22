export type WorkspaceView = 'workspace' | 'products' | 'opportunities' | 'geography' | 'scenarios' | 'portfolios' | 'schedule' | 'chat' | 'settings'
export type SpaceKind = 'global' | 'personal' | 'organization' | 'shared'
export interface SpaceOption { id: SpaceKind; label: string; available: boolean }
export interface ContextFilter { id: string; label: string; placeholder?: string; options?: string[] }
