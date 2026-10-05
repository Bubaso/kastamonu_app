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

import { tazeMi, yerelMi } from "./kaynak.js";

test("yerellik: ulusal dolgu eleniyor", () => {
  // Yerel gazetelerin beslemesi bunları da taşıyor; şehir portalının
  // haberi değiller.
  assert.equal(yerelMi({ baslik: "SGK'dan emeklilere 81 ilde indirim müjdesi", ozet: "" }), false);
  assert.equal(yerelMi({ baslik: "Konut kredisinde yeni faiz oranları belli oldu", ozet: "" }), false);
});

test("yerellik: Kastamonu ve ilçeler geçiyor", () => {
  assert.ok(yerelMi({ baslik: "Kastamonu'da kaza", ozet: "" }));
  assert.ok(yerelMi({ baslik: "Taşköprü'de sarımsak hasadı", ozet: "" }));
  assert.ok(yerelMi({ baslik: "Şelale ziyaretçi ağırlıyor", ozet: "Araç ilçesinde bulunan şelale" }));
});

test("tazelik: eski haber eleniyor", () => {
  const simdi = Date.parse("2026-10-05T12:00:00Z");
  assert.ok(tazeMi({ olusturuldu: "2026-10-03T12:00:00Z" }, 7, simdi));
  // Ölçümde altı ay önceki 23 Nisan haberi gelmişti.
  assert.equal(tazeMi({ olusturuldu: "2026-04-23T12:00:00Z" }, 7, simdi), false);
  assert.equal(tazeMi({ olusturuldu: "bozuk" }, 7, simdi), false);
});

import { kapsam } from "./kaynak.js";

test("kapsam: Kastamonu geçen haber yerel", () => {
  assert.equal(kapsam({ baslik: "Taşköprü'de sarımsak hasadı", ozet: "" }), "yerel");
  // Konusu ulusal olsa bile Kastamonu geçiyorsa yerel haberdir.
  assert.equal(kapsam({ baslik: "Kastamonu'da emeklilere indirim", ozet: "" }), "yerel");
});

test("kapsam: okurun cebine dokunan ulusal haber giriyor", () => {
  // Kastamonulu da Türkiye'de yaşıyor.
  assert.equal(kapsam({ baslik: "SGK'dan emeklilere 81 ilde indirim müjdesi", ozet: "" }), "ulusal");
  assert.equal(kapsam({ baslik: "Konut kredisinde yeni faiz oranları belli oldu", ozet: "" }), "ulusal");
  assert.equal(kapsam({ baslik: "YKS başvuru süresi uzatıldı", ozet: "" }), "ulusal");
});

test("kapsam: hayatı değiştirmeyen ulusal haber alınmıyor", () => {
  // Portalı ulusal gazeteye çeviren tam olarak bunlar.
  assert.equal(kapsam({ baslik: "Derbi öncesi transfer iddiası", ozet: "" }), null);
  assert.equal(kapsam({ baslik: "Mecliste muhalefet ve iktidar tartıştı", ozet: "" }), null);
  assert.equal(kapsam({ baslik: "Dolar kuru yeni rekor kırdı", ozet: "" }), null);
});

test("kapsam: eleme, etki listesinden önce geliyor", () => {
  // "Transfer" geçen bir haber "maaş" da geçse alınmamalı.
  assert.equal(kapsam({ baslik: "Transfer sezonunda maaş rekoru", ozet: "" }), null);
});

test("kapsam: ilgisiz ulusal haber alınmıyor", () => {
  assert.equal(kapsam({ baslik: "İzmir'de trafik kazası", ozet: "" }), null);
});

test("yerel gazetenin haberi, Kastamonu geçmese de yerel", () => {
  // Ölçümde elenen gerçek örnek: KATSO = Kastamonu Ticaret ve Sanayi Odası.
  const h = { baslik: "KATSO'da Fındıkoğlu yeniden başkan seçildi", ozet: "" };
  assert.equal(kapsam(h), null, "ulusal toplayıcıda alınmamalı");
  assert.equal(kapsam(h, { yerelKaynak: true }), "yerel");
});

test("yerel gazetenin ulusal dolgusu yine ulusal", () => {
  const h = { baslik: "SGK'dan emeklilere 81 ilde indirim", ozet: "" };
  assert.equal(kapsam(h, { yerelKaynak: true }), "ulusal");
});

test("yerel gazetenin siyaset haberi yine eleniyor", () => {
  const h = { baslik: "CHP Genel Başkanı aileyi ziyaret etti", ozet: "" };
  assert.equal(kapsam(h, { yerelKaynak: true }), null);
});

test("yayın adı Kastamonu gazetesiyse haber yerel", () => {
  // Google Haberler özet vermiyor; elde yalnız başlık ve yayın adı var.
  assert.equal(kapsam({
    baslik: "KATSO'da Fındıkoğlu yeniden başkan seçildi", ozet: "",
    kaynak_adi: "Taşköprü Postası (Google Haberler)",
  }), "yerel");
  assert.equal(kapsam({
    baslik: "Belediye personelinin açılışına yoğun ilgi!", ozet: "",
    kaynak_adi: "Kastamonu Güncel (Google Haberler)",
  }), "yerel");
});

test("ulusal yayının Kastamonu geçmeyen haberi yine alınmıyor", () => {
  assert.equal(kapsam({
    baslik: "İzmir'de trafik kazası", ozet: "",
    kaynak_adi: "Hürriyet (Google Haberler)",
  }), null);
});

test("adında yer adı geçmeyen yerel gazete tanınıyor", () => {
  // Açıksöz, Kastamonu'nun köklü gazetelerinden; adında yer adı yok.
  assert.equal(kapsam({
    baslik: "Belediye personelinin açılışına yoğun ilgi!", ozet: "",
    kaynak_adi: "Açıksöz Gazetesi (Google Haberler)",
  }), "yerel");
});

// ── Yayın adı kısayolunun sınırı ────────────────────────────────
//
// Kısayol Google Haberler için var: orada özet yok, elde yalnız başlık
// ve yayın adı kalıyor. Doğrudan beslemede özet VAR ve kısayol zarar
// veriyordu: "Taşköprü Postası" adı `YERLER`e takıldığı için gazetenin
// Çorum-Samsun yolundaki kazayı anlatan haberi de Kastamonu haberi
// sayılıyordu — yani portal başka ilin kazasını kendi haberi gibi
// yayımlayacaktı.

test("yerel gazetenin başka ildeki haberi yerel sayılmıyor", () => {
  assert.equal(kapsam({
    baslik: "İki otomobil çarpıştı: Anne öldü, 2 çocuk yaralandı",
    ozet: "Çorum-Samsun kara yolunda iki otomobilin çarpışması sonucu " +
          "33 yaşındaki anne hayatını kaybetti, iki çocuğu yaralandı.",
    kaynak_adi: "Taşköprü Postası",
  }), null);
});

test("yerel gazetenin Kastamonu haberi yerel", () => {
  assert.equal(kapsam({
    baslik: "Kastamonu İstanbul'a taşınıyor: Geri sayım başladı",
    ozet: "20. Kastamonu Tanıtım Günleri, 8-11 Ekim tarihlerinde " +
          "Atatürk Havalimanı Millet Bahçesi'nde düzenlenecek.",
    kaynak_adi: "Taşköprü Postası",
  }), "yerel");
});

test("yerel gazetenin ulusal gündem haberi ulusal kalıyor", () => {
  // Kastamonulunun cebine dokunuyor ama Kastamonu haberi değil:
  // kendi bölümüne, kotalı biçimde girmeli.
  assert.equal(kapsam({
    baslik: "Milyonları ilgilendiriyor: Memur ve emeklinin zam hesabı değişti",
    ozet: "Memur ve memur emeklilerinin ocak maaş zammında ilk üç aylık " +
          "tablo oluştu. Kümülatif enflasyon farkı belli oldu.",
    kaynak_adi: "Taşköprü Postası",
  }), "ulusal");
});

test("özet yokken yayın adı kısayolu hâlâ çalışıyor", () => {
  // Google Haberler'de durum bu: KATSO haberi başlıkta Kastamonu
  // geçmediği için eleniyordu.
  assert.equal(kapsam({
    baslik: "KATSO'da Fındıkoğlu yeniden başkan seçildi", ozet: "",
    kaynak_adi: "Taşköprü Postası (Google Haberler)",
  }), "yerel");
});

// ── Kaynak sırası belirleyici ───────────────────────────────────
//
// `tara` kaynakları paralel çekiyor. Eskiden her kaynak BİTTİĞİNDE
// listeye ekliyordu, yani sıra ağ hızına bağlıydı. Küme üyelerinin
// sırası da buna bağlı; tekilleştirme kümenin adresine baktığı için
// aynı haber bir koşuda "zaten kayıtlı", ötekinde yeni görünüyordu.
// Ölçümde 129 kümenin 7'si iki ardışık koşuda lider adresini
// değiştirdi.

test("tara: sonuç kaynak sırasını koruyor, bitiş sırasını değil", async () => {
  const bugun = new Date().toISOString();
  const yap = (ad) => ({
    ad,
    adres: `https://ornek/${ad}`,
    // Yavaş kaynak ÖNCE tanımlı: bitiş sırası kullanılsaydı sona düşerdi.
    coz: () => [{
      baslik: `Kastamonu'da ${ad} haberi`, ozet: "Kastamonu'da bir olay oldu.",
      adres: `https://ornek/${ad}/1`, gorsel: "https://foto/x.jpg",
      kaynak_adi: ad, olusturuldu: bugun,
    }],
  });
  const kaynaklar = [yap("yavas"), yap("hizli")];
  const getir = async (u) => {
    if (u.includes("yavas")) await new Promise((r) => setTimeout(r, 40));
    return "<rss/>";
  };

  for (let i = 0; i < 3; i++) {
    const { kayitlar } = await tara(kaynaklar, getir);
    assert.deepEqual(
      kayitlar.map((h) => h.kaynak_adi), ["yavas", "hizli"],
      "sıra kaynak listesini izlemeli",
    );
  }
});

test("tara: düşen kaynak ötekilerin sırasını bozmuyor", async () => {
  const bugun = new Date().toISOString();
  const yap = (ad, patla = false) => ({
    ad,
    adres: `https://ornek/${ad}`,
    coz: () => {
      if (patla) throw new Error("besleme bozuk");
      return [{
        baslik: `Kastamonu'da ${ad} haberi`, ozet: "Kastamonu'da bir olay oldu.",
        adres: `https://ornek/${ad}/1`, gorsel: "https://foto/x.jpg",
        kaynak_adi: ad, olusturuldu: bugun,
      }];
    },
  });
  const { kayitlar, hatalar } = await tara(
    [yap("bir"), yap("bozuk", true), yap("uc")], async () => "<rss/>");
  assert.deepEqual(kayitlar.map((h) => h.kaynak_adi), ["bir", "uc"]);
  assert.equal(hatalar.length, 1);
  assert.equal(hatalar[0].kaynak, "bozuk");
});
