import type {ContextFilterValues} from './context-panel.types';
import type {WorkspaceView} from './navigation.types';
import type {WorkspaceSpace} from './spaces.types';
export interface WorkspaceUIState{activeView:WorkspaceView;filters:ContextFilterValues;}
export interface WorkspaceNavigationContext{activeView:WorkspaceView;activeSpace:WorkspaceSpace;filters:ContextFilterValues;}
