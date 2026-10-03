import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kastamonu_app/cekirdek/bolum.dart';
import 'package:kastamonu_app/cekirdek/tema.dart';

/// WCAG 2.1 bağıl parlaklık.
double _parlaklik(Color c) {
  double kanal(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * kanal(c.r) + 0.7152 * kanal(c.g) + 0.0722 * kanal(c.b);
}

double oran(Color a, Color b) {
  final x = _parlaklik(a), y = _parlaklik(b);
  final buyuk = math.max(x, y), kucuk = math.min(x, y);
  return (buyuk + 0.05) / (kucuk + 0.05);
}

/// Kontrast bu portalda bir üslup tercihi değil kısıt: Kastamonu, TÜİK
/// 2025'e göre ortanca yaşı en yüksek üçüncü il (43,3) ve 65 üstü oranında
/// ikinci (%21,1). Değerler tema dosyasının yorumlarında yazılı ama yorum
/// bozulduğunu söylemez — bu testler söyler.
void main() {
  const en_az = 4.5; // WCAG AA, normal metin

  for (final (ad, r) in [('Açık', Renkler.acik), ('Koyu', Renkler.koyu)]) {
    group('$ad tema', () {
      test('metin renkleri zemin ve kart üstünde AA', () {
        for (final (uye, renk) in [
          ('murekkep', r.murekkep),
          ('murekkepIkincil', r.murekkepIkincil),
          ('solgun', r.solgun),
          ('patina', r.patina),
          ('bakir', r.bakir),
        ]) {
          for (final (zeminAd, zemin) in [
            ('zemin', r.zemin),
            ('kart', r.kart),
            ('sunk', r.sunk),
          ]) {
            expect(
              oran(renk, zemin),
              greaterThanOrEqualTo(en_az),
              reason: '$ad: $uye / $zeminAd = '
                  '${oran(renk, zemin).toStringAsFixed(2)}',
            );
          }
        }
      });

      test('uyarı rengi yazı olarak okunabiliyor', () {
        expect(oran(r.uyari, r.zemin), greaterThanOrEqualTo(en_az));
        expect(oran(r.uyari, r.kart), greaterThanOrEqualTo(en_az));
      });

      test('son dakika bandında beyaz yazı okunabiliyor', () {
        expect(oran(Colors.white, r.sonDakika), greaterThanOrEqualTo(en_az));
      });

      test('patina zemin olduğunda üstündeki yazı okunabiliyor', () {
        // Koyu temada patina açılıyor; beyaz yazı 2,84:1'e düşüyordu.
        expect(oran(r.patinaUstu, r.patina), greaterThanOrEqualTo(en_az));
      });

      test('koyu kuşakta metin okunabiliyor', () {
        expect(oran(r.kusakMetin, r.kusak), greaterThanOrEqualTo(en_az));
        expect(oran(r.kusakIkincil, r.kusak), greaterThanOrEqualTo(en_az));
      });

      test('kart zeminden ayırt edilebiliyor', () {
        // Kartın nerede bittiği görünmeli; ya renk farkı ya çizgi.
        final fark = oran(r.kart, r.zemin);
        final cizgi = oran(r.cizgi, r.zemin);
        expect(
          fark > 1.02 || cizgi > 1.2,
          isTrue,
          reason: '$ad: kart/zemin $fark, çizgi/zemin $cizgi',
        );
      });

      test('kuşak sayfa zemininden ayrılıyor', () {
        // Koyu temada kuşak `murekkep` olsaydı sayfa zeminiyle aynı renk
        // olur ve bant görünmezdi.
        expect(r.kusak, isNot(r.zemin));
      });
    });
  }

  test('bölüm renkleri beyaz yazıyı taşıyor', () {
    for (final a in BolumAilesi.values) {
      expect(
        oran(Colors.white, a.renk),
        greaterThanOrEqualTo(en_az),
        reason: '${a.name}: ${oran(Colors.white, a.renk).toStringAsFixed(2)}',
      );
    }
  });
}
