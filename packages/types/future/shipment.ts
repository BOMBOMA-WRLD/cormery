export interface Shipment {
  id: string;
  purchaseId: string;
  carrier?: string;
  trackingNumber?: string;
  status: 'planned' | 'in_transit' | 'delivered' | 'lost';
}
