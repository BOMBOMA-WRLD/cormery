export interface Forecast {
  id: string;
  subject: string;
  horizon: string;
  value: number;
  confidence: number;
}
