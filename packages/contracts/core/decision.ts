export interface Decision {
  id: string;
  workspaceId: string;
  title: string;
  outcome?: string;
  decidedAt?: string;
}
