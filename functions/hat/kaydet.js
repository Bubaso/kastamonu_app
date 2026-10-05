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
    /** Bu adres daha önce kaydedilmiş mi. */
    async varMi(adresler) {
      if (!adresler.length) return new Set();
      const ic = adresler.map((a) => `"${a.replace(/"/g, '')}"`).join(",");
      const y = await fetchIsl(
        `${taban}/rest/v1/haberler?select=kaynak_url&kaynak_url=in.(${encodeURIComponent(ic)})`,
        { headers: bas });
      if (!y.ok) return new Set();
      return new Set((await y.json()).map((h) => h.kaynak_url));
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

/** Sentez çıktısını veritabanı satırına çevirir. */
export function satirKur(sentez, olay, kategoriId) {
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
    onem: sentez.onem ?? 5,
    katman: 1,
    durum: "inceleme",
    olgular: {},
    sayilar: [],
  };
}
