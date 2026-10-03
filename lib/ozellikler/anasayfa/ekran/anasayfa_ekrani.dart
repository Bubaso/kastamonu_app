import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../cekirdek/kabuk.dart';
import '../../../cekirdek/metin.dart';
import '../../../cekirdek/tema.dart';
import '../../inceleme/model/haber.dart';
import '../veri/anasayfa_deposu.dart';

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
            data: (liste) => liste.isEmpty
                ? const SliverFillRemaining(hasScrollBody: false, child: Bos())
                : _Akis(liste: liste),
          ),
          const SliverToBoxAdapter(child: Alt()),
        ],
      ),
    );
  }
}

/// Künye — 92 pikselden 44'e.
///
/// Tarih künyeden çıkıp sağa, tek satıra geçti. Kazanılan 48 piksel
/// doğrudan habere gidiyor.
class Kunye extends StatelessWidget {
  const Kunye({super.key, this.baslik = 'Kastamonu Haber'});

  final String baslik;

  @override
  Widget build(BuildContext context) {
    final genis = !Kabuk.darMi(context);
    return SliverAppBar(
      backgroundColor: Colors.white,
      floating: true,
      pinned: false,
      elevation: 0,
      toolbarHeight: genis ? 60 : 44,
      titleSpacing: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: Container(color: Tema.murekkep, height: 2),
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
                  child: Text(
                    baslik,
                    style: TextStyle(
                      fontFamily: Tema.serif,
                      fontWeight: FontWeight.w700,
                      fontSize: genis ? 26 : 21,
                      letterSpacing: -0.6,
                      height: 1.05,
                      color: Tema.murekkep,
                    ),
                  ),
                ),
                const Spacer(),
                if (genis) ...[
                  const GenisGezinti(),
                  IconButton(
                    onPressed: () => context.go('/panel'),
                    icon: const Icon(Icons.dashboard_outlined, size: 18),
                    color: Tema.solgun,
                    tooltip: 'Panel',
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      DateFormat('d MMMM, EEEE', 'tr').format(DateTime.now()),
                      style: const TextStyle(
                        fontFamily: Tema.sans,
                        fontSize: 12,
                        color: Tema.solgun,
                      ),
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
    final liste = ref.watch(tumYayindakilerSaglayici).asData?.value;
    if (liste == null || liste.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final h = liste.first;
    if (DateTime.now().difference(h.zaman) > _esik) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Material(
        color: Tema.sonDakika,
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
    final kategoriler = ref.watch(kategoriListesiSaglayici);
    final secili = ref.watch(kategoriSecimiSaglayici);

    return SliverToBoxAdapter(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Tema.cizgi)),
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
    return InkWell(
      onTap: () => c.go(slug == null ? '/' : '/kategori/$slug'),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: sec ? Tema.patina : Colors.transparent,
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
            color: sec ? Tema.patina : Tema.murekkep,
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
    return genis ? _genis() : _dar();
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
  Widget _genis() {
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
                Container(width: 1, color: Tema.cizgi),
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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 62, child: Manset(haber: manset, genis: true)),
          Container(width: 1, color: Tema.cizgi),
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
/// Spot yalnızca geniş ekranda gösteriliyor. Telefonda spot, manşetin
/// hemen altında dört satır gri metin demek — ölçümde tam olarak bu, ikinci
/// başlığı ekranın dışına itiyordu.
class Manset extends StatelessWidget {
  const Manset({super.key, required this.haber, this.genis = false});

  final Haber haber;
  final bool genis;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.go('/haber/${haber.slug}');
        },
        child: Container(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KartBasi(haber: haber, yukseklik: genis ? 350 : 250),
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
                        color: Tema.murekkep,
                      ),
                    ),
                    if (genis && (haber.spot ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        haber.spot!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: Tema.serif,
                          fontSize: 17,
                          height: 1.5,
                          color: Tema.murekkepIkincil,
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
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.go('/haber/${haber.slug}');
        },
        child: Container(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KartBasi(haber: haber, yukseklik: 180),
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
                      style: const TextStyle(
                        fontFamily: Tema.serif,
                        fontWeight: FontWeight.w700,
                        fontSize: 21,
                        height: 1.18,
                        letterSpacing: -0.3,
                        color: Tema.murekkep,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Akış satırı — küçük görsel solda, başlık sağda, özet yok.
class Satir extends StatelessWidget {
  const Satir({super.key, required this.haber});
  final Haber haber;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.go('/haber/${haber.slug}');
        },
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
                  child: KartBasi(haber: haber, yukseklik: 76, kucuk: true),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Etiketler kaldırıldı, sadece başlık
                    Text(
                      haber.baslik,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: Tema.serif,
                        fontWeight: FontWeight.w600,
                        fontSize: 16.5,
                        height: 1.27,
                        letterSpacing: -0.1,
                        color: Tema.murekkep,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
  });

  final Haber haber;
  final double yukseklik;
  final bool kucuk;

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
        haber.gorselUrl!,
        fit: BoxFit.cover,
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

  /// Kategori renkleri yeni palete göre yeniden seçildi: hepsi beyaz yazıyı
  /// taşıyacak kadar koyu ve hepsi kâğıt zeminle aynı sıcaklıkta.
  static const renkler = {
    'Asayiş': Color(0xFF7A2E12),
    'Kaza ve Acil': Color(0xFFA03412),
    'Gündem': Color(0xFF0A5F4E),
    'Ekonomi': Color(0xFF2A4E68),
    'Tarım': Color(0xFF47651F),
    'Eğitim': Color(0xFF4C3E7A),
    'Spor': Color(0xFF15614A),
    'Kültür ve Turizm': Color(0xFF7E5210),
    'Sağlık': Color(0xFF7E2942),
    'Kent ve Yönetim': Color(0xFF38505F),
  };

  @override
  Widget build(BuildContext context) {
    final renk = renkler[haber.kategoriAd] ?? Tema.patina;
    return SizedBox(
      height: yukseklik,
      width: double.infinity,
      child: CustomPaint(
        painter: _BantCizer(renk),
        child: kucuk || haber.kategoriAd == null
            ? null
            : Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    buyult(haber.kategoriAd!),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: Tema.sans,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.2,
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
              color: Tema.patina,
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
              color: Tema.bakir,
            ),
          ),
        ),
        Text(
          gecenSure(haber.zaman),
          style: TextStyle(
            fontFamily: Tema.sans,
            fontSize: olcu + 0.5,
            color: Tema.solgun,
          ),
        ),
      ],
    );
  }
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.article_outlined, size: 40, color: Tema.cizgiKuvvetli),
            const SizedBox(height: 14),
            Text(
              baslik ?? 'Bu seçimde yayımlanmış haber yok.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: Tema.serif,
                fontSize: 17,
                color: Tema.murekkepIkincil,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              aciklama ?? 'Panelden haber yayınlandığında burada görünür.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: Tema.sans,
                fontSize: 13,
                color: Tema.solgun,
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
    return Container(
      color: Tema.sunk,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 26, 18, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kastamonu Haber',
                  style: TextStyle(
                    fontFamily: Tema.serif,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: Tema.murekkep,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Haberler kaynak gösterilerek derlenmektedir. Her haberin '
                  'künyesinde özgün kaynağı belirtilir.',
                  style: TextStyle(
                    fontFamily: Tema.sans,
                    fontSize: 12.5,
                    color: Tema.solgun,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: () => context.go('/panel'),
                  icon: const Icon(Icons.dashboard_outlined, size: 16),
                  label: const Text('Panel'),
                  style: TextButton.styleFrom(
                    foregroundColor: Tema.solgun,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 250, color: Tema.cizgi.withValues(alpha: 0.5)),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 80, height: 16, color: Tema.cizgi.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Container(width: double.infinity, height: 26, color: Tema.cizgi.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Container(width: 200, height: 26, color: Tema.cizgi.withValues(alpha: 0.5)),
            ],
          ),
        ),
        const Divider(height: 1, color: Tema.cizgi),
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
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Tema.cizgi))),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 68, height: 68, color: Tema.cizgi.withValues(alpha: 0.5)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 60, height: 14, color: Tema.cizgi.withValues(alpha: 0.5)),
                const SizedBox(height: 8),
                Container(width: double.infinity, height: 16, color: Tema.cizgi.withValues(alpha: 0.5)),
                const SizedBox(height: 6),
                Container(width: 150, height: 16, color: Tema.cizgi.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

