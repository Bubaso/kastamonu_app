import '../../../cekirdek/bolum.dart';
import '../../../cekirdek/metin.dart';
import '../../inceleme/model/haber.dart';

/// Aynı olayı anlatan kayıtların tekilleştirilmesi.
///
/// Neden gerekli
/// ─────────────
/// Hat aynı olayı iki ayrı kaynaktan alıp iki ayrı kayıt açabiliyor.
/// Hattın kendi tekilleştirmesi kaynak adresine bakıyor ve bu durumda
/// yakalamıyor, çünkü adresler gerçekten farklı — biri Haberler.com'dan,
/// öbürü Sondakika.com'dan.
///
/// Ölçümde yakalanan gerçek çift:
///
///     Daday'ın Bolatlar köyünde çıkan yangında samanlık kullanılamaz
///     hale geldi                                   (Sondakika, 21 Eyl)
///     Daday'ın Bolatlar köyünde çıkan yangında Yaşar Mıcık'a ait
///     samanlık kullanılamaz hale geldi            (Haberler.com, 20 Eyl)
///
/// Okur bunu akışta iki kez görüyordu.
///
/// Asıl çözüm hatta
/// ────────────────
/// Burası bir savunma, kök çözüm değil. Hat bu kuralı kendi tarafında
/// uygularsa ikinci kayıt hiç açılmaz ve inceleme masası da kalabalıkla
/// uğraşmaz. Buradaki eşikler o yüzden bilerek açıklanmış durumda:
/// aynısı hatta taşınabilsin.
///
/// Neden yalnız başlık benzerliği yetmiyor
/// ───────────────────────────────────────
/// Aynı ölçümde bir de şu çift vardı ve bunlar AYRI haberler:
///
///     Kastamonu'da 19 Eylül Gaziler Günü düzenlenen yürüyüş ve
///     törenlerle kutlandı                                    (merkez)
///     Tosya, Taşköprü ve Ağlı'da 19 Eylül Gaziler Günü törenlerle
///     kutlandı                                        (üç ilçe)
///
/// Başlık benzerliği 0,45. Ortak kelimelerin hepsi vesileye ait
/// ("19 Eylül Gaziler Günü törenlerle kutlandı"); ayıran şey yer. Yalnız
/// başlığa bakan bir kural bu ikisini birleştirir ve üç ilçenin haberini
/// yok eder — tekilleştirmenin yapabileceği en kötü hata bu.
///
/// Bu yüzden üç koşul birden aranıyor.

/// Başlıkta anlam taşımayan kelimeler.
///
/// Kısa olanlar zaten eleniyor; buradakiler üç harften uzun ama her
/// başlıkta geçebilen bağlaçlar.
const _duraklar = {
  'icin',
  'ile',
  'olarak',
  'sonra',
  'once',
  'kadar',
  'gibi',
  'daha',
  'ancak',
  'ayrica',
  'uzere',
};

/// Başlığın anlam taşıyan kelimeleri.
///
/// Türkçe sadeleştirmeden geçiyor ki "Taşköprü" ile "taskopru" aynı
/// kelime sayılsın.
Set<String> baslikKelimeleri(String baslik) => sadelestir(baslik)
    .split(RegExp(r'[^a-z0-9]+'))
    .where((k) => k.length > 2 && !_duraklar.contains(k))
    .toSet();

/// İki başlığın ortak kelime oranı (Jaccard), 0 ile 1 arasında.
double baslikBenzerligi(String a, String b) {
  final x = baslikKelimeleri(a);
  final y = baslikKelimeleri(b);
  if (x.isEmpty || y.isEmpty) return 0;
  return x.intersection(y).length / x.union(y).length;
}

/// Benzerlik eşiği.
///
/// Ölçülen iki çift arasında geniş bir boşluk var: gerçek tekrar 0,75,
/// tekrar olmayan 0,45. Eşik ortaya değil, yanlış birleştirmeye karşı
/// güvenli tarafa konuyor — bir tekrarı kaçırmak, iki ayrı haberi
/// birleştirmekten daha az zararlı.
const _benzerlikEsigi = 0.62;

/// Zaman penceresi — ve hangi zamana bakıldığı.
///
/// **`olusturuldu`, `yayinlandi` DEĞİL.** Bu ayrım kuralı ilk denemede
/// işlemez hale getirmişti: ölçülen çiftin iki kaydı bir gün arayla
/// DERLENMİŞ ama biri 21 Eylül'de, öbürü 3 Ekim'de YAYIMLANMIŞTI. Yayın
/// damgasına bakıldığında aradaki fark 12,5 gün çıkıyor ve gerçek tekrar
/// pencerenin dışında kalıyordu.
///
/// Doğrusu derleme anı: olay bir kez oluyor ve hat farklı kaynakların
/// raporlarını birbirine yakın zamanda alıyor. Yayımlamak ise editörün
/// sonradan verdiği ayrı bir karar — aynı olayın iki kaydını haftalarca
/// ayırabiliyor.
///
/// Yan faydası: bir yıl sonra benzer başlıklı bir dönem yazısı gelirse
/// derleme anları uzak olduğu için birleştirilmiyor.
const _pencere = Duration(days: 7);

/// Haberin onaylı ilçeleri.
Set<String> _ilceler(Haber h) =>
    h.ilceler.where((b) => b.onaylandi).map((b) => b.ilceId).toSet();

/// İki kayıt aynı olayı mı anlatıyor.
///
/// Üç koşul birden:
///
/// 1. **Yer uyuşuyor.** İlçe kümeleri kesişiyor, ya da ikisi de boş
///    (ikisi de il geneli). Boş bir küme dolu bir kümenin alt kümesi
///    SAYILMIYOR: "Kastamonu'da tören" ile "Tosya'da tören" ayrı
///    haberler ve tam olarak bu ayrım onları kurtarıyor.
/// 2. **Bölüm ailesi aynı.** Aynı olayı iki kaynak farklı kategoriye
///    koyabiliyor ama aile düzeyinde ayrışmıyorlar.
/// 3. **Başlık benzerliği eşiğin üstünde.**
///
/// Zaman penceresi dışındakiler bakılmadan eleniyor.
bool ayniOlay(Haber a, Haber b) {
  if (a.id == b.id) return false;

  final fark = a.olusturuldu.difference(b.olusturuldu).abs();
  if (fark > _pencere) return false;

  final ia = _ilceler(a);
  final ib = _ilceler(b);
  final yerUyuyor = (ia.isEmpty && ib.isEmpty) || ia.intersection(ib).isNotEmpty;
  if (!yerUyuyor) return false;

  if (Bolum.aile(a.kategoriAd) != Bolum.aile(b.kategoriAd)) return false;

  return baslikBenzerligi(a.baslik, b.baslik) >= _benzerlikEsigi;
}

/// Başlık farkının "bu başlık gerçekten daha bilgilendirici" sayılması
/// için gereken en az karakter.
///
/// Eşik olmadan tek karakterlik bir fark üç yüz karakterlik gövde farkını
/// deviriyor; başlık uzunluğu gürültülü bir ölçüt ve küçük farkları
/// anlamlı saymak yanlış. On karakter, kabaca bir ismin ya da yer
/// tamlamasının eklenmesi demek — ölçülen çiftte fark 18 karakterdi
/// (91'e 73: "Yaşar Mıcık'a ait").
const _baslikFarkEsigi = 10;

/// Aynı olayın kayıtlarından hangisi kalacak.
///
/// Sıra, okurun o bilgiyi nerede gördüğüne göre:
///
/// 1. **Gerçek fotoğraf.** Akışta en çok yer kaplayan şey.
/// 2. **Belirgin şekilde uzun başlık.** Başlık okurun tıklamadan önce
///    gördüğü tek şey; aynı olayın iki kaydından biri kimin, nerede,
///    kaç kişi olduğunu yazıyorsa akışta o durmalı. Yalnızca fark
///    [_baslikFarkEsigi] karakteri geçerse karar veriyor.
/// 3. **Gövde uzunluğu.** Tıklandıktan sonraki içerik.
/// 4. **Derleme anı.** Eşitlikte önce gelen.
///
/// Hattın "ilk gelen kalsın" refleksi okur için doğru değil — ikinci
/// kaynak çoğu zaman daha eksiksiz oluyor.
///
/// Ölçülen çiftte bu sıra kararı değiştiriyor: iki kaydın da fotoğrafı
/// var, gövde 571'e 532 (Sondakika önde) ama başlık 91'e 73 (Haberler.com
/// önde, "Yaşar Mıcık'a ait" diyen taraf). Başlık farkı 18 karakter, yani
/// eşiğin üstünde; akışta kalan kayıt artık sahibin adını yazan oluyor.
/// Gerçek veriyle doğrulandı.
int _ustunluk(Haber a, Haber b) {
  final fa = (a.gorselKaynak ?? '').isNotEmpty && (a.gorselUrl ?? '').isNotEmpty;
  final fb = (b.gorselKaynak ?? '').isNotEmpty && (b.gorselUrl ?? '').isNotEmpty;
  if (fa != fb) return fa ? -1 : 1;

  final ba = a.baslik.length;
  final bb = b.baslik.length;
  if ((ba - bb).abs() >= _baslikFarkEsigi) return bb.compareTo(ba);

  final ga = (a.govde ?? '').length;
  final gb = (b.govde ?? '').length;
  if (ga != gb) return gb.compareTo(ga);

  return a.olusturuldu.compareTo(b.olusturuldu);
}

/// Listeden aynı olayın fazladan kayıtlarını çıkarır.
///
/// Gelen sıra korunuyor: bu işlev neyin önce geleceğine karışmıyor,
/// yalnızca aynı olayın ikinci kaydını düşürüyor.
///
/// Düşen kayıt portaldan silinmiyor — kendi adresi çalışmaya devam
/// ediyor, yalnızca listede iki kez görünmüyor.
List<Haber> tekille(List<Haber> liste) {
  if (liste.length < 2) return liste;

  // Hangi kaydın hangi kümeye ait olduğu.
  final dusen = <String>{};

  for (var i = 0; i < liste.length; i++) {
    if (dusen.contains(liste[i].id)) continue;
    for (var j = i + 1; j < liste.length; j++) {
      if (dusen.contains(liste[j].id)) continue;
      if (!ayniOlay(liste[i], liste[j])) continue;
      // Üstün olan kalır; öbürü düşer.
      dusen.add(_ustunluk(liste[i], liste[j]) <= 0 ? liste[j].id : liste[i].id);
      if (dusen.contains(liste[i].id)) break;
    }
  }

  if (dusen.isEmpty) return liste;
  return liste.where((h) => !dusen.contains(h.id)).toList();
}
