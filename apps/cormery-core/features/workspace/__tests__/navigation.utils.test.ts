import assert from 'node:assert/strict';import test from 'node:test';import {getNavigationGroups,getNavigationItem,isWorkspaceView} from '../utils/navigation.utils';
test('navigation groups are unique and ordered',()=>{assert.deepEqual(getNavigationGroups(),['Explorer','Intelligence','Pilotage','Assistant','Compte']);});
test('known view resolves and invalid view is rejected',()=>{assert.equal(getNavigationItem('opportunities').label,'Opportunités');assert.equal(isWorkspaceView('workspace'),true);assert.equal(isWorkspaceView('unknown'),false);});
