export interface TokenRates {
  input: number;
  output: number;
}

export class CostManager {
  estimate(inputTokens: number, outputTokens: number, rates: TokenRates): number {
    return inputTokens * rates.input + outputTokens * rates.output;
  }
}
