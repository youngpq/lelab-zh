import React from "react";
import HfAuthChip from "./HfAuthChip";
import LanguageSwitcher from "@/components/LanguageSwitcher";

const LandingTopBar: React.FC = () => {
  return (
    <header className="sticky top-0 z-30 w-full border-b border-gray-800 bg-black/95 backdrop-blur supports-[backdrop-filter]:bg-black/70">
      <div className="mx-auto flex h-12 max-w-7xl items-center justify-between px-4">
        <div className="flex items-center gap-2">
          <img
            src="/logo.svg"
            alt="具身智能实验室"
            className="h-7 w-7"
          />
          <span className="text-base font-semibold tracking-tight text-white">
            具身智能实验室
          </span>
        </div>
        <div className="flex items-center gap-3">
          <LanguageSwitcher />
          <HfAuthChip />
        </div>
      </div>
    </header>
  );
};

export default LandingTopBar;
