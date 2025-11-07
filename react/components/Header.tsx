import React from "react";

const Header: React.FC = () => {
  return (
    <header className="sticky top-0 z-[1000] bg-surface/80 backdrop-blur-lg border-b border-outline">
      <div className="container mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
        <div className="flex items-center gap-3">
          {/* Icon */}
          <img
            src="/app_icon.png"
            alt="TrashMapr Icon"
            className="w-10 h-10 sm:w-12 sm:h-12 rounded-xl"
          />

          {/* Branding */}
          <div className="flex flex-col">
            <h1 className="text-xl sm:text-2xl font-bold text-on-surface tracking-wide leading-tight">
              TrashMapr
            </h1>
            <p className="text-xs text-on-surface-variant">
              Mapping waste for a cleaner tomorrow.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <a
            href="#" // Placeholder for Play Store or APK link
            className="flex items-center gap-2 px-4 py-2 bg-primary text-on-primary font-bold rounded-full shadow-lg hover:opacity-90 transition-opacity transform focus:outline-none focus:ring-2 focus:ring-primary focus:ring-opacity-50"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              className="h-5 w-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              strokeWidth="2"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"
              />
            </svg>
            <span className="text-sm hidden sm:inline">Download App</span>
          </a>
        </div>
      </div>
    </header>
  );
};

export default Header;
