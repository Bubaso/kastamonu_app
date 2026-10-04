# Kümeleme ve sentez

Aynı olayı anlatan kayıtları birleştirip portalın kendi haberini yazar.

## Sorun

Hat birden çok kaynağı tarıyor ve aynı olayı birden çok kaynak yazıyor.
Bugün fazlalıklar **siliniyor** — beş kaynaktan gelen aynı kazanın dördü
çöpe gidiyor. Oysa her kaynak farklı ayrıntı taşıyor.

Yayındaki gerçek örnek, Daday'da bir samanlık yangını:

| | Haberler.com | Sondakika.com |
| --- | --- | --- |
| kim | Yaşar Mıcık, itfaiye, **orman ekipleri, jandarma** | Yaşar Mıcık |
| nasıl | **Köylülerin ihbarı** üzerine sevk | İhbar üzerine sevk |

Biri silinince yeşil yazılanlar kayboluyor.

## Ne yapıyor

Silmek yerine kümeliyor, sonra kümenin olgularından tek metin yazdırıyor.
Ölçülen kazanç: olgu metni **358 → 600 karakter (1,7×)**, dört alanın
dördünde kaynaklar birbirini tamamlıyor.

Çıkan metin portala ait oluyor, çünkü kaynak cümleleri kopyalanmıyor;
olgulardan yeniden yazılıyor. Künyede kümedeki bütün kaynaklar anılıyor.

## Dosyalar

| Dosya | Ne |
| --- | --- |
| `kumele.py` | Kümeleme. Bağımlılığı yok. |
| `sentez.py` | Metin yazımı ve denetimi. `anthropic` + `pydantic`. |
| `dene.py` | Yayındaki veriyle koşturur, hiçbir şey yazmaz. |
| `test_*.py` | 30 test. Model anahtarı gerekmiyor. |

```bash
python3 -m unittest discover -s hat -t .   # testler
python3 -m hat.dene                        # gerçek veriyle kümeleme
```

## Kararlar

**Çapa ve lider ayrı.** Çapa, benzerliğin ölçüldüğü kayıt — olaya ilk
giren, asla değişmez. Değişseydi geçmişte verilmiş eşleştirme kararları
tutarsızlaşırdı. Lider ise görselin ve başlığın devralındığı kayıt;
yeni üye geldikçe değişebiliyor.

**Yalnız çapaya bakılıyor, bütün üyelere değil.** A~B ve B~C olup A≁C
olabiliyor; zincir uzadıkça küme ilgisiz haberleri yutuyor. Çapa sabit
olunca küme kayamıyor ve karar açıklanabilir kalıyor.

**Elemeler eşikten önce.** İlçe kümeleri kesişmiyorsa ya da bölüm
ailesi farklıysa benzerliğe hiç bakılmıyor. Yanlış birleştirme,
kaçırılan tekrardan daha zararlı: "Kastamonu'da tören" ile "Tosya'da
tören" birleşirse üç ilçenin haberi yok oluyor.

**Derleme anına bakılıyor, yayın anına değil.** Aynı olayın iki kaydı
haftalarca ayrı yayımlanabiliyor; ölçülen çiftte fark 12,5 gündü.

**Çelişki çözülmüyor, işaretleniyor.** Kaynaklardan biri "3 yaralı"
öbürü "5 yaralı" diyorsa sentez seçim yapmıyor; `celiskiler` alanına
yazıp haberi editöre düşürüyor.

**Model çağrısı dışarıdan veriliyor.** `istek()` ve `dogrula()` saf
işlevler; testler anahtarsız koşuyor.

## Eşik ölçülmedi

`ESIK = 0.62` **ölçülmüş bir değer değil.** Yayındaki 60 kayıtla 0,50 ·
0,55 · 0,62 · 0,70 denendi, dördü de birebir aynı sonucu verdi: gerçek
tekrar 0,85'te, tekrar olmayan en yakın çift 0,45'te, arada geniş bir
ölü bölge var.

`ADAY_ESIGI` bunun için: eşiğin altında kalan yakın çiftler
birleştirilmiyor, "aynı olay mı?" diye işaretleniyor. Biriken cevaplar
eşiğin gerçek değerini ölçmenin tek yolu. Kaynak listesi her
genişlediğinde yeniden taranmalı.

## Buradan nereye

Bu modül hattın içine taşınmak üzere yazıldı — hat ayrı bir Python
işçisi ve asıl yer orası. Bağımlılıklar o yüzden dar tutuldu:
`kumele.py` yalnız standart kitaplıkla koşuyor.

`sadelestir()` ve bölüm aileleri `lib/cekirdek/metin.dart` ve
`lib/cekirdek/bolum.dart` ile **aynı** olmak zorunda. İkisi ayrışırsa
portal ile hat farklı şeyleri aynı sayar.
