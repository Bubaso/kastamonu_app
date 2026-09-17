import 'package:go_router/go_router.dart';

import '../ozellikler/anasayfa/ekran/anasayfa_ekrani.dart';
import '../ozellikler/inceleme/ekran/giris_ekrani.dart';
import '../ozellikler/inceleme/ekran/inceleme_ekrani.dart';
import 'supabase.dart';

/// Yönlendirme.
///
/// `/` herkese açık — anon anahtarla yalnızca yayındaki haber görülüyor.
/// `/panel` oturum istiyor; oturumsuz gelen `/giris`e yönleniyor.
/// Koruma burada değil RLS'te; bu yönlendirme yalnızca kullanıcıya boş
/// ekran göstermemek için.
final yonlendirici = GoRouter(
  initialLocation: '/',
  redirect: (context, durum) {
    final oturumVar = sb.auth.currentSession != null;
    final yol = durum.matchedLocation;
    if (yol == '/panel' && !oturumVar) return '/giris';
    if (yol == '/giris' && oturumVar) return '/panel';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (c, s) => const AnasayfaEkrani()),
    GoRoute(path: '/giris', builder: (c, s) => const GirisEkrani()),
    GoRoute(path: '/panel', builder: (c, s) => const IncelemeEkrani()),
  ],
);
