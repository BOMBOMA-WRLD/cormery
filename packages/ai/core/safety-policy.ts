export interface SafetyPolicy {
  allow(prompt: string): boolean;
}

export class AllowAllSafetyPolicy implements SafetyPolicy {
  allow(): boolean {
    return true;
  }
}
