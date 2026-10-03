import 'package:flutter_test/flutter_test.dart';

import 'package:kastamonu_app/ozellikler/anasayfa/veri/tekille.dart';
import 'package:kastamonu_app/ozellikler/inceleme/model/haber.dart';

final _simdi = DateTime(2026, 10, 3, 10);
int _sayac = 0;

Haber _h({
  required String baslik,
  String? kategori,
  List<String> ilceler = const [],
  Duration yas = Duration.zero,
  String? govde,
  bool foto = false,
  String? id,
}) {
  final k = id ?? 'h${_sayac++}';
  final an = _simdi.subtract(yas);
  return Haber(
    id: k,
    slug: k,
    baslik: baslik,
    govde: govde,
    kategoriAd: kategori,
    kaynakAdi: 'Kaynak',
    kaynakUrl: 'https://ornek/$k',
    katman: 1,
    onem: 4,
    diaspora: false,
    durum: 'yayinda',
    gorselUrl: foto ? 'https://ornek/$k.jpg' : null,
    gorselKaynak: foto ? 'Ajans' : null,
    olusturuldu: an,
    yayinlandi: an,
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

// ── Ölçümde yakalanan gerçek çiftler ───────────────────────────
//
// Kural bu iki çiftle kalibre edildi; testler de onları kullanıyor ki
// eşik değişirse gerçek veriyle birlikte değişsin.

Haber _dadayA() => _h(
      baslik: "Daday'ın Bolatlar köyünde çıkan yangında Yaşar Mıcık'a ait "
          'samanlık kullanılamaz hale geldi',
      kategori: 'Kaza ve Acil',
      ilceler: const ['daday'],
      yas: const Duration(days: 13),
      govde: 'Uzun gövde metni, olayın ayrıntılarıyla birlikte.',
      foto: true,
      id: 'daday-a',
    );

Haber _dadayB() => _h(
      baslik: "Daday'ın Bolatlar köyünde çıkan yangında samanlık "
          'kullanılamaz hale geldi',
      kategori: 'Kaza ve Acil',
      ilceler: const ['daday'],
      yas: const Duration(days: 12),
      govde: 'Kısa.',
      id: 'daday-b',
    );

Haber _gazilerMerkez() => _h(
      baslik: "Kastamonu'da 19 Eylül Gaziler Günü düzenlenen yürüyüş ve "
          'törenlerle kutlandı',
      kategori: 'Gündem',
      yas: const Duration(days: 12),
      id: 'gaziler-merkez',
    );

Haber _gazilerIlceler() => _h(
      baslik: "Tosya, Taşköprü ve Ağlı'da 19 Eylül Gaziler Günü törenlerle "
          'kutlandı',
      kategori: 'Gündem',
      ilceler: const ['tosya', 'taskopru', 'agli'],
      yas: const Duration(days: 13),
      id: 'gaziler-ilceler',
    );

void main() {
  group('Başlık benzerliği', () {
    test('Türkçe sadeleşmeden sonra ölçülüyor', () {
      expect(
        baslikBenzerligi('Taşköprü sarımsağı', 'taskopru sarimsagi'),
        1.0,
      );
    });

    test('ortak kelimesi olmayan başlıklar sıfır', () {
      expect(baslikBenzerligi('Kaza oldu burada', 'Festival başladı orada'), 0);
    });

    test('boş başlık sıfır', () {
      expect(baslikBenzerligi('', 'Herhangi bir başlık'), 0);
    });
  });

  group('Aynı olay', () {
    test('gerçek tekrar yakalanıyor', () {
      expect(ayniOlay(_dadayA(), _dadayB()), isTrue);
    });

    test('aynı vesile farklı yer BİRLEŞTİRİLMİYOR', () {
      // Tekilleştirmenin yapabileceği en kötü hata bu: üç ilçenin
      // haberini merkez haberiyle birleştirip yok etmek.
      expect(ayniOlay(_gazilerMerkez(), _gazilerIlceler()), isFalse);
    });

    test('ilçeleri kesişmeyen haberler birleşmiyor', () {
      final a = _h(
        baslik: 'Köyde çıkan yangın söndürüldü',
        kategori: 'Kaza ve Acil',
        ilceler: const ['tosya'],
      );
      final b = _h(
        baslik: 'Köyde çıkan yangın söndürüldü',
        kategori: 'Kaza ve Acil',
        ilceler: const ['daday'],
      );
      expect(ayniOlay(a, b), isFalse);
    });

    test('ikisi de il geneliyse yer koşulu sağlanıyor', () {
      final a = _h(baslik: 'Valilikten kar yağışı uyarısı', kategori: 'Gündem');
      final b = _h(baslik: 'Valilikten kar yağışı uyarısı', kategori: 'Gündem');
      expect(ayniOlay(a, b), isTrue);
    });

    test('farklı bölüm ailesi birleşmiyor', () {
      final a = _h(
        baslik: 'Üniversitede düzenlenen etkinlik tamamlandı',
        kategori: 'Eğitim',
        ilceler: const ['merkez'],
      );
      final b = _h(
        baslik: 'Üniversitede düzenlenen etkinlik tamamlandı',
        kategori: 'Spor',
        ilceler: const ['merkez'],
      );
      expect(ayniOlay(a, b), isFalse);
    });

    test('zaman penceresi dışındakiler birleşmiyor', () {
      final a = _h(
        baslik: 'Belediye kaldırım çalışması başlattı',
        kategori: 'Kent ve Yönetim',
        ilceler: const ['merkez'],
      );
      final b = _h(
        baslik: 'Belediye kaldırım çalışması başlattı',
        kategori: 'Kent ve Yönetim',
        ilceler: const ['merkez'],
        yas: const Duration(days: 40),
      );
      expect(ayniOlay(a, b), isFalse);
    });

    test('derleme anına bakılıyor, yayın anına değil', () {
      // Gerçek veride yakalanan tuzak: iki kayıt bir gün arayla DERLENMİŞ
      // ama biri 21 Eylül'de, öbürü 3 Ekim'de YAYIMLANMIŞTI. Yayın
      // damgasına bakan ilk sürüm aradaki farkı 12,5 gün görüp gerçek
      // tekrarı pencerenin dışında bırakıyordu.
      final derleme = DateTime(2026, 9, 20, 4);
      Haber kayit(String id, DateTime yayin, String baslik) => Haber(
            id: id,
            slug: id,
            baslik: baslik,
            kategoriAd: 'Kaza ve Acil',
            kaynakAdi: 'Kaynak',
            kaynakUrl: 'https://ornek/\$id',
            katman: 1,
            onem: 4,
            diaspora: false,
            durum: 'yayinda',
            olusturuldu: derleme,
            yayinlandi: yayin,
            ilceler: const [
              IlceBagi(
                ilceId: 'daday',
                ad: 'Daday',
                guven: 1,
                kaynak: 'model+sozluk',
                onaylandi: true,
              ),
            ],
          );

      final a = kayit('erken', DateTime(2026, 9, 21), 'Bolatlar köyünde çıkan yangında samanlık kullanılamaz hale geldi');
      final b = kayit('gec', DateTime(2026, 10, 3), 'Bolatlar köyünde çıkan yangında samanlık kullanılamaz hale geldi');

      expect(a.zaman.difference(b.zaman).abs().inDays, greaterThan(7),
          reason: 'yayın damgaları gerçekten uzak olmalı');
      expect(ayniOlay(a, b), isTrue);
      expect(tekille([a, b]), hasLength(1));
    });

    test('kayıt kendisiyle eşleşmiyor', () {
      final a = _dadayA();
      expect(ayniOlay(a, a), isFalse);
    });
  });

  group('Tekilleştirme', () {
    test('aynı olaydan bir kayıt kalıyor', () {
      final sonuc = tekille([_dadayA(), _dadayB()]);
      expect(sonuc, hasLength(1));
    });

    test('okurun lehine olan kayıt kalıyor', () {
      // Fotoğrafı ve daha uzun gövdesi olan; ölçülen çiftte kalan kayıt
      // kimin samanlığı olduğunu da yazıyor.
      for (final liste in [
        [_dadayA(), _dadayB()],
        [_dadayB(), _dadayA()],
      ]) {
        expect(tekille(liste).single.id, 'daday-a');
      }
    });

    test('belirgin şekilde bilgilendirici başlık gövdeyi geçiyor', () {
      // Ölçülen gerçek durum: iki kaydın da fotoğrafı var, gövde kısa
      // olanın başlığı daha bilgilendirici. Akışta okurun gördüğü şey
      // başlık olduğu için o kayıt kalmalı.
      final zenginBaslik = _h(
        baslik: "Daday'ın Bolatlar köyünde çıkan yangında Yaşar Mıcık'a ait "
            'samanlık kullanılamaz hale geldi',
        kategori: 'Kaza ve Acil',
        ilceler: const ['daday'],
        govde: 'a' * 532,
        foto: true,
        id: 'zengin-baslik',
      );
      final uzunGovde = _h(
        baslik: "Daday'ın Bolatlar köyünde çıkan yangında samanlık "
            'kullanılamaz hale geldi',
        kategori: 'Kaza ve Acil',
        ilceler: const ['daday'],
        govde: 'a' * 571,
        foto: true,
        id: 'uzun-govde',
      );

      for (final liste in [
        [zenginBaslik, uzunGovde],
        [uzunGovde, zenginBaslik],
      ]) {
        expect(tekille(liste).single.id, 'zengin-baslik');
      }
    });

    test('küçük başlık farkı gövde kararını devirmiyor', () {
      // Tek karakterlik bir fark üç yüz karakterlik gövde farkını
      // devirmemeli; başlık uzunluğu gürültülü bir ölçüt.
      final kilBaslik = _h(
        baslik: 'Merkezde trafik kazası meydana geldii',
        kategori: 'Kaza ve Acil',
        ilceler: const ['merkez'],
        govde: 'a' * 100,
        id: 'kil-baslik',
      );
      final uzunGovde = _h(
        baslik: 'Merkezde trafik kazası meydana geldi',
        kategori: 'Kaza ve Acil',
        ilceler: const ['merkez'],
        govde: 'a' * 400,
        id: 'uzun-govde-2',
      );
      expect(tekille([kilBaslik, uzunGovde]).single.id, 'uzun-govde-2');
    });

    test('fotoğraf her iki ölçütün de önünde', () {
      // Başlıklar aynı olay sayılacak kadar benzer; fark fotoğrafta.
      final fotografli = _h(
        baslik: 'Merkezde çıkan yangın söndürüldü',
        kategori: 'Kaza ve Acil',
        ilceler: const ['merkez'],
        govde: 'a' * 50,
        foto: true,
        id: 'fotografli',
      );
      final fotografsiz = _h(
        baslik: 'Merkezde çıkan yangın itfaiye ekiplerince söndürüldü',
        kategori: 'Kaza ve Acil',
        ilceler: const ['merkez'],
        govde: 'a' * 900,
        id: 'fotografsiz',
      );
      expect(ayniOlay(fotografli, fotografsiz), isTrue,
          reason: 'önce aynı olay sayılmalı ki üstünlük kuralı sınansın');
      expect(tekille([fotografli, fotografsiz]).single.id, 'fotografli');
    });

    test('ayrı haberlerin ikisi de kalıyor', () {
      final sonuc = tekille([_gazilerMerkez(), _gazilerIlceler()]);
      expect(sonuc, hasLength(2));
    });

    test('tekrar yoksa liste aynen dönüyor', () {
      final liste = [
        _h(baslik: 'Birinci haber burada', kategori: 'Gündem'),
        _h(baslik: 'İkinci bambaşka konu', kategori: 'Spor'),
        _h(baslik: 'Üçüncü apayrı mesele', kategori: 'Tarım'),
      ];
      expect(tekille(liste), hasLength(3));
    });

    test('sıra korunuyor', () {
      final a = _h(baslik: 'Alfa konusunda gelişme', kategori: 'Gündem');
      final b = _h(baslik: 'Beta konusunda gelişme', kategori: 'Spor');
      final c = _h(baslik: 'Gama konusunda gelişme', kategori: 'Tarım');
      expect(tekille([a, b, c]).map((h) => h.id), [a.id, b.id, c.id]);
    });

    test('üçlü tekrarda tek kayıt kalıyor', () {
      final liste = [
        _h(
          baslik: 'Merkezde trafik kazası meydana geldi',
          kategori: 'Kaza ve Acil',
          ilceler: const ['merkez'],
          id: 'uc-1',
        ),
        _h(
          baslik: 'Merkezde trafik kazası meydana geldi',
          kategori: 'Kaza ve Acil',
          ilceler: const ['merkez'],
          yas: const Duration(hours: 2),
          id: 'uc-2',
        ),
        _h(
          baslik: 'Merkezde trafik kazası meydana geldi',
          kategori: 'Kaza ve Acil',
          ilceler: const ['merkez'],
          yas: const Duration(hours: 4),
          id: 'uc-3',
        ),
      ];
      expect(tekille(liste), hasLength(1));
    });

    test('boş ve tek elemanlı liste düşürmüyor', () {
      expect(tekille(const []), isEmpty);
      expect(tekille([_dadayA()]), hasLength(1));
    });
  });
}
