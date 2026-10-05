/// Nöbetçi eczaneler.
///
/// EN RİSKLİ GADGET BU
/// ───────────────────
/// Kaynağın resmî API'si yok; Kastamonu Eczacı Odası'nın sayfası
/// ayrıştırılıyor (bkz. `functions/eczane.js`). Yanlış bilgi burada
/// gerçekten zarar veriyor: insan gece yarısı kapalı eczaneye gidiyor.
///
/// Tasarım "şüphe varsa gösterme" üzerine kurulu. Sunucu sayfadaki
/// başlık tarihini okuyup bugünle karşılaştırıyor; tutmazsa liste boş
/// geliyor. Burada da [Nobet.gosterilebilir] aynı kuralı tekrarlıyor:
/// güncel değilse ya da liste boşsa hiçbir şey çizilmiyor.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

@immutable
class Eczane {
  const Eczane({
    required this.ad,
    required this.ilce,
    required this.adres,
    required this.telefon,
    required this.enlem,
    required this.boylam,
  });

  final String ad;
  final String? ilce;
  final String adres;
  final String telefon;
  final double? enlem;
  final double? boylam;

  /// Harita bağlantısı — konum yoksa null.
  Uri? get harita => (enlem == null || boylam == null)
      ? null
      : Uri.parse(
          'https://www.google.com/maps/search/?api=1'
          '&query=$enlem,$boylam',
        );

  Uri get arama => Uri.parse('tel:$telefon');

  /// Telefonu okunur biçime getiriyor: 03662142303 → 0366 214 23 03.
  String get telefonGosterim {
    final d = telefon.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length != 11) return telefon;
    return '${d.substring(0, 4)} ${d.substring(4, 7)} '
        '${d.substring(7, 9)} ${d.substring(9)}';
  }

  static Eczane? jsondan(Map<String, dynamic> j) {
    final ad = (j['ad'] as String?)?.trim();
    final adres = (j['adres'] as String?)?.trim();
    final tel = (j['telefon'] as String?)?.trim();
    // Üçü de zorunlu: yarım kayıt okuru yanlış yere gönderir.
    if (ad == null || ad.isEmpty) return null;
    if (adres == null || adres.isEmpty) return null;
    if (tel == null || tel.isEmpty) return null;
    return Eczane(
      ad: ad,
      ilce: (j['ilce'] as String?)?.trim(),
      adres: adres,
      telefon: tel,
      enlem: _ondalik(j['enlem']),
      boylam: _ondalik(j['boylam']),
    );
  }
}

@immutable
class Nobet {
  const Nobet({
    required this.tarih,
    required this.guncel,
    required this.eczaneler,
    required this.kaynak,
    required this.kaynakAdres,
  });

  final DateTime? tarih;
  final bool guncel;
  final List<Eczane> eczaneler;
  final String kaynak;
  final Uri? kaynakAdres;

  /// Güncel olmayan nöbet listesi GÖSTERİLMİYOR.
  bool get gosterilebilir => guncel && tarih != null && eczaneler.isNotEmpty;

  /// Okurun ilçesindekiler önce, sonra ötekiler.
  List<Eczane> siraliListe(String? ilcem) {
    if (ilcem == null) return eczaneler;
    final hedef = ilcem.toLocaleUpperCase();
    final onde = <Eczane>[], arkada = <Eczane>[];
    for (final e in eczaneler) {
      ((e.ilce ?? '').toLocaleUpperCase() == hedef ? onde : arkada).add(e);
    }
    return [...onde, ...arkada];
  }

  static Nobet jsondan(Map<String, dynamic> j) => Nobet(
    tarih: DateTime.tryParse(j['tarih'] as String? ?? ''),
    guncel: j['guncel'] == true,
    eczaneler: ((j['eczaneler'] as List?) ?? const [])
        .map((e) => Eczane.jsondan((e as Map).cast<String, dynamic>()))
        .whereType<Eczane>()
        .toList(),
    kaynak: j['kaynak'] as String? ?? '',
    kaynakAdres: Uri.tryParse(j['kaynakAdres'] as String? ?? ''),
  );
}

double? _ondalik(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

/// Türkçe büyük harf: `i` → `İ`, `ı` → `I`.
extension _TrBuyuk on String {
  String toLocaleUpperCase() =>
      replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
}

const eczaneTabani = String.fromEnvironment('ECZANE_TABANI');

final nobetSaglayici = FutureProvider<Nobet?>((ref) async {
  if (eczaneTabani.isEmpty) return null;
  final y = await http
      .get(Uri.parse(eczaneTabani))
      .timeout(const Duration(seconds: 8));
  if (y.statusCode != 200) return null;
  final govde = jsonDecode(utf8.decode(y.bodyBytes));
  if (govde is! Map) return null;
  final n = Nobet.jsondan(govde.cast<String, dynamic>());
  return n.gosterilebilir ? n : null;
});
