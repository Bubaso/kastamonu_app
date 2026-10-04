// Aynı olayı anlatan kayıtların tekilleştirilmesi — sunucu tarafı.
//
// Neden burada da var
// ───────────────────
// Kural `lib/ozellikler/anasayfa/veri/tekille.dart` içinde Dart olarak
// yazılmıştı ve yalnız Flutter açıldıktan sonra çalışıyordu. SSR'dan
// geçen sayfalar kendi sorgularını atıyor ve kuraldan haberleri yoktu:
// ölçümde ana sayfanın sunucu tarafından basılan hâli aynı Daday
// yangınını İKİ kez listeliyordu. Tarayıcıda düzeliyordu ama arama
// motorunun ve ilk görünümün gördüğü hâl buydu.
//
// Aynı kural sitemap için de gerekiyor: iki neredeyse aynı adres,
// arama motoruna tekrarlayan içerik sinyali veriyor.
//
// Eşikler ve gerekçeleri Dart dosyasında; burası onun karşılığı.
// İkisi ayrışırsa portal ile SSR farklı şeyleri aynı sayar.

/** Türkçe küçültme + harf eşleme.
 *
 * `lib/cekirdek/metin.dart` ile AYNI tablo. Sıra önemli: önce Türkçe
 * küçültme, sonra eşleme — tersi "Ilgaz" ile "ılgaz"ı ayırıyor.
 */
const ESLEME = {
  "ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u",
  "â": "a", "î": "i", "û": "u",
};

export function sadelestir(metin) {
  let s = String(metin ?? "").replace(/I/g, "ı").replace(/İ/g, "i").toLowerCase();
  for (const [kaynak, hedef] of Object.entries(ESLEME)) {
    s = s.split(kaynak).join(hedef);
  }
  return s;
}

// Üç harften uzun ama her başlıkta geçebilen bağlaçlar.
const DURAKLAR = new Set([
  "icin", "ile", "olarak", "sonra", "once", "kadar",
  "gibi", "daha", "ancak", "ayrica", "uzere",
]);

export function kelimeler(baslik) {
  return new Set(
    sadelestir(baslik).split(/[^a-z0-9]+/)
      .filter((k) => k.length > 2 && !DURAKLAR.has(k)));
}

/** İki başlığın ortak kelime oranı, 0 ile 1 arasında. */
export function benzerlik(a, b) {
  const x = kelimeler(a), y = kelimeler(b);
  if (x.size === 0 || y.size === 0) return 0;
  let ortak = 0;
  for (const k of x) if (y.has(k)) ortak++;
  return ortak / (x.size + y.size - ortak);
}

export const ESIK = 0.62;
const PENCERE_GUN = 7;

/** Haberin onaylı ilçeleri. */
function ilceler(h) {
  return new Set((h.haber_ilce ?? [])
    .filter((b) => b?.onaylandi && b?.ilceler?.ad)
    .map((b) => b.ilceler.ad));
}

// Bölüm aileleri — `lib/cekirdek/bolum.dart` ile aynı.
const AILELER = {
  "Asayiş": "asayis", "Kaza ve Acil": "asayis",
  "Gündem": "gundem", "Kent ve Yönetim": "gundem",
  "Ekonomi": "uretim", "Tarım": "uretim",
  "Eğitim": "toplum", "Sağlık": "toplum",
  "Kültür ve Turizm": "yasam", "Spor": "yasam",
};

function aile(h) {
  return AILELER[h?.kategoriler?.ad ?? ""] ?? "diger";
}

/** İki kayıt aynı olayı mı anlatıyor. */
export function ayniOlay(a, b) {
  if (!a || !b || a.id === b.id) return false;

  // Derleme anı, yayın anı DEĞİL: aynı olayın iki kaydı haftalarca
  // ayrı yayımlanabiliyor (ölçülen çiftte fark 12,5 gündü).
  const fark = Math.abs(
    new Date(a.olusturuldu).getTime() - new Date(b.olusturuldu).getTime());
  if (!Number.isFinite(fark) || fark > PENCERE_GUN * 864e5) return false;

  // Yer: kümeler kesişiyor ya da ikisi de boş. Boş küme dolu kümenin
  // alt kümesi SAYILMIYOR — "Kastamonu'da tören" ile "Tosya'da tören"
  // ayrı haberler ve bu ayrım onları kurtarıyor.
  const ia = ilceler(a), ib = ilceler(b);
  const bos = ia.size === 0 && ib.size === 0;
  const kesisiyor = [...ia].some((x) => ib.has(x));
  if (!bos && !kesisiyor) return false;

  if (aile(a) !== aile(b)) return false;

  return benzerlik(a.baslik, b.baslik) >= ESIK;
}

// Başlık farkının anlamlı sayılması için gereken en az karakter.
const BASLIK_FARK_ESIGI = 10;

/** Hangi kayıt kalacak: negatifse a, pozitifse b. */
function ustunluk(a, b) {
  const fa = Boolean(a.gorsel_url) && Boolean(a.gorsel_kaynak);
  const fb = Boolean(b.gorsel_url) && Boolean(b.gorsel_kaynak);
  if (fa !== fb) return fa ? -1 : 1;

  const ba = (a.baslik ?? "").length, bb = (b.baslik ?? "").length;
  if (Math.abs(ba - bb) >= BASLIK_FARK_ESIGI) return bb - ba;

  const ga = (a.govde ?? "").length, gb = (b.govde ?? "").length;
  if (ga !== gb) return gb - ga;

  return String(a.olusturuldu).localeCompare(String(b.olusturuldu));
}

/** Aynı olayın fazladan kayıtlarını listeden çıkarır.
 *
 * Gelen sıra korunuyor. Düşen kayıt silinmiyor — kendi adresi
 * çalışmaya devam ediyor, yalnız listede iki kez görünmüyor.
 */
export function tekille(liste) {
  if (!Array.isArray(liste) || liste.length < 2) return liste ?? [];

  const dusen = new Set();
  for (let i = 0; i < liste.length; i++) {
    if (dusen.has(liste[i].id)) continue;
    for (let j = i + 1; j < liste.length; j++) {
      if (dusen.has(liste[j].id)) continue;
      if (!ayniOlay(liste[i], liste[j])) continue;
      dusen.add(ustunluk(liste[i], liste[j]) <= 0 ? liste[j].id : liste[i].id);
      if (dusen.has(liste[i].id)) break;
    }
  }
  return dusen.size === 0 ? liste : liste.filter((h) => !dusen.has(h.id));
}
