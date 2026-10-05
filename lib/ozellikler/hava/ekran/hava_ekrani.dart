import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../cekirdek/tema.dart';
import '../../../cekirdek/tercihler.dart';
import '../../anasayfa/ekran/anasayfa_ekrani.dart';
import '../../pano/ekran/bilgi_seridi.dart' show gunAdi, havaSimgesi;
import '../veri/hava.dart';

/// Hava durumu sayfası.
///
/// Şerit bir vitrin: anlık sıcaklık ve günlerin dereceleri. Burada
/// sığmayanlar var — nem, rüzgar yönü ve hızı, yağış olasılığı — ve
/// on günün tamamı okunur biçimde.
class HavaEkrani extends ConsumerWidget {
  const HavaEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hava = ref.watch(havaSaglayici);
    final ilcem = ref.watch(ilcemSaglayici)?.ad;

    return CustomScrollView(
      slivers: [
        const Kunye(baslik: 'Hava Durumu'),
        hava.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          ),
          error: (_, _) => const _Yok(),
          data: (h) =>
              h == null ? const _Yok() : _Icerik(hava: h, ilcem: ilcem),
        ),
      ],
    );
  }
}

class _Yok extends StatelessWidget {
  const _Yok();

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 18),
        child: Center(
          child: Text(
            'Hava durumu alınamadı.',
            style: TextStyle(
              fontFamily: Tema.sans,
              fontSize: 15,
              color: r.murekkepIkincil,
            ),
          ),
        ),
      ),
    );
  }
}

class _Icerik extends StatelessWidget {
  const _Icerik({required this.hava, required this.ilcem});
  final Hava hava;
  final String? ilcem;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    final s = hava.simdi;

    return SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Şu an ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(havaSimgesi(s.simge), size: 46, color: r.patina),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${s.sicaklik}°',
                          style: TextStyle(
                            fontFamily: Tema.serif,
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            color: r.murekkep,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${hava.ilce} · ${s.ad}',
                          style: TextStyle(
                            fontFamily: Tema.sans,
                            fontSize: 14,
                            color: r.murekkepIkincil,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 22,
                  runSpacing: 8,
                  children: [
                    if (s.hissedilen != null)
                      _Olcum(ad: 'Hissedilen', deger: '${s.hissedilen}°'),
                    if (s.nem != null) _Olcum(ad: 'Nem', deger: '%${s.nem}'),
                    if (s.ruzgar != null)
                      _Olcum(
                        ad: 'Rüzgar',
                        deger: s.ruzgarYonu == null
                            ? '${s.ruzgar} km/s'
                            : '${s.ruzgarYonu} ${s.ruzgar} km/s',
                      ),
                  ],
                ),
                if (ilcem == null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'İlçeni seçersen hava durumu oraya göre gösterilir.',
                    style: TextStyle(
                      fontFamily: Tema.sans,
                      fontSize: 13,
                      color: r.solgun,
                    ),
                  ),
                ],

                const SizedBox(height: 26),
                Text(
                  '${hava.gunler.length} GÜNLÜK TAHMİN',
                  style: TextStyle(
                    fontFamily: Tema.sans,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: r.murekkep,
                  ),
                ),
                const SizedBox(height: 10),
                for (final g in hava.gunler) _GunSatiri(gun: g),

                const SizedBox(height: 18),
                Text(
                  'Kaynak: ${hava.kaynak}',
                  style: TextStyle(
                    fontFamily: Tema.sans,
                    fontSize: 12,
                    color: r.solgun,
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

class _Olcum extends StatelessWidget {
  const _Olcum({required this.ad, required this.deger});
  final String ad;
  final String deger;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ad.toUpperCase(),
          style: TextStyle(
            fontFamily: Tema.sans,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: r.solgun,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          deger,
          style: TextStyle(
            fontFamily: Tema.sans,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: r.murekkep,
          ),
        ),
      ],
    );
  }
}

class _GunSatiri extends StatelessWidget {
  const _GunSatiri({required this.gun});
  final HavaGunu gun;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    return Semantics(
      label:
          '${DateFormat('d MMMM EEEE', 'tr').format(gun.tarih)}, ${gun.ad}, '
          'en yüksek ${gun.enYuksek}, en düşük ${gun.enDusuk} derece'
          '${gun.yagisOlasiligi != null ? ', yağış olasılığı yüzde ${gun.yagisOlasiligi}' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: r.cizgi)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                gunAdi(gun.tarih),
                style: TextStyle(
                  fontFamily: Tema.sans,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .6,
                  color: r.murekkepIkincil,
                ),
              ),
            ),
            Icon(havaSimgesi(gun.simge), size: 18, color: r.murekkepIkincil),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                gun.ad,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: Tema.sans,
                  fontSize: 13.5,
                  color: r.murekkepIkincil,
                ),
              ),
            ),
            if (gun.yagisOlasiligi != null && gun.yagisOlasiligi! > 0) ...[
              Text(
                '%${gun.yagisOlasiligi}',
                style: TextStyle(
                  fontFamily: Tema.sans,
                  fontSize: 12.5,
                  color: r.patina,
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (gun.ruzgar != null) ...[
              Text(
                '${gun.ruzgar} km/s',
                style: TextStyle(
                  fontFamily: Tema.sans,
                  fontSize: 12.5,
                  color: r.solgun,
                ),
              ),
              const SizedBox(width: 14),
            ],
            SizedBox(
              width: 76,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${gun.enYuksek ?? '–'}°',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: r.murekkep,
                      ),
                    ),
                    TextSpan(
                      text: '  ${gun.enDusuk ?? '–'}°',
                      style: TextStyle(color: r.solgun),
                    ),
                  ],
                ),
                textAlign: TextAlign.right,
                style: TextStyle(fontFamily: Tema.sans, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
