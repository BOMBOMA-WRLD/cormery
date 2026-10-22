import {NAVIGATION_ITEMS} from '../config/navigation.config';
import type {NavigationItem,WorkspaceView} from '../types/navigation.types';
import {isWorkspaceView} from '../utils/navigation.utils';
export function resolveWorkspaceDestination(value:string):NavigationItem|undefined{return isWorkspaceView(value)?NAVIGATION_ITEMS.find((item)=>item.id===value):undefined;}
export function getDefaultWorkspaceView():WorkspaceView{return 'workspace';}
