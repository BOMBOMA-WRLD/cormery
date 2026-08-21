export class TokenManager {
  fitsBudget(inputTokens: number, outputTokens: number, budget: number): boolean {
    return inputTokens + outputTokens <= budget;
  }
}
