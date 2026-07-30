import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { headers } from "next/headers";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export async function generateMetadata(): Promise<Metadata> {
  const requestHeaders = await headers();
  const host = requestHeaders.get("host") ?? "localhost:3000";
  const protocol = host.startsWith("localhost") ? "http" : "https";
  const metadataBase = new URL(`${protocol}://${host}`);

  return {
    metadataBase,
    title: "NetHalo — A quieter macOS menu bar monitor",
    description:
      "A lightweight native macOS menu bar monitor for network speed, CPU, memory, and per-app usage. 简洁、原生、注重隐私。",
    icons: {
      icon: "/net-halo-icon.png",
      apple: "/net-halo-icon.png",
    },
    openGraph: {
      title: "NetHalo — Your Mac, at a glance.",
      description: "Native macOS monitoring without the dashboard clutter.",
      type: "website",
      url: "/",
      images: [{ url: "/og.png", width: 1200, height: 630, alt: "NetHalo for macOS" }],
    },
    twitter: {
      card: "summary_large_image",
      title: "NetHalo — Your Mac, at a glance.",
      description: "Native macOS monitoring without the dashboard clutter.",
      images: ["/og.png"],
    },
  };
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-CN">
      <body className={`${geistSans.variable} ${geistMono.variable}`}>{children}</body>
    </html>
  );
}
