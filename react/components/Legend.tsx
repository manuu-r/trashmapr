import React from 'react';
import { CATEGORIES } from '../constants';

const Legend: React.FC = () => {
  return (
    <div className="flex justify-center items-center gap-2 md:gap-4 flex-wrap px-4">
      <span className="font-semibold text-sm mr-2">Density:</span>
      {CATEGORIES.map((category) => (
        <div key={category.level} className="flex items-center gap-2">
          <div className={`w-3 h-3 rounded-full ${category.color}`}></div>
          <span className="text-xs text-gray-200">{category.label}</span>
        </div>
      ))}
    </div>
  );
};

export default Legend;
