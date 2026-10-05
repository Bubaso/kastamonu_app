// Üretilen haberi Supabase'e yazar.
//
// Neden ayrı anahtar
// ──────────────────
// Portalın her yerinde kullanılan anon anahtar RLS yüzünden yalnız
// `durum='yayinda'` kayıtları okuyabiliyor — yazamıyor. Hat kayıt
// açtığı için `service_role` anahtarına ihtiyacı var.
//
// O anahtar RLS'i TÜMDEN atlıyor: veritabanındaki her şeyi okur,
// değiştirir, siler. Bu yüzden:
//
//   • depoya, koda ya da `.env`e ASLA yazılmaz,
//   • Firebase'de bir SIR (Secret Manager) olarak tanımlanır,
//   • yalnız bu fonksiyona verilir, SSR fonksiyonlarına değil.
//
// Tanımlama (kullanıcı kendi makinesinde, anahtar hiçbir yere
// yapıştırılmadan):
//
//   firebase functions:secrets:set SUPABASE_SERVICE_KEY
//
// Durum
// ─────
// Kayıtlar `durum='inceleme'` ile açılıyor. Hiçbir şey kendiliğinden
// yayına çıkmıyor; editör onayı akışta kalıyor.

import { DenetimHatasi } from "./kos.js";

/** Başlıktan adres parçası üretir. */
export function slugla(baslik) {
  const esleme = { "ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u" };
  let s = String(baslik ?? "").replace(/I/g, "ı").replace(/İ/g, "i").toLowerCase();
  for (const [k, h] of Object.entries(esleme)) s = s.split(k).join(h);
  return s.replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 90);
}

/** Supabase'e yazan bir istemci üretir. */
export function yazici({ taban = null, anahtar = null, fetchIsl = fetch } = {}) {
  taban = taban || process.env.SUPABASE_URL;
  anahtar = anahtar || process.env.SUPABASE_SERVICE_KEY;
  if (!taban || !anahtar) {
    throw new DenetimHatasi(
      "SUPABASE_URL ve SUPABASE_SERVICE_KEY gerekiyor. Servis anahtarı " +
      "Firebase sırrı olarak tanımlanır, koda yazılmaz.");
  }

  const bas = {
    apikey: anahtar,
    Authorization: `Bearer ${anahtar}`,
    "Content-Type": "application/json",
  };

  return {
    /** Bu adresler daha önce kaydedilmiş mi.
     *
     * Sorgu PARÇA PARÇA gidiyor ve başarısızlık YUTULMUYOR. İkisi de
     * ölçümle öğrenildi:
     *
     * Adresler tek bir `in.(...)` süzgecine dizildiğinde 145 kayıtla
     * sorgu 37.639 karaktere çıkıyor — her URL sınırının çok
     * üstünde. İstek düşüyordu.
     *
     * Düşen istekte eski kod boş küme dönüyordu, yani "hiçbir haber
     * kayıtlı değil" diyordu. Sonuç: her koşu yayındaki haberleri
     * yeniden sentezliyor, on iki model çağrısını boşa yakıyor ve
     * hepsi veritabanının tekillik kısıtına çarpıp 409 ile
     * düşüyordu. Dışarıdan "bugün yeni haber yok" gibi görünüyordu.
     *
     * Tekilleştirme çalışmıyorsa koşu DURMALI: sessizce para yakmak
     * yerine hatayla dönmek doğru olan.
     */
    async varMi(adresler) {
      const benzersiz = [...new Set(adresler.filter(Boolean))];
      if (!benzersiz.length) return new Set();

      const PARCA = 25;
      const parcalar = [];
      for (let i = 0; i < benzersiz.length; i += PARCA) {
        parcalar.push(benzersiz.slice(i, i + PARCA));
      }

      const kumeler = await Promise.all(parcalar.map(async (p) => {
        const ic = p.map((a) => `"${a.replace(/"/g, "")}"`).join(",");
        const y = await fetchIsl(
          `${taban}/rest/v1/haberler?select=kaynak_url&kaynak_url=in.(${encodeURIComponent(ic)})`,
          { headers: bas });
        if (!y.ok) {
          throw new DenetimHatasi(
            `kayıtlı adresler okunamadı: ${y.status}. Tekilleştirme ` +
            "çalışmadan koşmak yayındaki haberleri yeniden üretir.");
        }
        return (await y.json()).map((h) => h.kaynak_url);
      }));

      return new Set(kumeler.flat());
    },

    /** Kategori adlarını kimliklere çevirir. */
    async kategoriler() {
      const y = await fetchIsl(`${taban}/rest/v1/kategoriler?select=id,ad`,
        { headers: bas });
      if (!y.ok) throw new DenetimHatasi(`kategoriler okunamadı: ${y.status}`);
      return new Map((await y.json()).map((k) => [k.ad, k.id]));
    },

    /** Haberi inceleme masasına ekler. */
    async ekle(satir) {
      const y = await fetchIsl(`${taban}/rest/v1/haberler`, {
        method: "POST",
        headers: { ...bas, Prefer: "return=representation" },
        body: JSON.stringify(satir),
      });
      if (!y.ok) {
        throw new DenetimHatasi(
          `yazılamadı ${y.status}: ${(await y.text()).slice(0, 200)}`);
      }
      return (await y.json())[0];
    },
  };
}

/** Kümedeki en iyi görsel ve onu veren yayın. */
export function gorselSec(olay) {
  const h = olay.uyeler.find((x) => (x.gorsel ?? "").startsWith("http"));
  return h ? { adres: h.gorsel, kaynak: h.kaynak_adi } : null;
}

/** Görseli kendi depomuza kopyalar.
 *
 * Neden kopyalanıyor: boyutlandırma fonksiyonu (`/gorsel/...`) yalnız
 * kendi depomuzdaki dosyaları servis ediyor. Kaynağın adresine
 * bağlanmak, hem boyutlandırmayı hem de kaynak o adresi değiştirdiğinde
 * görselin kaybolmamasını kaçırmak demek.
 *
 * Yüklenemezse null dönüyor; çağıran haberi görselsiz AÇMIYOR.
 */
export async function gorselKopyala(adres, slug, {
  taban = null, anahtar = null, fetchIsl = fetch,
} = {}) {
  taban = taban || process.env.SUPABASE_URL;
  anahtar = anahtar || process.env.SUPABASE_SERVICE_KEY;
  try {
    const y = await fetchIsl(adres, {
      headers: { "User-Agent": "Mozilla/5.0" },
    });
    if (!y.ok) return null;
    const tur = y.headers.get("content-type") ?? "";
    if (!/^image\/(jpeg|png|webp)/.test(tur)) return null;
    const veri = await y.arrayBuffer();
    if (veri.byteLength < 2000) return null;   // ikon/placeholder

    const uzanti = tur.includes("png") ? "png" : tur.includes("webp") ? "webp" : "jpg";
    const dosya = `${slug.slice(0, 70)}-${Date.now().toString(36)}.${uzanti}`;

    const u = await fetchIsl(`${taban}/storage/v1/object/gorseller/${dosya}`, {
      method: "POST",
      headers: {
        apikey: anahtar, Authorization: `Bearer ${anahtar}`,
        "Content-Type": tur, "x-upsert": "true",
      },
      body: veri,
    });
    if (!u.ok) return null;
    return `${taban}/storage/v1/object/public/gorseller/${dosya}`;
  } catch {
    return null;
  }
}

/** Sentez çıktısını veritabanı satırına çevirir. */
export function satirKur(sentez, olay, kategoriId, gorsel = null) {
  const lider = olay.uyeler.find((h) => h.adres) ?? olay.uyeler[0];
  return {
    baslik: sentez.baslik,
    spot: sentez.spot,
    govde: sentez.govde,
    slug: slugla(sentez.baslik),
    kategori_id: kategoriId ?? null,
    // Künyede kümedeki bütün yayınlar anılıyor: birine atıf verip
    // ötekini yutmak olmaz.
    kaynak_adi: (sentez.kullanilan_kaynaklar ?? []).join(", "),
    kaynak_url: lider?.adres ?? null,
    gorsel_url: gorsel?.adres ?? null,
    gorsel_kaynak: gorsel?.kaynak ?? null,
    onem: sentez.onem ?? 5,
    katman: 1,
    durum: "inceleme",
    olgular: {},
    sayilar: [],
  };
}
