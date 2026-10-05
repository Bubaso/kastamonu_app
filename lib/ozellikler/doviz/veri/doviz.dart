/// Döviz kurları — TCMB.
///
/// Neden sunucudan
/// ───────────────
/// `/api/doviz` üzerinden geçiyor (bkz. `functions/doviz.js`). Yanıt
/// CDN'de yarım saat duruyor ve okurun tarayıcısı TCMB'ye bağlanmıyor.
///
/// TARİH ZORUNLU
/// ─────────────
/// TCMB günde bir kez ve yalnız iş günleri yayımlıyor. Hafta sonu ve
/// pazartesi öğleden önce gelen sayı önceki iş gününe ait — ölçüldü,
/// 5 Ekim Pazartesi sabahı 2 Ekim Cuma bülteni geliyordu. Bu yüzden
/// [Doviz.tarih] her zaman taşınıyor ve arayüz onu gösteriyor.
/// Tarihsiz kur, okura "şu an böyle" demektir ve yanlıştır.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Bir para biriminin kuru.
@immutable
class Kur {
  const Kur({
    required this.kod,
    required this.ad,
    required this.birim,
    required this.alis,
    required this.satis,
  });

  final String kod;
  final String ad;
  final int birim;
  final double? alis;
  final double? satis;

  static Kur? jsondan(Map<String, dynamic> j) {
    final kod = j['kod'] as String?;
    if (kod == null || kod.isEmpty) return null;
    final k = Kur(
      kod: kod,
      ad: j['ad'] as String? ?? kod,
      birim: _tam(j['birim']) ?? 1,
      alis: _ondalik(j['alis']),
      satis: _ondalik(j['satis']),
    );
    // Satışı olmayan birim şeritte yeri olmayan birimdir.
    return k.satis == null ? null : k;
  }
}

/// Bir bültenin tamamı.
@immutable
class Doviz {
  const Doviz({
    required this.tarih,
    required this.kurlar,
    required this.kaynak,
  });

  /// Bültenin tarihi. Okunamadıysa null — o durumda şerit çizilmiyor,
  /// çünkü tarihsiz kur yanıltıcı.
  final DateTime? tarih;
  final List<Kur> kurlar;
  final String kaynak;

  bool get gosterilebilir => tarih != null && kurlar.isNotEmpty;

  static Doviz jsondan(Map<String, dynamic> j) => Doviz(
        tarih: DateTime.tryParse(j['tarih'] as String? ?? ''),
        kurlar: ((j['kurlar'] as List?) ?? const [])
            .map((k) => Kur.jsondan((k as Map).cast<String, dynamic>()))
            .whereType<Kur>()
            .toList(),
        kaynak: j['kaynak'] as String? ?? 'TCMB',
      );
}

int? _tam(Object? v) {
  if (v == null) return null;
  if (v is num) return v.round();
  return int.tryParse(v.toString());
}

double? _ondalik(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

/// Uç noktanın tabanı. `--dart-define=DOVIZ_TABANI=/api/doviz`.
///
/// Boş bırakılırsa şerit çizilmiyor; yerelde (`flutter run`) Hosting
/// yönlendirmesi olmadığı için istenen davranış bu.
const dovizTabani = String.fromEnvironment('DOVIZ_TABANI');

final dovizSaglayici = FutureProvider<Doviz?>((ref) async {
  if (dovizTabani.isEmpty) return null;
  final y = await http
      .get(Uri.parse(dovizTabani))
      .timeout(const Duration(seconds: 8));
  if (y.statusCode != 200) return null;
  final govde = jsonDecode(utf8.decode(y.bodyBytes));
  if (govde is! Map) return null;
  final d = Doviz.jsondan(govde.cast<String, dynamic>());
  return d.gosterilebilir ? d : null;
});
