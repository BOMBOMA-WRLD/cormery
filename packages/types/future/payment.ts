export interface Payment {
  id: string;
  purchaseId: string;
  amount: number;
  currency: string;
  status: 'pending' | 'authorized' | 'settled' | 'failed';
}
