import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:kastamonu_app/ozellikler/anasayfa/ekran/anasayfa_ekrani.dart';
import 'package:kastamonu_app/ozellikler/inceleme/model/haber.dart';

/// Flutter çizimi tuvale yaptığı için erişilebilirlik ağacı elle kurulmak
/// zorunda; kurulmazsa sayfa ekran okuyucu için tamamen boş. Uzun süre tüm
/// kod tabanında tek bir `Semantics` vardı.
///
/// Bu testler ağacın GERÇEKTEN kurulduğunu doğruluyor: widget'ların içine
/// `Semantics` yazmış olmak, o düğümün ağaca düştüğü anlamına gelmiyor.
Haber _haber() => Haber(
      id: '1',
      slug: 'ornek-haber',
      baslik: 'Taşköprü Akçakese köyünde çıkan yangın söndürüldü',
      kaynakAdi: 'Haberler.com',
      kaynakUrl: 'https://ornek',
      katman: 1,
      onem: 5,
      diaspora: false,
      durum: 'yayinda',
      kategoriAd: 'Kaza ve Acil',
      olusturuldu: DateTime.now().subtract(const Duration(hours: 3)),
      yayinlandi: DateTime.now().subtract(const Duration(hours: 3)),
      ilceler: const [
        IlceBagi(
          ilceId: 'tk',
          ad: 'Taşköprü',
          guven: 0.9,
          kaynak: 'model+sozluk',
          onaylandi: true,
        ),
      ],
    );

Widget _sar(Widget cocuk) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: cocuk)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting('tr');

  group('Haber etiketi', () {
    test('başlık, bölüm, ilçe ve zamanı tek cümlede veriyor', () {
      final e = haberEtiketi(_haber());
      expect(e, startsWith('Taşköprü Akçakese'));
      expect(e, contains('Kaza ve Acil'));
      expect(e, contains('Taşköprü'));
      expect(e, contains('3 saat önce'));
    });

    test('onaylanmamış ilçe bağı etikete girmiyor', () {
      final h = Haber(
        id: '2',
        slug: 's',
        baslik: 'Başlık',
        kaynakAdi: 'K',
        kaynakUrl: 'u',
        katman: 1,
        onem: 4,
        diaspora: false,
        durum: 'yayinda',
        olusturuldu: DateTime.now(),
        ilceler: const [
          IlceBagi(
            ilceId: 'x',
            ad: 'Onaysız',
            guven: 0.4,
            kaynak: 'yalniz_model',
            onaylandi: false,
          ),
        ],
      );
      expect(haberEtiketi(h), isNot(contains('Onaysız')));
    });
  });

  group('Ekran okuyucu ağacı', () {
    testWidgets('akış satırı tek bir buton olarak duyuruluyor', (t) async {
      final anlam = t.ensureSemantics();
      await t.pumpWidget(_sar(Satir(haber: _haber())));

      // Düğüm gerçekten ağaçta ve buton olarak işaretli.
      expect(
        find.bySemanticsLabel(RegExp('Taşköprü Akçakese')),
        findsOneWidget,
      );
      expect(
        t.getSemantics(find.bySemanticsLabel(RegExp('Taşköprü Akçakese'))),
        isSemantics(isButton: true, hasTapAction: true),
      );

      anlam.dispose();
    });

    testWidgets('kart içindeki metinler ayrı ayrı duyurulmuyor', (t) async {
      final anlam = t.ensureSemantics();
      await t.pumpWidget(_sar(Satir(haber: _haber())));

      // Başlık, kart etiketinin İÇİNDE geçiyor; ayrıca kendi düğümü
      // olmamalı, yoksa ekran okuyucu aynı cümleyi iki kez okuyor.
      final hepsi = find.bySemanticsLabel(RegExp('Taşköprü Akçakese'));
      expect(hepsi, findsOneWidget);

      anlam.dispose();
    });

    testWidgets('manşet de buton olarak duyuruluyor', (t) async {
      final anlam = t.ensureSemantics();
      await t.pumpWidget(_sar(Manset(haber: _haber())));

      expect(
        t.getSemantics(find.bySemanticsLabel(RegExp('Taşköprü Akçakese'))),
        isSemantics(isButton: true, hasTapAction: true),
      );

      anlam.dispose();
    });
  });
}
