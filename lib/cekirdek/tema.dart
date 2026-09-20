import 'package:flutter/material.dart';

/// Kastamonu Haber tema tanımı.
///
/// Renk: Küre bakır patinası yeşili. Kastamonu'nun kendi malzemesinden —
/// bakır madeni ve orman — geliyor; hazır bir kurumsal maviden değil.
/// Başlıklarda serif kullanılıyor: haber portalı okunmak için var ve
/// serif uzun başlıkta gözü daha az yoruyor. Sistem fontları tercih
/// edildi; çalışma anında font indirmek ilk yükü büyütüyor.
class Tema {
  static const patina = Color(0xFF0D6B5A);
  static const bakir = Color(0xFFA84A18);
  static const zemin = Color(0xFFF7F8F6);
  static const murekkep = Color(0xFF16211D);
  static const solgun = Color(0xFF6E7A73);
  static const cizgi = Color(0xFFD6DDD8);
  static const sunk = Color(0xFFEDF0EC);

  static const serif = 'Georgia';

  static ThemeData olustur() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: patina, surface: zemin),
    );
    return base.copyWith(
      scaffoldBackgroundColor: zemin,
      textTheme: base.textTheme.copyWith(
        displaySmall: const TextStyle(
          fontFamily: serif,
          fontWeight: FontWeight.w700,
          height: 1.15,
          letterSpacing: -0.5,
          color: murekkep,
        ),
        headlineSmall: const TextStyle(
          fontFamily: serif,
          fontWeight: FontWeight.w700,
          height: 1.22,
          color: murekkep,
        ),
        titleLarge: const TextStyle(
          fontFamily: serif,
          fontWeight: FontWeight.w700,
          height: 1.25,
          color: murekkep,
        ),
        titleMedium: const TextStyle(
          fontFamily: serif,
          fontWeight: FontWeight.w700,
          height: 1.3,
          color: murekkep,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: cizgi),
        ),
      ),
      dividerTheme: const DividerThemeData(color: cizgi, space: 1),
    );
  }
}
