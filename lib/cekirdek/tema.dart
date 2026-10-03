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

  /// Açık ve koyu tema aynı yerden üretiliyor; fark yalnızca [r].
  static ThemeData olustur({
    Renkler r = Renkler.acik,
    Brightness parlaklik = Brightness.light,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: parlaklik,
      colorScheme: ColorScheme.fromSeed(
        seedColor: r.patina,
        brightness: parlaklik,
        surface: r.zemin,
        primary: r.patina,
        error: r.sonDakika,
      ),
      // Arayüzün varsayılanı Archivo; serif yalnızca haber metninde.
      fontFamily: sans,
    );

    return base.copyWith(
      extensions: [r],
      scaffoldBackgroundColor: r.zemin,
      textTheme: base.textTheme.copyWith(
        // ── Haber dizgisi (Newsreader) ──────────────────────
        displaySmall: TextStyle(
          fontFamily: serif,
          fontWeight: FontWeight.w700,
          fontSize: 34,
          height: 1.14,
          letterSpacing: -0.7,
          color: r.murekkep,
        ),
        headlineSmall: TextStyle(
          fontFamily: serif,
          fontWeight: FontWeight.w700,
          fontSize: 24,
          height: 1.18,
          letterSpacing: -0.35,
          color: r.murekkep,
        ),
        titleLarge: TextStyle(
          fontFamily: serif,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          height: 1.19,
          letterSpacing: -0.3,
          color: r.murekkep,
        ),
        // Akıştaki satır başlıkları — manşetten yarım kademe hafif.
        titleMedium: TextStyle(
          fontFamily: serif,
          fontWeight: FontWeight.w600,
          fontSize: 16,
          height: 1.27,
          letterSpacing: -0.12,
          color: r.murekkep,
        ),
        // Haber gövdesi. 17,5 taban; okur punto ayarıyla büyütebiliyor.
        bodyLarge: TextStyle(
          fontFamily: serif,
          fontWeight: FontWeight.w400,
          fontSize: 17.5,
          height: 1.66,
          color: r.murekkep,
        ),
        // Spot / giriş paragrafı.
        bodyMedium: TextStyle(
          fontFamily: serif,
          fontWeight: FontWeight.w400,
          fontSize: 16.5,
          height: 1.52,
          color: r.murekkepIkincil,
        ),
        // ── Arayüz (Archivo) ────────────────────────────────
        bodySmall: TextStyle(
          fontFamily: sans,
          fontSize: 13,
          height: 1.4,
          color: r.solgun,
        ),
        labelLarge: const TextStyle(
          fontFamily: sans,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        labelMedium: etiket,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: r.kart,
        // Gazete köşesi keskindir. Önceki 10 px yuvarlaklık uygulamayı
        // habere değil panele benzetiyordu.
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(2)),
          side: BorderSide(color: r.cizgi),
        ),
      ),
      dividerTheme: DividerThemeData(color: r.cizgi, space: 1, thickness: 1),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: r.patinaZemin,
        cursorColor: r.patina,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: r.patina,
          foregroundColor: r.patinaUstu,
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: r.murekkep,
        contentTextStyle: TextStyle(
          fontFamily: sans,
          fontSize: 14.5,
          // Zemin `murekkep`; yazı da zeminin karşıtı olmak zorunda.
          // Sabit açık renk yazılsaydı koyu temada açık üstüne açık
          // düşerdi.
          color: r.zemin,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Temaya bağlı renkler.
///
/// Neden ayrı bir katman
/// ─────────────────────
/// [Tema] içindeki değerler `const`: `const TextStyle(color: Tema.murekkep)`
/// yazabilmek bundan geliyor ve derleme anında sabit oldukları için temaya
/// göre değişemiyorlar. Koyu tema, tek bir kaynaktan okunan ve bağlamla
/// gelen bir renk kümesi istiyor — burası o küme.
///
/// Kullanımı: her `build` başında bir kez `final r = Renkler.of(context);`
/// ve sonra `r.murekkep`.
///
/// Koyu değerler tahminle seçilmedi, hesaplandı. Portalın okur kitlesi için
/// kontrast bir üslup tercihi değil kısıt (ortanca yaş 43,3, 65 üstü oranı
/// %21,1), dolayısıyla koyu temada da hiçbir metin rengi WCAG AA'nın
/// altına düşmüyor: en düşük oran `solgun`, zemin üstünde 6,12:1.
@immutable
class Renkler extends ThemeExtension<Renkler> {
  const Renkler({
    required this.zemin,
    required this.sunk,
    required this.sunkKoyu,
    required this.kart,
    required this.murekkep,
    required this.murekkepIkincil,
    required this.solgun,
    required this.patina,
    required this.patinaUstu,
    required this.patinaZemin,
    required this.bakir,
    required this.sonDakika,
    required this.uyari,
    required this.cizgi,
    required this.cizgiKuvvetli,
    required this.kusak,
    required this.kusakMetin,
    required this.kusakIkincil,
  });

  /// Sayfa zemini.
  final Color zemin;

  /// Bir ve iki kademe çökük yüzeyler.
  final Color sunk;
  final Color sunkKoyu;

  /// Kart ve şerit yüzeyi. Açık temada beyaz; koyu temada zeminden bir
  /// kademe açık, yoksa kartın nerede bittiği görünmüyor.
  final Color kart;

  final Color murekkep;
  final Color murekkepIkincil;
  final Color solgun;

  final Color patina;

  /// Patina ZEMİN olarak kullanıldığında üstüne düşen yazı.
  ///
  /// Açık temada patina koyu bir yeşil, üstüne beyaz geliyor (7,61:1).
  /// Koyu temada açılıyor ve beyaz yazı 2,84:1'e düşüyor — AA'nın çok
  /// altı. Koyu temada üstüne sayfa zemini düşüyor: 6,59:1.
  final Color patinaUstu;

  final Color patinaZemin;
  final Color bakir;

  /// Son dakika bandının ZEMİNİ. Üstünde her zaman beyaz yazı var.
  final Color sonDakika;

  /// Kırmızının YAZI olarak kullanımı (yıkıcı eylemler).
  ///
  /// Bantla aynı değer olamıyor: bant zemin olduğu için koyulaşması,
  /// yazı ise zeminden ayrılmak için açılması gerekiyor. Koyu temada tek
  /// bir kırmızı ikisini birden yapamıyor.
  final Color uyari;

  final Color cizgi;
  final Color cizgiKuvvetli;

  /// Kapaktaki asayiş kuşağının zemini.
  ///
  /// Açık temada mürekkep. Koyu temada mürekkep OLAMAZ: sayfa zemini zaten
  /// o renk, kuşak görünmez olurdu. Bir kademe açık ve sıcak bir kömür.
  final Color kusak;
  final Color kusakMetin;

  /// Kuşaktaki yer etiketi — bakırın kuşak üstündeki karşılığı.
  final Color kusakIkincil;

  static const acik = Renkler(
    zemin: Tema.zemin,
    sunk: Tema.sunk,
    sunkKoyu: Tema.sunkKoyu,
    kart: Colors.white,
    murekkep: Tema.murekkep,
    murekkepIkincil: Tema.murekkepIkincil,
    solgun: Tema.solgun,
    patina: Tema.patina,
    patinaUstu: Colors.white, // 7,61:1
    patinaZemin: Tema.patinaZemin,
    bakir: Tema.bakir,
    sonDakika: Tema.sonDakika,
    uyari: Tema.sonDakika,
    cizgi: Tema.cizgi,
    cizgiKuvvetli: Tema.cizgiKuvvetli,
    kusak: Tema.murekkep,
    kusakMetin: Tema.zemin,
    kusakIkincil: Color(0xFFC9B99A),
  );

  static const koyu = Renkler(
    // Açık temanın mürekkebi koyu temanın zemini oluyor; palet kendi
    // içinde dönüyor, yeni bir renk ailesi uydurulmuyor.
    zemin: Color(0xFF14120F),
    sunk: Color(0xFF1F1B16),
    sunkKoyu: Color(0xFF2A241D),
    kart: Color(0xFF1A1713),
    murekkep: Color(0xFFF3EFE8), // zemin üstünde 16,31:1
    murekkepIkincil: Color(0xFFCFC7BA), // 11,16:1
    solgun: Color(0xFF9C9286), // 6,12:1 — koyu temanın en düşüğü
    patina: Color(0xFF4FA98F), // 6,59:1
    patinaUstu: Color(0xFF14120F), // patina üstünde 6,59:1
    patinaZemin: Color(0xFF16302A),
    bakir: Color(0xFFDB8551), // 6,66:1
    // Bant zemini koyulaşıyor: üstündeki beyaz yazı 6,5:1 kalıyor ve
    // kömür zeminde parlamıyor.
    sonDakika: Color(0xFFB81228),
    // Yazı olarak kırmızı ise açılıyor: zemin üstünde 6,56:1.
    uyari: Color(0xFFF0717F),
    cizgi: Color(0xFF332E26),
    cizgiKuvvetli: Color(0xFF4C453A),
    kusak: Color(0xFF2A241D),
    kusakMetin: Color(0xFFF3EFE8),
    kusakIkincil: Color(0xFFC9B99A),
  );

  static Renkler of(BuildContext context) =>
      Theme.of(context).extension<Renkler>() ?? acik;

  @override
  Renkler copyWith() => this;

  @override
  Renkler lerp(ThemeExtension<Renkler>? other, double t) =>
      // Tema geçişinde ara renk üretilmiyor: gazete yüzeyi yarı yolda
      // çamur rengine düşmesin, bir karede değişsin.
      t < 0.5 ? this : (other as Renkler? ?? this);
}
