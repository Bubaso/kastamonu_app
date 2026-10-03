import 'package:flutter/material.dart';

import 'metin.dart';

/// Bölümler: aile, renk, kısaltma.
///
/// Neden tek dosya
/// ───────────────
/// Aynı gruplama iki ayrı yerde yazılıydı: kapak tahsisi hangi haberin
/// hangi kata düşeceğine karar verirken "Asayiş ile Kaza ve Acil aynı
/// şey" diyordu, kategori bandı ise onlara ayrı renkler veriyordu. İki
/// liste birbirinden habersiz değişebiliyordu.
///
/// Renk neden beş
/// ──────────────
/// Önce on kategorinin her birinin kendi rengi vardı ve hepsi eşit
/// ağırlıktaydı. On eşit renk hiyerarşi kurmuyor, yalnızca çeşitlilik
/// üretiyor — okur "bu hangi bölüm" sorusunu zaten kartın üstündeki
/// yazıdan cevaplıyor. Beş aile, rengi bir gürültü kaynağı olmaktan
/// çıkarıp bir gruplama işareti yapıyor: koyu kuşakta gördüğü kiremit
/// rengiyle akışta gördüğü aynı şeyi söylüyor.
///
/// Kırmızı (`Tema.sonDakika`) hiçbir ailede yok ve olmamalı: o renk
/// yalnızca son dakika bandının. Bir bölümde kullanılırsa bant anlamını
/// kaybeder.
enum BolumAilesi {
  /// Asayiş, kaza ve acil. Kiremit — kâğıt zeminde en ağır duran aile.
  asayis(Color(0xFF7A2E12)),

  /// Gündem, kent ve yönetim. Patina.
  gundem(Color(0xFF0A5F4E)),

  /// Ekonomi ve tarım. Orman.
  uretim(Color(0xFF47651F)),

  /// Eğitim ve sağlık. Mürekkep moru.
  toplum(Color(0xFF4C3E7A)),

  /// Kültür, turizm ve spor. Bakır sarısı.
  yasam(Color(0xFF7E5210)),

  /// Listede olmayan bölüm.
  diger(Color(0xFF38505F));

  const BolumAilesi(this.renk);

  /// Beyaz yazıyı taşıyacak kadar koyu ve kâğıt zeminle aynı sıcaklıkta.
  final Color renk;
}

/// Kategori adından aile, renk ve kısaltma.
class Bolum {
  const Bolum._();

  static const _aileler = <String, BolumAilesi>{
    'Asayiş': BolumAilesi.asayis,
    'Kaza ve Acil': BolumAilesi.asayis,
    'Gündem': BolumAilesi.gundem,
    'Kent ve Yönetim': BolumAilesi.gundem,
    'Ekonomi': BolumAilesi.uretim,
    'Tarım': BolumAilesi.uretim,
    'Eğitim': BolumAilesi.toplum,
    'Sağlık': BolumAilesi.toplum,
    'Kültür ve Turizm': BolumAilesi.yasam,
    'Spor': BolumAilesi.yasam,
  };

  /// Küçük görselde gösterilen üç harfli damga.
  ///
  /// Küçük görsel önce tamamen yazısızdı: 104×76'lık blokta kategori adı
  /// sığmadığı için hiçbir şey basılmıyordu ve geriye anlamsız renkli bir
  /// dikdörtgen kalıyordu — ekranda bozuk görsel gibi okunuyor. Yayındaki
  /// haberin %30'unun fotoğrafı yok.
  ///
  /// Elle yazılı: otomatik kesme Türkçede yanlış üretiyor ("Eğitim" →
  /// "EGI") ve iki kelimeli adlarda anlamsız kalıyor. Aynı ailedeki iki
  /// bölümün rengi aynı ama damgası ayrı — ayrımı damga taşıyor.
  static const _kisaltmalar = <String, String>{
    'Asayiş': 'ASY',
    'Kaza ve Acil': 'KAZ',
    'Gündem': 'GND',
    'Kent ve Yönetim': 'KNT',
    'Ekonomi': 'EKO',
    'Tarım': 'TAR',
    'Eğitim': 'EĞT',
    'Sağlık': 'SAĞ',
    'Kültür ve Turizm': 'KÜL',
    'Spor': 'SPR',
  };

  static BolumAilesi aile(String? kategoriAd) =>
      _aileler[kategoriAd] ?? BolumAilesi.diger;

  static Color renk(String? kategoriAd) => aile(kategoriAd).renk;

  /// Bu ailenin kapsadığı kategori adları.
  static Set<String> adlar(BolumAilesi a) =>
      _aileler.entries.where((e) => e.value == a).map((e) => e.key).toSet();

  /// Listede olmayan bir kategori için yedek: ilk üç harf, Türkçe
  /// büyütmeyle.
  static String kisalt(String kategoriAd) {
    final hazir = _kisaltmalar[kategoriAd];
    if (hazir != null) return hazir;
    final sade = kategoriAd.trim();
    return buyult(sade.length <= 3 ? sade : sade.substring(0, 3));
  }
}
