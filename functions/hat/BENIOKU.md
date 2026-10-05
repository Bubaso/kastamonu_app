# Haber hattı — bulutta

Hat artık burada koşuyor. Daha önce kullanıcının kendi bilgisayarındaki
bir Python işçisiydi; o makine kapalıyken hiçbir şey çekilmiyordu.

## Akış

```
  Google Haberler RSS ─┐
                       ├─► kümele ─► sentezle ─► inceleme masası
  Haberler.com RSS ────┘   (aynı olay)  (Gemini)    (editör onayı)
```

## Ölçülen

Canlı beslemelerle tek koşu: **119 ham kayıt**, **105 olay**, **12 olay
birleşti** (14 tekrar eleniyor). Bugünkü hat günde ~17 haber getiriyor.

Kümelerde yerel Kastamonu yayınları çıktı — Taşköprü Postası, Açıksöz
Gazetesi, Kastamonu İstiklal, Kastamonu Güncel. Liste hafızadan
yazılmadı; Google Haberler keşfiyle kendiliğinden geldi.

## Dosyalar

| Dosya | Ne |
| --- | --- |
| `kaynak.js` | Besleme okuma ve çözümleme |
| `kos.js` | Kümeleme, sentez sözleşmesi, koşu |
| `gemini.js` | Sentezin Gemini uygulaması (REST, bağımlılık yok) |
| `kaydet.js` | Supabase'e yazma |
| `yetki.js` | Çağıranın editör oturumu doğrulaması |

## Çalıştırma

Uç nokta **açık değil**: geçerli bir editör oturumu istiyor.

```bash
# kuru koşu — hiçbir şey yazılmaz, ne yazılacağı döner
curl -H "Authorization: Bearer <editör oturum jetonu>" \
  https://<bölge>-<proje>.cloudfunctions.net/hatKos

# gerçekten yaz
curl -H "Authorization: Bearer <editör oturum jetonu>" \
  "https://<bölge>-<proje>.cloudfunctions.net/hatKos?yaz=1"
```

## Anahtarlar

İkisi de **sır**; depoya, koda ya da `.env`e girmez. Firebase'in sır
deposuna tanımlanır:

```bash
firebase functions:secrets:set GEMINI_API_KEY
firebase functions:secrets:set SUPABASE_SERVICE_KEY
```

Komut anahtarı sorar; yapıştırdığınız değer ekrana basılmaz, dosyaya
yazılmaz, depoya girmez.

`SUPABASE_SERVICE_KEY` RLS'i **tümden atlıyor** — veritabanındaki her
şeyi okur, değiştirir, siler. Yalnız bu fonksiyona veriliyor; SSR
fonksiyonları anon anahtarla çalışmaya devam ediyor.

## Kararlar

**Varsayılan kuru koşu.** Yazma yetkisi olan bir işin kazara koşması
kabul edilemez; yazmak `?yaz=1` ile bilerek isteniyor.

**Yazılanlar `durum='inceleme'`.** Hiçbir şey kendiliğinden yayına
çıkmıyor, editör onayı akışta kalıyor.

**Uç nokta kimlik doğruluyor.** Fonksiyon veritabanına yazıyor ve her
çağrı model maliyeti üretiyor. Açık bırakılsaydı adresi bulan herkes
haber uydurup yazdırabilir, fatura üretebilirdi. Yetkinin kaynağı
panelin zaten açtığı editör oturumu; yeni bir parola icat edilmedi.

**Doğrulama anon anahtarla yapılıyor,** servis anahtarıyla değil:
`/auth/v1/user` jetonun kendisini doğruluyor ve anon anahtar yetiyor.
Anon anahtarın jeton olarak gönderilmesi ayrıca reddediliyor — o anahtar
tarayıcıya iniyor, kabul edilseydi uç nokta fiilen açık olurdu.

**Google Haberler metin için değil keşif için.** `description` yalnız
başlığı tekrarlıyor ve bağlantısı gerçek adrese yönlenmiyor (JavaScript
ile çözülen ara sayfa). Değeri, aynı olayı hangi yayınların yazdığını
göstermesi ve kümeyi büyütmesi.

**Bir kaynak düşerse koşu devam ediyor.** Tek bir yayının sitesi kapalı
diye o günün hiç haberi gelmemesi kabul edilemez.

## Uydurmaya karşı iki sert kural

İlk gerçek koşuda sistem **iki başlıktan tam bir haber uydurdu**. Modele
giden girdi şuydu — iki başlık, özet alanları boş:

```
"baslik": "Kastamonu'da otobüsün çarptığı yaya hayatını kaybetti"
"ozet"  : ""
```

Çıkan metinde şunlar vardı: *"Kuzeykent Mahallesi Alparslan Türkeş
Bulvarı"*, *"E.K. idaresindeki 37 M 0134 plakalı halk otobüsü"*,
*"akşam saatlerinde"*, *"70 yaşındaki M.K."*. **Hiçbiri girdide yoktu.**

Yönergede "kayıtlarda olmayan hiçbir şey ekleme" yazıyordu. Yetmedi: üç
kümeden ikisinde kurala uydu, birinde uydurdu. Yönergeye güvenmek
denetim değildir.

**1. Kaynak metni olmayan küme modele hiç gitmiyor.** Bir kümenin hiçbir
üyesinde 40 karakterden uzun özet yoksa koşu onu atlıyor. Yalnız
başlıktan haber yazmak uydurmaktan başka bir şey değil.

**2. Gövdedeki her sayı kaynak metinde geçmek zorunda.** Geçmiyorsa
haber reddediliyor. Sayılar bir haberin en somut ve en zararlı uydurma
noktası: plaka, yaş, ölü sayısı, saat.

İkincisinin bedeli açık: kaynak "iki kişi" yazıp model "2 kişi" yazarsa
haber reddedilir. Haber sisteminde doğru taraf bu — reddedilen haber
editöre düşer, uydurulmuş haber okura gider.

## Eksik bilinen

Ham kayıtlarda henüz kategori yok, bu yüzden kümelemenin **bölüm ailesi
koruması** burada çalışmıyor; ilçe koruması başlıktan ilçe adı
aranarak korunuyor. Ölçülen tuzak çift 0,45'te kalıyor ve 0,62 eşiği
onu zaten ayırıyor, ama bu eksiğin farkında olarak yazıldı.
