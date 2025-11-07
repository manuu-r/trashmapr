import React from "react";
import Modal from "react-modal";
import MapView from "./MapView";
import Legend from "./Legend";

interface MapModalProps {
  isOpen: boolean;
  onClose: () => void;
}

Modal.setAppElement("#root");

const MapModal: React.FC<MapModalProps> = ({ isOpen, onClose }) => {
  return (
    <Modal
      isOpen={isOpen}
      onRequestClose={onClose}
      contentLabel="Fullscreen Map"
      className="fixed inset-0 bg-surface flex flex-col focus:outline-none"
      overlayClassName="fixed inset-0 bg-black bg-opacity-90 z-[3000]"
    >
      {/* Header with close button */}
      <div className="bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between shadow-sm">
        <h2 className="text-2xl font-semibold text-gray-900">
          Live Waste Heatmap
        </h2>
        <button
          onClick={onClose}
          className="text-gray-600 hover:text-gray-900 bg-gray-100 hover:bg-gray-200 rounded-full p-2 transition-all"
          aria-label="Close map"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            className="h-6 w-6"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={2}
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M6 18L18 6M6 6l12 12"
            />
          </svg>
        </button>
      </div>

      {/* Map content */}
      <div className="flex-1 relative">
        <MapView />
        <div className="absolute top-4 left-4 z-[100] bg-surface/90 backdrop-blur-lg border border-outline rounded-2xl shadow-xl">
          <Legend />
        </div>
      </div>
    </Modal>
  );
};

export default MapModal;
