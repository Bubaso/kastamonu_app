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
      if (k.bolumler.any((b) => b.haberler.any((h) => h.id == id))) 'bolum',
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
          k.bolumler.fold<int>(0, (t, b) => t + b.haberler.length);
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
        _h(onem: 8, kategori: 'Asayiş', id: 'a2'),
        _h(onem: 8, kategori: 'Kaza ve Acil', id: 'a3'),
        _h(onem: 8, kategori: 'Kaza ve Acil', id: 'a4'),
        _h(onem: 7, kategori: 'Asayiş', id: 'a5'),
        _h(onem: 7, kategori: 'Kaza ve Acil', id: 'a6'),
        _h(onem: 5, kategori: 'Spor', id: 's1'),
        _h(onem: 5, kategori: 'Tarım', id: 't1'),
        _h(onem: 4, kategori: 'Gündem', id: 'g1'),
        _h(onem: 4, kategori: 'Eğitim', id: 'e1'),
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
        for (var i = 0; i < 8; i++)
          _h(onem: 8 - (i % 5), yas: Duration(hours: i), kategori: 'Asayiş'),
      ];
      final k = Kapak.kur(liste, simdi: _simdi);
      expect(k.manset, isNotNull);
      expect(k.ikincil, hasLength(5));
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

    test('hiçbir haber "Diğer" başlığı altında kalmıyor', () {
      // Eskiden katlara girmeyenler tek bir "Diğer haberler" akışına
      // düşüyordu ve sayfanın sonunda tren gibi uzuyordu.
      final liste = List.generate(
        40,
        (i) => _h(onem: 3 + i % 5, id: 'h$i'),
      );
      final k = Kapak.kur(liste, simdi: _simdi);
      for (final b in k.bolumler) {
        expect(b.ad, isNot(contains('Diğer')));
        expect(b.ad.trim(), isNotEmpty);
        expect(b.haberler, isNotEmpty);
      }
    });

    test('bölümler kalabalıktan seyreğe sıralı', () {
      final liste = List.generate(40, (i) => _h(onem: 4, id: 'h$i'));
      final k = Kapak.kur(liste, simdi: _simdi);
      for (var i = 1; i < k.bolumler.length; i++) {
        expect(
          k.bolumler[i - 1].haberler.length,
          greaterThanOrEqualTo(k.bolumler[i].haberler.length),
        );
      }
    });

    test('boş liste düzeni düşürmüyor', () {
      final k = Kapak.kur(const [], simdi: _simdi);
      expect(k.bosMu, isTrue);
      expect(k.manset, isNull);
      expect(k.bolumler, isEmpty);
    });

    test('tek haber yalnızca manşete gidiyor', () {
      final k = Kapak.kur([_h(onem: 5, id: 'tek')], simdi: _simdi);
      expect(k.manset?.id, 'tek');
      expect(_katlar(k, 'tek'), ['manset']);
    });
  });

  _ulusalTestleri();
}

void _ulusalTestleri() {
  group('Ulusal gündem', () {
    Haber u(String id) => _h(onem: 8, id: id, kategori: 'Türkiye');

    test('manşete çıkamıyor', () {
      // Önemi en yüksek olsa bile: manşet Kastamonu haberinin yeri.
      final k = Kapak.kur([u('u1'), _h(onem: 3, id: 'y1')], simdi: _simdi);
      expect(k.manset?.id, 'y1');
    });

    test('üst katların hiçbirine girmiyor', () {
      final k = Kapak.kur(
        [u('u1'), u('u2'), for (var i = 0; i < 20; i++) _h(onem: 4, id: 'y$i')],
        simdi: _simdi,
      );
      final ust = [
        ...k.ikincil, ...k.kisaKisa, ...k.gundem,
        ...k.asayis, ...k.secme, ...k.gozden,
      ];
      expect(ust.where((h) => h.kategoriAd == 'Türkiye'), isEmpty);
    });

    test('kendi bölümünde ve en sonda', () {
      final k = Kapak.kur(
        [u('u1'), for (var i = 0; i < 20; i++) _h(onem: 4, id: 'y$i')],
        simdi: _simdi,
      );
      expect(k.bolumler.last.ad, 'Türkiye');
      expect(k.bolumler.last.haberler.single.id, 'u1');
    });

    test('sayısı sınırlı', () {
      final k = Kapak.kur(
        [for (var i = 0; i < 12; i++) u('u$i'), _h(onem: 4, id: 'y1')],
        simdi: _simdi,
      );
      final t = k.bolumler.firstWhere((b) => b.ad == 'Türkiye');
      expect(t.haberler.length, Kapak.ulusalSiniri);
    });
  });
}
