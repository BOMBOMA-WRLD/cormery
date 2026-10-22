import {workspaceUIStore,useWorkspaceUIState} from '../stores/workspace-ui.store';
import {getDefaultWorkspaceView} from '../services/workspace-navigation.service';
import {getNavigationItem} from '../utils/navigation.utils';
import type {WorkspaceView} from '../types/navigation.types';
export function useWorkspaceNavigation(){const state=useWorkspaceUIState();const activeView=state.activeView??getDefaultWorkspaceView();return{activeView,activeItem:getNavigationItem(activeView),selectView:(view:WorkspaceView)=>workspaceUIStore.setActiveView(view)};}
