import React from "react";

const Footer: React.FC = () => {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="bg-surface border-t border-outline">
      <div className="container mx-auto px-4 sm:px-6 lg:px-8 py-4">
        <div className="flex flex-col items-center justify-center gap-2 text-xs text-on-surface-variant text-center">
          <span className="font-medium">
            © {currentYear} TrashMapr. All rights reserved.
          </span>
          <span className="opacity-70">
            Built with purpose. Powered by community.
          </span>
        </div>
      </div>
    </footer>
  );
};

export default Footer;
