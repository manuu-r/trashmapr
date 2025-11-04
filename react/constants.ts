import { Category } from './types';

export const DEFAULT_CENTER = { lat: 40.7128, lng: -74.0060 }; // New York City
export const DEFAULT_ZOOM: number = 12;
export const MIN_ZOOM_FOR_MARKERS: number = 14;
export const API_DEBOUNCE_MS: number = 500;

export const CATEGORIES: Category[] = [
  { level: 1, label: 'Sparse', color: 'bg-blue-500' },
  { level: 2, label: 'Medium', color: 'bg-green-500' },
  { level: 3, label: 'High', color: 'bg-yellow-500' },
  { level: 4, label: 'Very High', color: 'bg-red-500' }
];