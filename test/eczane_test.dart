import 'package:flutter_test/flutter_test.dart';

import 'package:kastamonu_app/ozellikler/eczane/veri/eczane.dart';

Map<String, dynamic> _e({
  Object? ad = 'DOĞA ECZANESİ',
  Object? ilce = 'MERKEZ',
  Object? adres = 'ESKİ FİZİK TEDAVİ HASTANESİ KARŞISI',
  Object? tel = '03662142303',
  Object? enlem = 41.385459,
  Object? boylam = 33.783699,
}) =>
    {
      'ad': ad,
      'ilce': ilce,
      'adres': adres,
      'telefon': tel,
      'enlem': enlem,
      'boylam': boylam,
    };

Map<String, dynamic> _n({
  Object? tarih = '2026-10-05',
  bool guncel = true,
  List<Map<String, dynamic>>? eczaneler,
}) =>
    {
      'tarih': tarih,
      'guncel': guncel,
      'kaynak': 'Kastamonu Eczacı Odası',
      'kaynakAdres': 'https://www.kastamonueo.org.tr/nobetci-eczaneler/37',
      'eczaneler': eczaneler ?? [_e()],
    };

void main() {
  group('Nöbet çözümleme', () {
    test('liste modele dönüyor', () {
      final n = Nobet.jsondan(_n());
      expect(n.guncel, isTrue);
      expect(n.tarih, DateTime(2026, 10, 5));
      expect(n.eczaneler, hasLength(1));
      expect(n.eczaneler.single.ad, 'DOĞA ECZANESİ');
      expect(n.gosterilebilir, isTrue);
    });

    test('GÜNCEL DEĞİLSE gösterilmiyor', () {
      // En önemli kural: eski nöbet listesi insanı gece yarısı kapalı
      // eczaneye gönderir.
      expect(Nobet.jsondan(_n(guncel: false)).gosterilebilir, isFalse);
    });

    test('tarihsiz liste gösterilmiyor', () {
      expect(Nobet.jsondan(_n(tarih: null)).gosterilebilir, isFalse);
      expect(Nobet.jsondan(_n(tarih: 'çerçöp')).gosterilebilir, isFalse);
    });

    test('boş liste gösterilmiyor', () {
      expect(Nobet.jsondan(_n(eczaneler: [])).gosterilebilir, isFalse);
    });

    test('adresi ya da telefonu eksik kayıt atılıyor', () {
      final n = Nobet.jsondan(_n(eczaneler: [
        _e(),
        _e(ad: 'ADRESSİZ', adres: ''),
        _e(ad: 'TELEFONSUZ', tel: null),
        _e(ad: ''),
      ]));
      expect(n.eczaneler.map((e) => e.ad), ['DOĞA ECZANESİ']);
    });

    test('konumsuz eczane kalıyor, harita bağlantısı null', () {
      final n = Nobet.jsondan(_n(eczaneler: [_e(enlem: null, boylam: null)]));
      expect(n.eczaneler, hasLength(1));
      expect(n.eczaneler.single.harita, isNull);
    });

    test('harita bağlantısı koordinatı taşıyor', () {
      final e = Nobet.jsondan(_n()).eczaneler.single;
      expect(e.harita.toString(), contains('41.385459,33.783699'));
    });

    test('telefon okunur biçime giriyor', () {
      expect(Nobet.jsondan(_n()).eczaneler.single.telefonGosterim,
          '0366 214 23 03');
    });

    test('beklenmedik uzunluktaki telefon olduğu gibi kalıyor', () {
      final e = Nobet.jsondan(_n(eczaneler: [_e(tel: '112')])).eczaneler.single;
      expect(e.telefonGosterim, '112');
    });

    test('okurun ilçesi listenin başına geçiyor', () {
      final n = Nobet.jsondan(_n(eczaneler: [
        _e(ad: 'MERKEZ ECZ', ilce: 'MERKEZ'),
        _e(ad: 'TOSYA ECZ', ilce: 'TOSYA'),
        _e(ad: 'CİDE ECZ', ilce: 'CİDE'),
      ]));
      expect(n.siraliListe('Tosya').map((e) => e.ad).first, 'TOSYA ECZ');
      expect(n.siraliListe('Tosya'), hasLength(3), reason: 'hiçbiri düşmemeli');
    });

    test('ilçe seçilmemişse sıra korunuyor', () {
      final n = Nobet.jsondan(_n(eczaneler: [
        _e(ad: 'BİR', ilce: 'MERKEZ'),
        _e(ad: 'İKİ', ilce: 'TOSYA'),
      ]));
      expect(n.siraliListe(null).map((e) => e.ad), ['BİR', 'İKİ']);
    });

    test('Türkçe büyük harf eşleşmesi doğru', () {
      // "İnebolu" → "İNEBOLU"; İngilizce büyütme "INEBOLU" üretir ve
      // eşleşme kaçar.
      final n = Nobet.jsondan(_n(eczaneler: [
        _e(ad: 'MERKEZ ECZ', ilce: 'MERKEZ'),
        _e(ad: 'İNEBOLU ECZ', ilce: 'İNEBOLU'),
      ]));
      expect(n.siraliListe('İnebolu').first.ad, 'İNEBOLU ECZ');
    });
  });
}
