// Hat koşusunu kimin tetikleyebileceği.
//
// Neden gerekli
// ─────────────
// Hat fonksiyonu veritabanına YAZIYOR ve her koşu model çağrısı
// yapıyor. Kimlik doğrulaması olmayan bir uç nokta demek, adresi bulan
// herkesin haber uydurup yazdırabilmesi ve fatura üretebilmesi
// demek. Fonksiyonun kendisi `service_role` anahtarını taşıdığı için
// bunun bedeli RLS tarafından da sınırlanmıyor.
//
// Nasıl
// ─────
// Panel zaten Supabase oturumu açıyor (editör girişi). Çağıran o
// oturumun jetonunu gönderiyor, burada Supabase'e sorularak
// doğrulanıyor. Yeni bir parola ya da paylaşılan sır icat edilmiyor:
// yetkinin tek kaynağı mevcut editör oturumu.
//
// Doğrulama ANON anahtarla yapılıyor, servis anahtarıyla değil:
// `/auth/v1/user` jetonun kendisini doğruluyor ve anon anahtar bunun
// için yeterli. Servis anahtarını buraya sokmak gereksiz bir risk.

/** Çağıranın geçerli bir oturumu var mı.
 *
 * Döndürdüğü: `{ tamam: true, kullanici }` ya da `{ tamam: false, sebep }`.
 */
export async function oturumDogrula(istekBasliklari, {
  taban = null, anonAnahtar = null, fetchIsl = fetch,
} = {}) {
  taban = taban || process.env.SUPABASE_URL;
  anonAnahtar = anonAnahtar || process.env.SUPABASE_ANON_KEY;
  if (!taban || !anonAnahtar) {
    return { tamam: false, sebep: "sunucu yapılandırması eksik" };
  }

  const bas = istekBasliklari?.authorization || istekBasliklari?.Authorization || "";
  const jeton = /^Bearer\s+(.+)$/i.exec(String(bas))?.[1]?.trim();
  if (!jeton) return { tamam: false, sebep: "oturum jetonu yok" };

  // Anon anahtarın kendisi jeton olarak gönderilirse kabul edilmemeli:
  // o anahtar herkese açık ve paketin içinde tarayıcıya iniyor.
  if (jeton === anonAnahtar) {
    return { tamam: false, sebep: "anon anahtar oturum yerine geçmez" };
  }

  let y;
  try {
    y = await fetchIsl(`${taban}/auth/v1/user`, {
      headers: { apikey: anonAnahtar, Authorization: `Bearer ${jeton}` },
    });
  } catch (e) {
    return { tamam: false, sebep: "oturum doğrulanamadı" };
  }
  if (!y.ok) return { tamam: false, sebep: "oturum geçersiz" };

  const k = await y.json();
  if (!k?.id) return { tamam: false, sebep: "oturum geçersiz" };
  return { tamam: true, kullanici: { id: k.id, eposta: k.email ?? null } };
}
