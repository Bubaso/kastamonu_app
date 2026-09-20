# Gömülü yazı tipleri

| Dosya | Aile | Ağırlık | Kullanım |
|---|---|---|---|
| Newsreader-Regular.ttf  | Newsreader | 400 | haber gövdesi |
| Newsreader-SemiBold.ttf | Newsreader | 600 | akış başlıkları |
| Newsreader-Bold.ttf     | Newsreader | 700 | manşet, künye |
| Archivo-Regular.ttf     | Archivo    | 400 | arayüz metni |
| Archivo-SemiBold.ttf    | Archivo    | 600 | sekme, düğme |
| Archivo-Bold.ttf        | Archivo    | 700 | bölüm etiketleri (versal) |

## Nasıl üretildi

Google Fonts'un değişken (variable) kaynaklarından `fontTools` ile:

1. `varLib.instancer` ile eksenler sabitlendi —
   Newsreader `opsz` 16/20/32 (optik boy, ağırlıkla birlikte büyüyor),
   Archivo `wdth=100`.
2. `subset` ile Türkçe kesitine indirildi: temel latin, latin-1 eki,
   Ğğ İı Şş, tipografik tırnak/tire, € ve ₺.

Ham değişken dosyalar 1,1 MB idi; altı kesit toplam **247 KB**.

## Neden gömülü, neden `google_fonts` değil

CanvasKit işletim sistemi yazı tiplerine erişemez — `fontFamily: 'Georgia'`
sessizce Roboto'ya düşer, hata vermez. Tarım Portalı bunu `google_fonts` ile
çalışma anında indirerek çözüyor; burada gömmeyi seçtik çünkü portal PWA
olarak çevrimdışı da doğru görünmeli ve üçüncü bir alan adına istek
gitmemeli.

**Dikkat:** Flutter Web, manifest'teki *her* fontu açılışta indiriyor.
Kullanılmayan kesit buraya konmaz.

## Lisans

Her iki aile de SIL Open Font License 1.1 — `OFL-Newsreader.txt`,
`OFL-Archivo.txt`. Değiştirilmiş kesitlerin dağıtımı serbest; lisans
dosyaları uygulamayla birlikte kalmalı.
