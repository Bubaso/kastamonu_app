/// Hava durumu verisi.
///
/// Neden sunucudan
/// ───────────────
/// Uygulama sağlayıcıya DOĞRUDAN bağlanmıyor; `/api/hava` üzerinden
/// geçiyor (bkz. `functions/hava.js`). Böylece yanıt CDN'de yarım saat
/// duruyor, okurun tarayıcısı üçüncü bir alan adına çıkmıyor ve
/// sağlayıcı değişse uygulama güncellenmiyor.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../cekirdek/tercihler.dart';

/// Bir günün tahmini.
@immutable
class HavaGunu {
  const HavaGunu({
    required this.tarih,
    required this.enDusuk,
    required this.enYuksek,
    required this.ruzgar,
    required this.yagisOlasiligi,
    required this.ad,
    required this.simge,
  });

  final DateTime tarih;
  final int? enDusuk;
  final int? enYuksek;
  final int? ruzgar;
  final int? yagisOlasiligi;
  final String ad;
  final String simge;

  static HavaGunu? jsondan(Map<String, dynamic> j) {
    final t = DateTime.tryParse(j['tarih'] as String? ?? '');
    if (t == null) return null;
    return HavaGunu(
      tarih: t,
      enDusuk: _tam(j['enDusuk']),
      enYuksek: _tam(j['enYuksek']),
      ruzgar: _tam(j['ruzgar']),
      yagisOlasiligi: _tam(j['yagisOlasiligi']),
      ad: j['ad'] as String? ?? '—',
      simge: j['simge'] as String? ?? 'bilinmiyor',
    );
  }
}

/// Şu anki durum.
@immutable
class HavaSimdi {
  const HavaSimdi({
    required this.sicaklik,
    required this.hissedilen,
    required this.nem,
    required this.ruzgar,
    required this.ruzgarYonu,
    required this.ad,
    required this.simge,
  });

  final int? sicaklik;
  final int? hissedilen;
  final int? nem;
  final int? ruzgar;
  final String? ruzgarYonu;
  final String ad;
  final String simge;

  static HavaSimdi jsondan(Map<String, dynamic> j) => HavaSimdi(
        sicaklik: _tam(j['sicaklik']),
        hissedilen: _tam(j['hissedilen']),
        nem: _tam(j['nem']),
        ruzgar: _tam(j['ruzgar']),
        ruzgarYonu: j['ruzgarYonu'] as String?,
        ad: j['ad'] as String? ?? '—',
        simge: j['simge'] as String? ?? 'bilinmiyor',
      );
}

/// Bir ilçenin hava durumu.
@immutable
class Hava {
  const Hava({
    required this.ilce,
    required this.simdi,
    required this.gunler,
    required this.kaynak,
  });

  final String ilce;
  final HavaSimdi simdi;
  final List<HavaGunu> gunler;
  final String kaynak;

  /// Şerit çizilebilir mi: sıcaklık yoksa gösterecek bir şey yok.
  bool get gosterilebilir => simdi.sicaklik != null;

  static Hava jsondan(Map<String, dynamic> j) => Hava(
        ilce: j['ilce'] as String? ?? 'Merkez',
        simdi: HavaSimdi.jsondan(
            (j['simdi'] as Map?)?.cast<String, dynamic>() ?? const {}),
        gunler: ((j['gunler'] as List?) ?? const [])
            .map((g) => HavaGunu.jsondan((g as Map).cast<String, dynamic>()))
            .whereType<HavaGunu>()
            .toList(),
        kaynak: j['kaynak'] as String? ?? '',
      );
}

/// `num` da `String` de gelebiliyor; ikisi de tam sayıya iniyor.
///
/// `null` ÖNCE eleniyor: sunucu tarafında aynı tuzak ölçüldü —
/// `Number(null)` sıfır olduğu için veri gelmediğinde hava "Açık",
/// rüzgar "Kuzey" görünüyordu.
int? _tam(Object? v) {
  if (v == null) return null;
  if (v is num) return v.round();
  return int.tryParse(v.toString());
}

/// Uç noktanın tabanı.
///
/// `--dart-define=HAVA_TABANI=/api/hava` ile veriliyor. Boş bırakılırsa
/// şerit hiç çizilmiyor ve bu YERELDE İSTENEN DAVRANIŞ: `flutter run`
/// ile çalışırken Hosting yönlendirmesi, dolayısıyla fonksiyon da yok.
const havaTabani = String.fromEnvironment('HAVA_TABANI');

/// Okurun ilçesinin hava durumu.
///
/// İlçe seçilmemişse Merkez. `autoDispose` DEĞİL: sayfalar arası
/// gezinirken her seferinde yeniden istek atılmasın.
final havaSaglayici = FutureProvider<Hava?>((ref) async {
  if (havaTabani.isEmpty) return null;
  final ilce = ref.watch(ilcemSaglayici)?.ad ?? 'Merkez';
  final adres = Uri.parse('$havaTabani?ilce=${Uri.encodeComponent(ilce)}');

  final y = await http.get(adres).timeout(const Duration(seconds: 8));
  if (y.statusCode != 200) return null;
  final govde = jsonDecode(utf8.decode(y.bodyBytes));
  if (govde is! Map) return null;
  final hava = Hava.jsondan(govde.cast<String, dynamic>());
  return hava.gosterilebilir ? hava : null;
});
