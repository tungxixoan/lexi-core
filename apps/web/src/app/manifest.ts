import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "LexiCore",
    short_name: "LexiCore",
    description: "Ứng dụng học từ vựng cá nhân, Việt hoá.",
    start_url: "/",
    display: "standalone",
    background_color: "#FFF3EE",
    theme_color: "#FFF3EE",
    icons: [
      { src: "/icon-192.png", sizes: "192x192", type: "image/png" },
      { src: "/icon-512.png", sizes: "512x512", type: "image/png" },
      {
        src: "/icon-maskable-512.png",
        sizes: "512x512",
        type: "image/png",
        purpose: "maskable",
      },
    ],
  };
}
