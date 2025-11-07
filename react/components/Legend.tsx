import React from "react";
import { CATEGORIES } from "../constants";

const Legend: React.FC = () => {
  return (
    <div className="p-4 rounded-2xl">
      <h3 className="font-semibold text-sm mb-3 text-on-surface-variant">
        Garbage Density
      </h3>
      <div className="space-y-2">
        {CATEGORIES.map((category) => (
          <div key={category.level} className="flex items-center gap-3">
            <div
              className={`w-4 h-4 rounded-full ${category.color} border border-white/20`}
            ></div>
            <span className="text-sm text-on-surface">{category.label}</span>
          </div>
        ))}
      </div>
    </div>
  );
};

export default Legend;
