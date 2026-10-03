import 'package:flutter_test/flutter_test.dart';

import 'package:kastamonu_app/cekirdek/metin.dart';
import 'package:kastamonu_app/ozellikler/arama/veri/arama_deposu.dart';
import 'package:kastamonu_app/ozellikler/inceleme/model/haber.dart';

int _s = 0;

Haber _h({
  required String baslik,
  String? spot,
  String? govde,
  String? kategori,
  List<String> ilceler = const [],
  Duration yas = Duration.zero,
}) {
  final k = 'h${_s++}';
  final an = DateTime(2026, 10, 3, 10).subtract(yas);
  return Haber(
    id: k,
    slug: k,
    baslik: baslik,
    spot: spot,
    govde: govde,
    kategoriAd: kategori,
    kaynakAdi: 'K',
    kaynakUrl: 'u',
    katman: 1,
    onem: 4,
    diaspora: false,
    durum: 'yayinda',
    olusturuldu: an,
    yayinlandi: an,
    ilceler: [
      for (final i in ilceler)
        IlceBagi(
          ilceId: i,
          ad: i,
          guven: 1,
          kaynak: 'editor',
          onaylandi: true,
        ),
    ],
  );
}

void main() {
  group('Sadeleştirme', () {
    test('aksansız yazan okur aksanlıyı buluyor', () {
      expect(sadelestir('Çocuk'), 'cocuk');
      expect(sadelestir('Taşköprü'), 'taskopru');
      expect(sadelestir('İhsangazi'), 'ihsangazi');
      expect(sadelestir('Ilgaz'), 'ilgaz');
      expect(sadelestir('IĞDIR'), 'igdir');
    });

    test('büyük-küçük I ayrımı sadeleşmeden sonra kayboluyor', () {
      // "Ilgaz" ve "ılgaz" aynı şeye düşmeli, yoksa okur hangisini
      // yazdığına göre farklı sonuç alıyor.
      expect(sadelestir('Ilgaz'), sadelestir('ılgaz'));
      expect(sadelestir('İnebolu'), sadelestir('inebolu'));
    });
  });

  group('Kelimeler', () {
    test('tek harflik parçalar atılıyor', () {
      expect(aramaKelimeleri('a ve tosya'), ['ve', 'tosya']);
      expect(aramaKelimeleri('   '), isEmpty);
    });

    test('noktalama ayraç sayılıyor', () {
      expect(aramaKelimeleri('tosya, kaza!'), ['tosya', 'kaza']);
    });
  });

  group('Arama', () {
    test('aksansız sorgu aksanlı haberi buluyor', () {
      final liste = [_h(baslik: 'Taşköprü\'de sarımsak hasadı başladı')];
      expect(aramaSonuclari(liste, 'taskopru'), hasLength(1));
      expect(aramaSonuclari(liste, 'sarimsak'), hasLength(1));
    });

    test('kelimeler VE ile bağlı', () {
      final liste = [
        _h(baslik: 'Tosya\'da kaza', govde: 'ayrıntı'),
        _h(baslik: 'Tosya\'da festival', govde: 'ayrıntı'),
        _h(baslik: 'Daday\'da kaza', govde: 'ayrıntı'),
      ];
      // İkisini birden içeren tek haber
      final s = aramaSonuclari(liste, 'tosya kaza');
      expect(s, hasLength(1));
      expect(s.first.baslik, contains('Tosya'));
    });

    test('başlıkta geçen, gövdede geçenin üstünde', () {
      final liste = [
        _h(baslik: 'Alakasız başlık', govde: 'içinde sarımsak geçiyor'),
        _h(baslik: 'Sarımsak fiyatları yükseldi', govde: 'alakasız'),
      ];
      final s = aramaSonuclari(liste, 'sarimsak');
      expect(s, hasLength(2));
      expect(s.first.baslik, startsWith('Sarımsak'));
    });

    test('ilçe ve bölüm adı da aranıyor', () {
      final liste = [
        _h(baslik: 'Köyde yangın', ilceler: const ['Taşköprü']),
        _h(baslik: 'Başka haber', kategori: 'Spor'),
      ];
      expect(aramaSonuclari(liste, 'taskopru'), hasLength(1));
      expect(aramaSonuclari(liste, 'spor'), hasLength(1));
    });

    test('eşit uygunlukta taze olan önde', () {
      final liste = [
        _h(baslik: 'Kaza oldu', yas: const Duration(days: 3)),
        _h(baslik: 'Kaza oldu', yas: const Duration(hours: 1)),
      ];
      final s = aramaSonuclari(liste, 'kaza');
      expect(s.first.zaman.isAfter(s.last.zaman), isTrue);
    });

    test('boş ve tek harflik sorgu sonuç üretmiyor', () {
      final liste = [_h(baslik: 'Herhangi bir haber')];
      expect(aramaSonuclari(liste, ''), isEmpty);
      expect(aramaSonuclari(liste, 'a'), isEmpty);
      expect(aramaSonuclari(liste, '   '), isEmpty);
    });

    test('onaylanmamış ilçe bağı aramaya girmiyor', () {
      final h = Haber(
        id: 'x',
        slug: 'x',
        baslik: 'Başlık',
        kaynakAdi: 'K',
        kaynakUrl: 'u',
        katman: 1,
        onem: 4,
        diaspora: false,
        durum: 'yayinda',
        olusturuldu: DateTime(2026, 10, 3),
        ilceler: const [
          IlceBagi(
            ilceId: 'tk',
            ad: 'Taşköprü',
            guven: 0.3,
            kaynak: 'yalniz_model',
            onaylandi: false,
          ),
        ],
      );
      expect(aramaSonuclari([h], 'taskopru'), isEmpty);
    });
  });
}
