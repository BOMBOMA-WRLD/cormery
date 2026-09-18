export interface Execution {
  id: string;
  workflowId: string;
  status: 'queued' | 'running' | 'completed' | 'failed';
  startedAt?: string;
  finishedAt?: string;
}
