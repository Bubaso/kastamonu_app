// Döviz kurları — TCMB.
//
// Neden TCMB
// ──────────
// Resmî kaynak, ücretsiz, anahtar istemiyor ve lisans sorunu yok.
// "TCMB'ye göre" ibaresi okurda karşılığı olan bir ibare.
//
// NE VERMİYOR: altın. Ölçüldü — bültende 22 para birimi var (USD, EUR,
// GBP, CHF, … XDR) ve XAU YOK. Altın isteniyorsa başka bir kaynak
// gerekiyor; burada uydurulmuyor.
//
// TARİH MESELESİ
// ──────────────
// TCMB yalnız İŞ GÜNLERİ ve günde bir kez (~15:30) yayımlıyor.
// `today.xml` hafta sonu ve tatilde son iş gününün bültenini veriyor;
// pazartesi öğleden önce de cuma bülteni geliyor. Ölçüldü: 5 Ekim
// Pazartesi sabahı gelen bülten 2 Ekim Cuma tarihliydi.
//
// Bu yüzden `tarih` alanı yanıtta HER ZAMAN taşınıyor ve arayüz onu
// göstermek zorunda. Tarihsiz kur, okura "şu an böyle" demektir ve
// yanlıştır.

/** Şeritte gösterilen para birimleri. */
export const BIRIMLER = ["USD", "EUR", "GBP"];

const ISIM = { USD: "Dolar", EUR: "Euro", GBP: "Sterlin" };

/** `dd.mm.yyyy` → `yyyy-mm-dd`. Çözemezse null. */
export function tarihCevir(metin) {
  const m = /^(\d{2})\.(\d{2})\.(\d{4})$/.exec(String(metin ?? "").trim());
  if (!m) return null;
  const [, g, a, y] = m;
  // Gerçekten var olan bir gün mü: 31.02 gibi bir değer sessizce
  // kaymasın.
  const t = new Date(Date.UTC(+y, +a - 1, +g));
  if (t.getUTCMonth() !== +a - 1 || t.getUTCDate() !== +g) return null;
  return `${y}-${a}-${g}`;
}

/** Sayıyı okur: TCMB nokta ayracı kullanıyor, boş alan da olabiliyor. */
function sayi(metin) {
  if (metin === null || metin === undefined) return null;
  const s = String(metin).trim();
  if (s === "") return null;
  const d = Number(s);
  return Number.isFinite(d) ? d : null;
}

/** TCMB bülteninden bir alanı çeker. */
function alan(blok, etiket) {
  const m = new RegExp(`<${etiket}>([^<]*)</${etiket}>`).exec(blok);
  return m ? m[1] : null;
}

/** TCMB XML'ini okunabilir biçime indiriyor.
 *
 * Düzenli ifadeyle: bülten sabit ve dar bir biçim, bunun için ayrı bir
 * XML bağımlılığı taşımaya değmiyor. Biçim değişirse `kurlar` boş
 * kalıyor ve çağıran şeridi çizmiyor — yanlış sayı basmaktansa hiç
 * basmamak.
 */
export function bicimle(xml, { birimler = BIRIMLER } = {}) {
  const metin = String(xml ?? "");
  const tarih = tarihCevir(/Tarih="([^"]*)"/.exec(metin)?.[1]);

  const kurlar = [];
  for (const kod of birimler) {
    const blok = new RegExp(
      `<Currency[^>]*CurrencyCode="${kod}"[^>]*>([\\s\\S]*?)</Currency>`,
    ).exec(metin)?.[1];
    if (!blok) continue;

    // Efektif değil DÖVİZ satışı: haber sitesinde gösterilen kur bu.
    const alis = sayi(alan(blok, "ForexBuying"));
    const satis = sayi(alan(blok, "ForexSelling"));
    if (alis === null && satis === null) continue;

    kurlar.push({
      kod,
      ad: ISIM[kod] ?? kod,
      birim: sayi(alan(blok, "Unit")) ?? 1,
      alis,
      satis,
    });
  }

  return { tarih, kurlar, kaynak: "TCMB" };
}

/** Güncel bülten. */
export async function dovizCek({ fetchIsl = fetch } = {}) {
  const y = await fetchIsl("https://www.tcmb.gov.tr/kurlar/today.xml");
  if (!y.ok) throw new Error(`TCMB ${y.status}`);
  return bicimle(await y.text());
}
