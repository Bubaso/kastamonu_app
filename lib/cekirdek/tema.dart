import 'package:flutter/material.dart';

/// Kastamonu Haber tema tanımı.
///
/// Tasarımı belirleyen kısıt
/// ─────────────────────────
/// Kastamonu, TÜİK 2025'e göre Türkiye'nin ortanca yaşı en yüksek üçüncü
/// ili (43,3) ve 65 yaş üstü oranında ikinci (%21,1). Presbiyopi tam bu
/// yaşta başlıyor. Bu yüzden buradaki punto ve kontrast değerleri üslup
/// tercihi değil: gövde metni 17,5 px'in altına inmez, hiçbir metin rengi
/// WCAG AA'nın (4,5:1) altına düşmez.
///
/// Önceki palette `solgun` #6E7A73 idi ve zemin üzerinde 4,20:1 veriyordu —
/// yani özetlerin ve tarihlerin tamamı sınırın altındaydı. Yeni değer
/// 5,59:1.
///
/// Renk nereden geliyor
/// ────────────────────
/// Bakır (Bakırcılar Çarşısı hâlâ çalışıyor), orman (693 bin hektar verimli
/// ormanla Türkiye birincisi) ve badanalı ahşap konak. Kırmızı bilerek
/// kıt tutuluyor: rakiplerin künyesi kırmızı, bizde yalnızca son dakika
/// bandı. Kırmızı her yerdeyse son dakika hiçbir yerdedir.
///
/// Yazı tipleri
/// ────────────
/// Gömülü — CanvasKit sistem fontlarını tanımıyor, `fontFamily: 'Georgia'`
/// sessizce Roboto'ya düşüyordu. Üretim yöntemi assets/fonts/BENIOKU.md.
class Tema {
  // ── Zeminler ────────────────────────────────────────────────
  /// Sayfa zemini. Badanalı duvarın sıcaklığında; önceki #F7F8F6 soğuktu.
  static const zemin = Color(0xFFFAF7F2);

  /// Bir kademe çökük yüzey — şerit, bölüm arası bant.
  static const sunk = Color(0xFFF1ECE4);

  /// İki kademe çökük — görsel yeri, boş kutu.
  static const sunkKoyu = Color(0xFFE6DFD4);

  // ── Metin ───────────────────────────────────────────────────
  /// Başlık ve gövde. Saf siyah değil; kâğıt üstünde saf siyah sert duruyor.
  static const murekkep = Color(0xFF14120F); // 17,5:1

  /// İkincil metin — spot, açıklama.
  static const murekkepIkincil = Color(0xFF3A342C); // 10,9:1

  /// Tarih, künye, özet. AA sınırının üstünde.
  static const solgun = Color(0xFF6B6259); // 5,59:1

  // ── Vurgular ────────────────────────────────────────────────
  /// Tek birincil vurgu: bölüm adı, bağlantı, etkin sekme.
  static const patina = Color(0xFF0A5F4E); // 7,12:1 — AAA

  /// Patinanın çok açık hali; seçili arka planlar için.
  static const patinaZemin = Color(0xFFE0EBE6);

  /// İkincil ve seyrek: ilçe etiketi, kaynak künyesi. Sayfada ikiden
  /// fazla yerde görünüyorsa yanlış kullanılmıştır.
  static const bakir = Color(0xFF9C4116); // 6,18:1

  /// Yalnızca son dakika bandı. Başka hiçbir yerde kullanılmaz.
  static const sonDakika = Color(0xFFC0142B); // 5,82:1

  // ── Çizgiler ────────────────────────────────────────────────
  static const cizgi = Color(0xFFDDD5C8);
  static const cizgiKuvvetli = Color(0xFFBEB3A2);

  // ── Yazı tipleri ────────────────────────────────────────────
  /// Manşet, akış başlıkları, haber gövdesi.
  static const serif = 'Newsreader';

  /// Arayüz: sekme, düğme, künye, versal bölüm etiketleri.
  static const sans = 'Archivo';

  /// Versal bölüm etiketi — "EĞİTİM", "SON DAKİKA".
  /// Serif bu boyda versal olarak okunmuyor; her zaman Archivo.
  static const TextStyle etiket = TextStyle(
    fontFamily: sans,
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.3,
    height: 1.1,
  );

  /// Tarih ve künye satırı.
  static const TextStyle kunye = TextStyle(
    fontFamily: sans,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: solgun,
    height: 1.3,
  );

  static ThemeData olustur() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: patina,
        surface: zemin,
        primary: patina,
        error: sonDakika,
      ),
      // Arayüzün varsayılanı Archivo; serif yalnızca haber metninde.
      fontFamily: sans,
    );

    return base.copyWith(
      scaffoldBackgroundColor: zemin,
      textTheme: base.textTheme.copyWith(
        // ── Haber dizgisi (Newsreader) ──────────────────────
        displaySmall: const TextStyle(
          fontFamily: serif,
          fontWeight: FontWeight.w700,
          fontSize: 34,
          height: 1.14,
          letterSpacing: -0.7,
          color: murekkep,
        ),
        headlineSmall: const TextStyle(
          fontFamily: serif,
          fontWeight: FontWeight.w700,
          fontSize: 24,
          height: 1.18,
          letterSpacing: -0.35,
          color: murekkep,
        ),
        titleLarge: const TextStyle(
          fontFamily: serif,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          height: 1.19,
          letterSpacing: -0.3,
          color: murekkep,
        ),
        // Akıştaki satır başlıkları — manşetten yarım kademe hafif.
        titleMedium: const TextStyle(
          fontFamily: serif,
          fontWeight: FontWeight.w600,
          fontSize: 16,
          height: 1.27,
          letterSpacing: -0.12,
          color: murekkep,
        ),
        // Haber gövdesi. 17,5 taban; okur punto ayarıyla büyütebiliyor.
        bodyLarge: const TextStyle(
          fontFamily: serif,
          fontWeight: FontWeight.w400,
          fontSize: 17.5,
          height: 1.66,
          color: murekkep,
        ),
        // Spot / giriş paragrafı.
        bodyMedium: const TextStyle(
          fontFamily: serif,
          fontWeight: FontWeight.w400,
          fontSize: 16.5,
          height: 1.52,
          color: murekkepIkincil,
        ),
        // ── Arayüz (Archivo) ────────────────────────────────
        bodySmall: const TextStyle(
          fontFamily: sans,
          fontSize: 13,
          height: 1.4,
          color: solgun,
        ),
        labelLarge: const TextStyle(
          fontFamily: sans,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        labelMedium: etiket,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Colors.white,
        // Gazete köşesi keskindir. Önceki 10 px yuvarlaklık uygulamayı
        // habere değil panele benzetiyordu.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
          side: BorderSide(color: cizgi),
        ),
      ),
      dividerTheme: const DividerThemeData(color: cizgi, space: 1, thickness: 1),
      textSelectionTheme: const TextSelectionThemeData(
        selectionColor: patinaZemin,
        cursorColor: patina,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: patina,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontFamily: sans,
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
          // 45 yaş üstü okur için dokunma hedefi cömert tutuluyor.
          minimumSize: const Size(0, 48),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: murekkep,
        contentTextStyle: TextStyle(
          fontFamily: sans,
          fontSize: 14.5,
          color: Color(0xFFFAF7F2),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
