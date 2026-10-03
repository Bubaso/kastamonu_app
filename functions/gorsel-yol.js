// Görsel isteğinin yolunu çözümleyen saf işlev.
//
// Ayrı dosyada, çünkü güvenlik sınırı burası: bu işlev neyin
// boyutlandırılabileceğine karar veriyor. Bağımlılığı yok, dolayısıyla
// `node --test functions/gorsel-yol.test.js` ile tek başına koşuyor.

/// Hizmetin kabul ettiği genişlikler.
///
/// `lib/cekirdek/gorsel.dart` içindeki liste ile AYNI olmak zorunda.
export const GENISLIKLER = new Set([320, 640, 1200]);

// Dosya adı kalıbı. Hat içerik özetli ad üretiyor:
// "kastamonu-da-trafige-kayitli-arac-sayisi-a70407ff.jpg".
//
// Eğik çizgi kalıbın dışında, dolayısıyla "../" ile dizin dışına çıkmak
// mümkün değil; nokta tek başına geçiyor ama ".." bir uzantıyla
// bitmediği için kalıbı tutturamıyor.
const DOSYA = /^[A-Za-z0-9._-]+\.(jpe?g|png|webp)$/i;

/// `/gorsel/320/dosya.jpg` → `{ genislik: 320, dosya: "dosya.jpg" }`
///
/// Kabul etmediği her şey için `null` — çağıran bunu 404'e çeviriyor.
export function cozumle(yol) {
  const parcalar = String(yol ?? "")
    .split("/")
    .filter(Boolean);

  if (parcalar.length !== 3) return null;
  if (parcalar[0] !== "gorsel") return null;

  // `Number` boşluğu ve "+320" gibi şeyleri de sayıya çeviriyor; kümede
  // aranmadan önce tam sayı olduğu ayrıca doğrulanıyor.
  const genislik = Number(parcalar[1]);
  if (!Number.isInteger(genislik) || !GENISLIKLER.has(genislik)) return null;

  const dosya = parcalar[2];
  if (!DOSYA.test(dosya)) return null;

  return { genislik, dosya };
}
