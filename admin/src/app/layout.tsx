import type { Metadata } from 'next';
import './globals.css';
import { Toaster } from 'react-hot-toast';

export const metadata: Metadata = {
  title: 'Milan Admin',
  description: 'Milan — Jahan Dil Mile. | Admin Panel',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="bg-bg text-white font-sans antialiased">
        {children}
        <Toaster position="top-right" toastOptions={{ style: { background: '#1E1E3A', color: '#fff', border: '1px solid #2A2A4A' } }} />
      </body>
    </html>
  );
}
