import { createSystem, defaultConfig, defineConfig } from "@chakra-ui/react";

const customConfig = defineConfig({
  theme: {
    tokens: {
      colors: {
        // Define your custom primary color palette
        primary: {
          50: { value: "#fef2f2" },
          100: { value: "#fee2e2" },
          200: { value: "#fecaca" },
          300: { value: "#fca5a5" },
          400: { value: "#f87171" },
          500: { value: "#ef4444" },
          600: { value: "#db2739" }, // Your primary-600
          700: { value: "#c21e2e" }, // Your primary-700
          800: { value: "#991b27" }, // Your primary-800
          900: { value: "#7f1d1d" },
          950: { value: "#450a0a" },
        },
      },
    },
    semanticTokens: {
      colors: {
        // Map orange palette to your primary colors
        "orange.50": { value: "{colors.primary.50}" },
        "orange.100": { value: "{colors.primary.100}" },
        "orange.200": { value: "{colors.primary.200}" },
        "orange.300": { value: "{colors.primary.300}" },
        "orange.400": { value: "{colors.primary.400}" },
        "orange.500": { value: "{colors.primary.500}" },
        "orange.600": { value: "{colors.primary.600}" },
        "orange.700": { value: "{colors.primary.700}" },
        "orange.800": { value: "{colors.primary.800}" },
        "orange.900": { value: "{colors.primary.900}" },
        "orange.950": { value: "{colors.primary.950}" },
      },
    },
  },
});

export const system = createSystem(defaultConfig, customConfig);
