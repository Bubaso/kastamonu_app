import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../ozellikler/anasayfa/ekran/anasayfa_ekrani.dart';
import '../ozellikler/haber/ekran/haber_ekrani.dart';
import '../ozellikler/inceleme/ekran/giris_ekrani.dart';
import '../ozellikler/inceleme/ekran/inceleme_ekrani.dart';
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
    GoRoute(path: '/', builder: (c, s) => const AnasayfaEkrani()),
    GoRoute(
      path: '/kategori/:slug',
      builder: (c, s) => AnasayfaEkrani(kategoriSlug: s.pathParameters['slug']),
    ),
    GoRoute(
      path: '/haber/:slug',
      builder: (c, s) => HaberEkrani(slug: s.pathParameters['slug']!),
    ),
    GoRoute(path: '/giris', builder: (c, s) => const GirisEkrani()),
    GoRoute(path: '/panel', builder: (c, s) => const IncelemeEkrani()),
  ],
);
