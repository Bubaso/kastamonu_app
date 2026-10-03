import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kastamonu_app/cekirdek/metin.dart';
import 'package:kastamonu_app/cekirdek/tercihler.dart';
import 'package:kastamonu_app/ozellikler/anasayfa/ekran/anasayfa_ekrani.dart'
    show gecenSure;

/// Bu testler, tarayıcıda elle denenemeyen davranışı kilitliyor.
///
/// Neden yazıldılar: arayüz CanvasKit tuvaline çizildiği için otomatik
/// tıklama tuvale ulaşmıyor; İlçem seçimi, kaydetme ve punto ayarı
/// ekran görüntüsüyle doğrulanamıyor. Bu üçü de kalıcı durum yazıyor,
/// yani sessizce bozulabilecek türden.
Future<ProviderContainer> _kap([Map<String, Object> baslangic = const {}]) async {
  SharedPreferences.setMockInitialValues(baslangic);
  final t = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [tercihlerSaglayici.overrideWithValue(t)],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // `main()` ne yapıyorsa test de yapmalı: Türkçe ay ve gün adları bu
  // çağrı olmadan `DateFormat` tarafından reddediliyor.
  initializeDateFormatting('tr');

  group('Türkçe büyütme', () {
    // Bu testin varlık sebebi gerçek bir hata: bölüm etiketleri ekranda
    // "EĞITIM" ve "KAZA VE ACIL" olarak çıkıyordu.
    test('i harfi İ oluyor', () {
      expect(buyult('Eğitim'), 'EĞİTİM');
      expect(buyult('Kaza ve Acil'), 'KAZA VE ACİL');
      expect(buyult('Ekonomi'), 'EKONOMİ');
      expect(buyult('İnebolu'), 'İNEBOLU');
    });

    test('ı harfi I oluyor', () {
      expect(buyult('Ağlı'), 'AĞLI');
      expect(buyult('Tarım'), 'TARIM');
    });

    test('diğer Türkçe harfler bozulmuyor', () {
      expect(buyult('Şenpazar'), 'ŞENPAZAR');
      expect(buyult('Çatalzeytin'), 'ÇATALZEYTİN');
      expect(buyult('Taşköprü'), 'TAŞKÖPRÜ');
      expect(buyult('Küre'), 'KÜRE');
    });

    test('küçültme de Türkçe kurala uyuyor', () {
      expect(kucult('İNEBOLU'), 'inebolu');
      expect(kucult('TARIM'), 'tarım');
    });
  });

  group('İlçem', () {
    test('başlangıçta seçili ilçe yok', () async {
      final k = await _kap();
      expect(k.read(ilcemSaglayici), isNull);
    });

    test('seçim hem duruma hem cihaza yazılıyor', () async {
      final k = await _kap();
      await k.read(ilcemSaglayici.notifier).sec('id-1', 'Taşköprü');

      expect(k.read(ilcemSaglayici)?.ad, 'Taşköprü');
      expect(k.read(ilcemSaglayici)?.id, 'id-1');

      // Cihazda gerçekten duruyor mu — uygulama yeniden açılınca gelmeli.
      final t = k.read(tercihlerSaglayici);
      expect(t.getString(Anahtar.ilcemId), 'id-1');
      expect(t.getString(Anahtar.ilcemAd), 'Taşköprü');
    });

    test('kayıtlı seçim açılışta okunuyor', () async {
      final k = await _kap({
        'flutter.${Anahtar.ilcemId}': 'id-9',
        'flutter.${Anahtar.ilcemAd}': 'Tosya',
      });
      expect(k.read(ilcemSaglayici)?.ad, 'Tosya');
    });

    test('temizlemek seçimi hem durumdan hem cihazdan siliyor', () async {
      final k = await _kap();
      await k.read(ilcemSaglayici.notifier).sec('id-1', 'Daday');
      await k.read(ilcemSaglayici.notifier).temizle();

      expect(k.read(ilcemSaglayici), isNull);
      expect(k.read(tercihlerSaglayici).getString(Anahtar.ilcemId), isNull);
    });
  });

  group('Kaydettiklerim', () {
    test('kaydetme ve geri alma', () async {
      final k = await _kap();
      final n = k.read(kaydedilenlerSaglayici.notifier);

      expect(await n.degistir('bir-haber'), isTrue);
      expect(k.read(kaydedilenlerSaglayici), ['bir-haber']);

      expect(await n.degistir('bir-haber'), isFalse);
      expect(k.read(kaydedilenlerSaglayici), isEmpty);
    });

    test('en son kaydedilen başa geliyor', () async {
      final k = await _kap();
      final n = k.read(kaydedilenlerSaglayici.notifier);
      await n.degistir('ilk');
      await n.degistir('ikinci');
      await n.degistir('ucuncu');

      // Okur "sonra okurum" dediğini ararken en son kaydettiğine bakar.
      expect(k.read(kaydedilenlerSaglayici), ['ucuncu', 'ikinci', 'ilk']);
    });

    test('cihazda kalıcı', () async {
      final k = await _kap();
      await k.read(kaydedilenlerSaglayici.notifier).degistir('kalici');
      expect(
        k.read(tercihlerSaglayici).getStringList(Anahtar.kaydedilenler),
        ['kalici'],
      );
    });

    test('tümünü silmek listeyi boşaltıyor', () async {
      final k = await _kap();
      final n = k.read(kaydedilenlerSaglayici.notifier);
      await n.degistir('a');
      await n.degistir('b');
      await n.hepsiniSil();
      expect(k.read(kaydedilenlerSaglayici), isEmpty);
    });
  });

  group('Punto', () {
    test('varsayılan normal', () async {
      final k = await _kap();
      expect(k.read(puntoSaglayici), Punto.normal);
      expect(k.read(puntoSaglayici).carpan, 1.0);
    });

    test('seçim kalıcı', () async {
      final k = await _kap();
      await k.read(puntoSaglayici.notifier).sec(Punto.enBuyuk);
      expect(k.read(puntoSaglayici), Punto.enBuyuk);
      expect(k.read(tercihlerSaglayici).getInt(Anahtar.punto), 2);
    });

    test('bozuk kayıt uygulamayı düşürmüyor', () async {
      // Elle kurcalanmış ya da eski sürümden kalmış bir değer.
      final k = await _kap({'flutter.${Anahtar.punto}': 99});
      expect(k.read(puntoSaglayici), Punto.enBuyuk);
    });

    test('gövde puntosu 45 yaş tabanının altına inmiyor', () async {
      // Tasarımın taşıdığı kısıt: 17,5 px taban.
      for (final p in Punto.values) {
        expect(17.5 * p.carpan, greaterThanOrEqualTo(17.5));
      }
    });
  });

  group('Geçen süre', () {
    // Referans an SABİT. Önce `DateTime.now()` kullanılıyordu ve test
    // günün saatine bağlıydı: gece yarısından sonra koşturulduğunda
    // "7 saat önce" beklentisi bir önceki güne düşüyordu.
    final simdi = DateTime(2026, 9, 20, 10, 0); // Pazar 10:00

    test('yerel haberde tazelik göreli okunuyor', () {
      expect(gecenSure(simdi.subtract(const Duration(seconds: 20)),
          simdi: simdi), 'az önce');
      expect(gecenSure(simdi.subtract(const Duration(minutes: 5)),
          simdi: simdi), '5 dakika önce');
      expect(gecenSure(simdi.subtract(const Duration(hours: 7)),
          simdi: simdi), '7 saat önce');
      expect(gecenSure(DateTime(2026, 9, 14), simdi: simdi), '6 gün önce');
      expect(gecenSure(DateTime(2026, 8, 8, 9), simdi: simdi), '8 Ağu');
    });

    test('kademe takvim gününe göre, saat farkına göre değil', () {
      // Dün 23:00 — saat farkı 11, yani eski kurgu "11 saat önce" diyordu.
      expect(gecenSure(DateTime(2026, 9, 19, 23, 0), simdi: simdi),
          'dün 23:00');
      // Aynı gün 00:30 — 9,5 saat geride ama hâlâ bugün.
      expect(gecenSure(DateTime(2026, 9, 20, 0, 30), simdi: simdi),
          '9 saat önce');
    });

    test('gece yarısını yeni geçmişken 25 saatlik haber dün demiyor', () {
      final geceyarisi = DateTime(2026, 9, 20, 0, 30);
      // 25 saat geride = 19 Eylül 23:30 DEĞİL, 18 Eylül 23:30.
      expect(
        gecenSure(geceyarisi.subtract(const Duration(hours: 25)),
            simdi: geceyarisi),
        '2 gün önce',
      );
    });

    test('sunucu saati ileri kaymış kayıt geleceğe atılmıyor', () {
      expect(gecenSure(simdi.add(const Duration(hours: 2)), simdi: simdi),
          'az önce');
    });
  });
}
