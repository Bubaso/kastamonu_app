// Haber kaynaklarından ham kayıt toplama.
//
// Neden burada
// ────────────
// Hat bugüne kadar kullanıcının kendi bilgisayarındaki bir Python
// işçisiydi. O makine kapalıyken hiçbir şey çekilmiyordu ve paneldeki
// "Haber çek" düğmesi kuyruğa satır yazıp bekliyordu. Buraya taşınınca
// koşu buluta geçiyor: panel doğrudan tetikliyor, zamanlanmış koşu da
// kurulabiliyor.
//
// Ayıklama kuralları
// ──────────────────
// Her kaynak için ayrı bir çözümleyici var çünkü HTML'leri farklı.
// Hepsi aynı biçimi döndürüyor, böylece kümeleme ve sentez kaynaktan
// bağımsız kalıyor.
//
// Ağ çağrısı dışarıdan veriliyor (`getir`): testler sabit metinlerle
// koşuyor, internete çıkmıyor.

const UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 " +
           "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";

/** Varsayılan ağ çağrısı. */
export async function agdanGetir(adres) {
  const y = await fetch(adres, { headers: { "User-Agent": UA } });
  if (!y.ok) throw new Error(`${adres} → ${y.status}`);
  return await y.text();
}

// ── Metin yardımcıları ───────────────────────────────────────────

/** HTML/XML kaçışlarını çözer, etiketleri atar, boşlukları sadeleştirir. */
export function temizle(s) {
  return String(s ?? "")
    .replace(/<!\[CDATA\[|\]\]>/g, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/&apos;|&#39;|&rsquo;/g, "'")
    .replace(/&quot;|&ldquo;|&rdquo;/g, '"')
    .replace(/&nbsp;/g, " ")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&")
    .replace(/\s+/g, " ")
    .trim();
}

function etiket(parca, ad) {
  const m = parca.match(new RegExp(`<${ad}[^>]*>([\\s\\S]*?)</${ad}>`));
  return m ? m[1] : "";
}

/** RSS/Atom gövdesini `<item>` parçalarına böler. */
export function ogeler(xml) {
  return [...String(xml ?? "").matchAll(/<item>([\s\S]*?)<\/item>/g)]
    .map((m) => m[1]);
}

// ── Kaynaklar ────────────────────────────────────────────────────

/** Tek bir ham kayıt. `tekille.js` ve sentez bu biçimi bekliyor. */
function kayit({ baslik, ozet, adres, yayin, tarih }) {
  return {
    baslik: temizle(baslik),
    ozet: temizle(ozet),
    adres: temizle(adres),
    kaynak_adi: yayin,
    olusturuldu: tarih ? new Date(tarih).toISOString() : new Date().toISOString(),
  };
}

/** Standart RSS: başlık + gerçek özet + doğrudan adres.
 *
 * Haberler.com ve yerel Kastamonu gazeteleri aynı biçimi veriyor.
 */
export function rssOku(xml, yayin) {
  return ogeler(xml).map((o) => kayit({
    baslik: etiket(o, "title"),
    ozet: etiket(o, "description"),
    adres: etiket(o, "link"),
    yayin,
    tarih: temizle(etiket(o, "pubDate")),
  })).filter((h) => h.baslik);
}

/** Haberler.com'un Kastamonu RSS'i.
 *
 * `description` gerçek bir özet taşıyor (~200 karakter), bu yüzden
 * haber sayfasını ayrıca çekmeye gerek kalmıyor.
 */
export function haberlerCom(xml) {
  return rssOku(xml, "Haberler.com / Kastamonu");
}

/** Google Haberler RSS'i.
 *
 * Burada `description` yalnız başlığı tekrarlıyor ve `link` gerçek
 * adrese yönlenmiyor (JavaScript'le çözülen bir ara sayfa). O yüzden
 * bu kaynak METİN için değil, KEŞİF için: aynı olayı hangi yayınların
 * yazdığını gösteriyor ve kümeyi büyütüyor.
 *
 * Başlıklar " - Yayın Adı" ile bitiyor; yayın adı `<source>` etiketinden
 * alınıp başlıktan düşürülüyor, yoksa kümeleme o eki ortak kelime sanar.
 */
export function googleHaberler(xml) {
  return ogeler(xml).map((o) => {
    const yayin = temizle(etiket(o, "source")) || "Google Haberler";
    let baslik = temizle(etiket(o, "title"));
    const ek = ` - ${yayin}`;
    if (baslik.endsWith(ek)) baslik = baslik.slice(0, -ek.length).trim();
    return kayit({
      baslik,
      ozet: "",
      adres: temizle(etiket(o, "link")),
      yayin: `${yayin} (Google Haberler)`,
      tarih: temizle(etiket(o, "pubDate")),
    });
  }).filter((h) => h.baslik);
}

/** Tanımlı kaynaklar. */
export const KAYNAKLAR = [
  {
    ad: "Haberler.com",
    adres: "https://rss.haberler.com/rss.asp?kategori=kastamonu",
    coz: haberlerCom,
  },
  {
    // Yerel gazete: ilçe haberlerini ulusal toplayıcılar yazmıyor,
    // yerel basın yazıyor. Google Haberler keşfinde çıktı ve kendi
    // beslemesinin 40 öğesinin 40'ında gerçek özet var.
    ad: "Kastamonu İstiklal",
    adres: "https://www.kastamonuistiklal.com/rss",
    coz: (x) => rssOku(x, "Kastamonu İstiklal Gazetesi"),
  },
  {
    ad: "Google Haberler",
    adres: "https://news.google.com/rss/search?q=Kastamonu&hl=tr&gl=TR&ceid=TR:tr",
    coz: googleHaberler,
  },
];

/** Bütün kaynakları tarar.
 *
 * Bir kaynak düşerse koşu devam ediyor: tek bir yayının sitesi kapalı
 * diye o günün hiç haberi gelmemesi kabul edilemez. Düşenler dönen
 * nesnede `hatalar` içinde bildiriliyor.
 */
export async function tara(kaynaklar = KAYNAKLAR, getir = agdanGetir) {
  const kayitlar = [];
  const hatalar = [];
  await Promise.all(kaynaklar.map(async (k) => {
    try {
      const n = k.coz(await getir(k.adres));
      kayitlar.push(...n);
    } catch (e) {
      hatalar.push({ kaynak: k.ad, hata: String(e).slice(0, 200) });
    }
  }));
  return { kayitlar, hatalar };
}
