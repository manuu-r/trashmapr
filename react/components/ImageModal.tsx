import React from 'react';
import Modal from 'react-modal';
import { Point } from '../types';
import { CATEGORIES } from '../constants';

interface ImageModalProps {
  point: Point | null;
  isOpen: boolean;
  onClose: () => void;
}

Modal.setAppElement('#root');

const ImageModal: React.FC<ImageModalProps> = ({ point, isOpen, onClose }) => {
  if (!point) return null;

  const category = CATEGORIES.find(c => c.level === point.category);

  return (
    <Modal
      isOpen={isOpen}
      onRequestClose={onClose}
      contentLabel="Image Details"
      className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 bg-gray-900 border border-gray-700 rounded-lg shadow-2xl w-11/12 max-w-2xl max-h-[90vh] overflow-auto focus:outline-none p-4 md:p-6"
      overlayClassName="fixed inset-0 bg-black bg-opacity-75 z-[2000] flex items-center justify-center"
    >
      <div className="text-white">
        <button
          onClick={onClose}
          className="absolute top-3 right-3 text-gray-400 hover:text-white transition-colors text-2xl"
        >
          &times;
        </button>
        <div className="flex flex-col md:flex-row gap-4">
          <div className="flex-shrink-0 md:w-2/3">
            <img 
              src={point.image_url} 
              alt={`Geo-tagged photo ${point.id}`} 
              className="w-full h-auto max-h-[75vh] object-contain rounded-md" 
            />
          </div>
          <div className="flex-1 space-y-3 text-sm md:text-base">
            <h2 className="text-xl font-bold">Image Details</h2>
            <p><strong>Timestamp:</strong> {new Date(point.timestamp).toLocaleString()}</p>
            <p><strong>Latitude:</strong> {point.location.lat.toFixed(6)}</p>
            <p><strong>Longitude:</strong> {point.location.lng.toFixed(6)}</p>
            <div className="flex items-center gap-2">
              <strong>Category:</strong>
              {category && (
                <span className={`px-2 py-1 text-xs font-bold rounded-full text-white ${category.color}`}>
                  {point.category} - {category.label}
                </span>
              )}
            </div>
            <p><strong>Weight:</strong> {point.weight.toFixed(2)}</p>
          </div>
        </div>
      </div>
    </Modal>
  );
};

export default ImageModal;
