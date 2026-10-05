import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:kastamonu_app/ozellikler/hava/ekran/hava_seridi.dart';
import 'package:kastamonu_app/ozellikler/hava/veri/hava.dart';

Map<String, dynamic> _ham({
  Object? sicaklik = 18,
  Object? nem = 35,
  Object? ruzgar = 5,
  Object? yon = 'Kuzeydoğu',
  List<Map<String, dynamic>>? gunler,
}) =>
    {
      'ilce': 'Cide',
      'kaynak': 'Open-Meteo',
      'simdi': {
        'sicaklik': sicaklik,
        'hissedilen': 16,
        'nem': nem,
        'ruzgar': ruzgar,
        'ruzgarYonu': yon,
        'ad': 'Parçalı bulutlu',
        'simge': 'parcali-bulutlu',
      },
      'gunler': gunler ??
          [
            {
              'tarih': '2026-10-05',
              'enDusuk': 6,
              'enYuksek': 17,
              'ruzgar': 8,
              'yagisOlasiligi': 0,
              'ad': 'Parçalı bulutlu',
              'simge': 'parcali-bulutlu',
            },
            {
              'tarih': '2026-10-06',
              'enDusuk': -1,
              'enYuksek': 9,
              'ruzgar': 20,
              'yagisOlasiligi': 95,
              'ad': 'Yoğun kar',
              'simge': 'kar',
            },
          ],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting('tr');

  group('Hava çözümleme', () {
    test('sunucu yanıtı modele dönüyor', () {
      final h = Hava.jsondan(_ham());
      expect(h.ilce, 'Cide');
      expect(h.simdi.sicaklik, 18);
      expect(h.simdi.ruzgarYonu, 'Kuzeydoğu');
      expect(h.gunler, hasLength(2));
      expect(h.gunler[1].enDusuk, -1);
      expect(h.gunler[1].simge, 'kar');
      expect(h.gosterilebilir, isTrue);
    });

    test('sıcaklık yoksa şerit çizilmiyor', () {
      // Yer tutucu bir şerit, şeritsiz sayfadan kötü: okur boş bir
      // kutuya bakıyor ve sayfa bozuk görünüyor.
      final h = Hava.jsondan(_ham(sicaklik: null));
      expect(h.gosterilebilir, isFalse);
    });

    test('eksik alanlar çözümlemeyi düşürmüyor', () {
      final h = Hava.jsondan(_ham(nem: null, ruzgar: null, yon: null));
      expect(h.gosterilebilir, isTrue);
      expect(h.simdi.nem, isNull);
      expect(h.simdi.ruzgarYonu, isNull);
    });

    test('bozuk tarihli gün atılıyor, ötekiler kalıyor', () {
      final h = Hava.jsondan(_ham(gunler: [
        {'tarih': 'çerçöp', 'enDusuk': 1, 'enYuksek': 2, 'ad': 'x', 'simge': 'y'},
        {'tarih': '2026-10-06', 'enDusuk': 3, 'enYuksek': 4, 'ad': 'x', 'simge': 'y'},
      ]));
      expect(h.gunler, hasLength(1));
      expect(h.gunler.single.enYuksek, 4);
    });

    test('sayı metin olarak gelse de okunuyor', () {
      // PostgREST ve JSON sağlayıcıları sayıyı metin verebiliyor.
      final h = Hava.jsondan(_ham(sicaklik: '18', nem: '35'));
      expect(h.simdi.sicaklik, 18);
      expect(h.simdi.nem, 35);
    });
  });

  group('Gün adı', () {
    final simdi = DateTime(2026, 10, 5, 10);

    test('bugün ve yarın adlarıyla anılıyor', () {
      expect(gunAdi(DateTime(2026, 10, 5), simdi: simdi), 'BUGÜN');
      expect(gunAdi(DateTime(2026, 10, 6), simdi: simdi), 'YARIN');
    });

    test('sonraki günler kısa gün adı', () {
      expect(gunAdi(DateTime(2026, 10, 7), simdi: simdi), isNot('BUGÜN'));
      expect(gunAdi(DateTime(2026, 10, 7), simdi: simdi), isNotEmpty);
    });

    test('gün sınırı saate değil takvime bakıyor', () {
      // Gece 23:50'de bakan okur için 6 Ekim hâlâ "YARIN".
      final gec = DateTime(2026, 10, 5, 23, 50);
      expect(gunAdi(DateTime(2026, 10, 6), simdi: gec), 'YARIN');
    });
  });

  group('Hava simgesi', () {
    test('bilinen anahtarlar ikon veriyor', () {
      expect(havaSimgesi('kar'), Icons.ac_unit);
      expect(havaSimgesi('firtina'), Icons.thunderstorm_outlined);
    });

    test('bilinmeyen anahtar boş kutu bırakmıyor', () {
      // Sağlayıcı yeni bir hadise eklerse şerit yine çizilebilmeli.
      expect(havaSimgesi('bilinmiyor'), Icons.thermostat);
      expect(havaSimgesi('yepyeni-bir-sey'), Icons.thermostat);
    });
  });
}
