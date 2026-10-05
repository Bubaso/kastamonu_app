import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:kastamonu_app/ozellikler/anasayfa/ekran/anasayfa_ekrani.dart';
import 'package:kastamonu_app/ozellikler/anasayfa/veri/kapak.dart';
import 'package:kastamonu_app/ozellikler/inceleme/model/haber.dart';

/// Düzenin GENİŞLİK testleri.
///
/// Neden bu dosya var
/// ──────────────────
/// [Izgara] üç haberlik bloklar için yazılmıştı: bütün kartlar tek bir
/// `Row` içinde `Expanded` ile duruyordu. Sonra aynı bileşen kategori
/// bölümlerine bağlandı ve bir bölüm on dört haberle geldi. Satır bölmek
/// yerine on dördünü birden sıkıştırdı: her kart 52 piksel, 18 puntoluk
/// başlıklar harf harf alt alta. Sayfa okunamaz hâlde yayına çıktı.
///
/// Ekran görüntüsü almak bunu yakalamadı, çünkü bakılan kareler iki-üç
/// haberlik bölümlerdi. Yakalayan şey ölçüm: bir kart okunabilir
/// genişliğin altına düşerse test kırılıyor.
///
/// Diğer testler neyin NEREDE olduğunu doğruluyor; buradaki testler neyin
/// ne KADAR yer kapladığını.

/// İçeriğin ortalandığı genişlik (`_Orta`).
const _icerikGenisligi = 1080.0;

/// `Izgara` iç boşluğu: soldan ve sağdan 18.
const _izgaraBosluk = 36.0;

/// Sütun arası boşluk ve sütun sayısı.
const _ara = 24.0;
const _sutun = 3;

/// Üç sütun düzeninde bir kartın beklenen genişliği.
const _beklenenKart = (_icerikGenisligi - _izgaraBosluk - (_sutun - 1) * _ara) / _sutun;

/// 18 puntoluk serif bir başlığın kelime kelime sarılabildiği en az
/// genişlik. Bunun altında Türkçe başlıklar harf harf kırılıyor.
const _enAzKart = 220.0;

int _sayac = 0;

Haber _h({String? baslik, String kategori = 'Kaza ve Acil'}) {
  final k = 'h${_sayac++}';
  return Haber(
    id: k,
    slug: k,
    baslik: baslik ??
        'Kastamonu Taşköprü Akçakese köyünde çıkan orman yangını '
            'kontrol altına alındı',
    kaynakAdi: 'Haberler.com',
    kaynakUrl: 'https://ornek/$k',
    katman: 1,
    onem: 5,
    diaspora: false,
    durum: 'yayinda',
    kategoriAd: kategori,
    kategoriSlug: kategori.toLowerCase(),
    olusturuldu: DateTime.now().subtract(const Duration(hours: 4)),
    yayinlandi: DateTime.now().subtract(const Duration(hours: 4)),
    ilceler: const [],
  );
}

/// Verilen genişlikte bir ekran kurar. Yükseklik bol: kaydırma dışında
/// kalan kat kırpılmasın.
Future<void> _ekran(
  WidgetTester t,
  Widget cocuk, {
  required double genislik,
}) async {
  t.view.devicePixelRatio = 1.0;
  t.view.physicalSize = Size(genislik, 4000);
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: cocuk),
      ),
    ),
  );
}

/// Izgaradaki kartların genişlikleri. Her kartta tam bir [KartBasi] var,
/// genişliği kartın genişliği.
List<double> _kartGenislikleri(WidgetTester t) => t
    .widgetList(find.byType(KartBasi))
    .toList()
    .asMap()
    .keys
    .map((i) => t.getSize(find.byType(KartBasi).at(i)).width)
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting('tr');

  group('Izgara geniş ekranda', () {
    testWidgets('kalabalık bölümü satırlara bölüyor, tek satıra sıkmıyor',
        (t) async {
      // Yayına çıkan hata tam olarak buydu: on dört haber, tek satır.
      final haberler = [for (var i = 0; i < 14; i++) _h()];
      await _ekran(
        t,
        Izgara(baslik: 'Kaza ve Acil', haberler: haberler, genis: true, slug: 'kaza'),
        genislik: 1440,
      );

      final genislikler = _kartGenislikleri(t);
      expect(genislikler, hasLength(14));
      for (final g in genislikler) {
        expect(
          g,
          greaterThanOrEqualTo(_enAzKart),
          reason: 'kart $g piksel — başlık harf harf kırılır',
        );
        expect(g, closeTo(_beklenenKart, 1));
      }
    });

    testWidgets('eksik son satırda kart genişliği bozulmuyor', (t) async {
      // Dört haber: ikinci satırda tek kart var. Boş `Expanded`ler
      // olmasa o kart bütün satırı kaplar ve ızgara kayar.
      final haberler = [for (var i = 0; i < 4; i++) _h()];
      await _ekran(
        t,
        Izgara(baslik: 'Eğitim', haberler: haberler, genis: true, slug: 'egitim'),
        genislik: 1440,
      );

      final genislikler = _kartGenislikleri(t);
      expect(genislikler, hasLength(4));
      for (final g in genislikler) {
        expect(g, closeTo(_beklenenKart, 1));
      }
    });

    testWidgets('her satırda en çok üç kart var', (t) async {
      final haberler = [for (var i = 0; i < 7; i++) _h()];
      await _ekran(
        t,
        Izgara(baslik: 'Gündem', haberler: haberler, genis: true, slug: 'gundem'),
        genislik: 1440,
      );

      // Aynı dikey konumdaki kartlar bir satırda.
      final satirlar = <double, int>{};
      for (var i = 0; i < 7; i++) {
        final y = t.getTopLeft(find.byType(KartBasi).at(i)).dy;
        satirlar[y] = (satirlar[y] ?? 0) + 1;
      }
      expect(satirlar.length, 3, reason: '7 haber 3 satır olmalı');
      for (final adet in satirlar.values) {
        expect(adet, lessThanOrEqualTo(_sutun));
      }
    });

    testWidgets('bir ve iki haberlik bölüm de düzgün', (t) async {
      for (final adet in [1, 2]) {
        await _ekran(
          t,
          Izgara(
            baslik: 'Tarım',
            haberler: [for (var i = 0; i < adet; i++) _h()],
            genis: true,
            slug: 'tarim',
          ),
          genislik: 1440,
        );
        for (final g in _kartGenislikleri(t)) {
          expect(g, closeTo(_beklenenKart, 1), reason: '$adet haberde bozuldu');
        }
      }
    });
  });

  group('Izgara dar ekranda', () {
    testWidgets('telefonda kartlar yan yana dizilmiyor', (t) async {
      final haberler = [for (var i = 0; i < 10; i++) _h()];
      await _ekran(
        t,
        Izgara(baslik: 'Kaza ve Acil', haberler: haberler, genis: false, slug: 'kaza'),
        genislik: 390,
      );

      // Dar düzen: ilk haber Odak, gerisi Satir. Hiçbiri yan yana değil,
      // dolayısıyla taşma yok.
      expect(find.byType(Odak), findsOneWidget);
      expect(find.byType(Satir), findsNWidgets(9));

      // Her satır tek başına, ekran genişliğini aşmıyor.
      for (var i = 0; i < 9; i++) {
        final kutu = t.getRect(find.byType(Satir).at(i));
        expect(kutu.left, greaterThanOrEqualTo(0));
        expect(kutu.right, lessThanOrEqualTo(390));
      }
      for (var i = 1; i < 9; i++) {
        expect(
          t.getTopLeft(find.byType(Satir).at(i)).dy,
          greaterThan(t.getTopLeft(find.byType(Satir).at(i - 1)).dy),
          reason: 'dar ekranda satırlar alt alta olmalı',
        );
      }
    });
  });

  group('Kapak sınırı', () {
    test('bölüm katı ızgaranın taşıyabileceğinden fazlasını vermiyor', () {
      // Sınır ile ızgara birbirine bağlı: sınır büyürse ızgara satır
      // sayısı artar, ama kart genişliği sabit kalır. Yine de sınırın
      // sütun sayısının katı olması satırları dolu bırakıyor.
      expect(Kapak.bolumSiniri % _sutun, 0,
          reason: 'sınır sütun sayısının katı olmalı, yoksa son satır eksik');
    });
  });
}
