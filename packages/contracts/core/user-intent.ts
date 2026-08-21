export interface UserIntent {
  userId: string;
  workspaceId: string;
  action: string;
  parameters: Record<string, unknown>;
}
