import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../cekirdek/tema.dart';
import '../../anasayfa/ekran/anasayfa_ekrani.dart';
import '../veri/arama_deposu.dart';

/// Arama.
///
/// Kendi adresi var (`/ara?q=...`): portalın geri kalanında olduğu gibi
/// burada da durum adres çubuğunda duruyor, yani bir arama sonucu
/// paylaşılabiliyor ve yer imine eklenebiliyor.
class AramaEkrani extends ConsumerStatefulWidget {
  const AramaEkrani({super.key, this.baslangic});

  /// Adresten gelen sorgu.
  final String? baslangic;

  @override
  ConsumerState<AramaEkrani> createState() => _AramaEkraniState();
}

class _AramaEkraniState extends ConsumerState<AramaEkrani> {
  late final TextEditingController _kutu =
      TextEditingController(text: widget.baslangic ?? '');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aramaSorgusuSaglayici.notifier).yaz(_kutu.text);
    });
  }

  @override
  void dispose() {
    _kutu.dispose();
    super.dispose();
  }

  void _yaz(String s) {
    ref.read(aramaSorgusuSaglayici.notifier).yaz(s);
    // Adres her tuşta değil, yalnız aramada anlamlı olacak kadar
    // yazıldığında güncelleniyor — her harf için geçmişe kayıt düşmesin.
    if (s.trim().length >= 2) {
      context.replace('/ara?q=${Uri.encodeQueryComponent(s)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorgu = ref.watch(aramaSorgusuSaglayici);
    final sonuclar = ref.watch(aramaSonuclariSaglayici);
    final yeterliSorgu = aramaKelimeleri(sorgu).isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Cubuk(kutu: _kutu, onYaz: _yaz)),
          if (!yeterliSorgu)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Bos(
                baslik: 'Ne arıyorsunuz?',
                aciklama: 'Başlık, bölüm, ilçe ve haber metni içinde aranır.',
              ),
            )
          else if (sonuclar.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Bos(
                baslik: '"${sorgu.trim()}" için sonuç yok.',
                aciklama: 'Yayındaki haberlerde bu kelimeler geçmiyor.',
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  // `Center` gevşek kısıt veriyor; genişlik açıkça
                  // istenmezse satır içeriği kadar daralıp ortalanıyor.
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                    child: Text(
                      '${sonuclar.length} haber',
                      style: const TextStyle(
                        fontFamily: Tema.sans,
                        fontSize: 12.5,
                        color: Tema.solgun,
                      ),
                    ),
                  ),
                  ),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: sonuclar.length,
              itemBuilder: (c, i) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Satir(haber: sonuclar[i]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Cubuk extends StatelessWidget {
  const _Cubuk({required this.kutu, required this.onYaz});

  final TextEditingController kutu;
  final ValueChanged<String> onYaz;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Tema.murekkep, width: 2)),
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 14, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/'),
                    icon: const Icon(Icons.arrow_back, size: 22),
                    color: Tema.murekkep,
                    tooltip: 'Geri',
                  ),
                  Expanded(
                    child: TextField(
                      controller: kutu,
                      autofocus: true,
                      onChanged: onYaz,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(
                        fontFamily: Tema.serif,
                        // Arama kutusu da 17,5 tabanının altına inmiyor.
                        fontSize: 18,
                        color: Tema.murekkep,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Haberlerde ara',
                        hintStyle: TextStyle(
                          fontFamily: Tema.serif,
                          fontSize: 18,
                          color: Tema.solgun,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (kutu.text.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        kutu.clear();
                        onYaz('');
                      },
                      icon: const Icon(Icons.close, size: 20),
                      color: Tema.solgun,
                      tooltip: 'Temizle',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
