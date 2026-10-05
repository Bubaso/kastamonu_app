import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../cekirdek/tema.dart';
import '../../../cekirdek/tercihler.dart';
import '../../anasayfa/ekran/anasayfa_ekrani.dart';
import '../veri/eczane.dart';

/// Nöbetçi eczaneler sayfası.
///
/// Şeritteki tek satır ilk eczaneyi söylüyor; okurun gerçekten
/// ihtiyacı olan şey ise adres, telefon ve yol tarifi. Onlar burada.
///
/// Sayfa kaynağı ve tarihi GÖRÜNÜR biçimde yazıyor. Liste odanın
/// sayfasından derleniyor ve o sayfa bir gün geç güncellenebilir;
/// okur neye baktığını bilmeli ve doğrulayabilmeli.
class EczaneEkrani extends ConsumerWidget {
  const EczaneEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nobet = ref.watch(nobetSaglayici);
    final ilcem = ref.watch(ilcemSaglayici)?.ad;

    return CustomScrollView(
      slivers: [
        const Kunye(baslik: 'Nöbetçi Eczaneler'),
        nobet.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          ),
          error: (_, _) => const _Yok(),
          data: (n) => n == null
              ? const _Yok()
              : _Liste(nobet: n, sirali: n.siraliListe(ilcem), ilcem: ilcem),
        ),
      ],
    );
  }
}

/// Liste alınamadığında.
///
/// Eski listeyi göstermektense hiç göstermemek: kapalı eczaneye
/// yollamaktansa okuru odanın sayfasına yollamak.
class _Yok extends StatelessWidget {
  const _Yok();

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    return SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 48, 18, 48),
            child: Column(
              children: [
                Icon(Icons.local_pharmacy_outlined, size: 34, color: r.solgun),
                const SizedBox(height: 14),
                Text(
                  'Bugünün nöbet listesi alınamadı',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: Tema.serif,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: r.murekkep,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Eski bir listeyi göstermek yanlış yönlendirir. '
                  'Güncel nöbet listesi için Kastamonu Eczacı Odası.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: Tema.sans,
                    fontSize: 14,
                    height: 1.5,
                    color: r.murekkepIkincil,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => launchUrl(
                    Uri.parse(
                      'https://www.kastamonueo.org.tr/nobetci-eczaneler/37',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('Eczacı Odası sayfasını aç'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({
    required this.nobet,
    required this.sirali,
    required this.ilcem,
  });
  final Nobet nobet;
  final List<Eczane> sirali;
  final String? ilcem;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    return SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormat('d MMMM EEEE', 'tr').format(nobet.tarih!)} '
                  'nöbet listesi',
                  style: TextStyle(
                    fontFamily: Tema.sans,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .3,
                    color: r.murekkepIkincil,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${sirali.length} eczane · ${nobet.kaynak}',
                  style: TextStyle(
                    fontFamily: Tema.sans,
                    fontSize: 12.5,
                    color: r.solgun,
                  ),
                ),
                const SizedBox(height: 18),
                for (final e in sirali)
                  _Kart(eczane: e, benimIlcem: _ayni(e.ilce, ilcem)),
                const SizedBox(height: 18),
                if (nobet.kaynakAdres != null)
                  TextButton(
                    onPressed: () => launchUrl(
                      nobet.kaynakAdres!,
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Text('Listeyi ${nobet.kaynak} sayfasında doğrula'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static bool _ayni(String? a, String? b) {
    if (a == null || b == null) return false;
    String d(String s) =>
        s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase().trim();
    return d(a) == d(b);
  }
}

class _Kart extends StatelessWidget {
  const _Kart({required this.eczane, required this.benimIlcem});
  final Eczane eczane;
  final bool benimIlcem;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    return Semantics(
      label:
          '${eczane.ad}, ${eczane.ilce ?? ''}. '
          '${eczane.adres}. Telefon ${eczane.telefonGosterim}',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: r.kart,
          border: Border.all(color: benimIlcem ? r.patina : r.cizgi),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    eczane.ad,
                    style: TextStyle(
                      fontFamily: Tema.serif,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: r.murekkep,
                    ),
                  ),
                ),
                if (eczane.ilce != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    eczane.ilce!,
                    style: TextStyle(
                      fontFamily: Tema.sans,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: benimIlcem ? r.patina : r.solgun,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              eczane.adres,
              style: TextStyle(
                fontFamily: Tema.sans,
                fontSize: 14,
                height: 1.45,
                color: r.murekkepIkincil,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _Dugme(
                  simge: Icons.phone_outlined,
                  yazi: eczane.telefonGosterim,
                  tiklama: () => launchUrl(eczane.arama),
                ),
                if (eczane.harita != null)
                  _Dugme(
                    simge: Icons.map_outlined,
                    yazi: 'Yol tarifi',
                    tiklama: () => launchUrl(
                      eczane.harita!,
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dugme extends StatelessWidget {
  const _Dugme({
    required this.simge,
    required this.yazi,
    required this.tiklama,
  });
  final IconData simge;
  final String yazi;
  final VoidCallback tiklama;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    return Material(
      color: r.sunk,
      child: InkWell(
        onTap: tiklama,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(simge, size: 16, color: r.patina),
              const SizedBox(width: 7),
              Text(
                yazi,
                style: TextStyle(
                  fontFamily: Tema.sans,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: r.murekkep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
