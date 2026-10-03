import 'package:flutter_test/flutter_test.dart';

import 'package:kastamonu_app/ozellikler/anasayfa/veri/kapak.dart';
import 'package:kastamonu_app/ozellikler/inceleme/model/haber.dart';

final _simdi = DateTime(2026, 10, 3, 10, 0);

int _sayac = 0;

Haber _h({
  required int onem,
  Duration yas = Duration.zero,
  String? kategori,
  List<String> ilceler = const [],
  String? id,
}) {
  final k = id ?? 'h${_sayac++}';
  return Haber(
    id: k,
    slug: k,
    baslik: 'Başlık $k',
    kaynakAdi: 'Kaynak',
    kaynakUrl: 'https://ornek/$k',
    katman: 1,
    onem: onem,
    diaspora: false,
    durum: 'yayinda',
    kategoriAd: kategori,
    olusturuldu: _simdi.subtract(yas),
    yayinlandi: _simdi.subtract(yas),
    ilceler: [
      for (final i in ilceler)
        IlceBagi(
          ilceId: i,
          ad: i,
          guven: 1,
          kaynak: 'model+sozluk',
          onaylandi: true,
        ),
    ],
  );
}

/// Bir haberin sayfada göründüğü bütün katlar.
List<String> _katlar(Kapak k, String id) => [
      if (k.manset?.id == id) 'manset',
      if (k.ikincil.any((h) => h.id == id)) 'ikincil',
      if (k.kisaKisa.any((h) => h.id == id)) 'kisaKisa',
      if (k.ilcem.any((h) => h.id == id)) 'ilcem',
      if (k.gundem.any((h) => h.id == id)) 'gundem',
      if (k.asayis.any((h) => h.id == id)) 'asayis',
      if (k.secme.any((h) => h.id == id)) 'secme',
      if (k.gozden.any((h) => h.id == id)) 'gozden',
      if (k.kalan.any((h) => h.id == id)) 'kalan',
    ];

void main() {
  group('Puan', () {
    test('önem ve tazelik birlikte karar veriyor', () {
      // Az önce girilmiş önemsiz haber, bir günlük önemli haberi geçemiyor —
      // sayfada tam olarak bu yanlış vardı.
      final tazeOnemsiz = _h(onem: 3);
      final eskiOnemli = _h(onem: 8, yas: const Duration(days: 1));
      expect(
        puan(eskiOnemli, simdi: _simdi),
        greaterThan(puan(tazeOnemsiz, simdi: _simdi)),
      );
    });

    test('eşit önemde taze olan kazanıyor', () {
      final taze = _h(onem: 5, yas: const Duration(hours: 1));
      final eski = _h(onem: 5, yas: const Duration(days: 2));
      expect(puan(taze, simdi: _simdi), greaterThan(puan(eski, simdi: _simdi)));
    });

    test('eşit yaşta önemli olan kazanıyor', () {
      final a = _h(onem: 8, yas: const Duration(days: 12));
      final b = _h(onem: 3, yas: const Duration(days: 12));
      expect(puan(a, simdi: _simdi), greaterThan(puan(b, simdi: _simdi)));
    });

    test('çok eski haberlerde sıra kaybolmuyor', () {
      // Üstel azalmada bütün skorlar sıfıra yaklaşıp sıra kayboluyordu;
      // hattın durduğu ve her şeyin on iki günlük olduğu durum tam buydu.
      final a = _h(onem: 8, yas: const Duration(days: 400));
      final b = _h(onem: 7, yas: const Duration(days: 400));
      expect(puan(a, simdi: _simdi), greaterThan(0));
      expect(puan(a, simdi: _simdi), greaterThan(puan(b, simdi: _simdi)));
    });

    test('sunucu saati ileri kaymış kayıt fazladan puan almıyor', () {
      final gelecek = _h(onem: 5, yas: const Duration(hours: -6));
      final simdiki = _h(onem: 5);
      expect(
        puan(gelecek, simdi: _simdi),
        equals(puan(simdiki, simdi: _simdi)),
      );
    });
  });

  group('Kapak tahsisi', () {
    test('manşeti zaman değil puan seçiyor', () {
      final liste = [
        _h(onem: 3, id: 'yeni-onemsiz'), // en taze
        _h(onem: 8, yas: const Duration(hours: 4), id: 'onemli'),
      ];
      final k = Kapak.kur(liste, simdi: _simdi);
      expect(k.manset?.id, 'onemli');
    });

    test('hiçbir haber iki katta birden görünmüyor', () {
      final liste = [
        for (var i = 0; i < 30; i++)
          _h(
            onem: 3 + (i % 6),
            yas: Duration(hours: i * 5),
            kategori: [
              'Gündem',
              'Asayiş',
              'Kaza ve Acil',
              'Tarım',
              'Kent ve Yönetim',
              'Spor',
            ][i % 6],
            ilceler: i.isEven ? const ['tasköprü'] : const [],
          ),
      ];
      final k = Kapak.kur(liste, ilcemId: 'tasköprü', simdi: _simdi);
      for (final h in liste) {
        expect(
          _katlar(k, h.id),
          hasLength(1),
          reason: '${h.id} birden fazla katta ya da hiçbirinde',
        );
      }
    });

    test('hiçbir haber kaybolmuyor', () {
      final liste = [
        for (var i = 0; i < 25; i++)
          _h(onem: 4, yas: Duration(hours: i), kategori: 'Gündem'),
      ];
      final k = Kapak.kur(liste, simdi: _simdi);
      final toplam = 1 +
          k.ikincil.length +
          k.kisaKisa.length +
          k.ilcem.length +
          k.gundem.length +
          k.asayis.length +
          k.secme.length +
          k.gozden.length +
          k.kalan.length;
      expect(toplam, liste.length);
    });

    test('asayiş bütün havuzu yutamıyor', () {
      // Yayındaki haberin %41'i asayiş ve kaza; tek sırada bu oran sayfanın
      // tonunu tek başına belirliyordu.
      final liste = [
        for (var i = 0; i < 20; i++)
          _h(onem: 4, yas: Duration(hours: i), kategori: 'Asayiş'),
        for (var i = 0; i < 4; i++)
          _h(onem: 4, yas: Duration(hours: 30 + i), kategori: 'Tarım'),
      ];
      final k = Kapak.kur(liste, simdi: _simdi);
      expect(k.asayis, hasLength(lessThanOrEqualTo(4)));
      expect(k.secme, isNotEmpty, reason: 'tarım haberleri elenmemeli');
    });

    test('üst blok tek bölüm tonuna teslim olmuyor', () {
      // Gerçek veriyle ölçüldü: hat önem skorunu en çok asayiş ve kazaya
      // veriyor, dolayısıyla yalnız puana bakan bir üst blokta dört
      // başlığın dördü de asayiş oluyordu.
      final liste = [
        _h(onem: 8, kategori: 'Asayiş', id: 'a1'),
        _h(onem: 7, kategori: 'Asayiş', id: 'a2'),
        _h(onem: 7, kategori: 'Kaza ve Acil', id: 'a3'),
        _h(onem: 6, kategori: 'Kaza ve Acil', id: 'a4'),
        _h(onem: 5, kategori: 'Spor', id: 's1'),
        _h(onem: 4, kategori: 'Tarım', id: 't1'),
      ];
      final k = Kapak.kur(liste, simdi: _simdi);
      final ust = [k.manset!, ...k.ikincil];
      final asayisAdedi = ust
          .where((h) => h.kategoriAd == 'Asayiş' || h.kategoriAd == 'Kaza ve Acil')
          .length;
      expect(asayisAdedi, lessThanOrEqualTo(2));
      expect(ust.map((h) => h.id), contains('s1'));
      // Lider yine de en yüksek puanlı haber — kural çeşitlilik getiriyor,
      // manşeti elinden almıyor.
      expect(k.manset!.id, 'a1');
    });

    test('yalnızca tek bölüm varsa üst blok yine de doluyor', () {
      // Çeşitlilik kuralı boş bir manşet bloğuna yol açmamalı.
      final liste = [
        for (var i = 0; i < 6; i++)
          _h(onem: 8 - i, yas: Duration(hours: i), kategori: 'Asayiş'),
      ];
      final k = Kapak.kur(liste, simdi: _simdi);
      expect(k.manset, isNotNull);
      expect(k.ikincil, hasLength(3));
    });

    test('ilçe seçilmemişse ilçem katı boş', () {
      final liste = [
        for (var i = 0; i < 10; i++)
          _h(onem: 4, yas: Duration(hours: i), ilceler: const ['tasköprü']),
      ];
      expect(Kapak.kur(liste, simdi: _simdi).ilcem, isEmpty);
    });

    test('ilçem katı yalnızca onaylı bağı olan haberi alıyor', () {
      final liste = [
        _h(onem: 4, ilceler: const ['tasköprü'], id: 'bizim'),
        _h(onem: 4, yas: const Duration(hours: 1), ilceler: const ['tosya']),
        _h(onem: 4, yas: const Duration(hours: 2)),
      ];
      final k = Kapak.kur(liste, ilcemId: 'tasköprü', simdi: _simdi);
      // 'bizim' manşete ya da ikincile gitmiş olabilir; ilçem katına düşen
      // her şeyin bağı doğru olmalı.
      for (final h in k.ilcem) {
        expect(h.ilceler.any((b) => b.ilceId == 'tasköprü'), isTrue);
      }
    });

    test('gözden kaçmasın katı taze haberi almıyor', () {
      final liste = [
        for (var i = 0; i < 12; i++)
          _h(onem: 5, yas: Duration(hours: i), kategori: 'Gündem'),
        _h(onem: 8, yas: const Duration(days: 5), id: 'eski-onemli'),
      ];
      final k = Kapak.kur(liste, simdi: _simdi);
      for (final h in k.gozden) {
        expect(
          _simdi.difference(h.zaman),
          greaterThanOrEqualTo(const Duration(days: 2)),
        );
      }
    });

    test('boş liste düzeni düşürmüyor', () {
      final k = Kapak.kur(const [], simdi: _simdi);
      expect(k.bosMu, isTrue);
      expect(k.manset, isNull);
      expect(k.kalan, isEmpty);
    });

    test('tek haber yalnızca manşete gidiyor', () {
      final k = Kapak.kur([_h(onem: 5, id: 'tek')], simdi: _simdi);
      expect(k.manset?.id, 'tek');
      expect(_katlar(k, 'tek'), ['manset']);
    });
  });
}
