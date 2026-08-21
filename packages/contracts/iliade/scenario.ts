export interface Scenario {
  id: string;
  name: string;
  assumptions: Record<string, string | number | boolean>;
}
