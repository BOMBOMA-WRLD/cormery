export interface Opportunity {
  id: string;
  productId: string;
  marketId: string;
  score: number;
  status: 'detected' | 'validated' | 'dismissed';
}
