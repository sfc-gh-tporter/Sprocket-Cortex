export function ChainringLogo({ size = 42 }: { size?: number }) {
  return (
    <svg
      viewBox="0 0 100 100"
      width={size}
      height={size}
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      {/* Teeth */}
      <path d="M50 3 L52 9 L48 9 Z" fill="#10b981" />
      <path d="M58.5 3.8 L59.5 10 L55.8 9 Z" fill="#10b981" />
      <path d="M66.5 6.5 L66.2 12.8 L63 11 Z" fill="#10b981" />
      <path d="M73.5 11 L72 17 L69.2 14.5 Z" fill="#10b981" />
      <path d="M79.5 17 L76.5 22.5 L74.5 19.5 Z" fill="#10b981" />
      <path d="M84 24 L80 28.5 L78.5 25.5 Z" fill="#10b981" />
      <path d="M87.2 31.5 L82.5 35 L81.8 31.8 Z" fill="#10b981" />
      <path d="M89 39.5 L84 41.8 L83.8 38.5 Z" fill="#10b981" />
      <path d="M89.5 48 L84.5 49 L84.8 45.5 Z" fill="#10b981" />
      <path d="M88.5 56.5 L83.5 56 L84.5 52.8 Z" fill="#10b981" />
      <path d="M86 64.5 L81.2 62.5 L83 59.5 Z" fill="#10b981" />
      <path d="M82 72 L77.8 69 L80 66.2 Z" fill="#10b981" />
      <path d="M76.5 78.5 L73 74.5 L75.8 72.2 Z" fill="#10b981" />
      <path d="M70 83.5 L67.5 79 L70.5 77.5 Z" fill="#10b981" />
      <path d="M62.5 87 L61 82.2 L64 81.5 Z" fill="#10b981" />
      <path d="M54.5 89 L54 84 L57 84 Z" fill="#10b981" />
      <path d="M46 89.2 L47 84.2 L43.8 84.2 Z" fill="#10b981" />
      <path d="M38 87.2 L40 82.5 L37 81.8 Z" fill="#10b981" />
      <path d="M30.5 84 L33.5 79.5 L30.2 78 Z" fill="#10b981" />
      <path d="M24 79 L27.8 75 L25 73 Z" fill="#10b981" />
      <path d="M18.5 72.5 L23 69.5 L20.8 66.8 Z" fill="#10b981" />
      <path d="M14.5 65 L19.5 63 L17.8 60 Z" fill="#10b981" />
      <path d="M11.5 57 L16.8 56.2 L15.8 53 Z" fill="#10b981" />
      <path d="M10 49 L15.2 49.2 L14.8 46 Z" fill="#10b981" />
      <path d="M10.2 41 L15.2 42 L14.2 38.8 Z" fill="#10b981" />
      <path d="M12 33.5 L16.8 35.5 L15 32.5 Z" fill="#10b981" />
      <path d="M15.5 26.5 L19.8 29.5 L17.5 27 Z" fill="#10b981" />
      <path d="M20.5 20.5 L24 24.2 L21.2 22.5 Z" fill="#10b981" />
      <path d="M27 15.5 L29.5 20 L27 18.5 Z" fill="#10b981" />
      <path d="M34 11.5 L35.5 17 L33 15.5 Z" fill="#10b981" />
      <path d="M41.5 8.5 L42 14 L39.5 12.5 Z" fill="#10b981" />
      {/* Outer ring */}
      <circle cx="50" cy="50" r="35" stroke="#10b981" strokeWidth="3" fill="none" />
      {/* Inner chain engagement ring */}
      <circle cx="50" cy="50" r="28" stroke="#059669" strokeWidth="1.5" fill="none" />
      {/* Spider arms (4-arm) */}
      <path d="M50 50 L50 22" stroke="#059669" strokeWidth="4" strokeLinecap="round" />
      <path d="M50 50 L78 50" stroke="#059669" strokeWidth="4" strokeLinecap="round" />
      <path d="M50 50 L50 78" stroke="#059669" strokeWidth="4" strokeLinecap="round" />
      <path d="M50 50 L22 50" stroke="#059669" strokeWidth="4" strokeLinecap="round" />
      {/* Bolt holes */}
      <circle cx="50" cy="30" r="3" fill="#121416" stroke="#10b981" strokeWidth="1" />
      <circle cx="70" cy="50" r="3" fill="#121416" stroke="#10b981" strokeWidth="1" />
      <circle cx="50" cy="70" r="3" fill="#121416" stroke="#10b981" strokeWidth="1" />
      <circle cx="30" cy="50" r="3" fill="#121416" stroke="#10b981" strokeWidth="1" />
      {/* Center BB interface */}
      <circle cx="50" cy="50" r="10" stroke="#10b981" strokeWidth="1.5" fill="#121416" />
      <circle cx="50" cy="50" r="4" fill="#10b981" />
    </svg>
  )
}

export function ChainringIcon({ size = 20 }: { size?: number }) {
  return (
    <svg viewBox="0 0 100 100" width={size} height={size} fill="none">
      <circle cx="50" cy="50" r="35" stroke="#10b981" strokeWidth="4" fill="none" />
      <circle cx="50" cy="50" r="28" stroke="#059669" strokeWidth="2" fill="none" />
      <path d="M50 50 L50 20" stroke="#059669" strokeWidth="4" strokeLinecap="round" />
      <path d="M50 50 L80 50" stroke="#059669" strokeWidth="4" strokeLinecap="round" />
      <path d="M50 50 L50 80" stroke="#059669" strokeWidth="4" strokeLinecap="round" />
      <path d="M50 50 L20 50" stroke="#059669" strokeWidth="4" strokeLinecap="round" />
      <circle cx="50" cy="50" r="8" fill="#121416" stroke="#10b981" strokeWidth="2" />
      <circle cx="50" cy="50" r="3" fill="#10b981" />
    </svg>
  )
}
