export interface Purchase {
  id: string;
  supplierId: string;
  items: Array<{ productId: string; quantity: number }>;
  status: 'draft' | 'submitted' | 'confirmed' | 'cancelled';
}
