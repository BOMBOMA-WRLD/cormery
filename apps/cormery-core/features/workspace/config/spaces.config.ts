import type {WorkspaceSpace} from '../types/spaces.types';
export const WORKSPACE_SPACES:WorkspaceSpace[]=[
{id:'global',name:'Global Workspace',kind:'global',available:true,description:'Espace global de travail'},
{id:'personal',name:'Personal Space',kind:'personal',available:true,description:'Sélection locale sans persistance distante'},
{id:'organization',name:'Organisation',kind:'organization',available:false,description:'Contrat d’organisation non configuré'},
{id:'shared',name:'Espaces partagés',kind:'shared',available:false,description:'Partage et permissions non connectés'},
{id:'recent',name:'Espaces récents',kind:'recent',available:false,description:'Persistance non configurée'}];
