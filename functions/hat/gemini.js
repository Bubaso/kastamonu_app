// Sentezin Gemini uygulaması.
//
// `kos.js` hangi sağlayıcıyı kullandığımızı bilmiyor; burası onu
// bağlayan tek dosya.
//
// Neden SDK değil de doğrudan REST
// ────────────────────────────────
// Tek bir uç nokta çağrılıyor. SDK eklemek fonksiyon paketine yeni bir
// bağımlılık sokuyor ve `sharp` deneyiminden sonra bunun bedeli belli:
// her yeni paket kilit dosyası, kurulum ve dağıtım adımı demek.
// `fetch` Node 22'de yerleşik.
//
// Anahtar
// ───────
// `GEMINI_API_KEY` ortamdan okunuyor. Firebase'de bu bir SIR
// (Secret Manager) olarak tanımlanıyor; koda, depoya ya da `.env`e
// yazılmıyor.

import { DenetimHatasi, YONERGE, istek } from "./kos.js";

/** Varsayılan model.
 *
 * Kararlı sürüm bilerek seçildi: hat her gün koşacak ve "preview"
 * etiketli modeller haber vermeden değişebiliyor ya da kalkabiliyor.
 */
export const MODEL = "gemini-2.5-pro";

const SEMA = {
  type: "object",
  properties: {
    baslik: { type: "string" },
    spot: { type: "string" },
    govde: { type: "string" },
    kategori: {
      type: "string",
      enum: ["Asayiş", "Kaza ve Acil", "Gündem", "Kent ve Yönetim", "Ekonomi",
             "Tarım", "Eğitim", "Sağlık", "Kültür ve Turizm", "Spor"],
    },
    onem: { type: "integer" },
    kullanilan_kaynaklar: { type: "array", items: { type: "string" } },
    celiskiler: {
      type: "object",
      properties: {
        konu: { type: "string" },
        degerler: {
          type: "array",
          items: {
            type: "object",
            properties: { kaynak: { type: "string" }, deger: { type: "string" } },
            required: ["kaynak", "deger"],
          },
        },
      },
      required: ["konu", "degerler"],
    },
  },
  required: ["baslik", "spot", "govde", "kategori", "onem",
             "kullanilan_kaynaklar"],
};

const EK_YONERGE = `

Ayrıca:
- kategori alanına listedeki bölümlerden en uygununu yaz.
- onem alanına 3 ile 8 arasında bir sayı yaz: 3 rutin duyuru, 5 sıradan \
şehir haberi, 8 ilin tamamını ilgilendiren büyük olay.`;

/** Gemini'ye bağlı bir sentez çağırıcısı üretir. */
export function cagirici({ model = MODEL, anahtar = null, fetchIsl = fetch } = {}) {
  anahtar = anahtar || process.env.GEMINI_API_KEY;
  if (!anahtar) {
    throw new DenetimHatasi(
      "GEMINI_API_KEY tanımlı değil. Anahtar ortamdan okunuyor, koda yazılmaz.");
  }

  return async function cagir(olay) {
    const y = await fetchIsl(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": anahtar },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: YONERGE + EK_YONERGE }] },
          contents: [{ role: "user", parts: [{ text: istek(olay) }] }],
          generationConfig: {
            responseMimeType: "application/json",
            responseSchema: SEMA,
            // Haber metni: uydurmaya yer bırakmamak için düşük.
            temperature: 0.2,
          },
        }),
      });

    if (!y.ok) {
      throw new DenetimHatasi(
        `Gemini ${y.status}: ${(await y.text()).slice(0, 200)}`);
    }
    const j = await y.json();
    const metin = j?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!metin) {
      // Güvenlik süzgeci ya da biçim hatası. Ham yanıt gövdeye
      // konmuyor: denetlenmemiş çıktı yayına yaklaştırılmaz.
      throw new DenetimHatasi(
        `model metin döndürmedi (${JSON.stringify(j?.promptFeedback ?? j?.candidates?.[0]?.finishReason ?? {}).slice(0, 160)})`);
    }
    try {
      return JSON.parse(metin);
    } catch {
      throw new DenetimHatasi("model geçerli JSON döndürmedi");
    }
  };
}
