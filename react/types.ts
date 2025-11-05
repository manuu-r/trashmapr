export interface Point {
  id: number;
  image_url: string;
  location: {
    lat: number;
    lng: number;
  };
  weight: number;
  category: 1 | 2 | 3 | 4;
  timestamp: string;
}

export interface Category {
  level: 1 | 2 | 3 | 4;
  label: string;
  color: string;
}
