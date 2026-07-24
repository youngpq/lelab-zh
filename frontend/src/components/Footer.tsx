import React from "react";

const Footer: React.FC = () => {
  return (
    <footer className="fixed inset-x-0 bottom-0 z-30 border-t border-gray-800 bg-black/95">
      <div className="mx-auto flex max-w-7xl items-center justify-end px-4 py-4">
        <span className="text-lg text-gray-400">
          科技人才孵化营
        </span>
      </div>
    </footer>
  );
};

export default Footer;
