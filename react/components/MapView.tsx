// Fix: Add triple-slash directive for Vite types. Google Maps types are defined globally.
/// <reference types="vite/client" />

import React, { useState, useCallback, useRef, useMemo } from "react";
import {
  GoogleMap,
  useJsApiLoader,
  HeatmapLayer,
  OverlayView,
} from "@react-google-maps/api";
import { Point } from "../types";
import { usePoints } from "../hooks/usePoints";
import {
  DEFAULT_CENTER,
  DEFAULT_ZOOM,
  MIN_ZOOM_FOR_MARKERS,
  CATEGORIES,
} from "../constants";
import ImageModal from "./ImageModal";
import LoadingSpinner from "./LoadingSpinner";
import { GOOGLE_MAPS_API_KEY } from "../config";

const containerStyle = {
  width: "100%",
  height: "100%",
};

const libraries: "visualization"[] = ["visualization"]; // For HeatmapLayer

// Custom map styles to hide default points of interest (POIs)
const mapStyles = [
  {
    featureType: "poi",
    elementType: "labels",
    stylers: [{ visibility: "off" }],
  },
  {
    featureType: "poi.business",
    stylers: [{ visibility: "off" }],
  },
  {
    featureType: "transit",
    elementType: "labels.icon",
    stylers: [{ visibility: "off" }],
  },
];

// Heatmap gradient from green (clean) to red (high garbage density)
const heatmapOptions = {
  radius: 20,
  opacity: 0.8,
  gradient: [
    "rgba(0, 255, 0, 0)", // Transparent
    "rgba(0, 255, 0, 1)", // Green
    "rgba(255, 255, 0, 1)", // Yellow
    "rgba(255, 0, 0, 1)", // Red
  ],
};

const MapView: React.FC = () => {
  const mapRef = useRef<google.maps.Map | null>(null);

  const [bounds, setBounds] = useState<google.maps.LatLngBounds | null>(null);
  const [zoom, setZoom] = useState<number>(DEFAULT_ZOOM);
  const { points, loading, error } = usePoints(bounds);

  const [selectedPoint, setSelectedPoint] = useState<Point | null>(null);

  const { isLoaded, loadError } = useJsApiLoader({
    id: "google-map-script",
    googleMapsApiKey: GOOGLE_MAPS_API_KEY || "",
    libraries,
  });

  const onLoad = useCallback((map: google.maps.Map) => {
    mapRef.current = map;
    // Get user's location
    navigator.geolocation.getCurrentPosition(
      (position) => {
        const { latitude, longitude } = position.coords;
        map.setCenter({ lat: latitude, lng: longitude });
      },
      () => {
        console.warn("Geolocation permission denied. Defaulting to Bengaluru.");
      },
    );
    // Set initial bounds after map loads to trigger first fetch
    setBounds(map.getBounds());
  }, []);

  const onUnmount = useCallback(() => {
    mapRef.current = null;
  }, []);

  const onIdle = useCallback(() => {
    if (mapRef.current) {
      setBounds(mapRef.current.getBounds());
      setZoom(mapRef.current.getZoom() || DEFAULT_ZOOM);
    }
  }, []);

  const heatmapData = useMemo(() => {
    if (!isLoaded || !window.google) return [];
    return points.map((p) => ({
      location: new google.maps.LatLng(p.location.lat, p.location.lng),
      weight: p.weight,
    }));
  }, [points, isLoaded]);

  if (!GOOGLE_MAPS_API_KEY) {
    return (
      <div className="w-full h-full flex items-center justify-center bg-gray-700">
        <p className="text-red-400 font-semibold p-4 bg-gray-800 rounded-lg text-center">
          Google Maps API key is missing.
          <br /> Please add VITE_GOOGLE_MAPS_API_KEY to your .env file.
        </p>
      </div>
    );
  }

  if (loadError) {
    return (
      <div className="w-full h-full flex items-center justify-center bg-gray-700">
        <p className="text-red-400 font-semibold p-4 bg-gray-800 rounded-lg text-center">
          Error loading Google Maps.
          <br /> The API key may be invalid or there might be a network issue.
        </p>
      </div>
    );
  }

  return (
    <div className="w-full h-full relative">
      {(loading || error) && (
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 z-[1001] p-4 bg-surface/80 backdrop-blur-sm rounded-2xl shadow-xl text-center">
          {loading && !error && <LoadingSpinner />}
          {error && <p className="text-red-400 font-semibold">{error}</p>}
        </div>
      )}

      {isLoaded ? (
        <GoogleMap
          mapContainerStyle={containerStyle}
          center={DEFAULT_CENTER}
          zoom={DEFAULT_ZOOM}
          onLoad={onLoad}
          onUnmount={onUnmount}
          onIdle={onIdle}
          options={{
            streetViewControl: false,
            mapTypeControl: false,
            fullscreenControl: true,
            zoomControlOptions: {
              position: google.maps.ControlPosition.RIGHT_TOP,
            },
            styles: mapStyles,
            backgroundColor: "#1C1B1F", // Match with surface color
          }}
        >
          {points.length > 0 && (
            <HeatmapLayer data={heatmapData} options={heatmapOptions} />
          )}

          {zoom >= MIN_ZOOM_FOR_MARKERS &&
            points.map((point) => {
              const category = CATEGORIES.find(
                (c) => c.level === point.category,
              );
              const borderColor = category
                ? category.color.replace("bg-", "border-")
                : "border-gray-400";

              return (
                <OverlayView
                  key={point.id}
                  position={{
                    lat: point.location.lat,
                    lng: point.location.lng,
                  }}
                  mapPaneName={OverlayView.OVERLAY_MOUSE_TARGET}
                >
                  <div
                    className="relative group cursor-pointer transform -translate-x-1/2 -translate-y-1/2"
                    onClick={() => setSelectedPoint(point)}
                    style={{ zIndex: 1 }}
                  >
                    <img
                      src={point.image_url}
                      className={`w-12 h-12 object-cover rounded-full border-4 ${borderColor} shadow-lg transition-transform duration-200 group-hover:scale-110`}
                      alt="thumbnail"
                    />
                  </div>
                </OverlayView>
              );
            })}
        </GoogleMap>
      ) : (
        <div className="w-full h-full flex items-center justify-center">
          <LoadingSpinner />
        </div>
      )}

      {selectedPoint && (
        <ImageModal
          point={selectedPoint}
          isOpen={!!selectedPoint}
          onClose={() => setSelectedPoint(null)}
        />
      )}
    </div>
  );
};

export default MapView;
