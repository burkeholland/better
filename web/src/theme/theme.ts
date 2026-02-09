export const colors = {
  // Primary colors
  peach: "#FFAB91",
  coral: "#FF8A65",
  lavender: "#E1BEE7",
  lilac: "#CE93D8",
  skyBlue: "#81D4FA",
  mint: "#A5D6A7",
  sage: "#81C784",
  cream: "#FFF9E6",

  // Neutrals
  charcoal: "#2C2C2E",
  darkGray: "#48484A",
  lightGray: "#F2F2F7",
  
  // Dark mode specifics
  offBlack: "#1C1C1E",
};

export const gradients = {
  background: {
    light: "linear-gradient(135deg, #FFF9E6 0%, #FFE8E0 50%, #F5E6FF 100%)",
    dark: "linear-gradient(135deg, #1C1C1E 0%, #2C2C2E 100%)",
  },
  accent: "linear-gradient(135deg, #FF8A65 0%, #CE93D8 50%, #81D4FA 100%)",
  userBubble: "linear-gradient(135deg, #E1BEE7 0%, #CE93D8 100%)",
  sendButton: "linear-gradient(135deg, #FF8A65 0%, #FF6B6B 100%)",
};

export const shadows = {
  bubble: "0 2px 8px rgba(0, 0, 0, 0.08)",
  input: "0 4px 12px rgba(0, 0, 0, 0.1)",
  card: "0 4px 12px rgba(0, 0, 0, 0.05)",
};

export const radius = {
  bubble: "22px",
  input: "24px",
  card: "16px",
  small: "12px",
};

export const theme = {
  colors,
  gradients,
  shadows,
  radius,
};
