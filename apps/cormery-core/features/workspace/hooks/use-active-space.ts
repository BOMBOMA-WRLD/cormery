import {useState} from 'react';
import {WORKSPACE_SPACES} from '../config/spaces.config';
import type {WorkspaceSpace} from '../types/spaces.types';
export function useActiveSpace(){const[activeSpace,setActiveSpace]=useState(WORKSPACE_SPACES[0]);const selectSpace=(space:WorkspaceSpace)=>{if(space.available)setActiveSpace(space);};return{activeSpace,spaces:WORKSPACE_SPACES,selectSpace};}
