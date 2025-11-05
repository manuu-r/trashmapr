import React from 'react';
import MapView from './components/MapView';
import Legend from './components/Legend';
import InfoPanel from './components/InfoPanel';

function App() {
  return (
    <div className="relative w-screen h-screen bg-gray-800 text-white font-sans">
      <main className="w-full h-full">
        <MapView />
      </main>
      
      {/* Floating Info Panels */}
      <InfoPanel />
      <Legend />
    </div>
  );
}

export default App;