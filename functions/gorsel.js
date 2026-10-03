// Kastamonu Haber — görsel boyutlandırma
//
// ── Neden bu dosya var ───────────────────────────────────────────────
// Ölçüm: masaüstünde ilk açılışta 1,67 MB fotoğraf iniyordu. En büyüğü tek
// başına 293 KB ve akıştaki 104×76 piksellik küçük görsel için
// kullanılıyordu — hattın ürettiği 1200×630'luk özgün dosya, otuz katı
// büyüklükte bir yere sığdırılmaya çalışılıyor.
//
// Doğrusu Supabase'in kendi dönüştürme uç noktası olurdu
// (`/storage/v1/render/image/...`) ama bu projenin planında kapalı:
// `{"error":"FeatureNotEnabled"}`, 403. Bu fonksiyon onun yerini alıyor ve
// ücretsiz planla çalışıyor.
//
// ── Açık vekil DEĞİL — bilerek ───────────────────────────────────────
// Adres istenen görseli SERBESTÇE göstermiyor: kova koda yazılı, dosya adı
// dar bir kalıba uyuyor ve genişlik sabit bir listeden geliyor. Yani bu
// fonksiyonla yalnızca portalın kendi görselleri boyutlandırılabiliyor.
// "?u=<adres>" biçiminde bir parametre alsaydı, internetteki her görseli
// bizim faturamıza indiren bir vekile dönüşürdü.
//
// ── Biçim: her zaman WebP ────────────────────────────────────────────
// `Accept` başlığına bakıp JPEG/WebP seçmek `Vary: Accept` gerektiriyor ve
// CDN önbelleğini ikiye bölüyor. CanvasKit'i çalıştırabilen her tarayıcı
// zaten WebP destekliyor (Chrome 32+, Safari 14+, Firefox 65+), dolayısıyla
// pazarlık edecek bir şey yok.

import { onRequest } from "firebase-functions/v2/https";
import sharp from "sharp";

import { cozumle } from "./gorsel-yol.js";

const BOLGE = "europe-west1";

const SUPABASE_URL =
  process.env.SUPABASE_URL || "https://vcwgcvzqdnjyoitdfhma.supabase.co";

// Hattın görselleri yazdığı tek kova.
const KOVA = "gorseller";

// İçerik özeti dosya adında olduğu için aynı adres hiçbir zaman başka bir
// görsele dönmüyor: sonsuza kadar önbelleklenebilir.
const ONBELLEK = "public, max-age=31536000, immutable";

// Boyutlandırma başarısız olduğunda özgün dosyaya yönlendiriliyor. Kısa
// önbellek, çünkü bu geçici bir durum olmalı.
const YEDEK_ONBELLEK = "public, max-age=300";

export const gorsel = onRequest(
  { region: BOLGE, memory: "512MiB", timeoutSeconds: 30 },
  async (req, res) => {
    // Hosting yönlendirmesi özgün yolu olduğu gibi aktarıyor:
    // /gorsel/320/dosya.jpg
    const istek = cozumle(req.path);
    if (istek === null) {
      res.status(404).type("text/plain").send("Görsel bulunamadı.");
      return;
    }
    const { genislik, dosya } = istek;

    const kaynak = `${SUPABASE_URL}/storage/v1/object/public/${KOVA}/${dosya}`;

    try {
      const yanit = await fetch(kaynak);
      if (!yanit.ok) {
        res.status(yanit.status).type("text/plain").send("Kaynak alınamadı.");
        return;
      }

      const cikti = await sharp(Buffer.from(await yanit.arrayBuffer()))
        // EXIF yönü: telefonla çekilmiş fotoğraflar yan yatmış geliyor ve
        // boyutlandırma sırasında düzeltilmezse öyle kalıyor.
        .rotate()
        // `withoutEnlargement`: özgün dosya 1200 piksel genişliğinde, yani
        // 1200 kademesi onu büyütmeye çalışmamalı — bedava bulanıklık olurdu.
        .resize({ width: genislik, withoutEnlargement: true })
        .webp({ quality: 72 })
        .toBuffer();

      res.set("Cache-Control", ONBELLEK);
      res.type("image/webp").send(cikti);
    } catch (hata) {
      // Boyutlandırma düşerse okur fotoğrafsız kalmasın: özgün dosyaya
      // yönlendiriliyor. Yavaş ama doğru.
      console.error("görsel boyutlandırılamadı, özgüne düşüldü", dosya, hata);
      res.set("Cache-Control", YEDEK_ONBELLEK);
      res.redirect(302, kaynak);
    }
  },
);
