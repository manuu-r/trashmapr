import React from 'react';
import { CATEGORIES } from '../constants';

const Legend: React.FC = () => {
  return (
    <div className="absolute bottom-4 left-4 z-[1000] p-3 bg-black bg-opacity-60 backdrop-blur-md rounded-lg shadow-lg border border-white/10">
      <h3 className="font-semibold text-sm mb-2 text-gray-200">Garbage Density</h3>
      <div className="flex flex-col gap-2">
        {CATEGORIES.map((category) => (
          <div key={category.level} className="flex items-center gap-2">
            <div className={`w-3.5 h-3.5 rounded-full ${category.color}`}></div>
            <span className="text-xs text-gray-300">{category.label}</span>
          </div>
        ))}
      </div>
    </div>
  );
};

export default Legend;