/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        peach: "#FFAB91",
        coral: "#FF8A65",
        lavender: "#E1BEE7",
        lilac: "#CE93D8",
        skyBlue: "#81D4FA",
        mint: "#A5D6A7",
        sage: "#81C784",
        cream: "#FFF9E6",
        charcoal: "#2C2C2E",
        darkGray: "#48484A",
        lightGray: "#F2F2F7",
        offBlack: "#1C1C1E",
      },
      backgroundImage: {
        'gradient-bg-light': "linear-gradient(135deg, #FFF9E6 0%, #FFE8E0 50%, #F5E6FF 100%)",
        'gradient-bg-dark': "linear-gradient(135deg, #1C1C1E 0%, #2C2C2E 100%)",
        'gradient-accent': "linear-gradient(135deg, #FF8A65 0%, #CE93D8 50%, #81D4FA 100%)",
        'gradient-user': "linear-gradient(135deg, #E1BEE7 0%, #CE93D8 100%)",
        'gradient-send': "linear-gradient(135deg, #FF8A65 0%, #FF6B6B 100%)",
      },
      borderRadius: {
        'bubble': '22px',
        'input': '24px',
        'card': '16px',
        'small': '12px',
      },
      boxShadow: {
        'bubble': "0 2px 8px rgba(0, 0, 0, 0.08)",
        'input': "0 4px 12px rgba(0, 0, 0, 0.1)",
        'card': "0 4px 12px rgba(0, 0, 0, 0.05)",
      },
    }
  },
  plugins: []
};
