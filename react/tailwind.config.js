/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./**/*.{js,ts,tsx}"],
  theme: {
    extend: {
      colors: {
        primary: "#6750A4",
        "on-primary": "#FFFFFF",
        "primary-container": "#EADDFF",
        "on-primary-container": "#21005D",
        surface: "#1C1B1F",
        "on-surface": "#E6E1E5",
        "surface-container": "#211F26",
        "on-surface-variant": "#CAC4D0",
        outline: "#938F99",
      },
      borderRadius: {
        xl: "12px",
        "2xl": "16px",
        "3xl": "24px",
      },
    },
  },
  plugins: [],
};
