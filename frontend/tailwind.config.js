/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        carbon: {
          950: '#0a0c0e',
          900: '#121416',
          800: '#1a1c20',
          700: '#1f2328',
          600: '#2a2d33',
          500: '#3d4149',
        },
        emerald: {
          DEFAULT: '#10b981',
          dark: '#059669',
          deep: '#065f46',
          light: '#34d399',
        },
        muted: '#6b7280',
      },
      fontFamily: {
        sans: ['-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'sans-serif'],
        mono: ['SF Mono', 'Fira Code', 'monospace'],
      },
    },
  },
  plugins: [],
}
