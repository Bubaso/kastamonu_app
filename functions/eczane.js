// Nöbetçi eczaneler — Kastamonu Eczacı Odası.
//
// EN RİSKLİ GADGET BU
// ───────────────────
// Resmî bir API'si yok; odanın sayfası ayrıştırılıyor. İki sonucu var:
//
//   1. Kırılgan. Oda sayfa düzenini değiştirirse ayrıştırma boş döner.
//      Boş dönmek SORUN DEĞİL — gadget kendini gizliyor. Tehlikeli
//      olan, yanlış ayrıştırıp yanlış eczane göstermek.
//   2. Yanlış bilgi burada gerçekten zarar veriyor. İnsan gece 3'te
//      kapalı eczaneye gidiyor.
//
// Bu yüzden tasarım "şüphe varsa gösterme" üzerine kurulu:
//
//   • Sayfadaki BAŞLIK TARİHİ okunuyor ve bugün değilse hiçbir şey
//     dönmüyor. Oda sayfayı güncellemeyi unutursa dünün nöbetçisini
//     göstermektense hiç göstermemek.
//   • Adı, adresi ya da telefonu eksik kayıt listeye girmiyor.
//   • Yanıt her zaman `tarih` taşıyor; arayüz onu ve odanın
//     sayfasına bağlantıyı göstermek zorunda.

export const KAYNAK_ADRES = "https://www.kastamonueo.org.tr/nobetci-eczaneler/37";
export const KAYNAK_ADI = "Kastamonu Eczacı Odası";

const AYLAR = [
  "ocak", "şubat", "mart", "nisan", "mayıs", "haziran",
  "temmuz", "ağustos", "eylül", "ekim", "kasım", "aralık",
];

/** "05 Ekim 2026" → "2026-10-05". Çözemezse null. */
export function tarihCevir(metin) {
  const m = /(\d{1,2})\s+([A-Za-zÇĞİÖŞÜçğıöşü]+)\s+(\d{4})/.exec(String(metin ?? ""));
  if (!m) return null;
  const gun = Number(m[1]);
  const ay = AYLAR.indexOf(m[2].toLocaleLowerCase("tr"));
  const yil = Number(m[3]);
  if (ay < 0 || gun < 1 || gun > 31) return null;
  const t = new Date(Date.UTC(yil, ay, gun));
  if (t.getUTCMonth() !== ay || t.getUTCDate() !== gun) return null;
  return `${yil}-${String(ay + 1).padStart(2, "0")}-${String(gun).padStart(2, "0")}`;
}

/** Türkiye saatine göre bugünün tarihi (`yyyy-mm-dd`).
 *
 * Sunucu UTC'de koşuyor; nöbet günü Türkiye'ye göre değişiyor.
 * Gece yarısından sonra UTC hâlâ dünü gösterirken Kastamonu'da
 * yeni nöbetçi başlamış oluyor.
 */
export function bugun(simdi = new Date()) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Istanbul",
    year: "numeric", month: "2-digit", day: "2-digit",
  }).format(simdi);
}

const etiketsiz = (s) => String(s ?? "")
  .replace(/<[^>]+>/g, " ")
  .replace(/&nbsp;/g, " ")
  .replace(/&amp;/g, "&")
  .replace(/&#39;/g, "'")
  .replace(/&quot;/g, '"')
  .replace(/\s+/g, " ")
  .trim();

/** Sayfadan nöbet listesini çıkarıyor.
 *
 * `bugunTarih` verilirse başlık tarihi onunla karşılaştırılıyor ve
 * tutmazsa liste BOŞ dönüyor: eski nöbet listesi göstermek, hiç
 * göstermemekten kötü.
 */
export function bicimle(html, { bugunTarih = bugun() } = {}) {
  const metin = String(html ?? "");

  const basliklar = [...metin.matchAll(/<h3[^>]*>([^<]*)<\/h3>/g)]
    .map((m) => etiketsiz(m[1]));
  const baslik = basliklar.find((b) => /nöbet/i.test(b)) ?? null;
  const tarih = tarihCevir(baslik);

  if (!tarih || tarih !== bugunTarih) {
    return {
      tarih,
      guncel: false,
      eczaneler: [],
      kaynak: KAYNAK_ADI,
      kaynakAdres: KAYNAK_ADRES,
    };
  }

  const bloklar = metin.split(/<div class="col-md-12 nobetci">/).slice(1);
  const eczaneler = [];
  for (const blok of bloklar) {
    const govde = blok.split(/<\/div>\s*<\/div>/)[0] ?? blok;

    const basEsl = /<h4[^>]*>\s*<strong>([^<]*)<\/strong>\s*-?\s*([^<]*)<\/h4>/.exec(govde);
    if (!basEsl) continue;
    const ad = etiketsiz(basEsl[1]);
    const ilce = etiketsiz(basEsl[2]);

    const tel = /href="tel:([0-9+]+)"/.exec(govde)?.[1] ?? null;

    // Adres: ev simgesinden sonraki, telefon simgesine kadarki metin.
    const adresHam = /fa-home[^>]*>\s*<\/i>([\s\S]*?)<(?:br|i\s)/.exec(govde)?.[1];
    const adres = adresHam ? etiketsiz(adresHam) : null;

    const konum = /maps\?q=(-?[\d.]+),(-?[\d.]+)/.exec(govde);

    // Adı, adresi ya da telefonu eksikse listeye girmiyor: yarım
    // kayıt okuru yanlış yere gönderir.
    if (!ad || !adres || !tel) continue;

    eczaneler.push({
      ad,
      ilce: ilce || null,
      adres,
      telefon: tel,
      enlem: konum ? Number(konum[1]) : null,
      boylam: konum ? Number(konum[2]) : null,
    });
  }

  return {
    tarih,
    guncel: true,
    eczaneler,
    kaynak: KAYNAK_ADI,
    kaynakAdres: KAYNAK_ADRES,
  };
}

/** Bugünün nöbetçi eczaneleri. */
export async function eczaneCek({ fetchIsl = fetch, bugunTarih = bugun() } = {}) {
  const y = await fetchIsl(KAYNAK_ADRES, {
    headers: { "User-Agent": "Mozilla/5.0 (compatible; KastamonuHaber/1.0)" },
  });
  if (!y.ok) throw new Error(`eczacı odası ${y.status}`);
  return bicimle(await y.text(), { bugunTarih });
}
