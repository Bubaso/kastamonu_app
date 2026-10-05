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
function kayit({ baslik, ozet, adres, yayin, tarih, gorsel }) {
  return {
    baslik: temizle(baslik),
    ozet: temizle(ozet),
    adres: temizle(adres),
    gorsel: temizle(gorsel),
    kaynak_adi: yayin,
    olusturuldu: tarih ? new Date(tarih).toISOString() : new Date().toISOString(),
  };
}

/** RSS öğesindeki görsel adresi.
 *
 * Beslemeler görseli üç ayrı etiketten biriyle veriyor; üçü de
 * aranıyor. Haber sayfasını ayrıca çekip og:image okumaya gerek
 * kalmıyor — ölçümde Haberler.com ve Kastamonu İstiklal ikisi de
 * görseli doğrudan beslemede taşıyordu.
 */
export function gorselBul(parca) {
  const m = String(parca ?? "").match(
    /<(?:enclosure|media:content|media:thumbnail)[^>]*(?:url|href)=["']([^"']+)["']/i);
  return m ? m[1] : "";
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
    gorsel: gorselBul(o),
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

// ── Süzgeçler ────────────────────────────────────────────────────

/** Kastamonu ve ilçeleri — yerellik süzgeci için. */
const YERLER = [
  "kastamonu", "abana", "agli", "arac", "azdavay", "bozkurt", "catalzeytin",
  "cide", "daday", "devrekani", "doganyurt", "hanonu", "ihsangazi", "inebolu",
  "kure", "pinarbasi", "senpazar", "seydiler", "taskopru", "tosya",
];

/** Türkçe sadeleştirme — `lib/cekirdek/metin.dart` ile aynı tablo. */
function sade(x) {
  const e = { "ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u" };
  let s = String(x ?? "").replace(/I/g, "ı").replace(/İ/g, "i").toLowerCase();
  for (const [k, h] of Object.entries(e)) s = s.split(k).join(h);
  return s;
}

/** Haber Kastamonu'yu ilgilendiriyor mu. */
export function yerelMi(h) {
  const m = sade(`${h.baslik} ${h.ozet}`);
  return YERLER.some((y) => m.includes(y));
}

// ── Ülke gündemi ─────────────────────────────────────────────────
//
// Kastamonulu da Türkiye'de yaşıyor: emekli aylığı, vergi, sınav
// takvimi onu da ilgilendiriyor. Ama ulusal haberi serbest bıraksak
// portal bir anda ulusal portale dönüşür — yerel haber günde onlarca,
// ulusal haber günde yüzlerce.
//
// Ölçüt şu: haber okurun YAPTIĞINI, ALDIĞINI, ÖDEDİĞİNİ ya da BİLMEK
// ZORUNDA OLDUĞUNU değiştiriyor mu. "Emekliye zam" değiştiriyor,
// "Mecliste tartışma" değiştirmiyor.
//
// Liste bilerek açık ve dar: ayar düğmesi bu. Genişletmek portalı
// ulusala kaydırır, daraltmak okurun işine yarayan haberi kaçırır.

/** Okurun cebine, hakkına ya da takvimine dokunan alanlar. */
const ETKI = [
  "emekli", "maas", "zam", "asgari ucret", "promosyon",
  "vergi", "otv", "kdv", "harc", "faiz", "kredi",
  "sgk", "sosyal guvenlik", "saglik hakki", "tedavi bedeli", "ilac",
  "destek odemesi", "tesvik", "burs", "yardim odemesi",
  "sinav takvimi", "basvuru suresi", "son basvuru", "yks", "lgs", "kpss",
  "okul takvimi", "resmi tatil", "ehliyet", "askerlik",
  "geri cagirma", "salgin", "afet uyarisi", "saganak", "kar uyarisi",
];

/** Ulusal haberi eleyen konular.
 *
 * Bunlar da ülke geneli ama okurun hayatını değiştirmiyor; portalı
 * ulusal gazeteye çeviren tam olarak bu tür haberler.
 */
const ELE = [
  "transfer", "derbi", "super lig", "sampiyonlar ligi",
  "magazin", "dizi", "sosyal medyada gundem",
  "parti", "kurultay", "muhalefet", "iktidar", "aciklamasi gundem oldu",
  "genel baskan", "chp", "akp", "ak parti", "mhp", "iyi parti", "dem parti",
  "cumhurbaskani", "milletvekili", "bakan ", "meclis genel kurulu",
  "borsa", "dolar kuru", "kripto",
];

/** Adında yer adı geçmeyen Kastamonu yayınları.
 *
 * Çoğu yerel gazetenin adında şehir ya da ilçe adı var ve `YERLER`
 * onları yakalıyor. Bu liste yakalayamadıkları için: ölçümde "Açıksöz
 * Gazetesi" eleniyordu — Kastamonu'nun köklü gazetelerinden.
 *
 * Liste keşifle büyüyor, hafızadan değil: Google Haberler hangi
 * yayınların Kastamonu yazdığını gösteriyor, buraya onlar giriyor.
 */
const YEREL_YAYINLAR = ["aciksoz"];

/** Haberin kapsamı: 'yerel', 'ulusal' ya da null (alınmaz).
 *
 * `yerelKaynak`, haberi Kastamonu gazetesinin yayımladığını söylüyor.
 * Bu fark önemli: ölçümde "KATSO'da Fındıkoğlu yeniden başkan seçildi"
 * eleniyordu, çünkü başlıkta "Kastamonu" geçmiyor — oysa KATSO
 * Kastamonu Ticaret ve Sanayi Odası ve haber tam da yerel haber.
 *
 * Yerel gazete kendi bölgesini yazar; aksi ispatlanana kadar yazdığı
 * yereldir. Ulusal toplayıcıda ise tersi geçerli: Kastamonu adı
 * geçmiyorsa o haber bizim değil.
 */
export function kapsam(h, { yerelKaynak = false } = {}) {
  if (yerelMi(h)) return "yerel";

  // Google Haberler özet vermiyor, yalnız başlık ve YAYIN ADI veriyor.
  // Yayının kendisi Kastamonu gazetesiyse haber de yereldir —
  // ölçümde "KATSO'da Fındıkoğlu yeniden başkan seçildi" tam olarak
  // bu yüzden eleniyordu: başlıkta Kastamonu geçmiyor ama haberi
  // Taşköprü Postası yazmış.
  const yayin = sade(h.kaynak_adi ?? "");
  if (YERLER.some((y) => yayin.includes(y))) return "yerel";
  if (YEREL_YAYINLAR.some((y) => yayin.includes(y))) return "yerel";

  const m = sade(`${h.baslik} ${h.ozet}`);
  if (ELE.some((k) => m.includes(k))) return null;
  if (ETKI.some((k) => m.includes(k))) return "ulusal";

  // Yerel gazetenin, ulusal gündem olduğu belli olmayan haberi.
  return yerelKaynak ? "yerel" : null;
}

/** Haber yeterince taze mi.
 *
 * Yerel gazetelerin RSS'i aylar öncesine uzanabiliyor: ölçümde altı ay
 * önceki 23 Nisan kutlaması geldi. Haber sitesinin akışında eski haber
 * yeni haber gibi görünüyor.
 */
export function tazeMi(h, gun = 7, simdi = Date.now()) {
  const t = new Date(h.olusturuldu).getTime();
  if (!Number.isFinite(t)) return false;
  return simdi - t <= gun * 864e5;
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
    // Kastamonu gazetesi: yazdığı, aksi belli olmadıkça yereldir.
    yerel: true,
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
      // Yerellik ve tazelik süzgeci kaynakta uygulanıyor: elenen
      // kayıt kümelemeye de, modele de hiç gitmiyor.
      // Kapsam ve tazelik kaynakta uygulanıyor: elenen kayıt
      // kümelemeye de, modele de hiç gitmiyor.
      const n = k.coz(await getir(k.adres))
        .map((h) => ({ ...h, kapsam: kapsam(h, { yerelKaynak: k.yerel === true }) }))
        .filter((h) => h.kapsam && tazeMi(h));
      kayitlar.push(...n);
    } catch (e) {
      hatalar.push({ kaynak: k.ad, hata: String(e).slice(0, 200) });
    }
  }));
  return { kayitlar, hatalar };
}

// ── Haber gövdesi ────────────────────────────────────────────────
//
// RSS özeti ~150 karakter; bununla ancak tek cümlelik haber yazılıyor.
// Haber sayfasında ise 900-1300 karakter gerçek metin var. 5N1K'nın
// tamamını çıkarabilmek için gövde oradan alınıyor.
//
// Yalnız sentezlenecek kümeler için çağrılıyor: her ham kaydın
// sayfasını çekmek yüzlerce gereksiz istek demek.

/** Sayfanın kendi tanıtım/uyarı metinleri. Haberin parçası değiller. */
const KALIP = /yorumlar|çerez|telif|tüm hakları|editöryal|abone ol|künye|kullanım şartları|en kapsamlı haber/i;

/** HTML'den haber paragraflarını ayıklar.
 *
 * Süzgeçler ölçümle kondu: menü blobu tek bir `<p>` içinde 16 bin
 * karakter geliyordu, site tanıtımları ise cümle gibi görünüyordu.
 */
export function govdeCikar(html) {
  return [...String(html ?? "").matchAll(/<p[^>]*>([\s\S]*?)<\/p>/g)]
    .map((m) => temizle(m[1]))
    .filter((t) =>
      t.length >= 60 && t.length <= 1200 &&
      /[.!?]\s*$/.test(t) &&
      (t.match(/[.!?]/g) ?? []).length <= 12 &&
      !KALIP.test(t))
    .slice(0, 8)
    .join("\n\n");
}

/** Kaydın gövdesini haber sayfasından doldurur.
 *
 * Başarısız olursa kayıt olduğu gibi dönüyor: tek bir sayfanın
 * çekilememesi kümeyi düşürmemeli, elde özet zaten var.
 */
export async function govdeDoldur(kayit, getir = agdanGetir) {
  const u = kayit.adres ?? "";
  // Google Haberler bağlantısı gerçek adrese yönlenmiyor.
  if (!u.startsWith("http") || u.includes("news.google.com")) return kayit;
  try {
    const g = govdeCikar(await getir(u));
    return g.length > (kayit.ozet ?? "").length ? { ...kayit, ozet: g } : kayit;
  } catch {
    return kayit;
  }
}
