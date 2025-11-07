import React from "react";
import Modal from "react-modal";
import { Point } from "../types";
import { CATEGORIES } from "../constants";

interface ImageModalProps {
  point: Point | null;
  isOpen: boolean;
  onClose: () => void;
}

Modal.setAppElement("#root");

const ImageModal: React.FC<ImageModalProps> = ({ point, isOpen, onClose }) => {
  if (!point) return null;

  const category = CATEGORIES.find((c) => c.level === point.category);
  const directionsUrl = `https://www.google.com/maps/dir/?api=1&destination=${point.location.lat},${point.location.lng}`;

  return (
    <Modal
      isOpen={isOpen}
      onRequestClose={onClose}
      contentLabel="Image Details"
      className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 bg-surface border border-outline rounded-3xl shadow-2xl w-11/12 max-w-sm max-h-[90vh] overflow-hidden flex flex-col focus:outline-none"
      overlayClassName="fixed inset-0 bg-black bg-opacity-90 z-[4000]"
    >
      <div className="text-on-surface relative">
        <img
          src={point.image_url}
          alt={`Geo-tagged photo ${point.id}`}
          className="w-full h-96 object-cover"
        />
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-white bg-black/70 rounded-full p-2 hover:bg-black/90 transition-colors z-10 shadow-lg"
          aria-label="Close modal"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            className="h-6 w-6"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M6 18L18 6M6 6l12 12"
            />
          </svg>
        </button>
      </div>

      <div className="px-4 pt-3 pb-4 overflow-y-auto bg-white">
        <a
          href={directionsUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center justify-center w-full px-4 py-2 mb-3 bg-blue-600 text-white font-semibold rounded-full hover:bg-blue-700 transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-blue-500 shadow-md"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            className="h-5 w-5 mr-2"
            viewBox="0 0 20 20"
            fill="currentColor"
          >
            <path d="M10.894 2.553a1 1 0 00-1.788 0l-7 14a1 1 0 001.169 1.409l5-1.429A1 1 0 009 15.571V11a1 1 0 112 0v4.571a1 1 0 00.725.962l5 1.428a1 1 0 001.17-1.408l-7-14z" />
          </svg>
          <span>Get Directions</span>
        </a>

        <div className="space-y-2 text-sm">
          <div className="flex items-center">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              className="h-5 w-5 mr-3 text-gray-600"
              viewBox="0 0 20 20"
              fill="currentColor"
            >
              <path
                fillRule="evenodd"
                d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z"
                clipRule="evenodd"
              />
            </svg>
            <span className="text-gray-900">
              {new Date(point.timestamp).toLocaleString()}
            </span>
          </div>

          <div className="flex items-center">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              className="h-5 w-5 mr-3 text-gray-600"
              viewBox="0 0 20 20"
              fill="currentColor"
            >
              <path
                fillRule="evenodd"
                d="M5 2a1 1 0 00-1 1v1h14V3a1 1 0 00-1-1H5zM4 6h12v10a1 1 0 01-1 1H5a1 1 0 01-1-1V6z"
                clipRule="evenodd"
              />
            </svg>
            {category && (
              <span
                className={`px-2 py-1 text-xs font-bold rounded-full text-white ${category.color} border border-white/20`}
              >
                {category.label}
              </span>
            )}
          </div>

          <div className="flex items-center">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              className="h-5 w-5 mr-3 text-gray-600"
              viewBox="0 0 20 20"
              fill="currentColor"
            >
              <path d="M3 4a1 1 0 011-1h12a1 1 0 011 1v2a1 1 0 01-1 1H4a1 1 0 01-1-1V4zM3 10a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H4a1 1 0 01-1-1v-6zM14 9a1 1 0 00-1 1v6a1 1 0 001 1h2a1 1 0 001-1v-6a1 1 0 00-1-1h-2z" />
            </svg>
            <span className="text-gray-900">
              Weight: {point.weight.toFixed(2)}
            </span>
          </div>
        </div>
      </div>
    </Modal>
  );
};

export default ImageModal;
