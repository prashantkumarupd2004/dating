/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./src/**/*.{js,ts,jsx,tsx,mdx}'],
  theme: {
    extend: {
      colors: {
        primary: '#E91E8C',
        secondary: '#6C63FF',
        bg: '#0D0D0D',
        surface: '#1A1A2E',
        card: '#1E1E3A',
        border: '#2A2A4A',
        gold: '#FFD700',
        success: '#43A047',
        warning: '#FF9800',
        error: '#E53935',
        muted: '#B0B0C8',
        hint: '#6B6B8A',
      },
      fontFamily: { sans: ['Inter', 'system-ui', 'sans-serif'] },
    },
  },
  plugins: [],
};
