"use client";

import Sidebar from "./Sidebar";
import Header from "./Header";

interface MainLayoutProps {
  title: string;
  children: React.ReactNode;
}

export default function MainLayout({ title, children }: MainLayoutProps) {
  return (
    <div className="flex h-screen bg-gray-50">
      {/* Fixed left sidebar */}
      <Sidebar />

      {/* Right column: header + scrollable content */}
      <div className="flex-1 flex flex-col overflow-hidden">
        <Header title={title} />
        <main className="flex-1 overflow-y-auto p-6">{children}</main>
      </div>
    </div>
  );
}
