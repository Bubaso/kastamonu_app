/// İnceleme masasındaki bir haber kaydı.
class Haber {
  final String id;
  final String slug;
  final String baslik;
  final String? spot;
  final String? govde;
  final String? kategoriAd;
  final String? kategoriSlug;
  final String kaynakAdi;
  final String kaynakUrl;
  final String? yayinci;
  final int katman;
  final int onem;
  final bool diaspora;
  final String durum;
  final String? gorselUrl;
  final String? gorselKaynak;

  /// Hattın haberi derlediği an.
  final DateTime olusturuldu;

  /// Editörün yayına aldığı an. Damgayı tetikleyici koyuyor
  /// (migration 0002), yani yalnızca `durum='yayinda'` kayıtlarda dolu.
  /// Göçten önce yayına alınmış eski kayıtlarda boş kalabiliyor.
  final DateTime? yayinlandi;

  final List<IlceBagi> ilceler;

  const Haber({
    required this.id,
    required this.slug,
    required this.baslik,
    required this.kaynakAdi,
    required this.kaynakUrl,
    required this.katman,
    required this.onem,
    required this.diaspora,
    required this.durum,
    required this.olusturuldu,
    required this.ilceler,
    this.spot,
    this.govde,
    this.kategoriAd,
    this.kategoriSlug,
    this.yayinci,
    this.gorselUrl,
    this.gorselKaynak,
    this.yayinlandi,
  });

  /// Okura gösterilecek zaman damgası.
  ///
  /// Akış `yayinlandi` ile sıralanıyor; gösterimin de aynı damgaya düşmesi
  /// ZORUNLU. Önce `olusturuldu` yazılıyordu ve ikisi ayrışıyordu: iki gün
  /// önce derlenip bugün yayına alınan haber listenin en üstünde duruyor
  /// ama "2 gün önce" diyordu. Okur için haberin yaşı, onun önüne
  /// konulduğu andır.
  ///
  /// Göçten önceki kayıtlarda `yayinlandi` boş; orada derleme anına
  /// düşülüyor.
  DateTime get zaman => yayinlandi ?? olusturuldu;

  /// Künyede gösterilecek sade kaynak adı.
  ///
  /// Kaynak adları akış adından geliyor ve kategori eki taşıyor:
  /// "Haberler.com / Kastamonu", "Google News / Spor". Okur için o ek
  /// gürültü; ham ad veritabanında duruyor, gösterim sadeleştiriliyor.
  String get kaynakKisa {
    final ad = (yayinci?.isNotEmpty == true ? yayinci! : kaynakAdi).trim();
    final parca = ad.split('/').first.trim();
    return parca.isEmpty ? ad : parca;
  }

  /// İlçe bağlarından en az biri editör onayı bekliyorsa kart uyarı taşır.
  bool get bagOnayiBekliyor => ilceler.any((i) => !i.onaylandi);

  factory Haber.jsondan(Map<String, dynamic> j) {
    final kategori = j['kategoriler'];
    final baglar = (j['haber_ilce'] as List?) ?? const [];
    return Haber(
      id: j['id'] as String,
      slug: j['slug'] as String? ?? '',
      baslik: j['baslik'] as String? ?? '',
      spot: j['spot'] as String?,
      govde: j['govde'] as String?,
      kategoriAd: kategori is Map ? kategori['ad'] as String? : null,
      kategoriSlug: kategori is Map ? kategori['slug'] as String? : null,
      kaynakAdi: j['kaynak_adi'] as String? ?? '',
      kaynakUrl: j['kaynak_url'] as String? ?? '',
      yayinci: j['yayinci'] as String?,
      katman: (j['katman'] as num?)?.toInt() ?? 1,
      onem: (j['onem'] as num?)?.toInt() ?? 3,
      diaspora: j['diaspora'] as bool? ?? false,
      durum: j['durum'] as String? ?? 'inceleme',
      gorselUrl: j['gorsel_url'] as String?,
      gorselKaynak: j['gorsel_kaynak'] as String?,
      olusturuldu:
          DateTime.tryParse(j['olusturuldu'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      yayinlandi: DateTime.tryParse(
        j['yayinlandi'] as String? ?? '',
      )?.toLocal(),
      ilceler: baglar
          .map((b) => IlceBagi.jsondan(b as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Haber ile ilçe arasındaki bağ — güven skoru ve kaynağıyla birlikte.
///
/// `kaynak` alanı bağın nereden geldiğini söylüyor ve editörün en çok
/// ihtiyaç duyduğu bilgi bu: `model+sozluk` iki bağımsız yöntemin
/// mutabakatı, `yalniz_model` ise yalnızca modelin iddiası.
class IlceBagi {
  final String ilceId;
  final String ad;
  final double guven;
  final String kaynak;
  final bool onaylandi;

  /// İlçenin gösterim sırası (`ilceler.sira`). Gelmezse sona atılıyor.
  final int sira;

  const IlceBagi({
    required this.ilceId,
    required this.ad,
    required this.guven,
    required this.kaynak,
    required this.onaylandi,
    this.sira = 99,
  });

  bool get modelMutabakati => kaynak == 'model+sozluk';

  String get kaynakEtiketi => switch (kaynak) {
    'model+sozluk' => 'model + sözlük',
    'sozluk' => 'sözlük',
    'yalniz_model' => 'yalnız model',
    'editor' => 'editör',
    _ => kaynak,
  };

  factory IlceBagi.jsondan(Map<String, dynamic> j) {
    final ilce = j['ilceler'];
    return IlceBagi(
      ilceId: j['ilce_id'] as String,
      ad: ilce is Map ? (ilce['ad'] as String? ?? '?') : '?',
      guven: (j['guven'] as num?)?.toDouble() ?? 0,
      kaynak: j['kaynak'] as String? ?? '',
      onaylandi: j['onaylandi'] as bool? ?? false,
      sira: ilce is Map ? ((ilce['sira'] as num?)?.toInt() ?? 99) : 99,
    );
  }
}
