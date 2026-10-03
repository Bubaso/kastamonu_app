import 'package:flutter_test/flutter_test.dart';

import 'package:kastamonu_app/ozellikler/anasayfa/ekran/anasayfa_ekrani.dart';
import 'package:kastamonu_app/ozellikler/inceleme/model/haber.dart';

Haber _haber({String? gorselUrl, String? gorselKaynak}) => Haber(
      id: '1',
      slug: 'ornek',
      baslik: 'Örnek başlık',
      kaynakAdi: 'Haberler.com',
      kaynakUrl: 'https://ornek',
      katman: 1,
      onem: 1,
      diaspora: false,
      durum: 'yayinda',
      olusturuldu: DateTime(2026, 9, 20),
      gorselUrl: gorselUrl,
      gorselKaynak: gorselKaynak,
      ilceler: const [],
    );

/// Bu kural bir kez sessizce bozuldu: koşul `gorselKaynak` aranmadan
/// yalnızca `gorselUrl`e indirgendi. Sonuç iki ayrı hata oldu —
/// tipografik kartlar akışa fotoğraf gibi girdi (başlık iki kez okundu)
/// ve fotoğrafı olmayan habere "Fotoğraf: Haberler.com" künyesi düştü.
void main() {
  group('Gerçek fotoğraf ayrımı', () {
    test('kaynağın fotoğrafı: atıf VE adres birlikte', () {
      expect(
        KartBasi.gercekFotograf(
          _haber(gorselUrl: 'https://x/a.jpg', gorselKaynak: 'Haberler.com'),
        ),
        isTrue,
      );
    });

    test('tipografik kart fotoğraf SAYILMAZ (atıf yok)', () {
      // `gorsel_url` dolu ama `gorsel_kaynak` boş: bu bizim ürettiğimiz
      // paylaşım kartı, üstünde haberin başlığı yazılı.
      expect(
        KartBasi.gercekFotograf(_haber(gorselUrl: 'https://x/kart.jpg')),
        isFalse,
      );
    });

    test('atıf var ama adres yok → fotoğraf sayılmaz', () {
      expect(
        KartBasi.gercekFotograf(_haber(gorselKaynak: 'Haberler.com')),
        isFalse,
      );
    });

    test('hiçbiri yok', () {
      expect(KartBasi.gercekFotograf(_haber()), isFalse);
    });

    test('boş dizgi dolu sayılmaz', () {
      expect(
        KartBasi.gercekFotograf(_haber(gorselUrl: '', gorselKaynak: '')),
        isFalse,
      );
    });
  });
}
