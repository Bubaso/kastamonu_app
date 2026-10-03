import 'package:flutter_test/flutter_test.dart';

import 'package:kastamonu_app/cekirdek/gorsel.dart';

/// Bu işlev bir görselin hiç görünmemesine yol açamaz — testlerin asıl
/// kilitlediği şey bu. Her "çeviremedim" durumu özgün adresi döndürüyor.
void main() {
  const ornek =
      'https://vcwgcvzqdnjyoitdfhma.supabase.co/storage/v1/object/public/'
      'gorseller/kastamonu-da-trafige-kayitli-arac-sayisi-a70407ff.jpg';

  group('Kademe', () {
    test('mantıksal genişliği ikiye katlayıp yukarı yuvarlıyor', () {
      expect(kademe(104), 320); // 208 istiyor -> 320
      expect(kademe(160), 320); // 320 istiyor -> 320
      expect(kademe(161), 640); // 322 istiyor -> 640
      expect(kademe(320), 640); // 640 istiyor -> 640
      expect(kademe(400), 1200); // 800 istiyor -> 1200
    });

    test('en büyük kademenin üstünde ona sabitleniyor', () {
      expect(kademe(700), 1200);
      expect(kademe(4000), 1200);
    });
  });

  group('Görsel adresi', () {
    test('taban verilince boyutlandırma yoluna çevriliyor', () {
      expect(
        gorselAdresi(ornek, mantiksalGenislik: 104, taban: '/gorsel'),
        '/gorsel/320/kastamonu-da-trafige-kayitli-arac-sayisi-a70407ff.jpg',
      );
    });

    test('taban boşken özgün adres dönüyor — yerelde fonksiyon yok', () {
      expect(gorselAdresi(ornek, mantiksalGenislik: 104, taban: ''), ornek);
    });

    test('boş ve null adres olduğu gibi geçiyor', () {
      expect(gorselAdresi(null, mantiksalGenislik: 104, taban: '/gorsel'),
          isNull);
      expect(gorselAdresi('', mantiksalGenislik: 104, taban: '/gorsel'), '');
    });

    test('beklenmeyen dosya adında özgüne düşülüyor', () {
      const tuhaf = 'https://ornek/gorseller/dosya%20adi.gif';
      expect(
        gorselAdresi(tuhaf, mantiksalGenislik: 104, taban: '/gorsel'),
        tuhaf,
      );
    });

    test('uzantısız adreste özgüne düşülüyor', () {
      const uzantisiz = 'https://ornek/gorseller/dosya';
      expect(
        gorselAdresi(uzantisiz, mantiksalGenislik: 104, taban: '/gorsel'),
        uzantisiz,
      );
    });
  });
}
