export interface DeliveryZone {
  plz: string;
  minimumOrder: number;
  deliveryFee: number;
}

export const KITCHEN_ADDRESS = 'Minnesheimstraße 5, 5023 Salzburg';

export const SALZBURG_DELIVERY_ZONES: DeliveryZone[] = [
  { plz: '5020', minimumOrder: 19.99, deliveryFee: 1.99 },
  { plz: '5023', minimumOrder: 19.99, deliveryFee: 1.99 },
  { plz: '5026', minimumOrder: 25.0, deliveryFee: 2.99 },
  { plz: '5061', minimumOrder: 30.0, deliveryFee: 3.49 },
  { plz: '5071', minimumOrder: 30.0, deliveryFee: 3.49 },
  { plz: '5101', minimumOrder: 30.0, deliveryFee: 3.49 },
  { plz: '5161', minimumOrder: 35.0, deliveryFee: 3.49 },
  { plz: '5201', minimumOrder: 40.0, deliveryFee: 4.49 },
  { plz: '5300', minimumOrder: 25.0, deliveryFee: 2.49 },
  { plz: '5301', minimumOrder: 35.0, deliveryFee: 2.99 },
  { plz: '5321', minimumOrder: 40.0, deliveryFee: 4.49 },
];

export function normalizePostcode(raw: string | undefined | null): string {
  if (!raw) return '';
  const digits = raw.replace(/\D/g, '');
  return digits.length >= 4 ? digits.slice(0, 4) : digits;
}

export function deliveryZoneForPostcode(raw: string | undefined | null): DeliveryZone | null {
  const plz = normalizePostcode(raw);
  if (plz.length !== 4) return null;
  return SALZBURG_DELIVERY_ZONES.find((z) => z.plz === plz) ?? null;
}
