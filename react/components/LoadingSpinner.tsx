import React from "react";

const LoadingSpinner: React.FC = () => {
  return (
    <div className="flex flex-col justify-center items-center space-y-2">
      <div
        className="animate-spin rounded-full h-10 w-10 border-b-2 border-t-2 border-primary"
        role="status"
      ></div>
      <span className="text-on-surface-variant">Loading Data...</span>
    </div>
  );
};

export default LoadingSpinner;
