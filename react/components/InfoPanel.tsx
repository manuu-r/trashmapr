import React from 'react';

const InfoPanel: React.FC = () => {
  return (
    <div className="absolute top-4 left-4 z-[1000] p-4 max-w-xs bg-black bg-opacity-60 backdrop-blur-md rounded-lg shadow-lg border border-white/10">
      <h1 className="text-xl font-bold text-white">Trash Density Map</h1>
      <p className="text-sm text-gray-300 mt-1">Visualize garbage density reported by users</p>
    </div>
  );
};

export default InfoPanel;