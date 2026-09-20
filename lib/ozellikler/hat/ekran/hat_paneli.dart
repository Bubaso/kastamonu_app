import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../cekirdek/tema.dart';
import '../model/gorev.dart';
import '../veri/hat_deposu.dart';

/// İnceleme masasının üstündeki hat kontrol şeridi.
///
/// Yönetici haber çekimini istediği anda tetikliyor; zamanlanmış koşu
/// henüz yok (bilerek — önce elle kontrol, sonra otomasyon).
class HatPaneli extends ConsumerStatefulWidget {
  const HatPaneli({super.key, required this.onBitti});

  /// Koşu bittiğinde inceleme masası tazelensin diye.
  final VoidCallback onBitti;

  @override
  ConsumerState<HatPaneli> createState() => _HatPaneliState();
}

class _HatPaneliState extends ConsumerState<HatPaneli> {
  Timer? _sayac;
  bool _tetikleniyor = false;
  int _sinir = 20;
  bool _gecmisAcik = false;
  String? _oncekiDurum;

  @override
  void dispose() {
    _sayac?.cancel();
    super.dispose();
  }

  /// Koşu sürerken kuyruğu düzenli yokluyoruz.
  ///
  /// Gerçek zamanlı abonelik de kurulabilirdi ama koşu birkaç dakika
  /// sürüyor ve tek kullanıcı var; beş saniyelik yoklama hem yeterli
  /// hem de bağlantı koptuğunda kendiliğinden toparlıyor.
  void _sayaciAyarla(bool surmekte) {
    if (surmekte && _sayac == null) {
      _sayac = Timer.periodic(const Duration(seconds: 5), (_) {
        ref.invalidate(gorevGecmisiSaglayici);
      });
    } else if (!surmekte && _sayac != null) {
      _sayac!.cancel();
      _sayac = null;
    }
  }

  Future<void> _tetikle() async {
    setState(() => _tetikleniyor = true);
    try {
      await ref.read(hatDeposuSaglayici).tetikle(sinir: _sinir);
      ref.invalidate(gorevGecmisiSaglayici);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Tetiklenemedi: $e')));
      }
    } finally {
      if (mounted) setState(() => _tetikleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gecmis = ref.watch(gorevGecmisiSaglayici);
    final liste = gecmis.value ?? const <Gorev>[];
    final son = liste.isEmpty ? null : liste.first;
    final surmekte = son?.surmekte ?? false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sayaciAyarla(surmekte);
      // Koşu bittiği anda inceleme masası tazelensin
      if (_oncekiDurum != null &&
          _oncekiDurum != son?.durum &&
          son?.durum == 'bitti') {
        widget.onBitti();
      }
      _oncekiDurum = son?.durum;
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Tema.cizgi.withValues(alpha: .8)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                surmekte ? Icons.sync : Icons.download_outlined,
                size: 18,
                color: Tema.patina,
              ),
              const SizedBox(width: 8),
              const Text(
                'Haber hattı',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 14),
              if (son != null) _durumRozeti(son),
              const Spacer(),
              _sinirSecici(surmekte),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: (_tetikleniyor || surmekte) ? null : _tetikle,
                icon: surmekte
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow, size: 18),
                label: Text(surmekte ? 'Çalışıyor' : 'Haber çek'),
              ),
            ],
          ),
          if (son != null && !surmekte) _sonucSatiri(son),
          if (liste.isNotEmpty) ...[
            const SizedBox(height: 2),
            InkWell(
              onTap: () => setState(() => _gecmisAcik = !_gecmisAcik),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _gecmisAcik ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: Tema.solgun,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Son koşular (${liste.length})',
                      style: const TextStyle(fontSize: 12, color: Tema.solgun),
                    ),
                  ],
                ),
              ),
            ),
            if (_gecmisAcik) _gecmisListesi(liste),
          ],
        ],
      ),
    );
  }

  Widget _sinirSecici(bool kilitli) {
    return DropdownButton<int>(
      value: _sinir,
      isDense: true,
      underline: const SizedBox.shrink(),
      onChanged: kilitli ? null : (d) => setState(() => _sinir = d ?? 20),
      items: const [10, 20, 40]
          .map(
            (n) => DropdownMenuItem(
              value: n,
              child: Text('$n haber', style: const TextStyle(fontSize: 13)),
            ),
          )
          .toList(),
    );
  }

  Widget _durumRozeti(Gorev g) {
    final renk = switch (g.durum) {
      'calisiyor' => Tema.patina,
      'bekliyor' => const Color(0xFFA06000),
      'hata' => Tema.bakir,
      _ => Tema.solgun,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: .09),
        border: Border.all(color: renk.withValues(alpha: .4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        g.durumEtiketi,
        style: TextStyle(
          fontSize: 11,
          color: renk,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _sonucSatiri(Gorev g) {
    final zaman = DateFormat('d MMM HH:mm', 'tr').format(g.istendi);
    final parcalar = <String>[
      zaman,
      if (g.islenen != null) '${g.islenen} işlendi',
      if (g.onaylanan != null) '${g.onaylanan} onaylandı',
      if (g.elenen != null) '${g.elenen} elendi',
    ];
    return Padding(
      padding: const EdgeInsets.only(left: 26, top: 2),
      child: Text(
        parcalar.join('  ·  '),
        style: const TextStyle(fontSize: 12, color: Tema.solgun),
      ),
    );
  }

  Widget _gecmisListesi(List<Gorev> liste) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 260),
      child: SingleChildScrollView(
        child: Column(
          children: liste.map((g) {
            final zaman = DateFormat('d MMM HH:mm', 'tr').format(g.istendi);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      zaman,
                      style: const TextStyle(fontSize: 12, color: Tema.solgun),
                    ),
                  ),
                  _durumRozeti(g),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      g.durum == 'hata'
                          ? ((g.gunluk ?? '').split('\n').last)
                          : '${g.onaylanan ?? 0} onaylandı, '
                                '${g.elenen ?? 0} elendi '
                                '(${g.islenen ?? 0} işlendi)',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: g.durum == 'hata' ? Tema.bakir : Tema.murekkep,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
