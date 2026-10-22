import {NAVIGATION_ITEMS} from '../config/navigation.config';
import type {NavigationItem,WorkspaceView} from '../types/navigation.types';
export function getNavigationItem(view:WorkspaceView):NavigationItem{return NAVIGATION_ITEMS.find((item)=>item.id===view)??NAVIGATION_ITEMS[0];}
export function getNavigationGroups():string[]{return [...new Set(NAVIGATION_ITEMS.map((item)=>item.group))];}
export function isWorkspaceView(value:string):value is WorkspaceView{return NAVIGATION_ITEMS.some((item)=>item.id===value);}
