import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cekirdek/tema.dart';
import '../../../cekirdek/tercihler.dart';
import '../../anasayfa/ekran/anasayfa_ekrani.dart';
import '../../anasayfa/veri/anasayfa_deposu.dart';

/// İlçem — portalın Kastamonu'ya özgü parçası.
///
/// Rakiplerde "İlçeler" bir kategori: tıklarsın, 20 ilçenin listesi çıkar,
/// birini seçersin, geri dönünce yine baştan seçersin. Burada ilçe bir
/// **ayar**: okur bir kez seçiyor, uygulama hatırlıyor, sekme her açıldığında
/// doğrudan kendi ilçesinin haberleri geliyor.
///
/// Bunu yapabilmemizin nedeni hattaki ilçe etiketlemesi: haberler güvenle
/// ilçeye bağlanıyor, dolayısıyla bu sekme gerçek bir akış üretiyor.
/// Hazır yayın yazılımı kullanan yerel siteler bunu yapamıyor.
class IlcemEkrani extends ConsumerWidget {
  const IlcemEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ilcem = ref.watch(ilcemSaglayici);

    return CustomScrollView(
      slivers: [
        const Kunye(baslik: 'İlçem'),
        if (ilcem == null)
          const _Secim()
        else
          ..._akis(context, ref, ilcem),
        const SliverToBoxAdapter(child: Alt()),
      ],
    );
  }

  List<Widget> _akis(BuildContext context, WidgetRef ref, Ilcem ilcem) {
    final haberler = ref.watch(ilceAkisiSaglayici(ilcem.id));
    return [
      SliverToBoxAdapter(child: _Basi(ilcem: ilcem)),
      haberler.when(
        loading: () => const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (h, _) => SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('$h')),
        ),
        data: (liste) => liste.isEmpty
            ? SliverFillRemaining(
                hasScrollBody: false,
                child: Bos(
                  baslik: '${ilcem.ad} için henüz haber yok.',
                  aciklama:
                      'Bu ilçeden haber geldiğinde burada görünecek. '
                      'Bu arada Gündem sekmesinde il genelini izleyebilirsin.',
                ),
              )
            : SliverList.builder(
                itemCount: liste.length,
                itemBuilder: (c, i) => i == 0
                    ? Manset(haber: liste[i])
                    : Satir(haber: liste[i]),
              ),
      ),
    ];
  }
}

/// Seçili ilçenin başlığı ve değiştirme bağlantısı.
class _Basi extends ConsumerWidget {
  const _Basi({required this.ilcem});
  final Ilcem ilcem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Tema.sunk,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
            child: Row(
              children: [
                const Icon(Icons.place, size: 17, color: Tema.bakir),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    ilcem.ad,
                    style: const TextStyle(
                      fontFamily: Tema.serif,
                      fontWeight: FontWeight.w700,
                      fontSize: 19,
                      letterSpacing: -0.3,
                      color: Tema.murekkep,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(ilcemSaglayici.notifier).temizle(),
                  style: TextButton.styleFrom(foregroundColor: Tema.patina),
                  child: const Text(
                    'Değiştir',
                    style: TextStyle(
                      fontFamily: Tema.sans,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
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

/// İlçe seçimi.
///
/// Yalnızca haberi olan ilçeler listeleniyor. 20 ilçenin tamamını göstermek
/// yanıltıcı olurdu: ölçümde katman 1+2 akışında ilçelerin yarısından
/// fazlasına hiç haber gelmiyor ve okur seçtiği ilçede boş ekran görüyor.
class _Secim extends ConsumerWidget {
  const _Secim();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ilceler = ref.watch(tumIlcelerSaglayici);

    return SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'İlçeni seç',
                  style: TextStyle(
                    fontFamily: Tema.serif,
                    fontWeight: FontWeight.w700,
                    fontSize: 25,
                    height: 1.16,
                    letterSpacing: -0.5,
                    color: Tema.murekkep,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bir kez seç, bu sekme hep senin ilçenle açılsın. '
                  'Seçimin yalnızca bu cihazda saklanır; üyelik gerekmez.',
                  style: TextStyle(
                    fontFamily: Tema.sans,
                    fontSize: 14.5,
                    height: 1.55,
                    color: Tema.murekkepIkincil,
                  ),
                ),
                const SizedBox(height: 20),
                ilceler.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (h, _) => Text('$h'),
                  data: (liste) => liste.isEmpty
                      ? const Text(
                          'Henüz ilçe etiketli haber yok.',
                          style: TextStyle(
                            fontFamily: Tema.sans,
                            color: Tema.solgun,
                          ),
                        )
                      : Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: liste
                              .map((i) => _Dugme(id: i.id, ad: i.ad, adet: i.adet))
                              .toList(),
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

class _Dugme extends ConsumerWidget {
  const _Dugme({required this.id, required this.ad, required this.adet});

  final String id;
  final String ad;
  final int adet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => ref.read(ilcemSaglayici.notifier).sec(id, ad),
        child: Container(
          // Dokunma hedefi cömert: okur kitlesinin ortanca yaşı 43.
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(color: Tema.cizgiKuvvetli),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ad,
                style: const TextStyle(
                  fontFamily: Tema.serif,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  color: Tema.murekkep,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$adet',
                style: const TextStyle(
                  fontFamily: Tema.sans,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Tema.solgun,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
