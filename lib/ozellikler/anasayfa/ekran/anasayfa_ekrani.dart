import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../cekirdek/bolum.dart';
import '../../../cekirdek/gorsel.dart';
import '../../../cekirdek/kabuk.dart';
import '../../../cekirdek/metin.dart';
import '../../../cekirdek/tema.dart';
import '../../../cekirdek/tercihler.dart';
import '../../inceleme/model/haber.dart';
import '../veri/anasayfa_deposu.dart';
import '../veri/kapak.dart';

/// Ana sayfa — portalın asıl ürünü.
///
/// Tarım Portalı'nda ürün haberin kendisi: okur aramadan tek bir yazı için
/// gelir, okur, çıkar. Şehir portalında ürün bu sayfa: aynı okur günde
/// birkaç kez uğrayıp "yeni ne var" diye bakar. Bu yüzden buradaki düzen
/// bir dergi açılışı değil, bir **fihrist**.
///
/// Ölçüm: önceki düzende 375×812 telefonda ilk ekranda tek başlık
/// görünüyordu (künye 92 px + bölüm çubuğu 50 px + ilçe çubuğu 52 px, sonra
/// tek kart ve altı satırlık özet). Şimdi beş başlık görünüyor:
/// künye 44'e indi, ilçe çubuğu "İlçem" sekmesine taşındı, ikincil
/// haberlerde özet kalktı ve kart yerine satır kullanılıyor.
class AnasayfaEkrani extends ConsumerStatefulWidget {
  const AnasayfaEkrani({super.key, this.kategoriSlug});

  /// `/kategori/:slug` ile gelindiğinde dolu; ana sayfada null.
  final String? kategoriSlug;

  @override
  ConsumerState<AnasayfaEkrani> createState() => _AnasayfaEkraniState();
}

class _AnasayfaEkraniState extends ConsumerState<AnasayfaEkrani> {
  @override
  void initState() {
    super.initState();
    // Adres çubuğundaki kategori, süzgeç durumuna yansıtılıyor. Böylece
    // /kategori/spor paylaşılabilir bir adres oluyor; süzgeç yalnızca
    // uygulama içi bir durum değil.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(kategoriSecimiSaglayici.notifier).sec(widget.kategoriSlug);
    });
  }

  @override
  void didUpdateWidget(AnasayfaEkrani eski) {
    super.didUpdateWidget(eski);
    if (eski.kategoriSlug != widget.kategoriSlug) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(kategoriSecimiSaglayici.notifier).sec(widget.kategoriSlug);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final haberler = ref.watch(yayindakilerSaglayici);

    // Kategori sayfasında künye bölüm adını taşıyor: /kategori/spor
    // paylaşılabilir bir adres ve açıldığında kendini tanıtmalı.
    // Bölüm çubuğundaki vurgu tek başına yeterli değil — paylaşılan
    // bağlantıyla gelen okur çubuğu değil, sayfanın başını okuyor.
    final kategoriAdi = widget.kategoriSlug == null
        ? null
        : ref
            .watch(kategoriListesiSaglayici)
            .asData
            ?.value
            .where((k) => k.slug == widget.kategoriSlug)
            .map((k) => k.ad)
            .firstOrNull;

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.lightImpact();
        return ref.invalidate(tumYayindakilerSaglayici);
      },
      child: CustomScrollView(
        slivers: [
          Kunye(baslik: kategoriAdi ?? 'Kastamonu Haber'),
          const _SonDakika(),
          const _KategoriCubugu(),
          haberler.when(
            loading: () => SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: const Iskelet(),
                ),
              ),
            ),
            error: (h, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text('$h'),
                ),
              ),
            ),
            // Kapak düzeni YALNIZCA ana sayfada. `/kategori/spor` zaten
            // tek bir bölüm demek; orada kat kat ayırmanın anlamı yok,
            // okur o sayfaya "bu bölümde ne var" diye geliyor.
            data: (liste) => liste.isEmpty
                ? const SliverFillRemaining(hasScrollBody: false, child: Bos())
                : widget.kategoriSlug == null
                    ? const _Kapak()
                    : _Akis(liste: liste),
          ),
          const SliverToBoxAdapter(child: Alt()),
        ],
      ),
    );
  }
}

/// Künye — 92 pikselden 48'e.
///
/// Tarih künyeden çıkıp sağa geçti. Kazanılan 44 piksel doğrudan habere
/// gidiyor.
///
/// Tarih bir süre yalnızca telefonda vardı: geniş ekranda gezinti onu
/// düşürüyordu ve masaüstü okuru sayfanın hangi güne ait olduğunu hiçbir
/// yerden okuyamıyordu. Artık her iki ekranda da var ve yanında **son
/// güncelleme** duruyor — bir haber sitesinin canlı olduğunu söyleyen tek
/// satır bu. Damga en yeni yayının kendi damgasından okunuyor, yani
/// süslemiyor: hat durursa satır da durduğunu söylüyor.
class Kunye extends ConsumerWidget {
  const Kunye({super.key, this.baslik = 'Kastamonu Haber'});

  final String baslik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = Renkler.of(context);
    final genis = !Kabuk.darMi(context);
    final enYeni = ref.watch(tumYayindakilerSaglayici).asData?.value.firstOrNull;
    final tarih = _Tarih(enYeni: enYeni?.zaman);
    return SliverAppBar(
      backgroundColor: r.kart,
      floating: true,
      pinned: false,
      elevation: 0,
      toolbarHeight: genis ? 60 : 48,
      titleSpacing: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: Container(color: r.murekkep, height: 2),
      ),
      flexibleSpace: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, genis ? 14 : 11, 12, genis ? 14 : 11),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.go('/'),
                  child: Semantics(
                    header: true,
                    child: Text(
                    baslik,
                    style: TextStyle(
                      fontFamily: Tema.serif,
                      fontWeight: FontWeight.w700,
                      fontSize: genis ? 26 : 21,
                      letterSpacing: -0.6,
                      height: 1.05,
                      color: r.murekkep,
                    ),
                  ),
                  ),
                ),
                if (genis) ...[
                  Container(
                    width: 1,
                    height: 28,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: r.cizgi,
                  ),
                  tarih,
                  const Spacer(),
                  const GenisGezinti(),
                  IconButton(
                    onPressed: () => context.go('/ara'),
                    icon: const Icon(Icons.search, size: 20),
                    color: r.solgun,
                    tooltip: 'Ara',
                  ),
                  IconButton(
                    onPressed: () => context.go('/panel'),
                    icon: const Icon(Icons.dashboard_outlined, size: 18),
                    color: r.solgun,
                    tooltip: 'Panel',
                  ),
                ] else ...[
                  const Spacer(),
                  tarih,
                  IconButton(
                    onPressed: () => context.go('/ara'),
                    icon: const Icon(Icons.search, size: 20),
                    color: r.solgun,
                    tooltip: 'Ara',
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.only(left: 8),
                    constraints: const BoxConstraints(minWidth: 36),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Künyenin tarih bloğu: bugünün tarihi ve son yayının damgası.
class _Tarih extends StatelessWidget {
  const _Tarih({this.enYeni});

  /// En yeni yayının zamanı. Liste henüz gelmediyse null.
  final DateTime? enYeni;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat('d MMMM, EEEE', 'tr').format(DateTime.now()),
          style: TextStyle(
            fontFamily: Tema.sans,
            fontSize: 12,
            height: 1.25,
            fontWeight: FontWeight.w500,
            color: r.murekkepIkincil,
          ),
        ),
        if (enYeni != null)
          Text(
            'son güncelleme ${saatDamgasi(enYeni!)}',
            style: TextStyle(
              fontFamily: Tema.sans,
              fontSize: 10.5,
              height: 1.3,
              color: r.solgun,
            ),
          ),
      ],
    );
  }
}

/// Son dakika bandı — yalnızca gerçekten yeni haber varken.
///
/// Rakiplerin hepsinde bu bant sürekli açık; sürekli açık olan bir "son
/// dakika" uyarısı sinyal olmaktan çıkıp süse dönüşüyor. Burada haber
/// yoksa bant da yok.
///
/// **Geçici kural:** şimdilik "son [_esik] içinde yayımlanmış en yeni
/// haber" ölçütü kullanılıyor. Hat elle tetiklendiği için bu pratikte
/// "az önce geldi" demek oluyor. Doğrusu editörün panelden koyacağı bir
/// işaret; o alan açıldığında burası ona bağlanmalı.
class _SonDakika extends ConsumerWidget {
  const _SonDakika();

  static const _esik = Duration(hours: 3);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = Renkler.of(context);
    final liste = ref.watch(tumYayindakilerSaglayici).asData?.value;
    if (liste == null || liste.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final h = liste.first;
    if (DateTime.now().difference(h.zaman) > _esik) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      // `liveRegion`: bant sayfa açıkken belirdiğinde ekran okuyucu onu
      // kendiliğinden okuyor. Son dakika haberinin tek anlamı zaten
      // sıradan akışı bölebilmesi; bölme yalnızca görenler için olmamalı.
      child: Semantics(
        liveRegion: true,
        button: true,
        label: 'Son dakika. ${h.baslik}',
        excludeSemantics: true,
        onTap: () => context.go('/haber/${h.slug}'),
        child: Material(
        color: r.sonDakika,
        child: InkWell(
          onTap: () => context.go('/haber/${h.slug}'),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 9, 18, 9),
                child: Row(
                  children: [
                    const Text(
                      'SON DAKİKA',
                      style: TextStyle(
                        fontFamily: Tema.sans,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 13,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: Colors.white54,
                    ),
                    // Kayan yazı DEĞİL.
                    //
                    // Bandı kayan yazıyla denemek yaygın bir refleks ama
                    // bu portalın okur kitlesinde yanlış: ortanca yaş 43,3
                    // ve hareket eden metin hem okunması zor hem geri
                    // dönülemez — gözden kaçan kelimeyi tekrar okumak için
                    // turu beklemek gerekiyor. WCAG 2.2.2 de hareketli
                    // içeriğin durdurulabilir olmasını istiyor.
                    // Başlık sığmıyorsa kırpılıyor; tamamı bir dokunuş
                    // ötede zaten.
                    Expanded(
                      child: Text(
                        h.baslik,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: Tema.sans,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// Bölüm satırı — gazetenin kategori çizgisi.
///
/// Tek gezinme çubuğu kaldı. İlçe süzgeci buradan kalkıp "İlçem" sekmesine
/// taşındı; gerekçe `kabuk.dart` başında.
class _KategoriCubugu extends ConsumerWidget {
  const _KategoriCubugu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = Renkler.of(context);
    final kategoriler = ref.watch(kategoriListesiSaglayici);
    final secili = ref.watch(kategoriSecimiSaglayici);

    return SliverToBoxAdapter(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: r.kart,
          border: Border(bottom: BorderSide(color: r.cizgi)),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: SizedBox(
              height: 42,
              child: kategoriler.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (liste) => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    // "Gündem" DEĞİL: veritabanında o adda gerçek bir
                    // kategori var ve çubukta iki kez görünüyordu.
                    _baglanti(context, 'Tümü', null, secili == null),
                    ...liste.map(
                      (k) => _baglanti(context, k.ad, k.slug, secili == k.slug),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _baglanti(BuildContext c, String ad, String? slug, bool sec) {
    final r = Renkler.of(c);
    return InkWell(
      onTap: () => c.go(slug == null ? '/' : '/kategori/$slug'),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: sec ? r.patina : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        // Adet rozeti kaldırıldı: "Asayiş 7" okura hiçbir şey söylemiyordu,
        // yalnızca satırı kalabalıklaştırıyordu.
        child: Text(
          ad,
          style: TextStyle(
            fontFamily: Tema.sans,
            fontSize: 13.5,
            fontWeight: sec ? FontWeight.w600 : FontWeight.w400,
            color: sec ? r.patina : r.murekkep,
          ),
        ),
      ),
    );
  }
}

/// Akış — fihristin kendisi.
///
/// Omurga **tazelik**: en yeni haber üstte, aşağı indikçe eskiye gidiyor.
/// Şehir portalında okurun sorduğu soru "yeni ne var"; bölüme göre
/// gruplamak o soruyu cevapsız bırakıyor, çünkü bir bölümün en yenisiyle
/// bir başkasının üç günlüğü yan yana geliyor. Bölüme göre okumak isteyen
/// için zaten üstte bölüm çubuğu var.
///
/// Ritim `Odak` ile veriliyor: fotoğrafı olan her beşinci haber, görseli
/// üstte başlığı altta olan daha büyük bir blok olarak çıkıyor. Bu,
/// sırayı bozmadan sayfaya nefes aldırıyor.
///
/// Tembel kuruluyor (`SliverList.builder`): akış tek bir `Column` içinde
/// toplanırsa 200 haberin tamamı açılışta inşa ediliyor ve kaydırma
/// takılıyor.
class _Akis extends StatelessWidget {
  const _Akis({required this.liste});
  final List<Haber> liste;

  /// Kaçıncı haberde bir `Odak` denenecek.
  static const _odakAraligi = 5;

  static bool _fotografli(Haber h) => KartBasi.gercekFotograf(h);

  @override
  Widget build(BuildContext context) {
    final genis = MediaQuery.sizeOf(context).width >= 860;
    return genis ? _genis(context) : _dar();
  }

  static Widget _ortala(Widget cocuk) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: cocuk,
        ),
      );

  /// Telefon: manşet, sonra kesintisiz satır listesi.
  Widget _dar() {
    return SliverList.builder(
      itemCount: liste.length,
      itemBuilder: (c, i) {
        if (i == 0) return _ortala(Manset(haber: liste[0]));
        final h = liste[i];
        final odak = i % _odakAraligi == 0 && _fotografli(h);
        return _ortala(odak ? Odak(haber: h) : Satir(haber: h));
      },
    );
  }

  /// Masaüstü: manşet solda, en yeniler sağ sütunda; gerisi iki sütun.
  ///
  /// Geniş ekranda manşeti tek başına tam genişliğe yaymak sayfayı
  /// boşaltıyor — gözün ilk gördüğü yerde tek haber kalıyor. Yan sütun
  /// aynı alanda beş başlık daha veriyor.
  Widget _genis(BuildContext context) {
    final r = Renkler.of(context);
    final yan = liste.skip(1).take(5).toList();
    final alt = liste.skip(6).toList();
    // İki sütun: çiftler hâlinde, sıra soldan sağa korunuyor.
    final ciftSayisi = (alt.length + 1) ~/ 2;

    return SliverList.builder(
      itemCount: 1 + ciftSayisi,
      itemBuilder: (c, i) {
        if (i == 0) return _ortala(_UstBlok(manset: liste.first, yan: yan));
        final sol = alt[(i - 1) * 2];
        final sag = (i - 1) * 2 + 1 < alt.length ? alt[(i - 1) * 2 + 1] : null;
        return _ortala(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: Satir(haber: sol)),
                Container(width: 1, color: r.cizgi),
                Expanded(
                  child: sag == null
                      ? const SizedBox.shrink()
                      : Satir(haber: sag),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Masaüstünün üst bloğu: manşet ve yanındaki en yeniler.
class _UstBlok extends StatelessWidget {
  const _UstBlok({required this.manset, required this.yan});

  final Haber manset;
  final List<Haber> yan;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 62, child: Manset(haber: manset, genis: true)),
          Container(width: 1, color: r.cizgi),
          Expanded(
            flex: 38,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: yan.map((h) => Satir(haber: h)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}



/// Manşet.
///
/// Spot her iki ekranda da var, ama satır sayısı farklı: geniş ekranda üç,
/// telefonda iki.
///
/// Telefonda spot bir kez tamamen kaldırılmıştı ve gerekçesi ölçümdü —
/// manşetin altındaki DÖRT satır gri metin ikinci başlığı ekranın dışına
/// itiyordu. Doğru olan kaldırmak değil sınırlamaktı: iki satır 46 piksel,
/// dördü 92. Yayındaki haberin 41'inin 41'inde spot var ve akış onu tek
/// bir yerde gösteriyordu; okur neredeyse hiçbir yerde tıklamadan önce ne
/// okuyacağını bilmiyordu. Başlık dikkati çeker, tıklanan şey spottur.
class Manset extends StatelessWidget {
  const Manset({super.key, required this.haber, this.genis = false});

  final Haber haber;
  final bool genis;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    void git() {
      HapticFeedback.lightImpact();
      context.go('/haber/${haber.slug}');
    }

    return Semantics(
      button: true,
      label: haberEtiketi(haber),
      excludeSemantics: true,
      onTap: git,
      child: Material(
      color: r.kart,
      child: InkWell(
        onTap: git,
        child: Container(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KartBasi(
                haber: haber,
                yukseklik: genis ? 350 : 250,
                mantiksalGenislik: genis ? 700 : 400,
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(18, 13, 18, genis ? 20 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Etiketler(haber: haber),
                    const SizedBox(height: 7),
                    Text(
                      haber.baslik,
                      style: TextStyle(
                        fontFamily: Tema.serif,
                        fontWeight: FontWeight.w700,
                        fontSize: genis ? 36 : 26,
                        height: 1.16,
                        letterSpacing: -0.5,
                        color: r.murekkep,
                      ),
                    ),
                    if ((haber.spot ?? '').isNotEmpty) ...[
                      SizedBox(height: genis ? 10 : 8),
                      Text(
                        haber.spot!,
                        maxLines: genis ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: Tema.serif,
                          fontSize: genis ? 17 : 16,
                          height: 1.45,
                          color: r.murekkepIkincil,
                        ),
                      ),
                    ],
                  ],
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

/// Odak satırı — Manşetten küçük, Satırdan büyük, görsel üstte başlık altta.
/// Fihrist görünümüne ritim katmak için kullanılır.
class Odak extends StatelessWidget {
  const Odak({super.key, required this.haber});
  final Haber haber;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    void git() {
      HapticFeedback.lightImpact();
      context.go('/haber/${haber.slug}');
    }

    return Semantics(
      button: true,
      label: haberEtiketi(haber),
      excludeSemantics: true,
      onTap: git,
      child: Material(
      color: r.kart,
      child: InkWell(
        onTap: git,
        child: Container(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Odak geniş ekranda iki sütunlu düzende ~530 piksel.
              KartBasi(haber: haber, yukseklik: 180, mantiksalGenislik: 540),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Etiketler(haber: haber),
                    const SizedBox(height: 6),
                    Text(
                      haber.baslik,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: Tema.serif,
                        fontWeight: FontWeight.w700,
                        fontSize: 21,
                        height: 1.18,
                        letterSpacing: -0.3,
                        color: r.murekkep,
                      ),
                    ),
                    // Odak zaten akışın "nefes alan" bloğu; iki satır spot
                    // onu bir habere dönüştürüyor. Satır'da spot YOK —
                    // yoğunluğu ayakta tutan şey o.
                    if ((haber.spot ?? '').isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        haber.spot!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: Tema.serif,
                          fontSize: 15.5,
                          height: 1.45,
                          color: r.murekkepIkincil,
                        ),
                      ),
                    ],
                  ],
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

/// Akış satırı — küçük görsel solda, başlık sağda, özet yok.
///
/// Künye satırı (bölüm · ilçe · zaman) başlığın ÜSTÜNDE duruyor ve
/// kaldırılmamalı. Bir kez kaldırıldı ve depo üretimden ayrıştı: akışın
/// gövdesi satırlardan oluştuğu için okur, haberlerin çoğunda ne bölüme
/// ait olduğunu da ne zaman yayımlandığını da göremiyordu. Özet burada
/// yok — yer açan şey o, künye değil; künye tek satır ve 14 piksel.
class Satir extends StatelessWidget {
  const Satir({super.key, required this.haber, this.zemin});
  final Haber haber;

  /// Satırın zemini. Çökük kuşaklarda kart rengi sayfadan kopuyor.
  /// Verilmezse kart rengi — temaya bağlı olduğu için yapıcıda sabit
  /// olamıyor.
  final Color? zemin;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    void git() {
      HapticFeedback.lightImpact();
      context.go('/haber/${haber.slug}');
    }

    return Semantics(
      button: true,
      label: haberEtiketi(haber),
      excludeSemantics: true,
      onTap: git,
      child: Material(
      color: zemin ?? r.kart,
      child: InkWell(
        onTap: git,
        child: Container(
          // Çizgi kaldırıldı, boşluk eklendi
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 104,
                  height: 76,
                  child: KartBasi(
                    haber: haber,
                    yukseklik: 76,
                    kucuk: true,
                    mantiksalGenislik: 104,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Etiketler(haber: haber, kucuk: true),
                    const SizedBox(height: 5),
                    Text(
                      haber.baslik,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: Tema.serif,
                        fontWeight: FontWeight.w600,
                        fontSize: 16.5,
                        height: 1.27,
                        letterSpacing: -0.1,
                        color: r.murekkep,
                      ),
                    ),
                  ],
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


/// Kart başı görseli.
///
/// Kural: kaynağın GERÇEK fotoğrafı varsa o gösteriliyor, künyesinde
/// yayıncı adıyla birlikte. Yoksa kategori bandı çiziliyor.
///
/// Tipografik kart burada GÖSTERİLMİYOR — o kart haberin başlığını
/// taşıyor ve başlık zaten hemen altında; denendi, aynı cümle iki kez
/// okunuyordu. Kartın yeri paylaşım önizlemesi (og:image).
class KartBasi extends StatelessWidget {
  const KartBasi({
    super.key,
    required this.haber,
    this.yukseklik = 108,
    this.kucuk = false,
    this.mantiksalGenislik = 400,
  });

  final Haber haber;
  final double yukseklik;
  final bool kucuk;

  /// Kartın ekranda kaplayacağı genişlik. Boyutlandırma hizmetine hangi
  /// kademenin isteneceğini bu belirliyor — yükseklik değil, çünkü dosyayı
  /// küçülten şey genişlik.
  final int mantiksalGenislik;

  /// Haberde gösterilebilir GERÇEK bir fotoğraf var mı.
  ///
  /// Ayrı ve adlandırılmış: bu kural bir kez sessizce bozuldu
  /// (yalnızca `gorselUrl`e bakılmaya başlandı) ve tipografik kartlar
  /// akışa sızdı. Testi `test/kart_basi_test.dart` içinde.
  static bool gercekFotograf(Haber h) =>
      (h.gorselKaynak ?? '').isNotEmpty && (h.gorselUrl ?? '').isNotEmpty;

  @override
  Widget build(BuildContext context) {
    // İKİ koşul birden aranıyor: adres VE atıf.
    //
    // `gorsel_url` tek başına yetmez — fotoğrafı olmayan haberlerde o alan
    // bizim ürettiğimiz **tipografik kartın** adresini taşıyor ve o kartın
    // üstünde haberin başlığı yazılı. Akışta gösterilirse başlık hemen
    // altında bir kez daha çıkıyor; denendi, aynı cümle iki kez okunuyor.
    // Kartın yeri paylaşım önizlemesi (og:image), akış değil.
    //
    // `gorsel_kaynak` yalnızca kaynağın GERÇEK fotoğrafı kullanıldığında
    // doluyor, yani ayrımı tam olarak o alan taşıyor.
    final foto = gercekFotograf(haber);

    final bant = KategoriBandi(
      haber: haber,
      yukseklik: yukseklik,
      kucuk: kucuk,
    );
    if (!foto) return bant;

    // Yükseklik SABİT, oran DEĞİL.
    //
    // Önce `AspectRatio` kullanılmıştı: 1200/630 oranı geniş bir kartta
    // 394 piksele çıkıyor, manşet dev bir görsele dönüşüyordu.
    return SizedBox(
      height: yukseklik,
      width: double.infinity,
      child: Image.network(
        gorselAdresi(haber.gorselUrl, mantiksalGenislik: mantiksalGenislik)!,
        fit: BoxFit.cover,
        // Kartın kendi etiketi başlığı, bölümü ve zamanı zaten söylüyor;
        // görselin ayrıca "resim" diye duyurulması gürültü.
        excludeFromSemantics: true,
        // `loadingBuilder` DEĞİL, `frameBuilder`.
        //
        // Ölçüldü: CanvasKit'te `loadingProgress` yükleme boyunca null
        // kalıyor, dolayısıyla loadingBuilder'daki yer tutucu hiç
        // görünmüyordu. İlk açılışta manşetin yerinde 190 piksellik
        // bembeyaz bir boşluk duruyor, fotoğraf gelince aniden doluyordu.
        //
        // Yer tutucu düz gri değil kategori bandı: renk zaten haberin
        // bölümünü söylüyor, yani bekleme anı da bilgi taşıyor.
        frameBuilder: (c, cocuk, kare, esGirdi) {
          // Künye ancak fotoğraf BOYANDIĞINDA basılıyor.
          //
          // Önceki kurguda künye `Stack`in dışında duruyordu ve fotoğraf
          // yüklenemediğinde kategori bandının üstünde "Fotoğraf: X"
          // yazısı kalıyordu — ekranda görüldü. Olmayan bir fotoğrafa
          // kaynak göstermek, haber sitesinde yanlış bilgidir.
          if (kare == null && !esGirdi) return bant;
          return Stack(
            fit: StackFit.expand,
            children: [
              AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: cocuk,
              ),
              // 68 pikselik küçük görselde künye okunmuyor ve üstünü
              // kaplıyor; orada kaynak haber sayfasında yazılı.
              if (!kucuk)
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    color: Colors.black.withValues(alpha: .62),
                    child: Text(
                      'Fotoğraf: ${haber.gorselKaynak}',
                      style: const TextStyle(
                        fontFamily: Tema.sans,
                        fontSize: 10.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        errorBuilder: (c, e, s) => bant,
      ),
    );
  }
}

/// Fotoğrafsız haberde görselin yerini alan kategori bandı.
///
/// Önceki hali kategori renginin %6'sıyla boyanmış açık bir zemin ve onun
/// üstünde soluk eş yükselti çizgileriydi. Ekranda bozuk görsel gibi
/// duruyordu — beyaza yakın bir dikdörtgen, içinde zor seçilen çizgiler.
/// Şimdi zemin kategori renginin kendisi; sırt çizgileri beyazın düşük
/// saydamlığıyla üstüne çiziliyor. Aynı Küre sırtı göndermesi, ama bu kez
/// görünüyor ve "burada fotoğraf yok" demek yerine bir işaret oluyor.
class KategoriBandi extends StatelessWidget {
  const KategoriBandi({
    super.key,
    required this.haber,
    this.yukseklik = 74,
    this.kucuk = false,
  });

  final Haber haber;
  final double yukseklik;
  final bool kucuk;

  @override
  Widget build(BuildContext context) {
    final renk = Bolum.renk(haber.kategoriAd);
    return SizedBox(
      height: yukseklik,
      width: double.infinity,
      child: CustomPaint(
        painter: _BantCizer(renk),
        child: haber.kategoriAd == null
            ? null
            : Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: kucuk ? 4 : 12),
                  child: Text(
                    kucuk
                        ? Bolum.kisalt(haber.kategoriAd!)
                        : buyult(haber.kategoriAd!),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: Tema.sans,
                      fontSize: kucuk ? 13 : 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: kucuk ? 1.4 : 2.2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _BantCizer extends CustomPainter {
  const _BantCizer(this.renk);
  final Color renk;

  @override
  void paint(Canvas tuval, Size olcu) {
    tuval.drawRect(Offset.zero & olcu, Paint()..color = renk);
    // Küre sırtları — beyazın düşük saydamlığıyla, koyu zemin üstünde.
    for (var i = 0; i < 4; i++) {
      final kalem = Paint()
        ..color = Colors.white.withValues(alpha: 0.07 + i * 0.035)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      final yol = Path();
      final taban = olcu.height * (0.42 + i * 0.16);
      final genlik = (4 - i) * 2.2;
      yol.moveTo(0, taban);
      for (double x = 0; x <= olcu.width; x += 7) {
        yol.lineTo(x, taban + math.sin(x / 48 + i * 0.8) * genlik);
      }
      tuval.drawPath(yol, kalem);
    }
  }

  @override
  bool shouldRepaint(_BantCizer eski) => eski.renk != renk;
}


/// Bölüm · ilçe · zaman.
///
/// Renk ayrımı bilgiyi taşıyor: bölüm patina, ilçe bakır. İkisi farklı
/// türde etiket ve okur bunu renkten ayırt ediyor.
class Etiketler extends StatelessWidget {
  const Etiketler({super.key, required this.haber, this.kucuk = false});

  final Haber haber;
  final bool kucuk;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    final ilce = haber.ilceler.where((b) => b.onaylandi).map((b) => b.ad);
    final olcu = kucuk ? 10.0 : 11.0;
    return Wrap(
      spacing: 7,
      runSpacing: 3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (haber.kategoriAd != null)
          Text(
            buyult(haber.kategoriAd!),
            style: TextStyle(
              fontFamily: Tema.sans,
              fontSize: olcu,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: r.patina,
            ),
          ),
        ...ilce.map(
          (ad) => Text(
            buyult(ad),
            style: TextStyle(
              fontFamily: Tema.sans,
              fontSize: olcu,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: r.bakir,
            ),
          ),
        ),
        Text(
          gecenSure(haber.zaman),
          style: TextStyle(
            fontFamily: Tema.sans,
            fontSize: olcu + 0.5,
            color: r.solgun,
          ),
        ),
      ],
    );
  }
}

/// Ekran okuyucunun haber kartı yerine okuyacağı tek cümle.
///
/// Neden gerekli
/// ─────────────
/// Flutter çizimi tuvale yapıyor, yani erişilebilirlik ağacı elle
/// kurulmak zorunda — kurulmazsa sayfa ekran okuyucu için tamamen boş.
/// Uzun süre tüm kod tabanında tek bir `Semantics` vardı.
///
/// Bu, temadaki punto ve kontrast kararlarının eksik yarısıydı: aynı
/// gerekçeyle (Kastamonu'nun ortanca yaşı 43,3, 65 üstü oranı %21,1)
/// gövde metni 17,5 pikselin altına indirilmiyor ama hiç göremeyen okur
/// için sayfada okunacak hiçbir şey yoktu.
///
/// Sıra bilinçli: önce başlık. Ekran okuyucu kullanan okur listede
/// gezerken ilk kelimelerden karar veriyor, bölüm ve zaman sonra geliyor.
String haberEtiketi(Haber h) {
  final ilce = h.ilceler.where((b) => b.onaylandi).map((b) => b.ad).join(', ');
  return [
    h.baslik,
    if (h.kategoriAd != null) h.kategoriAd!,
    if (ilce.isNotEmpty) ilce,
    gecenSure(h.zaman),
  ].join('. ');
}

/// "2 saat önce" / "dün 14:30" / "18 Eyl".
///
/// Yerel haberde tazelik bilginin parçası: bir yangının iki saat mi iki
/// gün mü önce olduğu, haberin kendisi kadar önemli. Mutlak tarih ancak
/// bir günü geçince anlam kazanıyor.
///
/// Kademe TAKVİM GÜNÜNE göre, saat farkına göre değil. Önce saat farkı
/// kullanılıyordu ve gün sınırını atlayan haber yanlış okunuyordu: sabah
/// 10'da, bir önceki akşam 23'te yayımlanan haber "11 saat önce" diyordu —
/// oysa okur için o haber dünden kalma. Tersi de oluyordu: gece yarısını
/// yeni geçmişken 25 saatlik bir haber `inDays == 1` olduğu için "dün"
/// diyordu, gerçekte iki takvim günü geride.
///
/// [simdi] yalnızca test için; verilmezse o an okunuyor.
String gecenSure(DateTime an, {DateTime? simdi}) {
  final o = simdi ?? DateTime.now();
  final fark = o.difference(an);
  // Sunucu saati ileri kaymış kayıt geleceğe atılmıyor.
  if (fark.inMinutes < 1) return 'az önce';
  if (fark.inMinutes < 60) return '${fark.inMinutes} dakika önce';

  final gun = _gunSirasi(o) - _gunSirasi(an);
  if (gun == 0) return '${fark.inHours} saat önce';
  // Saat ekleniyor: "dün" tek başına 13 saatlik bir aralığı gösteriyor ve
  // gün içinde ne zaman olduğu yerel haberde çoğu zaman önemli.
  if (gun == 1) return 'dün ${DateFormat('HH:mm', 'tr').format(an)}';
  if (gun < 7) return '$gun gün önce';
  return DateFormat('d MMM', 'tr').format(an);
}

/// Aynı gün ise saat, değilse göreli.
///
/// "son güncelleme 09:47" ile "son güncelleme 12 gün önce" aynı satırda
/// aynı işi görüyor: ikisi de doğruyu söylüyor. İkincisi rahatsız edici
/// ama hat durduğunda okurun bunu görmesi gerekiyor — süsleyip "bugün"
/// demek, sayfanın tek canlılık ölçüsünü de yalana çevirirdi.
String saatDamgasi(DateTime an, {DateTime? simdi}) {
  final o = simdi ?? DateTime.now();
  final ayniGun = o.year == an.year && o.month == an.month && o.day == an.day;
  return ayniGun ? DateFormat('HH:mm', 'tr').format(an) : gecenSure(an, simdi: o);
}

/// Takvim gününün sıra numarası.
///
/// Gün farkı normalleştirilmiş yerel tarihler çıkarılarak hesaplanamaz:
/// yaz saati uygulanan bir bölgede geçiş gününde iki gece yarısının arası
/// 23 ya da 25 saat oluyor ve `inDays` bir gün şaşıyor. Türkiye 2016'dan
/// beri sabit UTC+3 ama bu işlev ona bel bağlamasın.
int _gunSirasi(DateTime t) =>
    DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/ 86400000;

class Bos extends StatelessWidget {
  const Bos({super.key, this.baslik, this.aciklama});

  final String? baslik;
  final String? aciklama;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 40, color: r.cizgiKuvvetli),
            const SizedBox(height: 14),
            Text(
              baslik ?? 'Bu seçimde yayımlanmış haber yok.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Tema.serif,
                fontSize: 17,
                color: r.murekkepIkincil,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              aciklama ?? 'Panelden haber yayınlandığında burada görünür.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Tema.sans,
                fontSize: 13,
                color: r.solgun,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Alt extends StatelessWidget {
  const Alt({super.key});

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    return Container(
      color: r.sunk,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 26, 18, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kastamonu Haber',
                  style: TextStyle(
                    fontFamily: Tema.serif,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: r.murekkep,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Haberler kaynak gösterilerek derlenmektedir. Her haberin '
                  'künyesinde özgün kaynağı belirtilir.',
                  style: TextStyle(
                    fontFamily: Tema.sans,
                    fontSize: 12.5,
                    color: r.solgun,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 16),
                const _TemaSecici(),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => context.go('/panel'),
                  icon: const Icon(Icons.dashboard_outlined, size: 16),
                  label: const Text('Panel'),
                  style: TextButton.styleFrom(
                    foregroundColor: r.solgun,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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


class Iskelet extends StatelessWidget {
  const Iskelet({super.key});

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 250, color: r.cizgi.withValues(alpha: 0.5)),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 80, height: 16, color: r.cizgi.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Container(width: double.infinity, height: 26, color: r.cizgi.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Container(width: 200, height: 26, color: r.cizgi.withValues(alpha: 0.5)),
            ],
          ),
        ),
        Divider(height: 1, color: r.cizgi),
        _IskeletSatir(),
        _IskeletSatir(),
        _IskeletSatir(),
      ],
    );
  }
}

class _IskeletSatir extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: r.cizgi))),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 68, height: 68, color: r.cizgi.withValues(alpha: 0.5)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 60, height: 14, color: r.cizgi.withValues(alpha: 0.5)),
                const SizedBox(height: 8),
                Container(width: double.infinity, height: 16, color: r.cizgi.withValues(alpha: 0.5)),
                const SizedBox(height: 6),
                Container(width: 150, height: 16, color: r.cizgi.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════
// Kapak düzeni
// ══════════════════════════════════════════════════════════════════

/// Ana sayfanın kat düzeni.
///
/// Akış uzun süre tek bir sıraydı: en yeni üstte, aşağı indikçe eskiye.
/// Bir şehir portalında okurun sorduğu soru "yeni ne var" olduğu için bu
/// doğru görünüyordu, ama iki şeyi birden kaybettiriyordu.
///
/// Birincisi hiyerarşi: sayfada kırk bir haber vardı ve kırk biri de aynı
/// ağırlıktaydı. İkincisi ton: yayındaki haberin %41'i asayiş ve kaza,
/// zamana göre dizilmiş tek bir sırada bu oran sayfanın karakterini tek
/// başına belirliyor ve kültür, tarım, eğitim haberleri aralarda kayboluyor.
///
/// Burada aynı haberler katlara dağılıyor. Haber sayısı artmıyor; sayfanın
/// yukarıdan aşağı okunurken bir ritmi oluyor. Üç blok tipi var — manşet,
/// ızgara, liste — ve sıraları ritmi kuruyor. Hangi haberin hangi kata
/// düştüğü `veri/kapak.dart` içinde.
class _Kapak extends ConsumerWidget {
  const _Kapak();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kapak = ref.watch(kapakSaglayici);
    if (kapak.bosMu) {
      return const SliverFillRemaining(hasScrollBody: false, child: Bos());
    }
    final genis = MediaQuery.sizeOf(context).width >= 860;

    return SliverMainAxisGroup(
      slivers: [
        SliverList.list(
          children: [
            _MansetBlogu(kapak: kapak, genis: genis),
            if (kapak.kisaKisa.isNotEmpty) _KisaKisa(haberler: kapak.kisaKisa),
            if (kapak.ilcem.isNotEmpty) _IlcemSeridi(haberler: kapak.ilcem),
            if (kapak.gundem.isNotEmpty)
              Izgara(
                baslik: 'Gündem',
                haberler: kapak.gundem,
                genis: genis,
                slug: 'gundem',
              ),
            if (kapak.asayis.isNotEmpty) _KoyuKusak(haberler: kapak.asayis),
            if (kapak.secme.isNotEmpty)
              Izgara(
                baslik: 'Kastamonu\'dan',
                haberler: kapak.secme,
                genis: genis,
              ),
            if (kapak.gozden.isNotEmpty) _Gozden(haberler: kapak.gozden),
          ],
        ),
        // Katlara girmeyen haberler BÖLÜM BÖLÜM, ızgara kartı olarak.
        //
        // Eskiden burası "Diğer haberler" başlıklı tek bir akıştı ve
        // sayfanın sonunda tren gibi uzuyordu — aynı puntoda, aynı
        // satırda, aynı küçük görselle onlarca haber. Artık her haber
        // kendi bölümünün altında ve kart olarak duruyor.
        //
        // Tembel kuruluyor: tek bir `Column`a toplanırsa bütün bölümler
        // açılışta inşa ediliyor ve kaydırma takılıyor.
        SliverList.builder(
          itemCount: kapak.bolumler.length,
          itemBuilder: (c, i) => Izgara(
            baslik: kapak.bolumler[i].ad,
            slug: kapak.bolumler[i].slug,
            haberler: kapak.bolumler[i].haberler,
            genis: genis,
          ),
        ),
      ],
    );
  }
}

/// İçeriği 1080 pikselde ortalayan sarmal. Kapaktaki her kat bunu kullanıyor.
class _Orta extends StatelessWidget {
  const _Orta({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: child,
        ),
      );
}

/// Bölüm başlığı: versal ad, çizgi, isteğe bağlı bağlantı.
///
/// Tek bir başlık biçimi var ve her kat onu kullanıyor. Yirmi farklı bölüm
/// kalıbı okuru sayfada nerede olduğunu kaybettiriyor.
class _BolumBasligi extends StatelessWidget {
  const _BolumBasligi({
    required this.baslik,
    this.renk,
    this.cizgiRengi,
    this.bagRengi,
    this.slug,
    this.yol,
    this.oncu,
  });

  final String baslik;

  // Üçü de null olabilir: varsayılanları bağlamdan geliyor, çünkü
  // temaya bağlı bir renk yapıcı parametresinde sabit olamıyor.
  final Color? renk;
  final Color? cizgiRengi;
  final Color? bagRengi;

  /// Verilirse `/kategori/<slug>` bağlantısı çizilir.
  final String? slug;

  /// Doğrudan bir yol; [slug] yerine geçiyor.
  final String? yol;

  /// Başlığın solundaki küçük işaret (İlçem'de konum ikonu).
  final Widget? oncu;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    final hedef = yol ?? (slug == null ? null : '/kategori/$slug');
    final baslikRengi = renk ?? r.murekkep;
    final cizgi = cizgiRengi ?? r.cizgi;
    final bag = bagRengi ?? r.patina;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (oncu != null) ...[oncu!, const SizedBox(width: 7)],
        Semantics(
          header: true,
          child: Text(
            buyult(baslik),
            style: TextStyle(
              fontFamily: Tema.sans,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: baslikRengi,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: cizgi)),
        if (hedef != null) ...[
          const SizedBox(width: 10),
          InkWell(
            onTap: () => context.go(hedef),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              child: Text(
                'Tümü →',
                style: TextStyle(
                  fontFamily: Tema.sans,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: bag,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Manşet bloğu — lider haber ve yanındaki ikincil başlıklar.
///
/// Geniş ekranda manşeti tek başına tam genişliğe yaymak sayfayı
/// boşaltıyor: gözün ilk gördüğü yerde tek haber kalıyor. Yan sütun aynı
/// alanda üç başlık daha veriyor.
///
/// Telefonda ikincil başlıkların ilk ikisi yan yana iki küçük kart; bu,
/// ilk ekranda görünen başlık sayısını satır düzenine göre artırmıyor ama
/// manşetten sonra gelen şeyin "devamı" değil "başka bir haber" olduğunu
/// biçimle söylüyor.
class _MansetBlogu extends StatelessWidget {
  const _MansetBlogu({required this.kapak, required this.genis});

  final Kapak kapak;
  final bool genis;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    final manset = kapak.manset!;
    if (genis) {
      return _Orta(
        child: ColoredBox(
          color: r.kart,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 62, child: Manset(haber: manset, genis: true)),
                Container(width: 1, color: r.cizgi),
                Expanded(
                  flex: 38,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final h in kapak.ikincil) Satir(haber: h),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final ikili = kapak.ikincil.take(2).toList();
    final kalanIkincil = kapak.ikincil.skip(2).toList();
    return _Orta(
      child: ColoredBox(
        color: r.kart,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Manset(haber: manset),
            if (ikili.isNotEmpty)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < ikili.length; i++) ...[
                      if (i > 0) Container(width: 1, color: r.cizgi),
                      Expanded(child: _IkiliKart(haber: ikili[i])),
                    ],
                    // Tek kart kaldıysa yarım genişlikte kalsın; tam
                    // genişliğe yayılmış tek kart manşetin tekrarı gibi
                    // duruyor.
                    if (ikili.length == 1) const Expanded(child: SizedBox()),
                  ],
                ),
              ),
            for (final h in kalanIkincil) Satir(haber: h),
          ],
        ),
      ),
    );
  }
}

/// Manşetin altındaki yan yana iki kart.
class _IkiliKart extends StatelessWidget {
  const _IkiliKart({required this.haber});
  final Haber haber;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    void git() {
      HapticFeedback.lightImpact();
      context.go('/haber/${haber.slug}');
    }

    return Semantics(
      button: true,
      label: haberEtiketi(haber),
      excludeSemantics: true,
      onTap: git,
      child: Material(
      color: r.kart,
      child: InkWell(
        onTap: git,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 82,
                width: double.infinity,
                child: KartBasi(
                  haber: haber,
                  yukseklik: 82,
                  kucuk: true,
                  mantiksalGenislik: 180,
                ),
              ),
              const SizedBox(height: 9),
              Etiketler(haber: haber, kucuk: true),
              const SizedBox(height: 5),
              Text(
                haber.baslik,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: Tema.serif,
                  fontWeight: FontWeight.w600,
                  fontSize: 15.5,
                  height: 1.26,
                  color: r.murekkep,
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

/// Kısa kısa — görselsiz, spotsuz, yalnız saat ve başlık.
///
/// Sayfadaki diğer her şey kart ya da görselli satırken burada bir ajans
/// bülteninin ritmi var, ve bu ritim farkı sayfaya iyi geliyor: aynı
/// yükseklikte üç katı haber sığıyor.
class _KisaKisa extends StatelessWidget {
  const _KisaKisa({required this.haberler});
  final List<Haber> haberler;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    final genis = MediaQuery.sizeOf(context).width >= 860;
    return _Orta(
      child: Container(
        color: r.sunk,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BolumBasligi(baslik: 'Kısa kısa', cizgiRengi: r.cizgiKuvvetli),
            const SizedBox(height: 4),
            if (genis)
              // Geniş ekranda üç sütun: aynı yükseklikte üç katı başlık.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var s = 0; s < 3; s++) ...[
                    if (s > 0) const SizedBox(width: 26),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = s; i < haberler.length; i += 3)
                            _KisaSatir(haber: haberler[i]),
                        ],
                      ),
                    ),
                  ],
                ],
              )
            else
              for (final h in haberler) _KisaSatir(haber: h),
          ],
        ),
      ),
    );
  }
}

class _KisaSatir extends StatelessWidget {
  const _KisaSatir({required this.haber});
  final Haber haber;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    return Semantics(
      button: true,
      label: '${haber.baslik}. ${gecenSure(haber.zaman)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.go('/haber/${haber.slug}'),
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: r.sunkKoyu)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  saatDamgasi(haber.zaman),
                  style: TextStyle(
                    fontFamily: Tema.sans,
                    fontSize: 11.5,
                    height: 1.45,
                    color: r.solgun,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  haber.baslik,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: Tema.serif,
                    fontWeight: FontWeight.w600,
                    fontSize: 15.5,
                    height: 1.3,
                    color: r.murekkep,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// İlçem şeridi — portalın en ayırt edici parçası, kapakta.
///
/// Uzun süre yalnızca ayrı bir sekmedeydi: okurun onu bulması için sekme
/// değiştirmesi gerekiyordu. Rakiplerin yapamadığı tek şey en görünmez
/// yerde duruyordu. Okur ilçesini seçmemişse bu kat hiç çizilmiyor —
/// "İlçeni seç" daveti ilçe sekmesinin kendi işi.
class _IlcemSeridi extends ConsumerWidget {
  const _IlcemSeridi({required this.haberler});
  final List<Haber> haberler;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = Renkler.of(context);
    final ilcem = ref.watch(ilcemSaglayici);
    if (ilcem == null) return const SizedBox.shrink();
    return _Orta(
      child: Container(
        color: r.kart,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BolumBasligi(
              baslik: 'İlçem · ${ilcem.ad}',
              renk: r.bakir,
              bagRengi: r.bakir,
              yol: '/ilcem',
              oncu: Icon(
                Icons.location_on_outlined,
                size: 15,
                color: r.bakir,
              ),
            ),
            const SizedBox(height: 2),
            for (final h in haberler)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: Satir(haber: h),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bir bölüm katı: bölüm başlığı + kart ızgarası.
///
/// Geniş ekranda üç sütunluk SATIRLAR; telefonda ilk haber Odak, gerisi
/// satır.
///
/// `Manset`, `Odak`, `Satir` gibi herkese açık: kart genişliği testte
/// ÖLÇÜLÜYOR. Bu bileşen bir kez üç haberlik bloklar için yazılmış, sonra
/// kategori bölümlerine bağlanmıştı; on dört haber geldiğinde her kart 52
/// piksele düşüp başlıklar harf harf alt alta dizildi. Genişliği ölçen bir
/// test olmadığı için bu yayına çıktı.
class Izgara extends StatelessWidget {
  const Izgara({
    super.key,
    required this.baslik,
    required this.haberler,
    required this.genis,
    this.slug,
  });

  final String baslik;
  final List<Haber> haberler;
  final bool genis;
  final String? slug;

  /// Geniş ekranda satır başına kart.
  static const _sutun = 3;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    return _Orta(
      child: Container(
        color: r.kart,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BolumBasligi(baslik: baslik, slug: slug),
            const SizedBox(height: 14),
            if (genis)
              // Kartlar SATIRLARA bölünüyor, tek bir satıra
              // sıkıştırılmıyor.
              //
              // Önceki hâli bütün haberleri tek `Row` içine `Expanded`
              // ile koyuyordu: üç haberde doğru çalışıyor, on dört
              // haberde her kart 75 piksele düşüyor ve başlıklar
              // harf harf alt alta diziliyordu. Bu bileşen üç haberlik
              // bloklar için yazılmıştı; kategori bölümlerine
              // bağlanınca ortaya çıktı.
              //
              // Son satır eksik kalırsa boş `Expanded`ler konuyor,
              // böylece kartlar dolu satırlarla aynı genişlikte
              // kalıyor.
              for (var satir = 0; satir * _sutun < haberler.length; satir++) ...[
                if (satir > 0) const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var k = 0; k < _sutun; k++) ...[
                      if (k > 0) const SizedBox(width: 24),
                      Expanded(
                        child: satir * _sutun + k < haberler.length
                            ? _IzgaraKarti(haber: haberler[satir * _sutun + k])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ]
            else ...[
              Odak(haber: haberler.first),
              for (final h in haberler.skip(1)) Satir(haber: h),
            ],
          ],
        ),
      ),
    );
  }
}

class _IzgaraKarti extends StatelessWidget {
  const _IzgaraKarti({required this.haber});
  final Haber haber;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    void git() {
      HapticFeedback.lightImpact();
      context.go('/haber/${haber.slug}');
    }

    return Semantics(
      button: true,
      label: haberEtiketi(haber),
      excludeSemantics: true,
      onTap: git,
      child: Material(
      color: r.kart,
      child: InkWell(
        onTap: git,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 150,
              width: double.infinity,
              child: KartBasi(
                haber: haber,
                yukseklik: 150,
                mantiksalGenislik: 340,
              ),
            ),
            const SizedBox(height: 10),
            Etiketler(haber: haber),
            const SizedBox(height: 6),
            Text(
              haber.baslik,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: Tema.serif,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                height: 1.22,
                color: r.murekkep,
              ),
            ),
            if ((haber.spot ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                haber.spot!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: Tema.serif,
                  fontSize: 15,
                  height: 1.45,
                  color: r.murekkepIkincil,
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
      ),
    );
  }
}

/// Asayiş ve kaza — koyu kuşakta, liste biçiminde.
///
/// Yayındaki haberin %41'i bu iki bölümden ve zamana göre dizilmiş tek bir
/// akışta bu oran sayfanın tonunu tek başına belirliyordu. Haber
/// gizlenmiyor: kendi yerine konuyor. Koyu zemin hem sayfayı bölüyor hem
/// de bu kuşağın ayrı bir şey olduğunu biçimle söylüyor.
class _KoyuKusak extends StatelessWidget {
  const _KoyuKusak({required this.haberler});
  final List<Haber> haberler;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    final genis = MediaQuery.sizeOf(context).width >= 860;
    return _Orta(
      child: Container(
        color: r.kusak,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BolumBasligi(
              baslik: 'Asayiş ve kaza',
              renk: r.kusakMetin,
              cizgiRengi: Colors.white24,
              bagRengi: r.kusakIkincil,
              slug: 'asayis',
            ),
            const SizedBox(height: 4),
            if (genis)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var s = 0; s < 2; s++) ...[
                    if (s > 0) const SizedBox(width: 30),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = s; i < haberler.length; i += 2)
                            _KusakSatiri(haber: haberler[i]),
                        ],
                      ),
                    ),
                  ],
                ],
              )
            else
              for (final h in haberler) _KusakSatiri(haber: h),
          ],
        ),
      ),
    );
  }
}

class _KusakSatiri extends StatelessWidget {
  const _KusakSatiri({required this.haber});
  final Haber haber;

  /// Soldaki yer etiketi: ilçe varsa o, yoksa bölüm.
  String get _yer {
    final ilce = haber.ilceler.where((b) => b.onaylandi).firstOrNull?.ad;
    return buyult(ilce ?? haber.kategoriAd ?? 'Kastamonu');
  }

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    return Semantics(
      button: true,
      label: '${haber.baslik}. $_yer, ${gecenSure(haber.zaman)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.go('/haber/${haber.slug}'),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 78,
                child: Text(
                  _yer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: Tema.sans,
                    fontSize: 10.5,
                    height: 1.5,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                    // Kâğıt zemindeki bakırın kuşak üstündeki karşılığı.
                    color: r.kusakIkincil,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  haber.baslik,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: Tema.serif,
                    fontWeight: FontWeight.w600,
                    fontSize: 15.5,
                    height: 1.3,
                    // Kuşağın kendi metin rengi. `zemin` yazılsaydı koyu
                    // temada kuşak zemininin üstüne yine koyu düşerdi.
                    color: r.kusakMetin,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gözden kaçmasın — önemi yüksek ama birkaç günlük haberler.
///
/// Kırk bir haberlik bir arşivin ikinci kez işe yaramasını sağlıyor:
/// tazelikten düştüğü için akışın dibine inmiş ama hâlâ okunmaya değer
/// haber, sayfanın sonunda bir kez daha görünüyor.
class _Gozden extends StatelessWidget {
  const _Gozden({required this.haberler});
  final List<Haber> haberler;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    return _Orta(
      child: Container(
        color: r.sunk,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BolumBasligi(
              baslik: 'Gözden kaçmasın',
              cizgiRengi: r.cizgiKuvvetli,
            ),
            const SizedBox(height: 2),
            for (final h in haberler) Satir(haber: h, zemin: r.sunk),
          ],
        ),
      ),
    );
  }
}

/// Tema seçici — alt künyede.
///
/// Yerel haber akşam okunuyor ve sıcak kâğıt zemini gece telefonda gözü
/// yoruyor. Varsayılan "Sistem": telefonun karanlık moda geçmesi okurun
/// zaten verdiği bir karar, portalın onu yok sayması için sebep yok.
///
/// Punto seçici gibi burası da bir okuma ayarı; seçim cihazda duruyor,
/// sunucuya gitmiyor.
class _TemaSecici extends ConsumerWidget {
  const _TemaSecici();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = Renkler.of(context);
    final secili = ref.watch(temaKipiSaglayici);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.brightness_6_outlined, size: 15, color: r.solgun),
        const SizedBox(width: 8),
        Text(
          'Görünüm',
          style: TextStyle(
            fontFamily: Tema.sans,
            fontSize: 12.5,
            color: r.solgun,
          ),
        ),
        const SizedBox(width: 12),
        for (final kipi in TemaKipi.values) ...[
          if (kipi != TemaKipi.values.first) const SizedBox(width: 6),
          _TemaDugmesi(kipi: kipi, secili: kipi == secili),
        ],
      ],
    );
  }
}

class _TemaDugmesi extends ConsumerWidget {
  const _TemaDugmesi({required this.kipi, required this.secili});

  final TemaKipi kipi;
  final bool secili;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = Renkler.of(context);
    return Semantics(
      button: true,
      selected: secili,
      label: 'Görünüm: ${kipi.ad}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => ref.read(temaKipiSaglayici.notifier).sec(kipi),
        child: Container(
          // Dokunma hedefi 44 pikselin altına inmiyor.
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: secili ? r.patina : r.kart,
            border: Border.all(
              color: secili ? r.patina : r.cizgiKuvvetli,
            ),
          ),
          child: Text(
            kipi.ad,
            style: TextStyle(
              fontFamily: Tema.sans,
              fontSize: 12.5,
              fontWeight: secili ? FontWeight.w600 : FontWeight.w400,
              color: secili ? r.patinaUstu : r.murekkep,
            ),
          ),
        ),
      ),
    );
  }
}
