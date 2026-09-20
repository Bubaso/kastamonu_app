import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Okurun cihazında saklanan tercihler.
///
/// Neden üyelik yok
/// ────────────────
/// Portalın okuru günde birkaç kez uğrayıp bakan biri; ondan hesap açmasını
/// istemek, verdiğimiz şeyle orantısız. İlçe seçimi, kaydedilen haberler ve
/// punto tercihi tarayıcıda duruyor. Sunucuya hiçbir şey gitmiyor, dolayısıyla
/// KVKK tarafında da taşıdığımız bir kişisel veri yok.
///
/// Bedeli açık: okur cihaz değiştirirse tercihleri gelmiyor. Bu, şu aşamada
/// üyelik sisteminin maliyetine değmez.
///
/// `SharedPreferences` açılışta bir kez okunuyor ve [tercihlerSaglayici]
/// üzerinden veriliyor; böylece arayüz tarafı tamamen eşzamanlı kalıyor
/// (her sekmede `FutureBuilder` beklemek gerekmiyor).
class Anahtar {
  static const ilcemId = 'ilcem_id';
  static const ilcemAd = 'ilcem_ad';
  static const kaydedilenler = 'kaydedilenler';
  static const punto = 'punto';
}

/// `main()` içinde gerçek örnekle geçersiz kılınıyor.
final tercihlerSaglayici = Provider<SharedPreferences>(
  (_) => throw StateError('tercihlerSaglayici main() içinde verilmeli'),
);

// ── İlçem ─────────────────────────────────────────────────────

/// Okurun kendi ilçesi. `null` = henüz seçmemiş.
typedef Ilcem = ({String id, String ad});

class IlcemNotifier extends Notifier<Ilcem?> {
  @override
  Ilcem? build() {
    final t = ref.watch(tercihlerSaglayici);
    final id = t.getString(Anahtar.ilcemId);
    final ad = t.getString(Anahtar.ilcemAd);
    if (id == null || ad == null) return null;
    return (id: id, ad: ad);
  }

  Future<void> sec(String id, String ad) async {
    final t = ref.read(tercihlerSaglayici);
    await t.setString(Anahtar.ilcemId, id);
    await t.setString(Anahtar.ilcemAd, ad);
    state = (id: id, ad: ad);
  }

  Future<void> temizle() async {
    final t = ref.read(tercihlerSaglayici);
    await t.remove(Anahtar.ilcemId);
    await t.remove(Anahtar.ilcemAd);
    state = null;
  }
}

final ilcemSaglayici = NotifierProvider<IlcemNotifier, Ilcem?>(
  IlcemNotifier.new,
);

// ── Kaydedilenler ─────────────────────────────────────────────

/// Kaydedilen haberlerin slug'ları, en son kaydedilen başta.
///
/// Slug saklanıyor, kimlik değil: slug adresin kendisi, yani kayıt
/// veritabanı şemasından bağımsız duruyor.
class KaydedilenlerNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    return ref.watch(tercihlerSaglayici).getStringList(Anahtar.kaydedilenler) ??
        const [];
  }

  bool kayitli(String slug) => state.contains(slug);

  /// Kayıtlıysa çıkarır, değilse başa ekler. Yeni durumu döner.
  Future<bool> degistir(String slug) async {
    final yeni = state.contains(slug)
        ? (state.where((s) => s != slug).toList())
        : ([slug, ...state]);
    await ref
        .read(tercihlerSaglayici)
        .setStringList(Anahtar.kaydedilenler, yeni);
    state = yeni;
    return yeni.contains(slug);
  }

  Future<void> hepsiniSil() async {
    await ref.read(tercihlerSaglayici).remove(Anahtar.kaydedilenler);
    state = const [];
  }
}

final kaydedilenlerSaglayici =
    NotifierProvider<KaydedilenlerNotifier, List<String>>(
      KaydedilenlerNotifier.new,
    );

// ── Punto ─────────────────────────────────────────────────────

/// Haber gövdesinin büyütme çarpanı.
///
/// Kastamonu'nun ortanca yaşı 43,3 ve 65 üstü oranı %21,1 — presbiyopi tam
/// bu yaşta başlıyor. Bu ayar erişilebilirlik eki değil, portalın ana
/// işlevlerinden biri; o yüzden haber sayfasında gizli bir menüde değil,
/// metnin hemen başında duruyor.
///
/// Üç kademe yeterli: daha fazlası kararı zorlaştırıyor, tarayıcının kendi
/// yakınlaştırması zaten ara değerleri veriyor.
enum Punto {
  normal(1.0, 'Normal'),
  buyuk(1.18, 'Büyük'),
  enBuyuk(1.38, 'En büyük');

  const Punto(this.carpan, this.ad);
  final double carpan;
  final String ad;
}

class PuntoNotifier extends Notifier<Punto> {
  @override
  Punto build() {
    final i = ref.watch(tercihlerSaglayici).getInt(Anahtar.punto) ?? 0;
    return Punto.values[i.clamp(0, Punto.values.length - 1)];
  }

  Future<void> sec(Punto p) async {
    await ref.read(tercihlerSaglayici).setInt(Anahtar.punto, p.index);
    state = p;
  }
}

final puntoSaglayici = NotifierProvider<PuntoNotifier, Punto>(
  PuntoNotifier.new,
);
