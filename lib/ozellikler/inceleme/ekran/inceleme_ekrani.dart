import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../cekirdek/supabase.dart';

import '../../hat/ekran/hat_paneli.dart';
import '../veri/inceleme_deposu.dart';
import 'haber_karti.dart';

class IncelemeEkrani extends ConsumerWidget {
  const IncelemeEkrani({super.key});

  static const _durumlar = [
    ('inceleme', 'İnceleme masası', Icons.inbox_outlined),
    ('yayinda', 'Yayında', Icons.public),
    ('reddedildi', 'Reddedilen', Icons.block_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final durum = ref.watch(durumSaglayici);
    final haberler = ref.watch(haberlerSaglayici);
    final sayimlar = ref.watch(sayimSaglayici);
    final depo = ref.read(depoSaglayici);

    void tazele() {
      ref.invalidate(haberlerSaglayici);
      ref.invalidate(sayimSaglayici);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kastamonu Haber — Panel'),
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.home_outlined),
          tooltip: 'Ana sayfa',
        ),
        actions: [
          IconButton(
            onPressed: tazele,
            icon: const Icon(Icons.refresh),
            tooltip: 'Tazele',
          ),
          IconButton(
            onPressed: () async {
              await sb.auth.signOut();
              if (context.mounted) context.go('/');
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          HatPaneli(onBitti: tazele),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              color: t.colorScheme.surfaceContainerHighest.withValues(
                alpha: .4,
              ),
              border: Border(
                bottom: BorderSide(color: t.dividerColor.withValues(alpha: .5)),
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _durumlar.map((d) {
                final secili = durum == d.$1;
                final n = sayimlar.value?[d.$1];
                return ChoiceChip(
                  selected: secili,
                  onSelected: (_) =>
                      ref.read(durumSaglayici.notifier).sec(d.$1),
                  avatar: Icon(
                    d.$3,
                    size: 16,
                    color: secili ? Colors.white : t.hintColor,
                  ),
                  label: Text(n == null ? d.$2 : '${d.$2}  $n'),
                  selectedColor: const Color(0xFF0D6B5A),
                  labelStyle: TextStyle(
                    color: secili ? Colors.white : null,
                    fontWeight: secili ? FontWeight.w600 : null,
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: haberler.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (h, _) => _hata(context, h, tazele),
              data: (liste) {
                if (liste.isEmpty) return _bos(t, durum);
                return RefreshIndicator(
                  onRefresh: () async => tazele(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    itemCount: liste.length,
                    itemBuilder: (c, i) {
                      final h = liste[i];
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 820),
                          child: HaberKarti(
                            key: ValueKey(h.id),
                            haber: h,
                            onKaydet: (b, s, g) async {
                              await depo.alanlariKaydet(
                                h.id,
                                baslik: b,
                                spot: s,
                                govde: g,
                              );
                              tazele();
                            },
                            onYayinla: () async {
                              await depo.yayinla(h.id);
                              tazele();
                            },
                            onReddet: (gerekce) async {
                              await depo.reddet(h.id, gerekce);
                              tazele();
                            },
                            onIncelemeyeAl: () async {
                              await depo.incelemeyeAl(h.id);
                              tazele();
                            },
                            onBagOnayla: (ilceId, onay) async {
                              await depo.bagOnayla(h.id, ilceId, onay);
                              tazele();
                            },
                            onBagSil: (ilceId) async {
                              await depo.bagSil(h.id, ilceId);
                              tazele();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _bos(ThemeData t, String durum) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.done_all, size: 44, color: t.hintColor),
        const SizedBox(height: 12),
        Text(
          durum == 'inceleme'
              ? 'İnceleme masası boş.\nHat yeni haber getirdiğinde burada görünecek.'
              : 'Bu listede kayıt yok.',
          textAlign: TextAlign.center,
          style: t.textTheme.bodyMedium?.copyWith(color: t.hintColor),
        ),
      ],
    ),
  );

  Widget _hata(BuildContext c, Object hata, VoidCallback tazele) {
    final yetki =
        hata.toString().contains('row-level security') ||
        hata.toString().contains('JWT') ||
        hata.toString().contains('permission');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Color(0xFFA84A18)),
            const SizedBox(height: 12),
            Text(
              yetki
                  ? 'Yetki hatası: inceleme masasını görmek için oturum açmak '
                        'gerekiyor.\nRLS yalnızca yayındaki haberi anonim açıyor.'
                  : 'Veri alınamadı.\n$hata',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: tazele,
              icon: const Icon(Icons.refresh),
              label: const Text('Yeniden dene'),
            ),
          ],
        ),
      ),
    );
  }
}
