import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'tema.dart';
import 'tercihler.dart';

/// Üç sekmeyi saran kabuk.
///
/// Neden alt çubuk
/// ───────────────
/// Önceki düzende ilçe süzgeci ana sayfanın tepesinde 52 piksellik ikinci
/// bir çubuktu ve her okura 20 ilçeyi birden gösteriyordu. Ölçümde telefonda
/// ilk ekranda tek bir başlık kalıyordu. Oysa okur her gün 20 ilçeye
/// bakmıyor, kendi ilçesine bakıyor — süzgeç bir liste değil, bir ayar.
///
/// Süzgeç "İlçem" sekmesine taşınınca tepedeki çubuk tamamen kalktı; aynı
/// ekranda beş başlık görünür oldu. Alt çubuk ayrıca portalı PWA olarak
/// uygulamaya yaklaştırıyor.
///
/// Geniş ekranda alt çubuk gösterilmiyor: orada aynı üç yer künyenin
/// sağında duruyor (bkz. `_Kunye`), çünkü masaüstünde ekranın altı gözün
/// gitmediği yer.
class Kabuk extends ConsumerWidget {
  const Kabuk({super.key, required this.gezinti});

  final StatefulNavigationShell gezinti;

  /// Alt çubuğun görüneceği azami genişlik.
  static const darEsik = 760.0;

  static bool darMi(BuildContext c) =>
      MediaQuery.sizeOf(c).width < darEsik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = Renkler.of(context);
    if (!darMi(context)) return Scaffold(body: gezinti);

    final kayitliAdet = ref.watch(kaydedilenlerSaglayici).length;

    return Scaffold(
      body: gezinti,
      bottomNavigationBar: DecoratedBox(
        // Gazete kuralı: alt çubuk sayfadan kalın bir çizgiyle ayrılıyor,
        // gölgeyle değil.
        decoration: BoxDecoration(
          color: r.kart,
          border: Border(top: BorderSide(color: r.murekkep, width: 2)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                _Sekme(
                  simge: Icons.article_outlined,
                  simgeEtkin: Icons.article,
                  ad: 'Gündem',
                  etkin: gezinti.currentIndex == 0,
                  bas: () => _git(0),
                ),
                _Sekme(
                  simge: Icons.place_outlined,
                  simgeEtkin: Icons.place,
                  ad: 'İlçem',
                  etkin: gezinti.currentIndex == 1,
                  bas: () => _git(1),
                ),
                _Sekme(
                  simge: Icons.bookmark_outline,
                  simgeEtkin: Icons.bookmark,
                  ad: 'Kaydettiklerim',
                  etkin: gezinti.currentIndex == 2,
                  adet: kayitliAdet,
                  bas: () => _git(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _git(int dal) {
    // Etkin sekmeye tekrar basmak o dalın köküne dönüyor — kategori
    // sayfasındayken "Gündem"e basınca ana sayfaya çıkmanın yolu bu.
    gezinti.goBranch(dal, initialLocation: dal == gezinti.currentIndex);
  }
}

class _Sekme extends StatelessWidget {
  const _Sekme({
    required this.simge,
    required this.simgeEtkin,
    required this.ad,
    required this.etkin,
    required this.bas,
    this.adet = 0,
  });

  final IconData simge;
  final IconData simgeEtkin;
  final String ad;
  final bool etkin;
  final VoidCallback bas;
  final int adet;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    final renk = etkin ? r.patina : r.solgun;
    return Expanded(
      child: Semantics(
        selected: etkin,
        button: true,
        child: InkWell(
          onTap: bas,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(etkin ? simgeEtkin : simge, size: 22, color: renk),
                  if (adet > 0)
                    Positioned(
                      right: -9,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: r.bakir,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(9)),
                        ),
                        child: Text(
                          '$adet',
                          style: const TextStyle(
                            fontFamily: Tema.sans,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                ad,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: Tema.sans,
                  fontSize: 11,
                  fontWeight: etkin ? FontWeight.w600 : FontWeight.w400,
                  color: renk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Künyenin sağındaki gezinti — yalnızca geniş ekranda.
///
/// Alt çubuğun masaüstü karşılığı. Aynı üç yer, aynı sıra.
class GenisGezinti extends ConsumerWidget {
  const GenisGezinti({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = Renkler.of(context);
    final adet = ref.watch(kaydedilenlerSaglayici).length;
    final yol = GoRouterState.of(context).matchedLocation;

    Widget bag(String ad, String hedef, IconData simge, {int rozet = 0}) {
      final etkin = hedef == '/'
          ? (yol == '/' || yol.startsWith('/kategori'))
          : yol.startsWith(hedef);
      final renk = etkin ? r.patina : r.solgun;
      return TextButton.icon(
        onPressed: () => context.go(hedef),
        icon: Icon(simge, size: 17, color: renk),
        label: Text(
          rozet > 0 ? '$ad · $rozet' : ad,
          style: TextStyle(
            fontFamily: Tema.sans,
            fontSize: 13.5,
            fontWeight: etkin ? FontWeight.w600 : FontWeight.w400,
            color: renk,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        bag('Gündem', '/', Icons.article_outlined),
        bag('İlçem', '/ilcem', Icons.place_outlined),
        bag(
          'Kaydettiklerim',
          '/kaydettiklerim',
          Icons.bookmark_outline,
          rozet: adet,
        ),
      ],
    );
  }
}
