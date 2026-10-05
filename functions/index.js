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

// Görsel boyutlandırma ayrı bir dosyada: bu dosyanın derdi sunucu tarafı
// render, onunki ağ trafiği. Dağıtımın görmesi için buradan geçiyor.
export { gorsel } from "./gorsel.js";

const BOLGE = "europe-west1";
const SITE_ADI = "Kastamonu Haber";
const SITE_ACIKLAMA =
  "Kastamonu ve ilçeleriyle ilgili haberler, kaynak gösterilerek derlenir.";

// Kanonik adres TEK yerden geliyor.
//
// Tarım Portalı'nda görsel ve paylaşım adresleri koda dağılmıştı; alan adı
// değişince paylaşım önizlemeleri sessizce eski adresi göstermeye devam
// etti. Burada tek sabit var ve her şey ondan türüyor: canonical, og:url,
// sitemap girdileri, iç bağlantılar.
//
// Şu an Firebase'in varsayılan adresi. Gerçek alan adı alındığında
// YALNIZCA bu satır değişecek — ya da dağıtımda `SITE_TABAN` ortam
// değişkeni verilecek.
const TABAN = process.env.SITE_TABAN || "https://kastamonuhaber-68645.web.app";

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

/** Künyede gösterilecek sade kaynak adı.
 *
 * Akış adları kategori eki taşıyor: "Haberler.com / Kastamonu". Okur için
 * o ek gürültü; uygulamada da aynı sadeleştirme yapılıyor.
 */
function kaynakKisa(yayinci, kaynakAdi) {
  const ad = String(yayinci || kaynakAdi || "").trim();
  const parca = ad.split("/")[0].trim();
  return parca || ad;
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

// Aynı olayı anlatan kayıtlar listede bir kez görünsün. Kural Dart
// tarafında da var ama orası ancak Flutter açıldıktan sonra çalışıyor;
// SSR kendi sorgusunu atıyor ve ölçümde ana sayfa aynı Daday yangınını
// iki kez listeliyordu.
import { tekille } from "./tekille.js";

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
      `<p>Kaynak: ${kacir(kaynakKisa(h.yayinci, h.kaynak_adi))} — ` +
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

    // Kırpma, kategori süzgecinden SONRA: önce kırpılsaydı bölümün
    // haberleri, başka bölümlerin daha yeni haberleri yüzünden listeden
    // düşerdi.
    const haberler = tekille(await supabase(
      `haberler?durum=eq.yayinda&select=${encodeURIComponent(SECIM)}` +
      `&order=yayinlandi.desc&limit=200`));
    const liste = haberler
      .filter((h) => h.kategoriler && h.kategoriler.slug === slug)
      .slice(0, 30);

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
    // Tekilleştirme eleyeceği için fazladan çekiliyor; ana sayfa yine
    // 30 haber listeliyor.
    const haberler = tekille(await supabase(
      `haberler?durum=eq.yayinda&select=${encodeURIComponent(SECIM)}` +
      `&order=yayinlandi.desc&limit=45`)).slice(0, 30);

    const meta = metaBlogu({
      baslik: SITE_ADI,
      aciklama: SITE_ACIKLAMA,
      adres: TABAN,
      gorsel: haberler[0]?.gorsel_url,
    });

    // Ana sayfa artık haber LİSTESİ basmıyor.
    //
    // Basıyordu ve okur siteyi her açtığında, CanvasKit inene kadar o
    // listeyi görüyordu. Stillendirmek yetmedi: liste okunacak sayfa
    // değil, bekleme ekranı; görünmesi gereken şey hiç değil.
    //
    // Gizlemek de doğru değildi — gizli metin arama motoru açısından
    // riskli. Üçüncü yol: makineye makinenin biçiminde vermek.
    //
    //   • Haber listesi JSON-LD `ItemList` olarak <head>'de. Yapısal
    //     veri zaten MAKİNE İÇİN tasarlanmış, görünmemesi kuralın
    //     kendisi; "gizli metin" sayılmıyor.
    //   • Keşif zaten sitemap.xml'de: ölçüldü, 81 adresin tamamı
    //     orada ve `robots.txt` artık onu açıkça bildiriyor.
    //   • İç bağlantı katmanı kategori sayfalarında: onlar SSR'da
    //     haber bağlantılarını basıyor ve ana sayfa onlara bağlanıyor.
    //
    // Yani "ana sayfa SSR'siz kalırsa hiçbir haber keşfedilemez"
    // doğru değilmiş; keşfin üç ayağı da ayakta.
    const kategoriler = await supabase("kategoriler?select=ad,slug&order=sira");

    const listeVerisi = {
      "@context": "https://schema.org",
      "@type": "CollectionPage",
      name: SITE_ADI,
      description: SITE_ACIKLAMA,
      url: TABAN + "/",
      mainEntity: {
        "@type": "ItemList",
        numberOfItems: haberler.length,
        itemListElement: haberler.map((h, i) => ({
          "@type": "ListItem",
          position: i + 1,
          url: `${TABAN}/haber/${h.slug}`,
          name: h.baslik,
        })),
      },
    };

    // Ekranda duran şey: uygulamanın kendi başlığının durağan kopyası.
    // Flutter açılınca aynı başlık tuvalde çiziliyor, dolayısıyla
    // geçiş göze çarpmıyor — "sayfa yükleniyor" değil, "sayfa açıldı"
    // hissi veren tek kurgu bu.
    const govde = [
      '<div class="kabuk">',
      `  <div class="kabuk-ad">${kacir(SITE_ADI)}</div>`,
      '  <nav class="kabuk-bolumler">',
      ...kategoriler.map((k) =>
        `    <a href="/kategori/${kacir(k.slug)}">${kacir(k.ad)}</a>`),
      "  </nav>",
      "</div>",
    ].join("\n");

    const yapisal =
      '<script type="application/ld+json">' +
      JSON.stringify(listeVerisi).replace(/</g, "\\u003c") +
      "</script>";

    yanitla(res, sayfaKur(meta + "\n" + yapisal, govde));
  } catch (hata) {
    console.error("anasayfaRender", hata);
    yanitla(res, kabuk());
  }
});

// ─── Sitemap ──────────────────────────────────────────────────────────

export const sitemap = onRequest({ region: BOLGE }, async (req, res) => {
  try {
    const [haberler, kategoriler] = await Promise.all([
      // Tekilleştirme için ilçe, kategori ve başlık da gerekiyor:
      // iki neredeyse aynı adres arama motoruna tekrarlayan içerik
      // sinyali veriyor.
      supabase("haberler?durum=eq.yayinda&select=" + encodeURIComponent(
        "id,slug,baslik,govde,gorsel_url,gorsel_kaynak,yayinlandi," +
        "olusturuldu,kategoriler(ad),haber_ilce(onaylandi,ilceler(ad))") +
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
      ...tekille(haberler).map((h) =>
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

// ─── Haber hattı ──────────────────────────────────────────────────
//
// Hat artık burada koşuyor. Daha önce kullanıcının kendi
// bilgisayarındaki bir Python işçisiydi; o makine kapalıyken hiçbir
// şey çekilmiyor, paneldeki düğme kuyruğa yazıp bekliyordu.
//
// YETKİ: koşu veritabanına yazıyor ve her çağrı model maliyeti
// üretiyor. Fonksiyon `service_role` anahtarını taşıdığı için RLS onu
// da sınırlamıyor. Bu yüzden uç nokta açık DEĞİL: çağıranın geçerli
// bir editör oturumu olmak zorunda. Panel o oturumu zaten açıyor.
//
// YAZMA: varsayılan kuru koşu — hiçbir şey yazılmıyor, ne yazılacağı
// dönüyor. Yazmak için `?yaz=1` gerekiyor. Yazılan kayıtlar
// `durum='inceleme'` ile açılıyor; editör onayı akıştan çıkmıyor.

export const hatKos = onRequest(
  {
    region: BOLGE,
    timeoutSeconds: 540,
    memory: "512MiB",
    secrets: ["GEMINI_API_KEY", "SUPABASE_SERVICE_KEY"],
  },
  async (req, res) => {
    const { oturumDogrula } = await import("./hat/yetki.js");
    const oturum = await oturumDogrula(req.headers);
    if (!oturum.tamam) {
      return res.status(401).json({ hata: oturum.sebep });
    }

    const yaz = req.query.yaz === "1";
    try {
      const { govdeDoldur, tara } = await import("./hat/kaynak.js");
      const { kos } = await import("./hat/kos.js");
      const { cagirici } = await import("./hat/gemini.js");
      const { gorselKopyala, gorselSec, satirKur, yazici } =
        await import("./hat/kaydet.js");

      const yz = yaz ? yazici() : null;
      const sonuc = await kos({
        tara, cagir: cagirici(), yazici: yz, kuru: !yaz, govdeDoldur,
        enCok: Math.min(Number(req.query.adet) || 20, 40),
      });

      const eklenen = [];
      if (yaz && yz) {
        const { slugla } = await import("./hat/kaydet.js");
        const { ilceBul } = await import("./hat/kos.js");
        const { ayniOlay } = await import("./tekille.js");

        // Tekilleştirmenin İKİNCİ katmanı: aynı olay, başka adres.
        //
        // Birincisi (`varMi`) adres eşitliğine bakıyor ve aynı olayın
        // başka bir yayından, başka bir adresle gelen kaydını
        // yakalayamıyor. Ölçümde "Cide'de balık tutarken kalp krizi
        // geçiren kişi" yayındayken hat "Cide'de denizde kalp krizi
        // geçiren balıkçı" diye ikinci bir kayıt üretti; benzerlik
        // 0,55 ve ikisi de okura görünüyordu.
        //
        // Ölçüt uydurulmuyor: sayfada tekrarı gizleyen `ayniOlay`in
        // ta kendisi kullanılıyor. Orada aynı sayılan iki haber
        // burada da aynıdır — iki yerde iki farklı tanım olması,
        // sayfanın gizlediği bir kaydın masaya düşmesi demekti.
        //
        // İlçe İKİ TARAFTA DA METİNDEN türetiliyor, kayıttaki bağdan
        // değil. `ayniOlay` iki KAYITLI satırı karşılaştırmak için
        // yazılmış ve ilçeyi `haber_ilce` bağından okuyor; oysa o bağ
        // ayrı bir süreçle doluyor ve seyrek: ölçümde 81 kaydın yalnız
        // 18'inde onaylı bağ vardı. Adaya başlıktan ilçe türetip
        // kayıtlıya bağından bakmak karşılaştırmayı asimetrik yapıyor
        // ve kural ters tepiyordu — ölçüldü: başlıklar BİREBİR aynıyken
        // (benzerlik 1,00) `ayniOlay` false döndü, çünkü aday {Cide}
        // diyordu, kayıtlı boş. Haber de ikinci kez yazılmaya kalkıp
        // slug çakışmasına düştü.
        const karsilastirilabilir = (o) => ({
          id: o.id ?? null,
          baslik: o.baslik,
          olusturuldu: o.olusturuldu,
          kategoriler: o.kategoriler,
          haber_ilce: [...ilceBul(o.baslik, o.spot ?? "")]
            .map((ad) => ({ onaylandi: true, ilceler: { ad } })),
        });
        const oncekiler = (await yz.sonKayitlar(7)).map(karsilastirilabilir);
        // Görsel kopyalama da paralel: her biri bir indirme + bir
        // yükleme, sırayla yapıldığında koşunun yarısını yiyor.
        const isler = sonuc.yazilan.map(({ sentez, olay, kapsam }) => async () => {
          try {
            // Görsel kendi depomuza kopyalanıyor; kopyalanamazsa haber
            // AÇILMIYOR. Görselsiz haber yayımlanmıyor.
            const sec = gorselSec(olay);
            const kopya = sec
              ? await gorselKopyala(sec.adres, slugla(sentez.baslik))
              : null;
            if (!kopya) {
              sonuc.atlanan.push({
                baslik: sentez.baslik, sebep: "görsel kopyalanamadı",
              });
              return;
            }
            // Ulusal haber kendi bölümüne giriyor: anasayfada manşete
            // çıkamasın ve yerel haberin yerini almasın diye.
            const katAd = kapsam === "ulusal" ? "Türkiye" : sentez.kategori;

            // Yazmadan önce: bu olay zaten kayıtlı mı?
            const aday = karsilastirilabilir({
              baslik: sentez.baslik,
              spot: sentez.spot,
              olusturuldu: new Date().toISOString(),
              kategoriler: { ad: katAd },
            });
            const ayni = oncekiler.find((o) => ayniOlay(aday, o));
            if (ayni) {
              sonuc.atlanan.push({
                baslik: sentez.baslik,
                sebep: `aynı olay zaten kayıtlı: ${String(ayni.baslik).slice(0, 60)}`,
              });
              return;
            }

            const k = await yz.ekle(satirKur(
              sentez, olay, sonuc.katMap.get(katAd),
              { adres: kopya, kaynak: sec.kaynak }));
            eklenen.push({ id: k.id, baslik: k.baslik });
          } catch (e) {
            sonuc.atlanan.push({
              baslik: sentez.baslik,
              sebep: String(e?.message ?? e).slice(0, 160),
            });
          }
        });
        const kuyruk = [...isler];
        await Promise.all(Array.from(
          { length: Math.min(5, kuyruk.length) },
          async () => { for (let f = kuyruk.shift(); f; f = kuyruk.shift()) await f(); }));
      }

      res.status(200).json({
        kuru: sonuc.kuru,
        ham: sonuc.ham,
        olay: sonuc.olay,
        birlesen: sonuc.birlesen,
        uretilen: sonuc.yazilan.length,
        eklenen,
        atlanan: sonuc.atlanan,
        kaynakHatalari: sonuc.kaynakHatalari,
        haberler: sonuc.yazilan.map(({ sentez, olay, durum, kapsam }) => ({
          durum,
          kapsam,
          baslik: sentez.baslik,
          spot: sentez.spot,
          govde: sentez.govde,
          kategori: sentez.kategori,
          onem: sentez.onem,
          kaynaklar: sentez.kullanilan_kaynaklar,
          kume: olay.uyeler.map((h) => h.kaynak_adi),
        })),
      });
    } catch (hata) {
      console.error("hatKos", hata);
      res.status(500).json({ hata: String(hata?.message ?? hata).slice(0, 300) });
    }
  });
