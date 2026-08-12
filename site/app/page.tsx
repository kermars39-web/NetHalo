"use client";

import Image from "next/image";
import { useEffect, useState } from "react";

const copy = {
  zh: {
    language: "EN",
    navTag: "原生 macOS 菜单栏工具",
    github: "GitHub",
    eyebrow: "NET SPEED · CPU · MEMORY",
    title: "状态，一眼就够了。",
    intro:
      "NetHalo 把实时网速留在菜单栏，把 CPU、内存和分应用占用收进一次点击里。简洁、原生，不打扰。",
    download: "下载 NetHalo 1.2",
    downloadMeta: "Apple Silicon · macOS 13+",
    source: "查看源代码",
    firstOpen: "当前版本为临时签名，首次启动请右键应用并选择“打开”。",
    visualLabel: "实时、清晰、只在本机",
    sectionEyebrow: "WHY NETHALO",
    sectionTitle: "不是更多数据，而是更少干扰。",
    sectionIntro: "保留真正需要看的一层，把其余信息放在需要时才出现的位置。",
    features: [
      {
        index: "01",
        title: "菜单栏不再拥挤",
        text: "上传在上、下载在下，固定宽度显示。数字变化时不左右晃动。",
      },
      {
        index: "02",
        title: "看起来就像系统的一部分",
        text: "原生 AppKit 与 macOS 27 弹层材质，不套网页外壳，也不堆装饰动画。",
      },
      {
        index: "03",
        title: "数据不离开你的 Mac",
        text: "无账号、无遥测、无上传。只有你主动检查更新时，才会访问 GitHub。",
      },
    ],
    detailTitle: "需要细节时，再点一下。",
    detailText:
      "点击网络、CPU 或内存卡片，下方立即切换对应的应用排行。NetHalo 会记住你的选择，下次打开仍停留在这里。",
    detailItems: ["最近一分钟趋势", "真实应用图标", "分应用实时排行", "手动检查更新"],
    ctaTitle: "让菜单栏重新安静下来。",
    ctaText: "免费下载、MIT 开源。你可以直接使用，也可以一起把它做得更好。",
    ctaButton: "下载 1.2",
    footer: "Native macOS. Zero telemetry. Built for calm.",
  },
  en: {
    language: "中文",
    navTag: "Native macOS menu bar utility",
    github: "GitHub",
    eyebrow: "NET SPEED · CPU · MEMORY",
    title: "Your Mac, at a glance.",
    intro:
      "NetHalo keeps live network speed in the menu bar and puts CPU, memory, and per-app usage one click away. Native, focused, and quiet.",
    download: "Download NetHalo 1.2",
    downloadMeta: "Apple Silicon · macOS 13+",
    source: "View source",
    firstOpen: "This build is ad-hoc signed. Right-click the app and choose Open on first launch.",
    visualLabel: "Live, legible, local",
    sectionEyebrow: "WHY NETHALO",
    sectionTitle: "Less dashboard. More signal.",
    sectionIntro: "Keep the one metric you need visible. Reveal everything else only when you ask for it.",
    features: [
      {
        index: "01",
        title: "A menu bar that stays calm",
        text: "Upload above, download below, in a fixed-width meter that never shifts as values change.",
      },
      {
        index: "02",
        title: "Designed like part of macOS",
        text: "Native AppKit and macOS 27 popover materials, with no web wrapper or decorative motion overload.",
      },
      {
        index: "03",
        title: "Your data stays on your Mac",
        text: "No account, telemetry, or uploads. NetHalo only contacts GitHub when you check for updates.",
      },
    ],
    detailTitle: "Details when you want them.",
    detailText:
      "Click Network, CPU, or Memory and the per-app ranking switches instantly. NetHalo remembers your choice for the next launch.",
    detailItems: ["One-minute trends", "Real app icons", "Per-app rankings", "Manual update checks"],
    ctaTitle: "Make your menu bar quiet again.",
    ctaText: "Free to download and open source under MIT. Use it as-is or help make it better.",
    ctaButton: "Download 1.2",
    footer: "Native macOS. Zero telemetry. Built for calm.",
  },
} as const;

const downloadUrl =
  "https://github.com/kermars39-web/NetHalo/releases/latest/download/NetHalo-macOS-arm64.dmg";
const githubUrl = "https://github.com/kermars39-web/NetHalo";
const assetBase = process.env.NEXT_PUBLIC_BASE_PATH ?? "";

export default function Home() {
  const [language, setLanguage] = useState<"zh" | "en">("zh");
  const text = copy[language];

  useEffect(() => {
    document.documentElement.lang = language === "zh" ? "zh-CN" : "en";
  }, [language]);

  return (
    <main>
      <nav className="nav shell" aria-label="Primary navigation">
        <a className="brand" href="#top" aria-label="NetHalo home">
          <Image src={`${assetBase}/net-halo-icon.png`} alt="" width={38} height={38} priority />
          <span>
            <strong>NetHalo</strong>
            <small>{text.navTag}</small>
          </span>
        </a>
        <div className="nav-actions">
          <a href={githubUrl} target="_blank" rel="noreferrer">
            {text.github}
          </a>
          <button
            className="language-button"
            type="button"
            onClick={() => setLanguage(language === "zh" ? "en" : "zh")}
            aria-label={language === "zh" ? "Switch to English" : "切换到中文"}
          >
            {text.language}
          </button>
        </div>
      </nav>

      <section className="hero shell" id="top">
        <div className="hero-copy">
          <p className="eyebrow">{text.eyebrow}</p>
          <h1>{text.title}</h1>
          <p className="hero-intro">{text.intro}</p>
          <div className="hero-actions">
            <a className="primary-button" href={downloadUrl}>
              <span>{text.download}</span>
              <small>{text.downloadMeta}</small>
            </a>
            <a className="secondary-button" href={githubUrl} target="_blank" rel="noreferrer">
              {text.source}
              <span aria-hidden="true">↗</span>
            </a>
          </div>
          <p className="first-open">{text.firstOpen}</p>
          <div className="trust-row" aria-label="Product attributes">
            <span>100% native</span>
            <span>MIT open source</span>
            <span>Zero telemetry</span>
          </div>
        </div>

        <div className="product-visual" aria-label={text.visualLabel}>
          <div className="halo halo-one" />
          <div className="halo halo-two" />
          <div className="screen-shell">
            <div className="screen-label">
              <span className="live-dot" />
              {text.visualLabel}
            </div>
            <div className="product-panel-mock" aria-label="NetHalo product interface preview">
              <div className="mock-header">
                <Image src={`${assetBase}/net-halo-icon.png`} alt="" width={38} height={38} />
                <div>
                  <strong>NetHalo</strong>
                  <small>Live system overview</small>
                </div>
                <span className="mock-status"><i />Calm</span>
              </div>

              <div className="mock-network-card">
                <div className="mock-card-heading">
                  <strong>Network flow</strong>
                  <span>↑↓</span>
                </div>
                <div className="mock-network-grid">
                  <div className="mock-network-value upload">
                    <small>↑ Upload</small>
                    <strong>8 KB/s</strong>
                    <div className="mock-spark upload-spark"><i /><i /><i /><i /><i /><i /></div>
                  </div>
                  <div className="mock-network-value download">
                    <small>↓ Download</small>
                    <strong>26 KB/s</strong>
                    <div className="mock-spark download-spark"><i /><i /><i /><i /><i /><i /></div>
                  </div>
                </div>
              </div>

              <div className="mock-usage-grid">
                <div className="mock-usage-card">
                  <span>CPU <i className="blue-dot" /></span>
                  <strong>28%</strong>
                  <div className="usage-line blue-line" />
                  <small>Current load</small>
                </div>
                <div className="mock-usage-card">
                  <span>Memory <i className="violet-dot" /></span>
                  <strong>67%</strong>
                  <div className="usage-line violet-line" />
                  <small>16.1 GB used</small>
                </div>
              </div>

              <div className="mock-app-card">
                <div className="mock-card-heading">
                  <strong>App activity</strong>
                  <span>Live</span>
                </div>
                {[
                  ["Browser", "18K/s", "blue"],
                  ["Terminal", "8K/s", "navy"],
                  ["Cloud Sync", "5K/s", "cyan"],
                  ["Messages", "2K/s", "green"],
                ].map(([name, value, color]) => (
                  <div className="mock-app-row" key={name}>
                    <i className={`mock-app-icon ${color}`} />
                    <strong>{name}</strong>
                    <span>{value}</span>
                  </div>
                ))}
              </div>

              <div className="mock-footer">
                <span>Local monitoring</span>
                <span>Settings&nbsp;&nbsp;⏻</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="why-section shell" id="why">
        <div className="section-heading">
          <p className="eyebrow">{text.sectionEyebrow}</p>
          <h2>{text.sectionTitle}</h2>
          <p>{text.sectionIntro}</p>
        </div>
        <div className="feature-grid">
          {text.features.map((feature) => (
            <article className="feature-card" key={feature.index}>
              <span className="feature-index">{feature.index}</span>
              <h3>{feature.title}</h3>
              <p>{feature.text}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="detail-section shell">
        <div className="detail-card">
          <div className="detail-copy">
            <span className="detail-kicker">ON DEMAND</span>
            <h2>{text.detailTitle}</h2>
            <p>{text.detailText}</p>
          </div>
          <div className="detail-list">
            {text.detailItems.map((item, index) => (
              <div className="detail-item" key={item}>
                <span>{String(index + 1).padStart(2, "0")}</span>
                <strong>{item}</strong>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="cta-section shell">
        <div className="cta-card">
          <Image src={`${assetBase}/net-halo-icon.png`} alt="" width={76} height={76} />
          <h2>{text.ctaTitle}</h2>
          <p>{text.ctaText}</p>
          <a className="primary-button compact" href={downloadUrl}>
            <span>{text.ctaButton}</span>
            <small>{text.downloadMeta}</small>
          </a>
        </div>
      </section>

      <footer className="footer shell">
        <div className="footer-brand">
          <Image src={`${assetBase}/net-halo-icon.png`} alt="" width={30} height={30} />
          <strong>NetHalo</strong>
        </div>
        <p>{text.footer}</p>
        <a href={githubUrl} target="_blank" rel="noreferrer">
          GitHub ↗
        </a>
      </footer>
    </main>
  );
}
