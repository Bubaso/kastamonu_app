import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cekirdek/tema.dart';
import '../../../cekirdek/tercihler.dart';
import '../../anasayfa/ekran/anasayfa_ekrani.dart';
import '../veri/kaydedilen_deposu.dart';

/// Kaydettiklerim.
///
/// Türkiye'de haber sitesi okurlarıyla yapılan ankette "kaydetme" %50'nin
/// üzerinde talep gören dört modülden biri; Kastamonu'daki yerel sitelerin
/// hiçbirinde yok. Maliyeti de yok: üyelik istemiyor, sunucuya hiçbir şey
/// yazmıyor, tarayıcıda duruyor.
class KaydedilenEkrani extends ConsumerWidget {
  const KaydedilenEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final haberler = ref.watch(kaydedilenHaberlerSaglayici);
    final sluglar = ref.watch(kaydedilenlerSaglayici);

    return CustomScrollView(
      slivers: [
        const Kunye(baslik: 'Kaydettiklerim'),
        if (sluglar.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Bos(
              baslik: 'Henüz haber kaydetmedin.',
              aciklama:
                  'Bir haberi açtığında sağ üstteki yer imi düğmesine bas; '
                  'burada birikir. Kayıtlar bu cihazda kalır.',
            ),
          )
        else ...[
          SliverToBoxAdapter(child: _Basi(adet: sluglar.length)),
          haberler.when(
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (h, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('$h')),
            ),
            data: (liste) => SliverList.builder(
              itemCount: liste.length,
              itemBuilder: (c, i) => Satir(haber: liste[i]),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: Alt()),
      ],
    );
  }
}

class _Basi extends ConsumerWidget {
  const _Basi({required this.adet});
  final int adet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = Renkler.of(context);
    return Container(
      color: r.sunk,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 11, 12, 11),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$adet haber kayıtlı',
                    style: TextStyle(
                      fontFamily: Tema.sans,
                      fontSize: 13.5,
                      color: r.solgun,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _hepsiniSil(context, ref),
                  style: TextButton.styleFrom(foregroundColor: r.solgun),
                  child: const Text(
                    'Tümünü kaldır',
                    style: TextStyle(fontFamily: Tema.sans, fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Geri alınamayan bir işlem; onay soruluyor.
  Future<void> _hepsiniSil(BuildContext context, WidgetRef ref) async {
    final r = Renkler.of(context);
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: r.zemin,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
        title: Text(
          'Kayıtlar kaldırılsın mı?',
          style: TextStyle(
            fontFamily: Tema.serif,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: r.murekkep,
          ),
        ),
        content: Text(
          '$adet haber listeden çıkacak. Haberler silinmiyor, yalnızca '
          'senin kayıt listenden kalkıyor.',
          style: TextStyle(
            fontFamily: Tema.sans,
            fontSize: 14.5,
            height: 1.5,
            color: r.murekkepIkincil,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            style: TextButton.styleFrom(foregroundColor: r.solgun),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: r.uyari),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    if (onay == true) {
      await ref.read(kaydedilenlerSaglayici.notifier).hepsiniSil();
    }
  }
}
