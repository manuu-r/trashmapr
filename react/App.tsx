import React from 'react';
import MapView from './components/MapView';
import Legend from './components/Legend';

function App() {
  return (
    <div className="relative w-screen h-screen bg-gray-800 text-white font-sans">
      <header className="absolute top-0 left-0 right-0 z-[1000] p-4 bg-black bg-opacity-50 backdrop-blur-sm shadow-lg">
        <h1 className="text-xl md:text-2xl font-bold text-center">Geo-Photo Density Map</h1>
        <p className="text-center text-sm text-gray-300">Explore photo density from around the world</p>
      </header>
      
      <main className="w-full h-full">
        <MapView />
      </main>
      
      <footer className="absolute bottom-0 left-0 right-0 z-[1000] p-2 bg-black bg-opacity-50 backdrop-blur-sm text-center text-xs text-gray-400">
        <Legend />
        <p className="mt-2">Map data &copy; <a href="https://www.google.com/maps" target="_blank" rel="noopener noreferrer" className="text-blue-400 hover:underline">Google Maps</a></p>
      </footer>
    </div>
  );
}

export default App;