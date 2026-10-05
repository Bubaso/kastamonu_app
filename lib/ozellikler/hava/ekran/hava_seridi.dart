import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../cekirdek/tema.dart';
import '../veri/hava.dart';

/// Bölüm çubuğunun altındaki hava şeridi.
///
/// Neden şerit, neden kart değil
/// ─────────────────────────────
/// Hava bakılıp geçilen bir bilgi. Kart olsaydı manşetin yanında yer
/// kaplar ve haberle yarışırdı; şerit başlığın devamı gibi duruyor,
/// göz haberin üstünden geçerken yolda okuyor.
///
/// Şerit yalnız veri VARSA çiziliyor. Sağlayıcı düştüğünde,
/// `HAVA_TABANI` verilmediğinde (yerel geliştirme) ya da sıcaklık
/// gelmediğinde hiç görünmüyor — hata kutusu da, boş yer tutucu da yok.
/// Hava durumu sayfanın yardımcı öğesi; yokluğu sayfayı bozmamalı.
class HavaSeridi extends ConsumerWidget {
  const HavaSeridi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hava = ref.watch(havaSaglayici).asData?.value;
    if (hava == null) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(child: _Serit(hava: hava));
  }
}

class _Serit extends StatelessWidget {
  const _Serit({required this.hava});
  final Hava hava;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    final genis = MediaQuery.sizeOf(context).width >= 860;

    return Container(
      width: double.infinity,
      color: r.sunk,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          // Genişliği ZORLAMAK gerekiyor: yatay kaydırma kutusu
          // içeriği kadar daralıyor ve `Center` onu ortalıyordu, yani
          // şerit sayfanın geri kalanıyla hizasız duruyordu —
          // ölçüldü, sol kenarı başlıktan 200 piksel içerideydi.
          child: SizedBox(
            width: double.infinity,
            child: Semantics(
              label: _etiket(hava),
              excludeSemantics: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _Simdi(hava: hava, genis: genis),
                    const SizedBox(width: 18),
                    // Bugün zaten solda; tahmin yarından başlıyor.
                    for (final g in hava.gunler.skip(1))
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: _Gun(gun: g),
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

class _Simdi extends StatelessWidget {
  const _Simdi({required this.hava, required this.genis});
  final Hava hava;
  final bool genis;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    final s = hava.simdi;
    return Row(
      children: [
        Icon(havaSimgesi(s.simge), size: 19, color: r.patina),
        const SizedBox(width: 7),
        Text(
          '${s.sicaklik}°',
          style: TextStyle(
            fontFamily: Tema.serif,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            height: 1,
            color: r.murekkep,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          hava.ilce,
          style: TextStyle(
            fontFamily: Tema.sans,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: r.solgun,
          ),
        ),
        // Dar ekranda ayrıntı düşüyor: şerit tek satır kalmalı.
        if (genis) ...[
          const SizedBox(width: 10),
          _Ayrinti(metin: s.ad),
          if (s.nem != null) _Ayrinti(metin: 'nem %${s.nem}'),
          if (s.ruzgar != null)
            _Ayrinti(
              metin: s.ruzgarYonu == null
                  ? 'rüzgar ${s.ruzgar} km/s'
                  : '${s.ruzgarYonu} ${s.ruzgar} km/s',
            ),
        ],
      ],
    );
  }
}

class _Ayrinti extends StatelessWidget {
  const _Ayrinti({required this.metin});
  final String metin;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Text(
        metin,
        style: TextStyle(
          fontFamily: Tema.sans,
          fontSize: 12.5,
          color: r.murekkepIkincil,
        ),
      ),
    );
  }
}

class _Gun extends StatelessWidget {
  const _Gun({required this.gun});
  final HavaGunu gun;

  @override
  Widget build(BuildContext context) {
    final r = Renkler.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          gunAdi(gun.tarih),
          style: TextStyle(
            fontFamily: Tema.sans,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: .6,
            color: r.solgun,
          ),
        ),
        const SizedBox(height: 3),
        Icon(havaSimgesi(gun.simge), size: 15, color: r.murekkepIkincil),
        const SizedBox(height: 3),
        Text.rich(
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
                text: ' ${gun.enDusuk ?? '–'}°',
                style: TextStyle(color: r.solgun),
              ),
            ],
          ),
          style: TextStyle(fontFamily: Tema.sans, fontSize: 12, height: 1),
        ),
      ],
    );
  }
}

/// Simge anahtarını ikona çeviriyor.
///
/// Anahtarlar sunucudan geliyor (`functions/hava.js`); burada
/// bilinmeyen anahtar da bir ikon alıyor, şerit boş kutu göstermiyor.
IconData havaSimgesi(String simge) => switch (simge) {
  'acik' => Icons.wb_sunny_outlined,
  'az-bulutlu' => Icons.wb_cloudy_outlined,
  'parcali-bulutlu' => Icons.wb_cloudy_outlined,
  'cok-bulutlu' => Icons.cloud_outlined,
  'sis' => Icons.foggy,
  'cisenti' => Icons.grain,
  'yagmur' => Icons.water_drop_outlined,
  'saganak' => Icons.umbrella_outlined,
  'kar' => Icons.ac_unit,
  'firtina' => Icons.thunderstorm_outlined,
  _ => Icons.thermostat,
};

/// Günün kısa adı. Bugün ve yarın adlarıyla anılıyor.
String gunAdi(DateTime t, {DateTime? simdi}) {
  final an = simdi ?? DateTime.now();
  final bugun = DateTime(an.year, an.month, an.day);
  final gun = DateTime(t.year, t.month, t.day);
  final fark = gun.difference(bugun).inDays;
  if (fark == 0) return 'BUGÜN';
  if (fark == 1) return 'YARIN';
  return DateFormat('EEE', 'tr').format(t).toUpperCase();
}

/// Ekran okuyucu için tek cümle.
///
/// Şeridin kendisi onlarca küçük metin; ayrı ayrı okunması gürültü.
String _etiket(Hava hava) {
  final s = hava.simdi;
  final parcalar = <String>[
    '${hava.ilce} hava durumu',
    '${s.sicaklik} derece',
    if (s.ad != '—') s.ad,
    if (s.nem != null) 'nem yüzde ${s.nem}',
    if (s.ruzgar != null)
      s.ruzgarYonu == null
          ? 'rüzgar saatte ${s.ruzgar} kilometre'
          : '${s.ruzgarYonu} yönünden saatte ${s.ruzgar} kilometre rüzgar',
    if (hava.gunler.length > 1) '${hava.gunler.length} günlük tahmin',
  ];
  return parcalar.join(', ');
}
