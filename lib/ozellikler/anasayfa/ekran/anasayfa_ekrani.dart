import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../cekirdek/tema.dart';
import '../../inceleme/model/haber.dart';
import '../veri/anasayfa_deposu.dart';

class AnasayfaEkrani extends ConsumerWidget {
  const AnasayfaEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final haberler = ref.watch(yayindakilerSaglayici);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(yayindakilerSaglayici),
        child: CustomScrollView(
          slivers: [
            const _Kunye(),
            const _IlceCubugu(),
            haberler.when(
              loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator())),
              error: (h, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Padding(
                      padding: const EdgeInsets.all(28), child: Text('$h')))),
              data: (liste) => liste.isEmpty
                  ? const SliverFillRemaining(
                      hasScrollBody: false, child: _Bos())
                  : _Akis(liste: liste),
            ),
            const SliverToBoxAdapter(child: _Alt()),
          ],
        ),
      ),
    );
  }
}

class _Kunye extends StatelessWidget {
  const _Kunye();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Tema.cizgi)),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Row(children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Kastamonu Haber',
                        style: t.textTheme.displaySmall?.copyWith(fontSize: 30)),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat("d MMMM y, EEEE", 'tr').format(DateTime.now()),
                      style: t.textTheme.labelMedium
                          ?.copyWith(color: Tema.solgun),
                    ),
                  ],
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.go('/panel'),
                  icon: const Icon(Icons.dashboard_outlined, size: 17),
                  label: const Text('Panel'),
                  style: TextButton.styleFrom(foregroundColor: Tema.solgun),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// İlçe süzgeci — portalın Kastamonu'ya özgü parçası.
///
/// Haber akışını ilçeye göre daraltıyor. Rakiplerin hazır yayın
/// yazılımlarında bu kırılım yok; bizde etiketleme hattan geliyor.
class _IlceCubugu extends ConsumerWidget {
  const _IlceCubugu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ilceler = ref.watch(ilceListesiSaglayici);
    final secili = ref.watch(ilceSuzgeciSaglayici);

    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: SizedBox(
              height: 52,
              child: ilceler.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (liste) => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  children: [
                    _cip(context, ref, 'İl geneli', null, secili == null),
                    ...liste.map((i) =>
                        _cip(context, ref, i.ad, i.id, secili == i.id)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cip(BuildContext c, WidgetRef ref, String ad, String? id, bool sec) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
      child: ChoiceChip(
        selected: sec,
        onSelected: (_) => ref.read(ilceSuzgeciSaglayici.notifier).sec(id),
        label: Text(ad, style: TextStyle(
            fontSize: 12.5,
            color: sec ? Colors.white : Tema.murekkep,
            fontWeight: sec ? FontWeight.w600 : FontWeight.w400)),
        selectedColor: Tema.patina,
        backgroundColor: Colors.white,
        side: BorderSide(color: sec ? Tema.patina : Tema.cizgi),
        showCheckmark: false,
      ),
    );
  }
}

class _Akis extends StatelessWidget {
  const _Akis({required this.liste});
  final List<Haber> liste;

  @override
  Widget build(BuildContext context) {
    final genis = MediaQuery.sizeOf(context).width >= 860;
    final manset = liste.first;
    final kalan = liste.skip(1).toList();

    return SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 8),
            child: Column(children: [
              _Manset(haber: manset),
              if (kalan.isNotEmpty) ...[
                const SizedBox(height: 26),
                const _BolumBasligi('Diğer haberler'),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: genis ? 3 : 1,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    mainAxisExtent: 196,
                  ),
                  itemCount: kalan.length,
                  itemBuilder: (c, i) => _Kutu(haber: kalan[i]),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _BolumBasligi extends StatelessWidget {
  const _BolumBasligi(this.metin);
  final String metin;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(metin.toUpperCase(),
          style: const TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w700,
              letterSpacing: 1.2, color: Tema.solgun)),
      const SizedBox(width: 12),
      const Expanded(child: Divider()),
    ]);
  }
}

class _Manset extends StatelessWidget {
  const _Manset({required this.haber});
  final Haber haber;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Etiketler(haber: haber, buyuk: true),
          const SizedBox(height: 12),
          Text(haber.baslik,
              style: t.textTheme.displaySmall?.copyWith(fontSize: 27)),
          if ((haber.spot ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(haber.spot!,
                style: t.textTheme.bodyLarge
                    ?.copyWith(color: Tema.solgun, height: 1.5)),
          ],
          const SizedBox(height: 14),
          _KaynakSatiri(haber: haber),
        ]),
      ),
    );
  }
}

class _Kutu extends StatelessWidget {
  const _Kutu({required this.haber});
  final Haber haber;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Etiketler(haber: haber),
          const SizedBox(height: 9),
          Text(haber.baslik,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.titleMedium?.copyWith(fontSize: 16)),
          const SizedBox(height: 7),
          Expanded(
            child: Text(haber.spot ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.bodySmall
                    ?.copyWith(color: Tema.solgun, height: 1.45)),
          ),
          _KaynakSatiri(haber: haber, kucuk: true),
        ]),
      ),
    );
  }
}

class _Etiketler extends StatelessWidget {
  const _Etiketler({required this.haber, this.buyuk = false});
  final Haber haber;
  final bool buyuk;

  @override
  Widget build(BuildContext context) {
    final ilce = haber.ilceler.where((b) => b.onaylandi).map((b) => b.ad);
    return Wrap(spacing: 8, runSpacing: 5, crossAxisAlignment:
        WrapCrossAlignment.center, children: [
      if (haber.kategoriAd != null)
        Text(haber.kategoriAd!.toUpperCase(),
            style: TextStyle(
                fontSize: buyuk ? 11.5 : 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: Tema.patina)),
      ...ilce.map((ad) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: Tema.cizgi),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(ad,
                style: const TextStyle(fontSize: 10.5, color: Tema.solgun)),
          )),
      Text(DateFormat('d MMM HH:mm', 'tr').format(haber.olusturuldu),
          style: const TextStyle(fontSize: 10.5, color: Tema.solgun)),
    ]);
  }
}

/// Kaynak künyesi. Her haberde görünür — telif zemininin arayüz karşılığı.
class _KaynakSatiri extends StatelessWidget {
  const _KaynakSatiri({required this.haber, this.kucuk = false});
  final Haber haber;
  final bool kucuk;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(Icons.link, size: kucuk ? 12 : 14, color: Tema.solgun),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          'Kaynak: ${haber.kaynakAdi}'
          '${haber.yayinci?.isNotEmpty == true ? " · ${haber.yayinci}" : ""}',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: kucuk ? 10.5 : 12, color: Tema.solgun),
        ),
      ),
    ]);
  }
}

class _Bos extends StatelessWidget {
  const _Bos();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.article_outlined, size: 44, color: Tema.solgun),
          SizedBox(height: 14),
          Text('Bu seçimde yayımlanmış haber yok.',
              style: TextStyle(color: Tema.solgun)),
          SizedBox(height: 6),
          Text('Panelden haber yayınlandığında burada görünür.',
              style: TextStyle(color: Tema.solgun, fontSize: 12.5)),
        ]),
      ),
    );
  }
}

class _Alt extends StatelessWidget {
  const _Alt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 34, 20, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Divider(),
            SizedBox(height: 14),
            Text(
              'Kastamonu Haber · haberler kaynak gösterilerek derlenmektedir. '
              'Her haberin künyesinde özgün kaynağı belirtilir.',
              style: TextStyle(fontSize: 12, color: Tema.solgun, height: 1.5),
            ),
          ]),
        ),
      ),
    );
  }
}
