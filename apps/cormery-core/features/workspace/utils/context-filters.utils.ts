import type {ContextFilterValues} from '../types/context-panel.types';
export function countActiveFilters(values:ContextFilterValues):number{return Object.values(values).filter((value)=>value!==''&&value!==undefined&&value!==false).length;}
export function clearFilterValues(values:ContextFilterValues):ContextFilterValues{return Object.fromEntries(Object.keys(values).map((key)=>[key,'']));}
export function hasActiveFilter(value:string|boolean|undefined):boolean{return value!==undefined&&value!==''&&value!==false;}
