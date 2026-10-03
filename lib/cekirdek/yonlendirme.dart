import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../ozellikler/anasayfa/ekran/anasayfa_ekrani.dart';
import '../ozellikler/arama/ekran/arama_ekrani.dart';
import '../ozellikler/haber/ekran/haber_ekrani.dart';
import '../ozellikler/ilcem/ekran/ilcem_ekrani.dart';
import '../ozellikler/inceleme/ekran/giris_ekrani.dart';
import '../ozellikler/inceleme/ekran/inceleme_ekrani.dart';
import '../ozellikler/kaydedilen/ekran/kaydedilen_ekrani.dart';
import 'kabuk.dart';
import 'supabase.dart';

/// Oturum değişimini yönlendiriciye duyuran köprü.
///
/// GoRouter'ın `redirect`'i YALNIZCA gezinme olduğunda çalışıyor; oturum
/// durumu değiştiğinde kendiliğinden yeniden değerlendirmiyor. Bu köprü
/// olmadan giriş başarılı oluyor ama ekran giriş formunda kalıyor —
/// kullanıcıya hiçbir uyarı da çıkmıyor, düğme sessizce eski hâline
/// dönüyor. Tam olarak bu yaşandı.
class _OturumDinleyici extends ChangeNotifier {
  _OturumDinleyici(Stream<dynamic> akis) {
    _abone = akis.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _abone;

  @override
  void dispose() {
    _abone.cancel();
    super.dispose();
  }
}

/// Yönlendirme.
///
/// `/` herkese açık — anon anahtarla yalnızca yayındaki haber görülüyor.
/// `/panel` oturum istiyor; oturumsuz gelen `/giris`e yönleniyor.
/// Koruma burada değil RLS'te; bu yönlendirme yalnızca kullanıcıya boş
/// ekran göstermemek için.
final yonlendirici = GoRouter(
  initialLocation: '/',
  refreshListenable: _OturumDinleyici(sb.auth.onAuthStateChange),
  redirect: (context, durum) {
    final oturumVar = sb.auth.currentSession != null;
    final yol = durum.matchedLocation;
    if (yol == '/panel' && !oturumVar) return '/giris';
    if (yol == '/giris' && oturumVar) return '/panel';
    return null;
  },
  routes: [
    // Üç sekme tek kabuğun altında. `indexedStack` her dalın durumunu
    // koruyor: İlçem'e geçip Gündem'e dönünce akış kaydırma konumunu
    // kaybetmiyor.
    StatefulShellRoute.indexedStack(
      builder: (c, s, gezinti) => Kabuk(gezinti: gezinti),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (c, s) => const AnasayfaEkrani()),
            GoRoute(
              path: '/kategori/:slug',
              builder: (c, s) =>
                  AnasayfaEkrani(kategoriSlug: s.pathParameters['slug']),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/ilcem', builder: (c, s) => const IlcemEkrani()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/kaydettiklerim',
              builder: (c, s) => const KaydedilenEkrani(),
            ),
          ],
        ),
      ],
    ),
    // Haber sayfası kabuğun DIŞINDA: okurken alt çubuk yer kaplamasın.
    // Kaydetme düğmesi zaten haberin kendi başlığında.
    GoRoute(
      path: '/haber/:slug',
      builder: (c, s) => HaberEkrani(slug: s.pathParameters['slug']!),
    ),
    // Arama kabuğun DIŞINDA: klavye açıkken alt çubuk yer kaplamasın.
    GoRoute(
      path: '/ara',
      builder: (c, s) => AramaEkrani(baslangic: s.uri.queryParameters['q']),
    ),
    GoRoute(path: '/giris', builder: (c, s) => const GirisEkrani()),
    GoRoute(path: '/panel', builder: (c, s) => const IncelemeEkrani()),
  ],
);
