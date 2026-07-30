import type { NextConfig } from "next";

const isGitHubPages = process.env.GITHUB_PAGES === "true";

const nextConfig: NextConfig = {
  output: "export",
  basePath: isGitHubPages ? "/NetHalo" : undefined,
  assetPrefix: isGitHubPages ? "/NetHalo/" : undefined,
  images: {
    unoptimized: true,
  },
};

export default nextConfig;
