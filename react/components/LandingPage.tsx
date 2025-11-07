import React from "react";

import MapView from "./MapView";
import Legend from "./Legend";
import Header from "./Header";
import Footer from "./Footer";

const LandingPage: React.FC = () => {
  return (
    <div className="flex flex-col min-h-screen">
      <Header />

      <main className="flex-grow container mx-auto px-4 sm:px-6 lg:px-8 py-12 md:py-16 lg:py-20">
        {/* Two Column Layout on Tablet+ */}
        <div className="grid grid-cols-1 lg:grid-cols-[1fr,1.5fr] xl:grid-cols-[1fr,1.8fr] gap-12 lg:gap-16 xl:gap-20 items-stretch max-w-[1600px] mx-auto">
          {/* Left: Hero & Info Section */}
          <div className="flex flex-col justify-center space-y-12 lg:space-y-16">
            {/* Hero Content */}
            <div>
              <h2 className="text-5xl sm:text-6xl lg:text-6xl xl:text-7xl font-bold tracking-tight mb-8 leading-tight whitespace-nowrap">
                Snap. Map. Clean.
              </h2>
              <p className="text-xl lg:text-2xl text-on-surface-variant leading-relaxed">
                Contribute to a cleaner planet. Every photo you share helps
                build a live waste heatmap that reveals hotspots in real time.
                powered by AI that analyzes your uploads to guide faster,
                smarter cleanups.
              </p>
            </div>

            {/* CTA Section */}
            <div className="space-y-6">
              <p className="text-2xl lg:text-3xl text-on-surface font-semibold">
                Ready to make an impact?
              </p>
              <div className="flex flex-col items-start space-y-3">
                <a
                  href="https://mega.nz/file/1qZSwaDR#VIv04mpm79YjtC7e5IGbBneQWg3aBO6VIKl3av1m8W4"
                  download
                  className="inline-flex items-center gap-3 px-8 py-4 bg-primary text-on-primary text-lg font-semibold rounded-full shadow-lg hover:opacity-90 transition-all hover:scale-[1.02] active:scale-[0.98]"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    className="h-6 w-6"
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
                  Download APK
                </a>
                <a
                  href="https://mega.nz/file/pz4XhCIY#uKMeT6_PuLdKbFfHIBXfUZJUdTHOKECxeg0VhWSvaqw"
                  download
                  className="inline-flex items-center gap-1.5 text-sm text-primary hover:underline font-medium pl-8"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    className="h-4 w-4"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    strokeWidth="2"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                    />
                  </svg>
                  Download SHA-1 Checksum
                </a>
              </div>
            </div>

            {/* Google Play Internal Testing Form */}
            <div className="bg-surface-container border border-outline rounded-2xl p-6 space-y-4">
              <div className="flex items-start gap-3">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  className="h-6 w-6 text-primary flex-shrink-0 mt-1"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  strokeWidth="2"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z"
                  />
                </svg>
                <div>
                  <h3 className="text-xl font-semibold text-on-surface mb-2">
                    Prefer Google Play Store?
                  </h3>
                  <p className="text-sm text-on-surface-variant">
                    Join our internal testing program and install directly from
                    the Play Store.
                  </p>
                </div>
              </div>
              <form
                action="https://formspree.io/f/xanlrzrd"
                method="POST"
                className="space-y-3"
              >
                <input
                  type="email"
                  name="email"
                  required
                  placeholder="Enter your email"
                  className="w-full px-4 py-3 bg-surface border border-outline rounded-xl text-on-surface placeholder:text-on-surface-variant focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent transition-all"
                />
                <button
                  type="submit"
                  className="w-full inline-flex items-center justify-center gap-2 px-6 py-3 bg-primary text-on-primary font-semibold rounded-xl shadow-md hover:opacity-90 transition-all hover:scale-[1.01] active:scale-[0.99]"
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
                      d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                    />
                  </svg>
                  Request Access
                </button>
              </form>
            </div>
          </div>

          {/* Right: Map Section */}
          <section className="bg-surface-container border border-outline rounded-3xl shadow-2xl overflow-hidden flex flex-col h-full lg:min-h-[700px]">
            <div className="p-8">
              <h3 className="text-3xl font-semibold text-on-surface">
                Your Contributions in Action
              </h3>
            </div>
            <div className="flex-1 w-full relative min-h-[60vh]">
              <MapView />
              <div className="absolute top-4 left-4 z-[100] bg-surface/90 backdrop-blur-lg border border-outline rounded-2xl shadow-xl">
                <Legend />
              </div>
            </div>
          </section>
        </div>
      </main>

      <Footer />
    </div>
  );
};

export default LandingPage;
