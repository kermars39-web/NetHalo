import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://kermars39-web.github.io/NetHalo/"),
  title: "NetHalo — A quieter macOS menu bar monitor",
  description:
    "A lightweight native macOS menu bar monitor for network speed, CPU, memory, and per-app usage. 简洁、原生、注重隐私。",
  icons: {
    icon: "/NetHalo/net-halo-icon.png",
    apple: "/NetHalo/net-halo-icon.png",
  },
  openGraph: {
    title: "NetHalo — Your Mac, at a glance.",
    description: "Native macOS monitoring without the dashboard clutter.",
    type: "website",
    url: "/",
    images: [{ url: "/NetHalo/og.png", width: 1200, height: 630, alt: "NetHalo for macOS" }],
  },
  twitter: {
    card: "summary_large_image",
    title: "NetHalo — Your Mac, at a glance.",
    description: "Native macOS monitoring without the dashboard clutter.",
    images: ["/NetHalo/og.png"],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
