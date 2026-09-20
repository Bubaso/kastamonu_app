import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../cekirdek/metin.dart';
import '../../../cekirdek/tema.dart';
import '../../../cekirdek/tercihler.dart';
import '../../inceleme/model/haber.dart';
import '../../anasayfa/ekran/anasayfa_ekrani.dart' show gecenSure;
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
    // Okurun seçtiği punto. Gövde tam çarpanla, başlık daha yumuşak
    // büyüyor: başlık zaten büyük, aynı çarpanla üç satır daha uzuyor.
    final carpan = ref.watch(puntoSaglayici).carpan;
    final baslikCarpani = 1 + (carpan - 1) * 0.45;
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
                    const SizedBox(height: 12),
                    Text(
                      haber.baslik,
                      style: TextStyle(
                        fontFamily: Tema.serif,
                        fontWeight: FontWeight.w700,
                        fontSize: 31 * baslikCarpani,
                        height: 1.14,
                        letterSpacing: -0.6,
                        color: Tema.murekkep,
                      ),
                    ),
                    if ((haber.spot ?? '').isNotEmpty) ...[
                      const SizedBox(height: 13),
                      Text(
                        haber.spot!,
                        style: TextStyle(
                          fontFamily: Tema.serif,
                          fontSize: 18.5 * carpan,
                          height: 1.5,
                          // Spot artık `solgun` değil: giriş paragrafı
                          // okunacak metin, künye değil.
                          color: Tema.murekkepIkincil,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // Gerçek kaynak fotoğrafı varsa gösteriliyor; atıf
                    // hemen altında. Tipografik karta düşüldüyse burada
                    // görsel yok — başlık zaten sayfanın tepesinde.
                    if ((haber.gorselKaynak ?? '').isNotEmpty &&
                        (haber.gorselUrl ?? '').isNotEmpty) ...[
                      AspectRatio(
                        aspectRatio: 1200 / 630,
                        child: Image.network(
                          haber.gorselUrl!,
                          fit: BoxFit.cover,
                          // Ana sayfadaki ile aynı gerekçe: CanvasKit'te
                          // `loadingProgress` yükleme boyunca null kaldığı
                          // için yerinde beyaz boşluk duruyordu.
                          // `frameBuilder` ilk kare boyanana kadar zemini
                          // dolduruyor.
                          frameBuilder: (c, cocuk, kare, esGirdi) =>
                              kare == null
                              ? const ColoredBox(
                                  color: Tema.sunkKoyu,
                                  child: SizedBox.expand(),
                                )
                              : cocuk,
                          errorBuilder: (c, e, s) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Fotoğraf: ${haber.gorselKaynak}',
                        style: const TextStyle(
                          fontFamily: Tema.sans,
                          fontSize: 12,
                          color: Tema.solgun,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    // Punto ayarı metnin hemen başında — okur zorlandığı
                    // anda görüyor, aramak zorunda kalmıyor.
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: _PuntoSecici(),
                    ),
                    const Divider(),
                    const SizedBox(height: 22),
                    ...paragraflar.map(
                      (p) => Padding(
                        padding: EdgeInsets.only(bottom: 15 * carpan),
                        child: Text(
                          p,
                          style: TextStyle(
                            fontFamily: Tema.serif,
                            // 17,5 taban: 45 yaş okur için asgari.
                            fontSize: 17.5 * carpan,
                            height: 1.7,
                            color: Tema.murekkep,
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

class _UstCubuk extends ConsumerWidget {
  const _UstCubuk({required this.haber});
  final Haber haber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kayitli = ref.watch(kaydedilenlerSaglayici).contains(haber.slug);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Tema.murekkep, width: 2)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
            child: Row(
              children: [
                IconButton(
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/'),
                  icon: const Icon(Icons.arrow_back, size: 22),
                  color: Tema.murekkep,
                  tooltip: 'Geri',
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => context.go('/'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Kastamonu Haber',
                        style: TextStyle(
                          fontFamily: Tema.serif,
                          fontWeight: FontWeight.w700,
                          fontSize: 19,
                          letterSpacing: -0.4,
                          color: Tema.murekkep,
                        ),
                      ),
                    ),
                  ),
                ),
                // Kaydetme haberin kendi başlığında: okur "bunu sonra
                // okurum" kararını tam burada veriyor.
                IconButton(
                  onPressed: () => _kaydet(context, ref),
                  icon: Icon(
                    kayitli ? Icons.bookmark : Icons.bookmark_outline,
                    size: 22,
                  ),
                  color: kayitli ? Tema.bakir : Tema.solgun,
                  tooltip: kayitli ? 'Kayıttan çıkar' : 'Kaydet',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _kaydet(BuildContext context, WidgetRef ref) async {
    final artikKayitli =
        await ref.read(kaydedilenlerSaglayici.notifier).degistir(haber.slug);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(
            artikKayitli
                ? 'Kaydedildi — "Kaydettiklerim"de.'
                : 'Kayıttan çıkarıldı.',
          ),
          action: artikKayitli
              ? SnackBarAction(
                  label: 'Git',
                  textColor: Tema.patinaZemin,
                  onPressed: () => context.go('/kaydettiklerim'),
                )
              : null,
        ),
      );
  }
}

/// Punto ayarı.
///
/// Kastamonu'nun ortanca yaşı 43,3 ve 65 üstü oranı %21,1 — presbiyopi tam
/// bu yaşta başlıyor. Bu yüzden ayar bir ayarlar menüsünde değil, metnin
/// hemen başında: okur zorlandığı anda görüyor.
class _PuntoSecici extends ConsumerWidget {
  const _PuntoSecici();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secili = ref.watch(puntoSaglayici);
    return Row(
      children: [
        const Icon(Icons.text_fields, size: 17, color: Tema.solgun),
        const SizedBox(width: 9),
        const Text(
          'Yazı boyutu',
          style: TextStyle(
            fontFamily: Tema.sans,
            fontSize: 13,
            color: Tema.solgun,
          ),
        ),
        const Spacer(),
        ...Punto.values.map((p) {
          final etkin = p == secili;
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Material(
              color: etkin ? Tema.patina : Colors.white,
              child: InkWell(
                onTap: () => ref.read(puntoSaglayici.notifier).sec(p),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 38),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: etkin ? Tema.patina : Tema.cizgiKuvvetli,
                    ),
                  ),
                  child: Text(
                    'A',
                    style: TextStyle(
                      fontFamily: Tema.serif,
                      // Düğmenin kendisi ne yaptığını gösteriyor.
                      fontSize: 12 + p.index * 3.5,
                      fontWeight: FontWeight.w700,
                      color: etkin ? Colors.white : Tema.murekkep,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
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
        // Renk ayrımı bilgi taşıyor: bölüm patina, ilçe bakır.
        if (haber.kategoriAd != null)
          Text(
            buyult(haber.kategoriAd!),
            style: const TextStyle(
              fontFamily: Tema.sans,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Tema.patina,
            ),
          ),
        ...ilce.map(
          (ad) => Text(
            buyult(ad),
            style: const TextStyle(
              fontFamily: Tema.sans,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Tema.bakir,
            ),
          ),
        ),
        // Haber sayfasında hem göreli hem mutlak zaman: tazelik bir
        // bakışta, kayıt için tam tarih.
        Text(
          '${gecenSure(haber.olusturuldu)}  ·  '
          '${DateFormat("d MMMM y, HH:mm", 'tr').format(haber.olusturuldu)}',
          style: const TextStyle(
            fontFamily: Tema.sans,
            fontSize: 12,
            color: Tema.solgun,
          ),
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
        border: Border.all(color: Tema.cizgiKuvvetli),
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
            haber.kaynakKisa,
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
                          buyult(h.kategoriAd!),
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
