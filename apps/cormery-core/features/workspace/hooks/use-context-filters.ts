import {CONTEXT_FILTERS} from '../config/context-filters.config';
import {workspaceUIStore,useWorkspaceUIState} from '../stores/workspace-ui.store';
import {countActiveFilters} from '../utils/context-filters.utils';
export function useContextFilters(){const{activeView,filters}=useWorkspaceUIState();return{definitions:CONTEXT_FILTERS[activeView]??[],values:filters,activeCount:countActiveFilters(filters),setFilter:workspaceUIStore.setFilter,clearFilters:workspaceUIStore.clearFilters};}
