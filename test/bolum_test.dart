import 'package:flutter_test/flutter_test.dart';

import 'package:kastamonu_app/cekirdek/bolum.dart';
import 'package:kastamonu_app/cekirdek/tema.dart';

void main() {
  group('Bölüm ailesi', () {
    test('okurun aynı gördüğü bölümler aynı ailede', () {
      expect(Bolum.aile('Asayiş'), Bolum.aile('Kaza ve Acil'));
      expect(Bolum.aile('Gündem'), Bolum.aile('Kent ve Yönetim'));
      expect(Bolum.aile('Ekonomi'), Bolum.aile('Tarım'));
    });

    test('farklı tonlar ayrı ailede', () {
      expect(Bolum.aile('Asayiş'), isNot(Bolum.aile('Spor')));
      expect(Bolum.aile('Gündem'), isNot(Bolum.aile('Eğitim')));
    });

    test('tanınmayan bölüm uygulamayı düşürmüyor', () {
      expect(Bolum.aile('Olmayan Bölüm'), BolumAilesi.diger);
      expect(Bolum.aile(null), BolumAilesi.diger);
      expect(Bolum.renk(null), isNotNull);
    });
  });

  group('Renk', () {
    test('son dakika kırmızısı hiçbir bölümde kullanılmıyor', () {
      // O renk yalnızca son dakika bandının; bir bölümde kullanılırsa
      // bant anlamını kaybeder.
      for (final a in BolumAilesi.values) {
        expect(a.renk, isNot(Tema.sonDakika));
      }
    });

    test('aynı ailedeki bölümler aynı rengi alıyor', () {
      expect(Bolum.renk('Asayiş'), Bolum.renk('Kaza ve Acil'));
      expect(Bolum.renk('Kültür ve Turizm'), Bolum.renk('Spor'));
    });

    test('beş aile artı yedek, on ayrı renk değil', () {
      expect(BolumAilesi.values.map((a) => a.renk).toSet(), hasLength(6));
    });
  });

  group('Kısaltma', () {
    test('Türkçe büyütme kuralına uyuyor', () {
      // Otomatik kesme "Eğitim" için "EGI" üretirdi.
      expect(Bolum.kisalt('Eğitim'), 'EĞT');
      expect(Bolum.kisalt('Sağlık'), 'SAĞ');
    });

    test('aynı ailedeki bölümler ayrı damga taşıyor', () {
      // Renk ailesi gösteriyor, ayrımı damga taşıyor.
      expect(Bolum.kisalt('Asayiş'), isNot(Bolum.kisalt('Kaza ve Acil')));
    });

    test('listede olmayan bölümde ilk üç harfe düşüyor', () {
      expect(Bolum.kisalt('Ilgaz'), 'ILG');
      expect(Bolum.kisalt('iz'), 'İZ');
    });
  });
}
