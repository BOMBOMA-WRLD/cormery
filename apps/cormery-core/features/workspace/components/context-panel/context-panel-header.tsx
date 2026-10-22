import {ClearFiltersButton} from './clear-filters-button';
export function ContextPanelHeader({activeCount,onClear}:{activeCount:number;onClear:()=>void}){return <div className="context-heading"><div><span className="eyebrow">AFFINER LA VUE</span><h2>Filtres <span className="filter-count">{activeCount||''}</span></h2></div><ClearFiltersButton disabled={activeCount===0} onClear={onClear}/></div>;}
