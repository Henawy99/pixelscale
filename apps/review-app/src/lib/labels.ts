import { BookingsResponse } from '../types';

/** Human name of where the last booking sync came from. */
export function syncSourceLabel(source: BookingsResponse['source'] | null): string | null {
  switch (source) {
    case 'multi':
      return 'Zoho (GYG) + Gmail (Airbnb)';
    case 'zoho':
      return 'Zoho Mail (GYG)';
    case 'gmail':
      return 'Gmail (Airbnb)';
    case 'cache':
      return 'Server cache';
    case 'mock':
      return 'Sample data';
    default:
      return null;
  }
}
