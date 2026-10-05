import assert from "node:assert/strict";
import { test } from "node:test";

import { googleHaberler, haberlerCom, tara, temizle } from "./kaynak.js";

// Gerçek beslemelerden alınmış kısaltılmış örnekler. Testler ağa çıkmıyor.
const HABERLER_RSS = `<rss><channel>
<item>
  <title>Kastamonu Cide&apos;de balıkçı teknedeyken kalp krizi geçirdi</title>
  <description>Kastamonu&apos;nun Cide ilçesinde Gideros koyu açıklarında tekneyle balık tutan 65 yaşındaki balıkçı rahatsızlandı.</description>
  <link>https://www.haberler.com/3-sayfa/kastamonu-cide-de-balikci-20297846/</link>
  <pubDate>Sun, 05 Oct 2026 08:12:00 GMT</pubDate>
</item>
<item>
  <title>Kastamonu Cide&apos;de 5 kişi mantar zehirlenmesi şüphesiyle hastanede</title>
  <description>Mantar yedikten sonra rahatsızlanan 3&apos;ü çocuk 5 kişi hastaneye kaldırıldı.</description>
  <link>https://www.haberler.com/guncel/kastamonu-cide-de-mantar-20297123/</link>
  <pubDate>Sat, 04 Oct 2026 16:25:16 GMT</pubDate>
</item>
</channel></rss>`;

const GOOGLE_RSS = `<rss><channel>
<item>
  <title>Kastamonu'da mantar yiyen 30 kişi zehirlendi! - pusulahaber.com.tr</title>
  <description>&lt;a href="https://news.google.com/rss/articles/CBMi"&gt;Kastamonu'da mantar&lt;/a&gt;</description>
  <link>https://news.google.com/rss/articles/CBMixAFBVV95cUxP</link>
  <pubDate>Sat, 03 Oct 2026 11:57:34 GMT</pubDate>
  <source url="https://pusulahaber.com.tr">pusulahaber.com.tr</source>
</item>
</channel></rss>`;

test("temizle: kaçışları çözer, etiketleri atar", () => {
  assert.equal(temizle("Cide&apos;de <b>balıkçı</b>  kriz"), "Cide'de balıkçı kriz");
  assert.equal(temizle("<![CDATA[Ağlı &amp; Tosya]]>"), "Ağlı & Tosya");
  assert.equal(temizle(null), "");
});

test("Haberler.com RSS: başlık, özet, adres, tarih", () => {
  const k = haberlerCom(HABERLER_RSS);
  assert.equal(k.length, 2);
  assert.equal(k[0].baslik,
    "Kastamonu Cide'de balıkçı teknedeyken kalp krizi geçirdi");
  assert.ok(k[0].ozet.includes("Gideros"));
  assert.equal(k[0].kaynak_adi, "Haberler.com / Kastamonu");
  assert.equal(k[0].olusturuldu, "2026-10-05T08:12:00.000Z");
  assert.ok(k[0].adres.startsWith("https://www.haberler.com/"));
});

test("Google Haberler: yayın adı başlıktan düşürülüyor", () => {
  // Düşürülmezse " - pusulahaber.com.tr" eki her başlıkta ortak kelime
  // sayılır ve kümeleme bozulur.
  const k = googleHaberler(GOOGLE_RSS);
  assert.equal(k.length, 1);
  assert.equal(k[0].baslik, "Kastamonu'da mantar yiyen 30 kişi zehirlendi!");
  assert.ok(!k[0].baslik.includes("pusulahaber"));
  assert.equal(k[0].kaynak_adi, "pusulahaber.com.tr (Google Haberler)");
});

test("Google Haberler: özet boş bırakılıyor", () => {
  // description yalnız başlığı tekrarlıyor; özet diye saklamak
  // sentezi yanıltır.
  assert.equal(googleHaberler(GOOGLE_RSS)[0].ozet, "");
});

test("boş ve bozuk besleme çökertmiyor", () => {
  assert.deepEqual(haberlerCom(""), []);
  assert.deepEqual(haberlerCom("<rss></rss>"), []);
  assert.deepEqual(googleHaberler(null), []);
});

test("başlıksız öğe atılıyor", () => {
  assert.deepEqual(haberlerCom("<item><link>x</link></item>"), []);
});

test("tara: bir kaynak düşse de öbürü geliyor", async () => {
  const kaynaklar = [
    { ad: "iyi", adres: "a", coz: haberlerCom },
    { ad: "bozuk", adres: "b", coz: haberlerCom },
  ];
  const getir = async (a) => {
    if (a === "b") throw new Error("503");
    return HABERLER_RSS;
  };
  const { kayitlar, hatalar } = await tara(kaynaklar, getir);
  assert.equal(kayitlar.length, 2);
  assert.equal(hatalar.length, 1);
  assert.equal(hatalar[0].kaynak, "bozuk");
});

import { govdeCikar, govdeDoldur } from "./kaynak.js";

const SAYFA = `<html><body>
<p>Menü Son Dakika Güncel Dünya Ekonomi Spor Magazin Yerel Politika Finans Teknoloji Kültür Sanat Kadın Moda Otomobil Yaşam Sağlık Turizm Eğitim 3.Sayfa Döviz Altın Hava Namaz Burç Puan Fikstür Canlı Skor Video Foto Galeri İletişim Künye Reklam.</p>
<p>Olay, Cide ilçesine bağlı Gideros koyu açıklarında meydana geldi. Arkadaşının teknesiyle denize açılan Mustafa Türcan rahatsızlandı.</p>
<p>Kısa.</p>
<p>Haberler.com'da yer alan yorumlar, kullanıcıların kişisel görüşlerini yansıtır ve editöryal politika ile örtüşmeyebilir bu nedenle sorumluluk kabul edilmez.</p>
<p>Ekiplerin müdahalesine rağmen Türcan kurtarılamadı. Cenaze, otopsi için Kastamonu Adli Tıp Kurumuna gönderildi.</p>
</body></html>`;

test("gövde: menü ve site kalıpları eleniyor", () => {
  const g = govdeCikar(SAYFA);
  assert.ok(g.includes("Gideros"));
  assert.ok(g.includes("otopsi"));
  assert.ok(!g.includes("Fikstür"), "menü blobu girmemeli");
  assert.ok(!g.includes("yorumlar"), "site kalıbı girmemeli");
  assert.ok(!g.includes("Kısa."), "çok kısa paragraf girmemeli");
});

test("gövde: boş girdi çökertmiyor", () => {
  assert.equal(govdeCikar(""), "");
  assert.equal(govdeCikar(null), "");
});

test("govdeDoldur: Google bağlantısı atlanıyor", async () => {
  // O adres gerçek sayfaya yönlenmiyor; çekmek boşa istek.
  const kayit = { adres: "https://news.google.com/rss/articles/X", ozet: "kısa" };
  let cagrildi = 0;
  const d = await govdeDoldur(kayit, async () => { cagrildi++; return SAYFA; });
  assert.equal(cagrildi, 0);
  assert.equal(d.ozet, "kısa");
});

test("govdeDoldur: daha uzun gövde özetin yerine geçiyor", async () => {
  const kayit = { adres: "https://www.haberler.com/x/", ozet: "Kısa RSS özeti." };
  const d = await govdeDoldur(kayit, async () => SAYFA);
  assert.ok(d.ozet.length > 200);
  assert.ok(d.ozet.includes("Gideros"));
});

test("govdeDoldur: çekim düşerse kayıt bozulmuyor", async () => {
  const kayit = { adres: "https://www.haberler.com/x/", ozet: "RSS özeti" };
  const d = await govdeDoldur(kayit, async () => { throw new Error("503"); });
  assert.equal(d.ozet, "RSS özeti");
});
