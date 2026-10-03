# Kastamonu Haber

Kastamonu ve ilçeleri için şehir haber portalı. Haberler harici kaynaklardan
derleniyor, her birinin künyesinde özgün kaynağı belirtiliyor.

Tek kod tabanında iki yüzü var:

- **Okur tarafı** (`/`) — herkese açık. Üyelik yok.
- **İnceleme masası** (`/panel`) — editör oturumu istiyor. Derlenen haber
  buradan geçmeden yayına çıkmıyor.

Yayında: <https://kastamonuhaber-68645.web.app>

## Nasıl çalışıyor

```
  haber kaynakları
         │
         ▼
   ┌───────────┐   hat_gorevleri      ┌──────────────┐
   │   hat     │◀──── kuyruk ─────────│   /panel     │
   │ (Python)  │                      │  (Flutter)   │
   └─────┬─────┘                      └──────▲───────┘
         │  haber + ilçe bağı + güven skoru         │
         ▼                                          │
   ┌──────────────────── Supabase ──────────────────┴──┐
   │  Postgres · PostgREST · RLS · Auth                │
   └───────────────────────┬───────────────────────────┘
                           │  anon anahtar: yalnızca durum='yayinda'
         ┌─────────────────┴─────────────────┐
         ▼                                   ▼
  Cloud Functions (SSR)              Flutter Web (CanvasKit)
  meta + gövde metni                 okur arayüzü
```

Haber hattı **bu depoda değil**: ayrı bir Python işçisi. Panel onu doğrudan
çağıramıyor (biri tarayıcıda, öbürü yerelde), araya `hat_gorevleri` kuyruğu
giriyor — panel satır yazıyor, işçi görüp koşuyor, sonucu aynı satıra
yazıyor. SQL göçleri de bu depoda tutulmuyor; kod yorumlarındaki
"migration 0002" gibi atıflar oraya işaret ediyor.

Haberin yolu: hat derler → `durum='inceleme'` → editör başlığı/spotu düzeltir,
ilçe bağlarını onaylar → `durum='yayinda'` (ya da `reddedildi`). Okur tarafı
anon anahtarla çalıştığı için RLS gereği yalnızca `yayinda` olanı görebiliyor;
inceleme masasındaki haber kod hatasıyla bile akışa sızamaz.

### İlçe bağları

Hat her haberi bir ya da birkaç ilçeye bağlıyor, bağın **nereden geldiğini**
de yazıyor: `model+sozluk` (iki bağımsız yöntemin mutabakatı), `sozluk`,
`yalniz_model`, `editor`. Panel bu etiketi ve güven skorunu gösteriyor,
çünkü editörün en çok ihtiyaç duyduğu bilgi bu. Yalnızca onaylanmış bağlar
okur tarafında etiket olarak görünüyor ve "İlçem" sekmesini besliyor.

## Teknoloji

| Katman | Ne |
| --- | --- |
| Arayüz | Flutter Web (CanvasKit), Dart SDK ^3.11.4 |
| Durum | `flutter_riverpod` |
| Yönlendirme | `go_router`, gerçek yol stratejisi (hash yok) |
| Veri | Supabase — Postgres, PostgREST, RLS, Auth |
| Barındırma | Firebase Hosting (`kastamonuhaber-68645`) |
| SSR | Cloud Functions, Node 22, `europe-west1` |
| Cihaz belleği | `shared_preferences` |

## Dizinler

```
lib/
  cekirdek/            uygulama geneli
    kabuk.dart         üç sekmeyi saran kabuk, alt çubuk
    yonlendirme.dart   rotalar ve oturum yönlendirmesi
    tema.dart          renk, punto, yazı tipi kararları
    tercihler.dart     cihazda saklanan okur tercihleri
    supabase.dart      bağlantı ayarları
    metin.dart         Türkçeye uygun büyütme/küçültme
  ozellikler/
    anasayfa/          akış, manşet, kart, kategori çubuğu
    haber/             haber detay sayfası
    ilcem/             okurun kendi ilçesi
    kaydedilen/        sonra okunacaklar
    inceleme/          editör paneli, haber modeli
    hat/               hat tetikleme ve koşu geçmişi
functions/             sunucu tarafı render (Node)
test/                  birim testleri
```

Her özellik `ekran/` + `veri/` (+ gerektiğinde `model/`) olarak bölünüyor.
Adlandırma baştan sona Türkçe; `metin.dart` başındaki gerekçe bunun neden
tutarlı tutulduğunu anlatıyor.

## Rotalar

| Yol | Ne |
| --- | --- |
| `/` | Akış — en yeni üstte |
| `/kategori/:slug` | Bölüme göre akış, paylaşılabilir adres |
| `/ilcem` | Okurun seçtiği ilçenin haberleri |
| `/kaydettiklerim` | Cihazda saklanan kayıtlar |
| `/haber/:slug` | Haber sayfası |
| `/giris` · `/panel` | Editör girişi ve inceleme masası |

`/`, `/kategori/*` ve `/sitemap.xml` Cloud Functions üzerinden geçiyor;
gerisi Flutter kabuğuna (`/app.html`) düşüyor. Eşleştirme `firebase.json`
içindeki `rewrites` bölümünde.

## Çalıştırma

Anahtar kaynağa yazılmıyor, `--dart-define` ile veriliyor.

```bash
echo 'SUPABASE_ANON_KEY=...' > .env.panel   # depoya girmiyor
./calistir.sh                               # flutter run -d chrome
```

Testler:

```bash
flutter test
flutter analyze
```

## Dağıtım

```bash
./yayinla.sh
```

Betiğin asıl işi kabuk üretimi: `functions/shell.html`, Flutter'ın ürettiği
`build/web/index.html`in birebir kopyası olmak zorunda — elle tutulan bir
kabuk, Flutter sürüm damgalı betik yolunu değiştirdiğinde sessizce bayatlıyor
ve SSR'lı sayfalar eski paketi yüklemeye çalışıyor. Betik ayrıca
`index.html`i `app.html`e taşıyor: Firebase Hosting statik dosyayı
yönlendirmeden önce sunduğu için, `index.html` yerinde kalırsa `/` isteği
ana sayfa SSR fonksiyonuna hiç ulaşmıyor.

## Kararlar

Aşağıdakiler üslup tercihi değil; her birinin gerekçesi ilgili dosyanın
başında yazılı.

**Üyelik yok.** İlçe seçimi, kaydedilen haberler ve punto tercihi okurun
cihazında duruyor; sunucuya kişisel veri gitmiyor. Bedeli açık — okur cihaz
değiştirirse tercihleri gelmiyor. Bu aşamada üyelik sisteminin maliyetine
değmiyor. (`cekirdek/tercihler.dart`)

**Punto ve kontrast bir erişilebilirlik kısıtı.** Kastamonu, TÜİK 2025'e göre
Türkiye'nin ortanca yaşı en yüksek üçüncü ili (43,3) ve 65 yaş üstü oranında
ikinci (%21,1). Gövde metni 17,5 px'in altına inmiyor, hiçbir metin rengi
WCAG AA'nın (4,5:1) altına düşmüyor, okur punto ayarını haberin başında
buluyor. (`cekirdek/tema.dart`)

**Yazı tipleri gömülü.** CanvasKit sistem yazı tiplerini tanımıyor; bir aile
adı `pubspec.yaml`da bildirilmemişse sessizce Roboto'ya düşüyor. Altı kesit,
toplam 247 KB. (`assets/fonts/BENIOKU.md`)

**Sunucu tarafı render zorunlu.** Flutter çizimi tuvale yaptığı için sayfanın
kaynağında okunacak tek kelime yok — paylaşılan bağlantı başlıksız bir kutu
olarak görünüyor, arama motoru indeksleyecek metin bulamıyor. Dört fonksiyon
kabuğun içine gerçek meta etiketlerini ve gövde metnini basıyor, Flutter
sonra açılıp devralıyor. Bot tespiti bilerek yapılmıyor: aynı HTML hem bota
hem insana dönüyor. (`functions/index.js`)

**Anon anahtar yayımlanmak üzere tasarlandı.** Flutter Web'de paket tarayıcıya
indiği için oradaki anahtar zaten görünür; tek başına RLS'i aşamıyor. Panelin
yetkisi anahtardan değil, açtığı oturumdan geliyor. `service_role` anahtarı
istemciye de, `functions/.env`e de konulmaz. (`cekirdek/supabase.dart`)

**Türkçe büyütme ayrı bir işlev.** Dart'ın `toUpperCase()` metodu `"i"` → `"I"`
üretiyor; doğrusu `"İ"`. Bölüm etiketleri versal yazıldığı için bu ekranda
doğrudan görünen bir hataydı. (`cekirdek/metin.dart`)
