// Koşu: kaynakları tara → aynı olayı kümele → tek metin yazdır.
//
// Buradaki kümeleme `../tekille.js` ile aynı kuralı izliyor ama
// girdisi FARKLI: orada veritabanındaki kayıtlar var (kategori ve
// onaylı ilçe bağlarıyla), burada ham besleme kayıtları — henüz
// sınıflandırılmamış.
//
// Kaybolan korumayı geri koymak için ilçe adları başlık ve özet
// metninden aranıyor. Bölüm ailesi koruması burada yok; onun yerine
// eşik tek başına çalışıyor. Ölçülen tuzak çift ("Kastamonu'da tören"
// / "Tosya'da tören") 0,45'te kalıyor, yani 0,62 eşiği onu zaten
// ayırıyor — ama bu korumanın bir eksiğiyle yaşadığımız bilinerek
// yazıldı.

import { benzerlik, ESIK, sadelestir } from "../tekille.js";

/** Kastamonu'nun ilçeleri. Veritabanındaki `ilceler` ile aynı. */
export const ILCELER = [
  "Abana", "Ağlı", "Araç", "Azdavay", "Bozkurt", "Çatalzeytin", "Cide",
  "Daday", "Devrekani", "Doğanyurt", "Hanönü", "İhsangazi", "İnebolu",
  "Küre", "Merkez", "Pınarbaşı", "Şenpazar", "Seydiler", "Taşköprü", "Tosya",
];

const ILCE_ANAHTARI = ILCELER.map((ad) => [ad, sadelestir(ad)]);

/** Metinde geçen ilçeler.
 *
 * Sadeleştirilmiş karşılaştırma: "Taşköprü'de" içinde "taskopru"
 * aranıyor, böylece ek alan biçimler de yakalanıyor.
 */
export function ilceBul(...metinler) {
  const s = sadelestir(metinler.filter(Boolean).join(" "));
  return new Set(ILCE_ANAHTARI.filter(([, k]) => s.includes(k)).map(([ad]) => ad));
}

const PENCERE_SAAT = 48;

/** İki ham kayıt aynı olayı mı anlatıyor. */
export function ayniOlayHam(a, b) {
  const fark = Math.abs(
    new Date(a.olusturuldu).getTime() - new Date(b.olusturuldu).getTime());
  if (!Number.isFinite(fark) || fark > PENCERE_SAAT * 36e5) return false;

  const ia = ilceBul(a.baslik, a.ozet);
  const ib = ilceBul(b.baslik, b.ozet);
  const bos = ia.size === 0 && ib.size === 0;
  const kesisiyor = [...ia].some((x) => ib.has(x));
  if (!bos && !kesisiyor) return false;

  return benzerlik(a.baslik, b.baslik) >= ESIK;
}

/** Ham kayıtları olaylara ayırır.
 *
 * Her kayıt kümenin ÇAPASINA ölçülüyor, bütün üyelere değil: zincir
 * uzadıkça küme ilgisiz haberleri yutuyor ve karar açıklanamaz hale
 * geliyor. Çapa kümenin ilk kaydı ve değişmiyor.
 */
export function kumele(kayitlar) {
  const olaylar = [];
  for (const h of [...kayitlar].sort(
    (x, y) => String(x.olusturuldu).localeCompare(String(y.olusturuldu)))) {
    let enIyi = null, enSkor = 0;
    for (const o of olaylar) {
      if (!ayniOlayHam(h, o.capa)) continue;
      const s = benzerlik(h.baslik, o.capa.baslik);
      if (s > enSkor) { enIyi = o; enSkor = s; }
    }
    if (enIyi) enIyi.uyeler.push(h);
    else olaylar.push({ capa: h, uyeler: [h] });
  }
  return olaylar;
}

/** Kümedeki farklı yayınlar. */
export function kaynaklar(olay) {
  return [...new Set(olay.uyeler.map((h) => h.kaynak_adi))];
}

// ── Sentez ───────────────────────────────────────────────────────

export const YONERGE = `\
Sen bir şehir haber portalının yazı işlerindesin. Aynı olayı anlatan \
birden çok kaynak kaydı veriliyor. Bunlardan portalın KENDİ haberini \
yazacaksın.

Kurallar:

1. Yazdığın her cümle verilen kayıtlardaki bir bilgiye dayanmalı. \
Kayıtlarda olmayan hiçbir şey ekleme — tahmin, yorum, genel bilgi yok.
2. Kaynakların cümlelerini KOPYALAMA. Olgulardan kendi cümlelerini kur.
3. Bir kaynağın yazıp öbürünün yazmadığı ayrıntıları MUTLAKA kullan. \
Birleştirmenin amacı bu.
4. Kaynaklar aynı şey için farklı değer veriyorsa (sayı, saat, isim) \
ARALARINDA SEÇİM YAPMA: metinde belirsiz bırak, çelişkiyi celiskiler \
alanına yaz.
5. Elindeki bilgi bir haber metni yazmaya yetmiyorsa govde alanını boş \
bırak; uydurarak doldurma.

Üslup: Türkçe, haber dili, sade. Başlık tek cümle. Spot iki cümleyi \
geçmesin.`;

/** Modele gidecek istek. */
export function istek(olay) {
  return `Aşağıda aynı olayı anlatan ${olay.uyeler.length} kaynak kaydı var.\n\n` +
    JSON.stringify(olay.uyeler.map((h) => ({
      kaynak: h.kaynak_adi, baslik: h.baslik, ozet: h.ozet, adres: h.adres,
    })), null, 2);
}

export class DenetimHatasi extends Error {}

/** Sentez ile kaynak metin arasında kabul edilen en uzun ortak parça. */
export const KOPYA_ESIGI = 100;

function enUzunOrtak(a, b) {
  // Kayan pencere: kısa metinlerde yeterli ve bağımlılık istemiyor.
  a = String(a ?? ""); b = String(b ?? "");
  let en = 0;
  for (let i = 0; i < a.length; i++) {
    for (let j = i + en + 1; j <= a.length; j++) {
      if (b.includes(a.slice(i, j))) en = j - i; else break;
    }
  }
  return en;
}

/** Çıktıyı yayına uygun mu diye denetler. Modelin sözüne güvenmiyoruz. */
export function dogrula(s, olay) {
  if (!s?.baslik?.trim()) throw new DenetimHatasi("başlık boş");
  if (!s?.govde?.trim()) throw new DenetimHatasi("gövde boş");

  const kumedeki = new Set(kaynaklar(olay));
  const uydurma = (s.kullanilan_kaynaklar ?? []).filter((k) => !kumedeki.has(k));
  if (uydurma.length) {
    throw new DenetimHatasi(`kümede olmayan kaynak: ${uydurma.join(", ")}`);
  }
  if (!(s.kullanilan_kaynaklar ?? []).length) {
    throw new DenetimHatasi("hiçbir kaynak gösterilmemiş");
  }
  for (const h of olay.uyeler) {
    const boy = enUzunOrtak(s.govde, `${h.baslik} ${h.ozet}`);
    if (boy >= KOPYA_ESIGI) {
      throw new DenetimHatasi(
        `${h.kaynak_adi} kaynağından ${boy} karakterlik birebir parça`);
    }
  }
}

/** Çelişki varsa haber editör görmeden yayına çıkmamalı. */
export function durum(s) {
  return (s.celiskiler ?? []).length ? "celiskili" : "yazildi";
}

// ── Koşu ─────────────────────────────────────────────────────────

/** Bir koşu: tara → kümele → sentezle → (yaz).
 *
 * `kuru` verildiğinde hiçbir şey yazılmıyor, ne yazılacağı dönüyor.
 * Varsayılan bu: yazma yetkisi olan bir işin kazara koşması kabul
 * edilemez, yazmak bilerek istenmeli.
 *
 * Tek bir olayın sentezi düşerse koşu devam ediyor; düşenler
 * `atlanan` içinde bildiriliyor. Bir modelin tek bir haberde
 * takılması o günün bütün haberlerini engellememeli.
 */
export async function kos({
  tara: taraIsl,
  cagir,
  yazici: yz = null,
  kuru = true,
  enCok = 12,
} = {}) {
  const { kayitlar, hatalar } = await taraIsl();
  const olaylar = kumele(kayitlar);

  // Daha çok kaynağın yazdığı olay daha önemli ve sentezin kazancı da
  // orada en yüksek: tek kaynaklı bir kaydı "birleştirmenin" anlamı yok.
  const sira = olaylar
    .slice()
    .sort((a, b) => b.uyeler.length - a.uyeler.length)
    .slice(0, enCok);

  let zatenVar = new Set();
  let katMap = new Map();
  if (!kuru && yz) {
    zatenVar = await yz.varMi(kayitlar.map((h) => h.adres).filter(Boolean));
    katMap = await yz.kategoriler();
  }

  const yazilan = [], atlanan = [];
  for (const o of sira) {
    const adres = o.uyeler.find((h) => h.adres)?.adres;
    if (adres && zatenVar.has(adres)) {
      atlanan.push({ baslik: o.capa.baslik, sebep: "zaten kayıtlı" });
      continue;
    }
    try {
      const s = await cagir(o);
      dogrula(s, o);
      yazilan.push({ sentez: s, olay: o, durum: durum(s) });
    } catch (e) {
      atlanan.push({
        baslik: o.capa.baslik,
        sebep: String(e?.message ?? e).slice(0, 160),
      });
    }
  }

  return {
    kuru,
    ham: kayitlar.length,
    olay: olaylar.length,
    birlesen: olaylar.filter((o) => o.uyeler.length > 1).length,
    denenen: sira.length,
    yazilan,
    atlanan,
    kaynakHatalari: hatalar,
    katMap,
  };
}
