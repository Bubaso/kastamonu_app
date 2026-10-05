import 'package:flutter_test/flutter_test.dart';

import 'package:kastamonu_app/ozellikler/doviz/veri/doviz.dart';

Map<String, dynamic> _ham({
  Object? tarih = '2026-10-02',
  List<Map<String, dynamic>>? kurlar,
}) =>
    {
      'tarih': tarih,
      'kaynak': 'TCMB',
      'kurlar': kurlar ??
          [
            {'kod': 'USD', 'ad': 'Dolar', 'birim': 1, 'alis': 48.9699, 'satis': 49.0582},
            {'kod': 'EUR', 'ad': 'Euro', 'birim': 1, 'alis': 55.0826, 'satis': 55.1819},
          ],
    };

void main() {
  group('Döviz çözümleme', () {
    test('bülten modele dönüyor', () {
      final d = Doviz.jsondan(_ham());
      expect(d.tarih, DateTime(2026, 10, 2));
      expect(d.kaynak, 'TCMB');
      expect(d.kurlar, hasLength(2));
      expect(d.kurlar.first.kod, 'USD');
      expect(d.kurlar.first.satis, closeTo(49.0582, 1e-9));
      expect(d.gosterilebilir, isTrue);
    });

    test('TARİHSİZ bülten gösterilmiyor', () {
      // TCMB yalnız iş günleri yayımlıyor; hafta sonu gelen sayı
      // önceki iş gününe ait. Tarihi basamıyorsak kuru da basmamalıyız,
      // yoksa okur "şu an böyle" sanır.
      expect(Doviz.jsondan(_ham(tarih: null)).gosterilebilir, isFalse);
      expect(Doviz.jsondan(_ham(tarih: 'çerçöp')).gosterilebilir, isFalse);
    });

    test('kuru olmayan bülten gösterilmiyor', () {
      expect(Doviz.jsondan(_ham(kurlar: [])).gosterilebilir, isFalse);
    });

    test('satışı olmayan birim listeye girmiyor', () {
      // TCMB bazı birimlerin (XDR) alış/satışını boş bırakıyor.
      final d = Doviz.jsondan(_ham(kurlar: [
        {'kod': 'USD', 'ad': 'Dolar', 'birim': 1, 'alis': 48.9, 'satis': 49.0},
        {'kod': 'XDR', 'ad': 'SDR', 'birim': 1, 'alis': null, 'satis': null},
      ]));
      expect(d.kurlar.map((k) => k.kod), ['USD']);
    });

    test('kodsuz kayıt atılıyor', () {
      final d = Doviz.jsondan(_ham(kurlar: [
        {'ad': 'Bilinmeyen', 'satis': 10.0},
        {'kod': 'USD', 'ad': 'Dolar', 'birim': 1, 'satis': 49.0},
      ]));
      expect(d.kurlar.map((k) => k.kod), ['USD']);
    });

    test('sayı metin olarak gelse de okunuyor', () {
      final d = Doviz.jsondan(_ham(kurlar: [
        {'kod': 'USD', 'ad': 'Dolar', 'birim': '1', 'alis': '48.97', 'satis': '49.06'},
      ]));
      expect(d.kurlar.single.satis, closeTo(49.06, 1e-9));
      expect(d.kurlar.single.birim, 1);
    });
  });
}
