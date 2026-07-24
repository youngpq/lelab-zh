import React from "react";
import HfAuthChip from "./HfAuthChip";
import LanguageSwitcher from "@/components/LanguageSwitcher";

const LandingTopBar: React.FC = () => {
  return (
    <header className="sticky top-0 z-30 w-full border-b border-gray-800 bg-black/95 backdrop-blur supports-[backdrop-filter]:bg-black/70">
      <div className="mx-auto flex h-12 max-w-7xl items-center justify-end px-4">
        <div className="flex items-center gap-3">
          <LanguageSwitcher />
          <HfAuthChip />
        </div>
      </div>
    </header>
  );
};

export default LandingTopBar;
