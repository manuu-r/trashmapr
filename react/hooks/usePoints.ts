import { useState, useEffect, useCallback } from 'react';
import { Point } from '../types';
import { API_DEBOUNCE_MS } from '../constants';

// Fix: Hardcoded the API URL to resolve runtime errors with environment variables.
const API_URL = 'https://dev.trashmapr.com';

export function usePoints(bounds: google.maps.LatLngBounds | null) {
  const [points, setPoints] = useState<Point[]>([]);
  const [loading, setLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  const fetchPoints = useCallback(async (currentBounds: google.maps.LatLngBounds) => {
    setLoading(true);
    setError(null);

    const ne = currentBounds.getNorthEast();
    const sw = currentBounds.getSouthWest();
    const url = `${API_URL}/points?lat1=${sw.lat()}&lng1=${sw.lng()}&lat2=${ne.lat()}&lng2=${ne.lng()}`;

    try {
      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(`Failed to fetch data: ${response.status} ${response.statusText}`);
      }
      const data: Point[] = await response.json();
      setPoints(data);
    } catch (err) {
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('An unknown error occurred.');
      }
      setPoints([]); // Clear points on error
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!bounds) return;

    const handler = setTimeout(() => {
      fetchPoints(bounds);
    }, API_DEBOUNCE_MS);

    // Cleanup function to cancel the timeout if bounds change again quickly
    return () => {
      clearTimeout(handler);
    };
  }, [bounds, fetchPoints]);

  return { points, loading, error };
}
