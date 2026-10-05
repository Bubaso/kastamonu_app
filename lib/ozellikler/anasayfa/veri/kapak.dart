import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cekirdek/bolum.dart';
import '../../../cekirdek/tercihler.dart';
import '../../inceleme/model/haber.dart';
import 'anasayfa_deposu.dart';

/// Ana sayfanın kat düzeni: hangi haberin nereye düştüğü.
///
/// Neden bu dosya var
/// ──────────────────
/// Akış uzun süre tek bir sıraydı: en yeni üstte, aşağı indikçe eskiye.
/// Ölçüldüğünde ortaya çıkan şey şuydu — portal her habere bir **önem**
/// skoru (3–8), bir katman, bir kategori ve güven skorlu ilçe bağları
/// üretiyor, panel hepsini gösteriyor, ana sayfa hiçbirini okumuyordu.
/// Manşeti seçen tek ölçüt zamandı.
///
/// Somut sonucu: manşette önem 3 olan bir haber duruyordu — listedeki en
/// düşük kademelerden biri — çünkü en son yayımlanan oydu. Önem 8 olan
/// haber akışın ortasında, aynı puntoda, aynı satırdaydı.
///
/// İkinci sonucu monotonluk. Yayındaki haberin %41'i asayiş ve kaza;
/// zamana göre dizilmiş tek bir sırada bu oran sayfanın tonunu tek başına
/// belirliyor ve kültür, tarım, eğitim haberleri aralarda kayboluyor.
///
/// Buradaki düzen aynı haberleri katlara dağıtıyor. Haber sayısı artmıyor,
/// hiyerarşi geliyor.
/// Anasayfadaki bir bölüm katı: başlık + o bölümün haberleri.
class BolumKati {
  const BolumKati({required this.ad, required this.slug, required this.haberler});

  final String ad;
  final String? slug;
  final List<Haber> haberler;
}

class Kapak {
  /// Ulusal gündem bölümünün adı.
  ///
  /// Kastamonulu da Türkiye'de yaşıyor: emekli aylığı, vergi, sınav
  /// takvimi onu da ilgilendiriyor. Ama bu haberler manşete ÇIKAMIYOR
  /// ve üst katların hiçbirine GİREMİYOR — girselerdi "emekliye zam"
  /// o günün Kastamonu haberini aşağı iter, portal şehir gazetesi
  /// olmaktan çıkıp ulusal portalin taşra baskısına dönerdi.
  ///
  /// Yeri sayfanın kendi bölümü, en altta, ve orada da sınırlı.
  static const ulusalBolum = 'Türkiye';

  /// Anasayfada gösterilen en çok ulusal haber.
  ///
  /// Ayar düğmesi bu. Büyütmek portalı ulusala kaydırır, küçültmek
  /// okurun işine yarayan haberi kaçırır.
  static const ulusalSiniri = 4;

  /// Lider haber. Liste boşsa null.
  final Haber? manset;

  /// Manşetin yanındaki ikincil başlıklar.
  final List<Haber> ikincil;

  /// Görselsiz, saat + başlık listesi.
  final List<Haber> kisaKisa;

  /// Okurun kendi ilçesinden. İlçe seçilmemişse boş.
  final List<Haber> ilcem;

  /// Gündem ve kent yönetimi ızgarası.
  final List<Haber> gundem;

  /// Asayiş ve kaza — koyu kuşakta, liste biçiminde.
  final List<Haber> asayis;

  /// Kültür, turizm, spor, ekonomi, tarım.
  final List<Haber> secme;

  /// Önemi yüksek ama birkaç günlük.
  final List<Haber> gozden;

  /// Katlara girmeyenler, BÖLÜME göre gruplanmış hâlde.
  ///
  /// Eskiden burası "Diğer haberler" başlıklı tek bir akıştı ve sayfanın
  /// sonunda tren gibi uzuyordu: aynı puntoda, aynı satırda, aynı küçük
  /// görselle onlarca haber. Haber sayısı arttıkça üst kısım donuyor,
  /// kuyruk uzuyordu.
  ///
  /// Artık her haber bir bölümün altına giriyor. "Diğer" diye bir yer
  /// yok; kategorisi olmayan haber de kendi adıyla anılıyor.
  final List<BolumKati> bolumler;

  const Kapak({
    required this.manset,
    required this.ikincil,
    required this.kisaKisa,
    required this.ilcem,
    required this.gundem,
    required this.asayis,
    required this.secme,
    required this.gozden,
    required this.bolumler,
  });

  static const bos = Kapak(
    manset: null,
    ikincil: [],
    kisaKisa: [],
    ilcem: [],
    gundem: [],
    asayis: [],
    secme: [],
    gozden: [],
    bolumler: [],
  );

  // ── Kat sınırları ────────────────────────────────────────────
  //
  // Bilerek dar. Portal ölçeğinde yayındaki toplam birkaç yüz haber;
  // katları genişletmek sayfayı yine tek bir uzun listeye çevirirdi.
  /// Manşetin yanındaki başlık sayısı.
  ///
  /// Beş, çünkü geniş ekranda yan sütun manşetin yüksekliğini doldurmak
  /// zorunda: üçle denendi ve sütunun altında manşet kadar boş beyaz
  /// kalıyordu. Telefonda ilk ikisi yan yana kart, gerisi satır.
  static const _ikincilAdedi = 5;
  static const _kisaKisaAdedi = 5;
  static const _ilcemAdedi = 3;
  static const _gundemAdedi = 3;
  static const _asayisAdedi = 4;
  static const _secmeAdedi = 3;
  static const _gozdenAdedi = 3;

  /// Hangi aile hangi kata ait.
  ///
  /// Gruplama `cekirdek/bolum.dart` içinde tek yerde duruyor: aynı liste
  /// hem burada hem kategori renklerinde yazılıydı ve ikisi birbirinden
  /// habersiz değişebiliyordu.
  static const _gundemAilesi = BolumAilesi.gundem;
  static const _asayisAilesi = BolumAilesi.asayis;
  static const _secmeAileleri = {
    BolumAilesi.uretim,
    BolumAilesi.toplum,
    BolumAilesi.yasam,
  };

  /// "Gözden kaçmasın" için en düşük yaş: bundan yenisi zaten yukarıda.
  static const _gozdenEnAzYas = Duration(days: 2);

  /// Üst blokta (manşet + ikincil) tek bir bölüm ailesinden gelebilecek en
  /// fazla haber.
  ///
  /// Bu sınır olmadan sayfanın en değerli yeri tek bir tona teslim oluyor.
  /// Gerçek veriyle ölçüldü: hat önem skorunu en çok asayiş ve kaza
  /// haberine veriyor (8, 7, 6, 6), dolayısıyla yalnız puana bakan bir üst
  /// blokta dört başlığın DÖRDÜ birden asayişti. Zamana göre sıralamanın
  /// ürettiği monotonluğun yerine önem sırasının ürettiği monotonluk
  /// geçmiş oluyordu.
  ///
  /// İki tane bilerek: bir olay gerçekten günün en önemlisiyse hem manşet
  /// hem yanındaki takip haberi onun olabilmeli. Üçüncüsü artık bölüm
  /// sayfasının işi.
  static const _ustBlokAileSiniri = 2;

  /// Düzeni kurar.
  ///
  /// Kural: her kat kendinden öncekinin ALMADIĞINDAN seçiyor ve her katın
  /// bir üst sınırı var. Böylece aynı haber sayfada iki kez görünemiyor ve
  /// "Asayiş" bütün havuzu yutup diğer katları boşaltamıyor. Artan haber
  /// sona, [kalan] akışına düşüyor — hiçbir şey kaybolmuyor.
  factory Kapak.kur(
    List<Haber> tumu, {
    String? ilcemId,
    DateTime? simdi,
  }) {
    if (tumu.isEmpty) return bos;
    final o = simdi ?? DateTime.now();
    final alinan = <String>{};

    // Ulusal gündem havuzun DIŞINDA tutuluyor: üst katların hiçbirine
    // giremiyor. Girseydi "emekliye zam" manşete çıkıp o günün
    // Kastamonu haberini aşağı iterdi ve portal şehir gazetesi olmaktan
    // çıkardı. Yeri sayfanın kendi bölümü, orada da sınırlı.
    final yerel = tumu.where((h) => h.kategoriAd != ulusalBolum).toList();
    final ulusalHaberler = tumu
        .where((h) => h.kategoriAd == ulusalBolum)
        .take(ulusalSiniri)
        .toList();

    /// Henüz alınmamış, koşula uyan ilk [adet] haber.
    ///
    /// [sira] verilmezse gelen sıra korunuyor — depo zaten yayın zamanına
    /// göre getiriyor, yani kat içinde en yeni üstte.
    List<Haber> al(
      int adet,
      bool Function(Haber) kosul, {
      Comparator<Haber>? sira,
    }) {
      if (adet <= 0) return const [];
      final adaylar = yerel
          .where((h) => !alinan.contains(h.id) && kosul(h))
          .toList();
      if (sira != null) adaylar.sort(sira);
      final secilen = adaylar.take(adet).toList();
      alinan.addAll(secilen.map((h) => h.id));
      return secilen;
    }

    // ── Üst blok: manşet + ikincil ──
    //
    // Puana göre, ama tek bölüm ailesi bloğu ele geçiremiyor. Önce sınırlı
    // bir geçiş yapılıyor; blok dolmazsa (örneğin yayında yalnızca asayiş
    // haberi varsa) sınır gevşetilip kalan yerler dolduruluyor, çünkü boş
    // bir manşet bloğu çeşitlilikten daha kötü.
    final ustHedef = 1 + _ikincilAdedi;
    final ustAdaylar = yerel.toList()
      ..sort((a, b) => puanKarsilastir(a, b, simdi: o));
    final ustBlok = <Haber>[];
    final aileSayisi = <BolumAilesi, int>{};

    void ustEkle(Haber h) {
      ustBlok.add(h);
      final aile = Bolum.aile(h.kategoriAd);
      aileSayisi[aile] = (aileSayisi[aile] ?? 0) + 1;
      alinan.add(h.id);
    }

    for (final h in ustAdaylar) {
      if (ustBlok.length >= ustHedef) break;
      if ((aileSayisi[Bolum.aile(h.kategoriAd)] ?? 0) >= _ustBlokAileSiniri) {
        continue;
      }
      ustEkle(h);
    }
    for (final h in ustAdaylar) {
      if (ustBlok.length >= ustHedef) break;
      if (alinan.contains(h.id)) continue;
      ustEkle(h);
    }

    final manset = ustBlok.firstOrNull;
    final ikincil = ustBlok.skip(1).toList();

    final kisaKisa = al(_kisaKisaAdedi, (_) => true);

    // İlçem: okur seçmemişse bu kat hiç çizilmiyor.
    final ilcem = ilcemId == null
        ? const <Haber>[]
        : al(
            _ilcemAdedi,
            (h) => h.ilceler.any((b) => b.onaylandi && b.ilceId == ilcemId),
          );

    final gundem = al(
      _gundemAdedi,
      (h) => Bolum.aile(h.kategoriAd) == _gundemAilesi,
    );

    final asayis = al(
      _asayisAdedi,
      (h) => Bolum.aile(h.kategoriAd) == _asayisAilesi,
    );

    final secme = al(
      _secmeAdedi,
      (h) => _secmeAileleri.contains(Bolum.aile(h.kategoriAd)),
    );

    // Gözden kaçmasın: birkaç günlük ama önemi yüksek olanlar. Önem sırası,
    // tazelik değil — zaten bu katın derdi tazelikten düşmüş haberi geri
    // getirmek.
    final gozden = al(
      _gozdenAdedi,
      (h) => o.difference(h.zaman) >= _gozdenEnAzYas,
      sira: (a, b) => b.onem.compareTo(a.onem),
    );

    // Katlara girmeyenler bölüme göre gruplanıyor. Tek bir "Diğer
    // haberler" akışı yok: her haber kendi bölümünün altında, ızgara
    // kartı olarak duruyor.
    final artan = yerel.where((h) => !alinan.contains(h.id)).toList();
    final gruplar = <String, List<Haber>>{};
    final sluglar = <String, String?>{};
    for (final h in artan) {
      final ad = (h.kategoriAd ?? '').trim().isEmpty ? 'Kastamonu' : h.kategoriAd!;
      gruplar.putIfAbsent(ad, () => []).add(h);
      sluglar[ad] = h.kategoriSlug;
    }
    final bolumler = gruplar.entries
        .map((e) => BolumKati(ad: e.key, slug: sluglar[e.key], haberler: e.value))
        // Kalabalık bölüm önce: okur en çok haberin olduğu yerde daha
        // uzun kalıyor ve sayfa yukarıdan aşağı seyrelerek bitiyor.
        .toList()
      ..sort((a, b) => b.haberler.length.compareTo(a.haberler.length));

    // Ulusal bölüm her zaman EN SONDA, yerel bölümlerin tamamının
    // altında. Sıralamaya katılsaydı kalabalık olduğu günlerde en üste
    // çıkabilirdi.
    if (ulusalHaberler.isNotEmpty) {
      bolumler.add(BolumKati(
        ad: ulusalBolum,
        slug: ulusalHaberler.first.kategoriSlug,
        haberler: ulusalHaberler,
      ));
    }

    return Kapak(
      manset: manset,
      ikincil: ikincil,
      kisaKisa: kisaKisa,
      ilcem: ilcem,
      gundem: gundem,
      asayis: asayis,
      secme: secme,
      gozden: gozden,
      bolumler: bolumler,
    );
  }

  /// Sayfada gösterilen hiçbir haber yoksa düzen çizilmiyor.
  bool get bosMu => manset == null;
}

// ── Skor ───────────────────────────────────────────────────────

/// Tazelik yarılanma süresi: haber bu kadar saat sonra ağırlığının yarısını
/// kaybediyor.
const _yariOmurSaat = 18.0;

/// Haberin kapaktaki ağırlığı: önem × tazelik.
///
/// Neden çarpım ve neden bu biçim
/// ──────────────────────────────
/// İki uç da yanlış. Yalnız zamana bakmak, az önce girilmiş önemsiz bir
/// haberi manşete çıkarıyor — bugün sayfada tam olarak bu var. Yalnız
/// öneme bakmak ise bir haftalık bir haberi günlerce manşette tutuyor.
///
/// Azalma `1 / (1 + yas/yariOmur)` biçiminde; üstel değil. Üstel azalma
/// birkaç günden sonra bütün skorları sıfıra yaklaştırıyor ve aralarındaki
/// sıra kayboluyor — hattın durduğu, yayındaki her şeyin on iki günlük
/// olduğu bir durumda tam olarak bu oluyordu. Bu biçimde sıra her zaman
/// korunuyor: her şey eşit yaştaysa karar öneme kalıyor, ki doğrusu bu.
///
/// Örnekler (önem / yaş → skor):
///   8 / 2 saat  → 7,2      3 / az önce → 3,0
///   8 / 1 gün   → 3,4      3 / 2 saat  → 2,7
///   6 / 2 gün   → 1,6      3 / 2 gün   → 0,8
double puan(Haber h, {DateTime? simdi}) {
  final yasSaat =
      (simdi ?? DateTime.now()).difference(h.zaman).inMinutes / 60.0;
  // Sunucu saati ileri kaymış kayıt tazelikten fazladan puan almıyor.
  final yas = yasSaat < 0 ? 0.0 : yasSaat;
  return h.onem / (1 + yas / _yariOmurSaat);
}

/// Büyük puan önce. Eşitlikte önem, sonra tazelik karar veriyor; böylece
/// sıralama her girdide aynı sonucu veriyor.
int puanKarsilastir(Haber a, Haber b, {DateTime? simdi}) {
  final f = puan(b, simdi: simdi).compareTo(puan(a, simdi: simdi));
  if (f != 0) return f;
  final onemFarki = b.onem.compareTo(a.onem);
  if (onemFarki != 0) return onemFarki;
  return b.zaman.compareTo(a.zaman);
}

/// Ana sayfanın kat düzeni.
///
/// `autoDispose` DEĞİL: sayfalar arası gezinirken yeniden hesaplanmasın.
final kapakSaglayici = Provider<Kapak>((ref) {
  final liste = ref.watch(tumYayindakilerSaglayici).asData?.value;
  if (liste == null) return Kapak.bos;
  final ilcem = ref.watch(ilcemSaglayici);
  return Kapak.kur(liste, ilcemId: ilcem?.id);
});
