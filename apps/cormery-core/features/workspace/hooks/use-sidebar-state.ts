import {useState} from 'react';
export function useSidebarState(){const[collapsed,setCollapsed]=useState(false);const[mobileOpen,setMobileOpen]=useState(false);return{collapsed,mobileOpen,toggleCollapsed:()=>setCollapsed((v)=>!v),openMobile:()=>setMobileOpen(true),closeMobile:()=>setMobileOpen(false)};}
