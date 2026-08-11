import assert from "node:assert/strict";
import { readFile, stat } from "node:fs/promises";
import test from "node:test";

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request("http://localhost/", {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );
}

test("server-renders the NetHalo product page", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>NetHalo — A quieter macOS menu bar monitor<\/title>/i);
  assert.match(html, /状态，一眼就够了。/);
  assert.match(html, /下载 NetHalo 1\.1/);
  assert.match(html, /NetHalo-macOS-arm64\.dmg/);
  assert.match(html, /github\.com\/kermars39-web\/NetHalo/);
  assert.doesNotMatch(html, /boost(?:net)?/i);
});

test("keeps the bilingual, accessible release surface intact", async () => {
  const [page, css, icon, socialCard] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/globals.css", import.meta.url), "utf8"),
    stat(new URL("../public/net-halo-icon.png", import.meta.url)),
    stat(new URL("../public/og.png", import.meta.url)),
  ]);

  assert.match(page, /language === "zh" \? "en" : "zh"/);
  assert.match(page, /Your Mac, at a glance\./);
  assert.match(page, /当前版本为临时签名/);
  assert.match(page, /This build is ad-hoc signed/);
  assert.match(css, /prefers-reduced-motion:\s*reduce/);
  assert.match(css, /prefers-reduced-transparency:\s*reduce/);
  assert.doesNotMatch(page, /boost(?:net)?/i);
  assert.ok(icon.size > 100_000);
  assert.ok(socialCard.size > 100_000);
});
