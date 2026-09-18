import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../cekirdek/tema.dart';
import '../../inceleme/model/haber.dart';
import '../../anasayfa/veri/anasayfa_deposu.dart';
import '../veri/haber_deposu.dart';

class HaberEkrani extends ConsumerWidget {
  const HaberEkrani({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Haber, paylaşılan listeden alınıyor — kendi sorgusunu ATMIYOR.
    //
    // Bu sayfa önce iki ayrı sorgu atıyordu: biri haberin kendisi, biri
    // alt şerit. Ana sayfadan gelindiğinde ikisi de çalışıyordu; doğrudan
    // adrese girildiğinde (paylaşılan bağlantı) alt şerit sorgusu HİÇ
    // tamamlanmıyordu. Fark tek: derin bağlantıda ikisi de açılışta,
    // Supabase istemcisi daha oturumunu kurarken aynı anda tetikleniyor.
    // Tek sorguya indirmek sorunu ortadan kaldırıyor.
    //
    // Liste son 200 yayını kapsıyor; daha eski bir habere doğrudan
    // gelinirse `haberSaglayici` yedeği devreye giriyor.
    final tumu = ref.watch(tumYayindakilerSaglayici);

    return Scaffold(
      body: tumu.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (h, _) => _Uyari(metin: 'Haber yüklenemedi.\n$h'),
        data: (liste) {
          for (final h in liste) {
            if (h.slug == slug) return _Govde(haber: h);
          }
          return _YedekGetirme(slug: slug);
        },
      ),
    );
  }
}

/// Liste dışında kalmış (çok eski) haber için tek seferlik getirme.
class _YedekGetirme extends ConsumerWidget {
  const _YedekGetirme({required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final haber = ref.watch(haberSaglayici(slug));
    return haber.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (h, _) => _Uyari(metin: 'Haber yüklenemedi.\n$h'),
      data: (h) => h == null
          ? const _Uyari(
              metin: 'Bu haber bulunamadı ya da yayından kaldırıldı.',
            )
          : _Govde(haber: h),
    );
  }
}

class _Govde extends ConsumerStatefulWidget {
  const _Govde({required this.haber});
  final Haber haber;

  @override
  ConsumerState<_Govde> createState() => _GovdeState();
}

class _GovdeState extends ConsumerState<_Govde> {
  @override
  Widget build(BuildContext context) {
    final haber = widget.haber;
    final t = Theme.of(context);
    final paragraflar = (haber.govde ?? '')
        .split(RegExp(r'\n\s*\n|\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _UstCubuk(haber: haber)),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              // Okuma sütunu dar tutuluyor: uzun satır gözü yoruyor ve
              // Kastamonu'da 65 yaş üstü nüfus oranı %21 — Türkiye'de ikinci.
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Etiketler(haber: haber),
                    const SizedBox(height: 14),
                    Text(
                      haber.baslik,
                      style: t.textTheme.displaySmall?.copyWith(fontSize: 31),
                    ),
                    if ((haber.spot ?? '').isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        haber.spot!,
                        style: t.textTheme.bodyLarge?.copyWith(
                          fontSize: 17.5,
                          height: 1.55,
                          color: Tema.solgun,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 20),
                    ...paragraflar.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 17),
                        child: Text(
                          p,
                          style: t.textTheme.bodyLarge?.copyWith(
                            fontSize: 16.5,
                            height: 1.72,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _KaynakKutusu(haber: haber),
                    const SizedBox(height: 30),
                    _IlgiliBolum(haber: haber),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UstCubuk extends StatelessWidget {
  const _UstCubuk({required this.haber});
  final Haber haber;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Tema.cizgi)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 22, 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/'),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Geri',
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => context.go('/'),
                  child: Text(
                    'Kastamonu Haber',
                    style: t.textTheme.titleLarge?.copyWith(fontSize: 19),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Etiketler extends StatelessWidget {
  const _Etiketler({required this.haber});
  final Haber haber;

  @override
  Widget build(BuildContext context) {
    final ilce = haber.ilceler.where((b) => b.onaylandi).map((b) => b.ad);
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (haber.kategoriAd != null)
          Text(
            haber.kategoriAd!.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Tema.patina,
            ),
          ),
        ...ilce.map(
          (ad) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: Tema.cizgi),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              ad,
              style: const TextStyle(fontSize: 11.5, color: Tema.solgun),
            ),
          ),
        ),
        Text(
          DateFormat("d MMMM y, HH:mm", 'tr').format(haber.olusturuldu),
          style: const TextStyle(fontSize: 12, color: Tema.solgun),
        ),
      ],
    );
  }
}

/// Kaynak kutusu — telif zemininin görünür karşılığı.
///
/// FSEK 36 günlük havadisin kaynak göstererek iktibasına izin veriyor;
/// şart, kaynağın belirtilmesi. Bu kutu o şartın arayüzdeki hâli ve
/// okuyucuyu orijinal habere yönlendiriyor.
class _KaynakKutusu extends StatelessWidget {
  const _KaynakKutusu({required this.haber});
  final Haber haber;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Tema.cizgi),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'KAYNAK',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Tema.solgun,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            haber.yayinci?.isNotEmpty == true
                ? '${haber.yayinci} · ${haber.kaynakAdi}'
                : haber.kaynakAdi,
            style: t.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Bu haber kaynağındaki bilgilerden derlenmiştir. '
            'Tam metin için özgün habere gidebilirsiniz.',
            style: TextStyle(fontSize: 12.5, color: Tema.solgun, height: 1.45),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(haber.kaynakUrl),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Özgün habere git'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Tema.patina,
              side: const BorderSide(color: Tema.patina),
            ),
          ),
        ],
      ),
    );
  }
}

/// Detay sayfasının alt şeridi.
///
/// Kendi sorgusunu ATMIYOR: ana sayfanın da kullandığı paylaşılan
/// `tumYayindakilerSaglayici` listesinden bellekte süzüyor. Önceki sürüm
/// burada ayrı bir sorgu çalıştırıyordu ve bölüm hiç açılmadı — ne hata
/// verdi ne veri; birkaç farklı kurgu denendi, hiçbiri değiştirmedi.
/// Zaten yüklü listeyi kullanmak hem o sorunu tamamen atlıyor hem de
/// fazladan ağ isteği doğurmuyor.
class _IlgiliBolum extends ConsumerWidget {
  const _IlgiliBolum({required this.haber});
  final Haber haber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tumu = ref.watch(tumYayindakilerSaglayici);
    return tumu.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (liste) {
        final digerleri = liste.where((h) => h.id != haber.id).toList();
        if (digerleri.isEmpty) return const SizedBox.shrink();

        final benimIlceler = onayliIlceler(haber);
        // Önce aynı ilçeden: yerel portalda bu bağ kategoriden anlamlı.
        // Tosya haberi okuyan Tosya'nın başka haberini merak eder.
        final ayniIlce = digerleri
            .where(
              (h) => onayliIlceler(h).intersection(benimIlceler).isNotEmpty,
            )
            .toList();
        final ayniKategori = digerleri
            .where(
              (h) => h.kategoriAd != null && h.kategoriAd == haber.kategoriAd,
            )
            .toList();

        final secilen = <String, Haber>{};
        for (final h in [...ayniIlce, ...ayniKategori, ...digerleri]) {
          if (secilen.length >= 4) break;
          secilen[h.id] = h;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _Ilgililer(
            liste: secilen.values.toList(),
            // Başlık dürüst olsun: gerçekten aynı ilçeden haber yoksa
            // "ilgili" demek okuru yanıltır.
            baslik: ayniIlce.isNotEmpty ? 'AYNI İLÇEDEN' : 'DİĞER HABERLER',
          ),
        );
      },
    );
  }
}

class _Ilgililer extends StatelessWidget {
  const _Ilgililer({required this.liste, required this.baslik});
  final List<Haber> liste;
  final String baslik;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              baslik,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Tema.solgun,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 6),
        ...liste.map(
          (h) => InkWell(
            onTap: () => context.go('/haber/${h.slug}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      if (h.kategoriAd != null)
                        Text(
                          h.kategoriAd!.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .8,
                            color: Tema.patina,
                          ),
                        ),
                      ...h.ilceler
                          .where((b) => b.onaylandi)
                          .map(
                            (b) => Text(
                              b.ad,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Tema.solgun,
                              ),
                            ),
                          ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    h.baslik,
                    style: t.textTheme.titleMedium?.copyWith(fontSize: 15.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Uyari extends StatelessWidget {
  const _Uyari({required this.metin});
  final String metin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.article_outlined, size: 42, color: Tema.solgun),
            const SizedBox(height: 14),
            Text(
              metin,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Tema.solgun),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Ana sayfaya dön'),
            ),
          ],
        ),
      ),
    );
  }
}
