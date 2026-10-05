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
6. kullanilan_kaynaklar alanına kayıtlardaki "kaynak" değerlerini BİREBİR \
yaz — yayın adını, adresi değil.

GÖVDE: Tek cümlelik haber olmaz. Elindeki bilgiden 5N1K'nın hepsini \
çıkar ve her birini metne yerleştir — NE oldu, KİM, NEREDE, NE ZAMAN, \
NASIL, NEDEN. Kaynaklarda olmayanı yazma; eksik kalan varsa onu atla, \
ama elindekinin hepsini kullan. En az üç paragraf yaz, paragrafları boş \
satırla ayır.

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
/** Künyeyi kümedeki yayın adlarına oturtur.
 *
 * Ölçümde model künye alanına yayın adı yerine ADRES yazdı ve iki
 * geçerli haber "uydurulmuş kaynak" diye reddedildi. Adres kümede
 * gerçekten var olan bir kaydı işaret ediyorsa bu uydurma değil, alan
 * karışıklığı: yayın adına çevriliyor.
 *
 * Çevrilemeyen değer olduğu gibi bırakılıyor; [dogrula] onu reddediyor.
 */
export function kunyeyiDuzelt(s, olay) {
  const adresten = new Map(
    olay.uyeler.filter((h) => h.adres).map((h) => [h.adres, h.kaynak_adi]));
  const duzeltilmis = (s.kullanilan_kaynaklar ?? [])
    .map((k) => adresten.get(k) ?? k);
  return { ...s, kullanilan_kaynaklar: [...new Set(duzeltilmis)] };
}

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
  // Sayı dayanağı.
  //
  // Ölçümde yakalanan gerçek hata: modele yalnız iki BAŞLIK verildi
  // (özetler boştu) ve model plaka numarası, cadde adı, saat ve yaş
  // uydurup tam bir haber metni yazdı — "37 M 0134 plakalı halk
  // otobüsü", "Kuzeykent Mahallesi Alparslan Türkeş Bulvarı". Hiçbiri
  // girdide yoktu.
  //
  // Yönergede "uydurma" yazması yetmiyor; ölçmek gerekiyor. Metindeki
  // her sayı dizisi kaynak metinlerde geçmek zorunda. Sayılar bir
  // haberin en somut ve en zararlı uydurma noktası: plaka, yaş, ölü
  // sayısı, saat.
  //
  // Bedeli: kaynak "iki kişi" yazıp model "2 kişi" yazarsa bu denetim
  // haberi reddediyor. Haber sisteminde bu doğru taraf — reddedilen
  // haber editöre düşüyor, uydurulmuş haber okura gidiyor.
  const kaynakMetni = olay.uyeler.map((h) => `${h.baslik} ${h.ozet}`).join(" ");
  const sayilar = [...new Set(String(s.govde).match(/\d+/g) ?? [])];
  const dayanaksiz = sayilar.filter((n) => !kaynakMetni.includes(n));
  if (dayanaksiz.length) {
    throw new DenetimHatasi(
      `kaynakta geçmeyen sayı: ${dayanaksiz.slice(0, 5).join(", ")}`);
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
  govdeDoldur = null,
} = {}) {
  const { kayitlar, hatalar } = await taraIsl();
  const olaylar = kumele(kayitlar);

  // Sıralama ÖNCE metne bakıyor, sonra kaynak sayısına.
  //
  // Sebebi ölçümle çıktı: yalnız kaynak sayısına göre sıralandığında
  // en büyük kümelerin hepsi Google Haberler kaynaklıydı ve onlarda
  // metin yok — koşu sıfır haber üretti. Metni olan küme, kaynağı az
  // olsa bile yazılabilir bir haber demek.
  const metinli = (o) => o.uyeler.some((h) => (h.ozet ?? "").trim().length > 40);
  const sira = olaylar
    .slice()
    .sort((a, b) => (metinli(b) - metinli(a)) || (b.uyeler.length - a.uyeler.length))
    .slice(0, enCok);

  let zatenVar = new Set();
  let katMap = new Map();
  if (!kuru && yz) {
    zatenVar = await yz.varMi(kayitlar.map((h) => h.adres).filter(Boolean));
    katMap = await yz.kategoriler();
  }

  // Kümeler PARALEL işleniyor, sırayla değil.
  //
  // Sırayla yapıldığında 20 küme × (sayfa çekme + model çağrısı) 540
  // saniyelik fonksiyon sınırını aşıyordu ve koşu hiçbir şey
  // yazamadan düşüyordu. Eşzamanlılık sınırlı: kaynak sitelere ve
  // modele aynı anda onlarca istek atmak hem kaba hem kırılgan.
  const EŞZAMAN = 5;
  const yazilan = [], atlanan = [];

  async function birKume(o) {
    const adres = o.uyeler.find((h) => h.adres)?.adres;
    if (adres && zatenVar.has(adres)) {
      atlanan.push({ baslik: o.capa.baslik, sebep: "zaten kayıtlı" });
      return;
    }
    // Hiçbir üyede metin yoksa modele hiç gitmiyoruz. Yalnız başlıkla
    // haber yazmak uydurmaktan başka bir şey değil ve ölçümde tam
    // olarak bu oldu. Modelin "yetmiyorsa boş bırak" kuralına
    // güvenmek yetmedi: üç kümeden ikisinde uydu, birinde uydurdu.
    if (!o.uyeler.some((h) => (h.ozet ?? "").trim().length > 40)) {
      atlanan.push({ baslik: o.capa.baslik, sebep: "kaynak metni yok" });
      return;
    }

    // Görselsiz haber yayımlanmıyor. Bu bir ürün kararı: fotoğrafsız
    // yerel haber sitesi okunmuyor. Kümede hiçbir üyenin görseli yoksa
    // haber üretilmiyor — görselsiz bir kayıt açıp sonra elle
    // doldurmayı beklemek, inceleme masasını çöple doldurmak demek.
    if (!o.uyeler.some((h) => (h.gorsel ?? "").startsWith("http"))) {
      atlanan.push({ baslik: o.capa.baslik, sebep: "görsel yok" });
      return;
    }
    try {
      // Gövdeler sentezden HEMEN ÖNCE dolduruluyor. RSS özeti ~150
      // karakter ve onunla ancak tek cümlelik haber çıkıyor; haber
      // sayfasında 900-1300 karakter var. Yalnız sentezlenecek kümeler
      // için çekiliyor, her ham kayıt için değil.
      if (govdeDoldur) {
        o.uyeler = await Promise.all(o.uyeler.map((h) => govdeDoldur(h)));
      }
      const s = kunyeyiDuzelt(await cagir(o), o);
      dogrula(s, o);
      yazilan.push({ sentez: s, olay: o, durum: durum(s) });
    } catch (e) {
      atlanan.push({
        baslik: o.capa.baslik,
        sebep: String(e?.message ?? e).slice(0, 160),
      });
    }
  }

  // Sabit genişlikte havuz: sıradaki küme, biten işin yerine giriyor.
  const kuyruk = [...sira];
  await Promise.all(
    Array.from({ length: Math.min(EŞZAMAN, kuyruk.length) }, async () => {
      for (let o = kuyruk.shift(); o; o = kuyruk.shift()) await birKume(o);
    }));

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
