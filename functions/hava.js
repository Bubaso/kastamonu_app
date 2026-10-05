// Hava durumu — Kastamonu ve ilçeleri.
//
// Neden sunucuda
// ──────────────
// Veri tarayıcıdan DOĞRUDAN çekilmiyor. Üç sebep:
//
//   1. Önbellek. Her ziyaretçi kendi isteğini atarsa sağlayıcıya günde
//      binlerce çağrı gider. Buradan geçince Hosting'in CDN'i yanıtı
//      yarım saat tutuyor ve yukarı akışa ilçe başına saatte iki istek
//      kalıyor.
//   2. Kaynağı değiştirebilmek. Sağlayıcı değişirse uygulama
//      güncellenmiyor; yalnız bu dosya değişiyor. Lisans sebebiyle bu
//      ihtimal gerçek: Open-Meteo'nun ücretsiz katmanı TİCARİ KULLANIMA
//      KAPALI ve koşullarında "reklam veya abonelik içeren siteler"
//      açıkça dışarıda. Portal reklam almaya başlarsa ya ücretli plana
//      geçilecek ya da kaynak değişecek.
//   3. Okurun tarayıcısı üçüncü bir alan adına bağlanmıyor.
//
// Veri sağlayıcı: Open-Meteo (open-meteo.com), CC-BY 4.0.

/** Kastamonu ilçelerinin koordinatları.
 *
 * Hafızadan yazılmadı: Open-Meteo'nun coğrafi arama ucundan çekildi ve
 * yirmisinin de `admin1` alanının Kastamonu olduğu doğrulandı.
 * "Merkez" il merkezini gösteriyor.
 */
export const ILCE_KOORDINAT = {
  "Abana": [41.9786, 34.0110],
  "Ağlı": [41.6860, 33.5538],
  "Araç": [41.2422, 33.3277],
  "Azdavay": [41.6427, 33.3000],
  "Bozkurt": [41.9577, 34.0109],
  "Çatalzeytin": [41.9531, 34.2163],
  "Cide": [41.8921, 33.0044],
  "Daday": [41.4787, 33.4667],
  "Devrekani": [41.6030, 33.8392],
  "Doğanyurt": [42.0046, 33.4603],
  "Hanönü": [41.6270, 34.4667],
  "İhsangazi": [41.2043, 33.5545],
  "İnebolu": [41.9789, 33.7601],
  "Küre": [41.8058, 33.7116],
  "Merkez": [41.3781, 33.7753],
  "Pınarbaşı": [41.6039, 33.1110],
  "Şenpazar": [41.8089, 33.2313],
  "Seydiler": [41.6200, 33.7182],
  "Taşköprü": [41.5098, 34.2141],
  "Tosya": [41.0155, 34.0401],
};

/** WMO hava olayı kodlarının Türkçe karşılığı.
 *
 * Kodlar Open-Meteo'nun değil, Dünya Meteoroloji Örgütü'nün (WMO 4677)
 * standardı; sağlayıcı değişse de bu tablo çoğunlukla geçerli kalıyor.
 */
const HADISE = new Map([
  [0, ["Açık", "acik"]],
  [1, ["Az bulutlu", "az-bulutlu"]],
  [2, ["Parçalı bulutlu", "parcali-bulutlu"]],
  [3, ["Çok bulutlu", "cok-bulutlu"]],
  [45, ["Sisli", "sis"]],
  [48, ["Kırağılı sis", "sis"]],
  [51, ["Hafif çisenti", "cisenti"]],
  [53, ["Çisenti", "cisenti"]],
  [55, ["Yoğun çisenti", "cisenti"]],
  [56, ["Dondurucu çisenti", "cisenti"]],
  [57, ["Yoğun dondurucu çisenti", "cisenti"]],
  [61, ["Hafif yağmur", "yagmur"]],
  [63, ["Yağmurlu", "yagmur"]],
  [65, ["Kuvvetli yağmur", "yagmur"]],
  [66, ["Dondurucu yağmur", "yagmur"]],
  [67, ["Kuvvetli dondurucu yağmur", "yagmur"]],
  [71, ["Hafif kar", "kar"]],
  [73, ["Kar yağışlı", "kar"]],
  [75, ["Yoğun kar", "kar"]],
  [77, ["Kar taneleri", "kar"]],
  [80, ["Hafif sağanak", "saganak"]],
  [81, ["Sağanak yağışlı", "saganak"]],
  [82, ["Kuvvetli sağanak", "saganak"]],
  [85, ["Hafif kar sağanağı", "kar"]],
  [86, ["Yoğun kar sağanağı", "kar"]],
  [95, ["Gök gürültülü fırtına", "firtina"]],
  [96, ["Dolulu fırtına", "firtina"]],
  [99, ["Kuvvetli dolulu fırtına", "firtina"]],
]);

/** Kodun Türkçe adı ve simge anahtarı. Bilinmeyen kod düşürülmüyor.
 *
 * `null` ÖNCE eleniyor, çünkü `Number(null)` sıfır ve sıfır "Açık"
 * demek: veri gelmediğinde hava açık görünüyordu. Haber sitesinde
 * olmayan veriyi uydurmak, boş bırakmaktan kötü.
 */
export function hadise(kod) {
  if (kod === null || kod === undefined || kod === "") {
    return { ad: "—", simge: "bilinmiyor" };
  }
  const e = HADISE.get(Number(kod));
  return e ? { ad: e[0], simge: e[1] } : { ad: "—", simge: "bilinmiyor" };
}

const YONLER = [
  "Kuzey", "Kuzeydoğu", "Doğu", "Güneydoğu",
  "Güney", "Güneybatı", "Batı", "Kuzeybatı",
];

/** Dereceyi sekiz yönden birine çeviriyor.
 *
 * `null` ÖNCE eleniyor: `Number(null)` sıfır, sıfır da "Kuzey". Yön
 * bilgisi gelmediğinde rüzgar kuzeyden esiyor gibi görünüyordu.
 */
export function ruzgarYonu(derece) {
  if (derece === null || derece === undefined || derece === "") return null;
  const d = Number(derece);
  if (!Number.isFinite(d)) return null;
  // 45°'lik dilimler; 337,5–22,5 arası Kuzey.
  return YONLER[Math.round(((d % 360) + 360) % 360 / 45) % 8];
}

/** Open-Meteo yanıtını uygulamanın beklediği biçime indiriyor.
 *
 * Ayrı ve saf: ağ olmadan test edilebiliyor ve sağlayıcı değişirse
 * yalnız bu işlev değişiyor.
 */
export function bicimle(ham, ilce) {
  const a = ham?.current ?? {};
  const g = ham?.daily ?? {};
  const gunler = (g.time ?? []).map((t, i) => ({
    tarih: t,
    enDusuk: Math.round(g.temperature_2m_min?.[i]),
    enYuksek: Math.round(g.temperature_2m_max?.[i]),
    ruzgar: Math.round(g.wind_speed_10m_max?.[i]),
    yagisOlasiligi: g.precipitation_probability_max?.[i] ?? null,
    ...hadise(g.weather_code?.[i]),
  }));
  return {
    ilce,
    guncellendi: a.time ?? null,
    simdi: {
      sicaklik: Math.round(a.temperature_2m),
      hissedilen: Math.round(a.apparent_temperature),
      nem: a.relative_humidity_2m ?? null,
      ruzgar: Math.round(a.wind_speed_10m),
      ruzgarYonu: ruzgarYonu(a.wind_direction_10m),
      ...hadise(a.weather_code),
    },
    gunler,
    kaynak: "Open-Meteo",
  };
}

const ALANLAR = {
  current: "temperature_2m,apparent_temperature,relative_humidity_2m," +
    "wind_speed_10m,wind_direction_10m,weather_code",
  daily: "weather_code,temperature_2m_max,temperature_2m_min," +
    "wind_speed_10m_max,precipitation_probability_max",
};

/** İlçenin hava durumu. Tanınmayan ilçe için Merkez veriliyor. */
export async function havaCek(ilceAdi, { fetchIsl = fetch, gun = 10 } = {}) {
  const ilce = ILCE_KOORDINAT[ilceAdi] ? ilceAdi : "Merkez";
  const [enlem, boylam] = ILCE_KOORDINAT[ilce];
  const u = "https://api.open-meteo.com/v1/forecast" +
    `?latitude=${enlem}&longitude=${boylam}` +
    `&current=${ALANLAR.current}&daily=${ALANLAR.daily}` +
    `&timezone=Europe%2FIstanbul&forecast_days=${gun}`;

  const y = await fetchIsl(u);
  if (!y.ok) throw new Error(`hava servisi ${y.status}`);
  return bicimle(await y.json(), ilce);
}
