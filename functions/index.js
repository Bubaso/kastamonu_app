// Kastamonu Haber — sunucu tarafı render
//
// ── Neden bu dosya var ───────────────────────────────────────────────
// Flutter'ın HTML renderer'ı 2026'da kaldırıldı; geriye yalnızca CanvasKit
// ve skwasm kaldı ve ikisi de çizimi tuvale yapıyor. Uygulama açıldıktan
// sonra sayfanın kaynağında okunacak TEK BİR KELİME yok.
//
// Sonuç: WhatsApp'a düşen bağlantı başlıksız, görselsiz bir kutu olarak
// görünüyor; Google da indeksleyecek metin bulamıyor. Bölüm 1'de dağıtımın
// WhatsApp üzerinden olacağını ölçmüştük — yani bu eksik, portalın
// büyümesini doğrudan engelliyor.
//
// Bu fonksiyonlar `index.html` kabuğunun içine gerçek meta etiketlerini VE
// gerçek gövde metnini basıyor. Flutter sonra açılıp devralıyor.
//
// ── Bot tespiti YOK — bilerek ────────────────────────────────────────
// Aynı HTML hem bota hem insana dönüyor. User-Agent'a bakıp farklı içerik
// sunmak (cloaking) Google tarafından cezalandırılabiliyor; ayrıca bot
// listesi sürekli bakım istiyor. Tarım Portalı'nda da aynı karar verildi.
//
// Güzel yan etkisi: bota giden o gerçek metin insana da gidiyor. Bölüm
// 2'de ölçülen 3,54 MB'lık paket inerken okunacak bir şey zaten var.

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { onRequest } from "firebase-functions/v2/https";

const BOLGE = "europe-west1";
const SITE_ADI = "Kastamonu Haber";
const SITE_ACIKLAMA =
  "Kastamonu ve ilçeleriyle ilgili haberler, kaynak gösterilerek derlenir.";

// Kanonik adres TEK yerden geliyor.
//
// Tarım Portalı'nda görsel ve paylaşım adresleri koda dağılmıştı; alan adı
// değişince paylaşım önizlemeleri sessizce eski adresi göstermeye devam
// etti. Burada tek sabit var ve her şey ondan türüyor.
const TABAN = process.env.SITE_TABAN || "https://kastamonuhaber.net";

const SUPABASE_URL =
  process.env.SUPABASE_URL || "https://vcwgcvzqdnjyoitdfhma.supabase.co";
// Anon anahtar yayımlanmak üzere tasarlandı; RLS'i tek başına aşamıyor ve
// zaten Flutter paketinin içinde tarayıcıya iniyor.
const SUPABASE_ANON = process.env.SUPABASE_ANON_KEY || "";

const ISARET_BAS = "<!-- SOCIAL_META_START -->";
const ISARET_SON = "<!-- SOCIAL_META_END -->";

// Tarayıcıda 5 dk, CDN'de 1 saat. `stale-while-revalidate` sayesinde süre
// dolduğunda okuyucu beklemiyor: CDN eski kopyayı verip arka planda
// yeniliyor. Bölüm 2'de ölçülen 13,9 saniyelik soğuk başlatma böylece
// haber başına yalnızca ilk isteği etkiliyor.
const ONBELLEK = "public, max-age=300, s-maxage=3600, stale-while-revalidate=86400";

// ─── Kabuk ────────────────────────────────────────────────────────────
// `deploy.sh` build/web/index.html'i buraya kopyalıyor; yani Flutter'ın
// ürettiği gerçek bootstrap etiketleriyle (sürüm damgalı betik yolu dâhil)
// birebir aynı. Tembel okunuyor: dağıtım sırasındaki fonksiyon tanıma
// zaman aşımını önlemek için.
const ASGARI_KABUK = `<!DOCTYPE html>
<html lang="tr"><head><base href="/"><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
${ISARET_BAS}<title>${SITE_ADI}</title>${ISARET_SON}
<link rel="manifest" href="manifest.json"></head>
<body><script src="flutter_bootstrap.js" async></script></body></html>`;

let _kabuk = null;
function kabuk() {
  if (_kabuk !== null) return _kabuk;
  try {
    _kabuk = readFileSync(
      fileURLToPath(new URL("./shell.html", import.meta.url)), "utf8");
  } catch (hata) {
    // Kabuk okunamazsa TÜM sayfaların 500 dönmesi kabul edilemez.
    // Dağıtım hatasının bedeli jenerik bir paylaşım kartı olmalı,
    // site kesintisi değil.
    console.error("shell.html okunamadı, asgari kabuğa düşüldü", hata);
    _kabuk = ASGARI_KABUK;
  }
  return _kabuk;
}

// ─── Yardımcılar ──────────────────────────────────────────────────────

/** Meta `content` niteliğine girecek HER metin buradan geçmek ZORUNDA. */
function kacir(deger) {
  return String(deger ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function duzMetin(html) {
  return String(html ?? "")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/** Kelimenin ortasından kesmez. */
function kirp(metin, sinir) {
  const t = String(metin ?? "").trim();
  if (t.length <= sinir) return t;
  const kes = t.slice(0, sinir);
  const bosluk = kes.lastIndexOf(" ");
  const temel = bosluk > sinir * 0.6 ? kes.slice(0, bosluk) : kes;
  return `${temel.replace(/[.,;:\-–—\s]+$/, "")}…`;
}

async function supabase(yol) {
  const yanit = await fetch(`${SUPABASE_URL}/rest/v1/${yol}`, {
    headers: {
      apikey: SUPABASE_ANON,
      Authorization: `Bearer ${SUPABASE_ANON}`,
    },
  });
  if (!yanit.ok) throw new Error(`Supabase ${yanit.status}`);
  return yanit.json();
}

const SECIM =
  "id,slug,baslik,spot,govde,kaynak_adi,kaynak_url,yayinci,gorsel_url," +
  "gorsel_kaynak,olusturuldu,yayinlandi,kategoriler(ad,slug)," +
  "haber_ilce(onaylandi,ilceler(ad))";

/** Meta bloğunu üretir. */
function metaBlogu({ baslik, aciklama, adres, gorsel, tur = "website", tarih }) {
  const satirlar = [
    ISARET_BAS,
    `  <title>${kacir(baslik)}</title>`,
    `  <meta name="description" content="${kacir(aciklama)}">`,
    `  <link rel="canonical" href="${kacir(adres)}">`,
    `  <meta property="og:type" content="${tur}">`,
    `  <meta property="og:site_name" content="${kacir(SITE_ADI)}">`,
    `  <meta property="og:locale" content="tr_TR">`,
    `  <meta property="og:title" content="${kacir(baslik)}">`,
    `  <meta property="og:description" content="${kacir(aciklama)}">`,
    `  <meta property="og:url" content="${kacir(adres)}">`,
  ];
  if (gorsel) {
    satirlar.push(
      `  <meta property="og:image" content="${kacir(gorsel)}">`,
      // Ölçüyü bildirmek, botun görseli indirip incelemeden karar
      // vermesini sağlıyor; önizleme daha hızlı çiziliyor.
      `  <meta property="og:image:width" content="1200">`,
      `  <meta property="og:image:height" content="630">`,
      `  <meta property="og:image:type" content="image/jpeg">`,
      `  <meta property="og:image:alt" content="${kacir(baslik)}">`,
      `  <meta name="twitter:card" content="summary_large_image">`,
      `  <meta name="twitter:image" content="${kacir(gorsel)}">`);
  } else {
    satirlar.push(`  <meta name="twitter:card" content="summary">`);
  }
  satirlar.push(
    `  <meta name="twitter:title" content="${kacir(baslik)}">`,
    `  <meta name="twitter:description" content="${kacir(aciklama)}">`);
  if (tarih) {
    satirlar.push(
      `  <meta property="article:published_time" content="${kacir(tarih)}">`);
  }
  satirlar.push(ISARET_SON);
  return satirlar.join("\n");
}

/**
 * Kabuğa meta ve gövde yerleştirir.
 *
 * Gövde `<body>`nin BAŞINA konuyor: Flutter açıldığında üzerine çiziyor,
 * ama bot ve yavaş bağlantıdaki okuyucu o metni önce görüyor.
 */
function sayfaKur(meta, govdeHtml) {
  let html = kabuk();
  const bas = html.indexOf(ISARET_BAS);
  const son = html.indexOf(ISARET_SON);
  if (bas !== -1 && son !== -1) {
    html = html.slice(0, bas) + meta + html.slice(son + ISARET_SON.length);
  }
  if (govdeHtml) {
    html = html.replace("<body>", `<body>\n<div id="ssr">${govdeHtml}</div>`);
  }
  return html;
}

function yanitla(res, html) {
  res.set("Content-Type", "text/html; charset=utf-8");
  res.set("Cache-Control", ONBELLEK);
  res.status(200).send(html);
}

// ─── Haber sayfası ────────────────────────────────────────────────────

export const haberRender = onRequest({ region: BOLGE }, async (req, res) => {
  try {
    const slug = decodeURIComponent(
      (req.path || "").split("/").filter(Boolean).pop() || "");
    if (!slug) return yanitla(res, kabuk());

    const kayitlar = await supabase(
      `haberler?slug=eq.${encodeURIComponent(slug)}` +
      `&durum=eq.yayinda&select=${encodeURIComponent(SECIM)}&limit=1`);
    const h = kayitlar[0];
    if (!h) return yanitla(res, kabuk());

    const adres = `${TABAN}/haber/${h.slug}`;
    const spot = duzMetin(h.spot || "") ||
      kirp(duzMetin(h.govde || ""), 160);
    const ilceler = (h.haber_ilce || [])
      .filter((b) => b.onaylandi && b.ilceler)
      .map((b) => b.ilceler.ad);

    const meta = metaBlogu({
      baslik: `${h.baslik} | ${SITE_ADI}`,
      aciklama: kirp(spot, 200),
      adres,
      gorsel: h.gorsel_url,
      tur: "article",
      tarih: h.yayinlandi || h.olusturuldu,
    });

    // Gövde: gerçek metin. Bölüm 2'de tarım portalında ölçtüğümüz gibi,
    // botun gördüğü şey bu — meta etiketleri paylaşım kartını, bu blok
    // arama motorunu besliyor.
    const paragraflar = String(h.govde || "")
      .split(/\n+/).map((p) => p.trim()).filter(Boolean)
      .map((p) => `<p>${kacir(p)}</p>`).join("\n");

    const govde = [
      "<article>",
      h.kategoriler ? `<p>${kacir(h.kategoriler.ad)}</p>` : "",
      `<h1>${kacir(h.baslik)}</h1>`,
      ilceler.length ? `<p>${kacir(ilceler.join(", "))}</p>` : "",
      spot ? `<p><strong>${kacir(spot)}</strong></p>` : "",
      paragraflar,
      `<p>Kaynak: ${kacir(h.yayinci || h.kaynak_adi)} — ` +
      `<a href="${kacir(h.kaynak_url)}" rel="nofollow noopener">özgün haber</a></p>`,
      h.gorsel_kaynak
        ? `<p>Fotoğraf: ${kacir(h.gorsel_kaynak)}</p>` : "",
      "</article>",
    ].filter(Boolean).join("\n");

    yanitla(res, sayfaKur(meta, govde));
  } catch (hata) {
    console.error("haberRender", hata);
    yanitla(res, kabuk());
  }
});

// ─── Kategori sayfası ─────────────────────────────────────────────────

export const kategoriRender = onRequest({ region: BOLGE }, async (req, res) => {
  try {
    const slug = decodeURIComponent(
      (req.path || "").split("/").filter(Boolean).pop() || "");
    if (!slug) return yanitla(res, kabuk());

    const kategoriler = await supabase(
      `kategoriler?slug=eq.${encodeURIComponent(slug)}&select=ad,slug&limit=1`);
    const k = kategoriler[0];
    if (!k) return yanitla(res, kabuk());

    const haberler = await supabase(
      `haberler?durum=eq.yayinda&select=${encodeURIComponent(SECIM)}` +
      `&order=yayinlandi.desc&limit=30`);
    const liste = haberler.filter(
      (h) => h.kategoriler && h.kategoriler.slug === slug);

    const adres = `${TABAN}/kategori/${k.slug}`;
    const meta = metaBlogu({
      baslik: `${k.ad} haberleri | ${SITE_ADI}`,
      aciklama: `Kastamonu ${k.ad.toLowerCase()} haberleri. ${SITE_ACIKLAMA}`,
      adres,
      gorsel: liste[0]?.gorsel_url,
    });

    const govde = [
      `<h1>${kacir(k.ad)} haberleri</h1>`,
      "<ul>",
      ...liste.map((h) =>
        `<li><a href="/haber/${kacir(h.slug)}">${kacir(h.baslik)}</a>` +
        (h.spot ? ` — ${kacir(kirp(duzMetin(h.spot), 140))}` : "") + "</li>"),
      "</ul>",
    ].join("\n");

    yanitla(res, sayfaKur(meta, govde));
  } catch (hata) {
    console.error("kategoriRender", hata);
    yanitla(res, kabuk());
  }
});

// ─── Ana sayfa ────────────────────────────────────────────────────────

export const anasayfaRender = onRequest({ region: BOLGE }, async (req, res) => {
  try {
    const haberler = await supabase(
      `haberler?durum=eq.yayinda&select=${encodeURIComponent(SECIM)}` +
      `&order=yayinlandi.desc&limit=30`);

    const meta = metaBlogu({
      baslik: SITE_ADI,
      aciklama: SITE_ACIKLAMA,
      adres: TABAN,
      gorsel: haberler[0]?.gorsel_url,
    });

    // İç bağlantılar: tarayıcının derin sayfalara ulaşabilmesi için tek
    // yol bu. Ana sayfa SSR'siz kalırsa hiçbir haber keşfedilemiyor.
    const govde = [
      `<h1>${kacir(SITE_ADI)}</h1>`,
      `<p>${kacir(SITE_ACIKLAMA)}</p>`,
      "<ul>",
      ...haberler.map((h) =>
        `<li><a href="/haber/${kacir(h.slug)}">${kacir(h.baslik)}</a></li>`),
      "</ul>",
    ].join("\n");

    yanitla(res, sayfaKur(meta, govde));
  } catch (hata) {
    console.error("anasayfaRender", hata);
    yanitla(res, kabuk());
  }
});

// ─── Sitemap ──────────────────────────────────────────────────────────

export const sitemap = onRequest({ region: BOLGE }, async (req, res) => {
  try {
    const [haberler, kategoriler] = await Promise.all([
      supabase("haberler?durum=eq.yayinda&select=slug,yayinlandi,olusturuldu" +
               "&order=yayinlandi.desc&limit=2000"),
      supabase("kategoriler?select=slug&order=sira"),
    ]);

    const girdi = (yol, tarih) =>
      `  <url><loc>${TABAN}${yol}</loc>` +
      (tarih ? `<lastmod>${new Date(tarih).toISOString()}</lastmod>` : "") +
      "</url>";

    const govde = [
      '<?xml version="1.0" encoding="UTF-8"?>',
      '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
      girdi("/"),
      ...kategoriler.map((k) => girdi(`/kategori/${k.slug}`)),
      ...haberler.map((h) =>
        girdi(`/haber/${h.slug}`, h.yayinlandi || h.olusturuldu)),
      "</urlset>",
    ].join("\n");

    res.set("Content-Type", "application/xml; charset=utf-8");
    res.set("Cache-Control", "public, max-age=3600, s-maxage=21600");
    res.status(200).send(govde);
  } catch (hata) {
    console.error("sitemap", hata);
    res.status(500).send("");
  }
});
