import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model/haber.dart';

/// İnceleme masasındaki tek haber kartı.
///
/// Tasarım kararı: ilçe bağının **kaynağı** kartın en görünür ögelerinden
/// biri. Editörün ilk sorusu "bu ilçe doğru mu" ve cevabı belirleyen şey
/// bağın model+sözlük mutabakatından mı yoksa yalnız modelden mi geldiği.
/// Mutabakat yeşil ve onaylı gelir; yalnız model amber ve onay bekler.
class HaberKarti extends StatefulWidget {
  const HaberKarti({
    super.key,
    required this.haber,
    required this.onKaydet,
    required this.onYayinla,
    required this.onReddet,
    required this.onIncelemeyeAl,
    required this.onBagOnayla,
    required this.onBagSil,
  });

  final Haber haber;
  final Future<void> Function(String baslik, String spot, String govde)
  onKaydet;
  final Future<void> Function() onYayinla;
  final Future<void> Function(String? gerekce) onReddet;
  final Future<void> Function() onIncelemeyeAl;
  final Future<void> Function(String ilceId, bool onay) onBagOnayla;
  final Future<void> Function(String ilceId) onBagSil;

  @override
  State<HaberKarti> createState() => _HaberKartiState();
}

class _HaberKartiState extends State<HaberKarti> {
  late TextEditingController _baslik;
  late TextEditingController _spot;
  late TextEditingController _govde;
  bool _acik = false;
  bool _mesgul = false;
  bool _degisti = false;

  @override
  void initState() {
    super.initState();
    _kur();
  }

  void _kur() {
    _baslik = TextEditingController(text: widget.haber.baslik)
      ..addListener(_isaretle);
    _spot = TextEditingController(text: widget.haber.spot ?? '')
      ..addListener(_isaretle);
    _govde = TextEditingController(text: widget.haber.govde ?? '')
      ..addListener(_isaretle);
  }

  void _isaretle() {
    if (!_degisti) setState(() => _degisti = true);
  }

  @override
  void didUpdateWidget(HaberKarti eski) {
    super.didUpdateWidget(eski);
    if (eski.haber.id != widget.haber.id) {
      _baslik.dispose();
      _spot.dispose();
      _govde.dispose();
      _kur();
      _degisti = false;
    }
  }

  @override
  void dispose() {
    _baslik.dispose();
    _spot.dispose();
    _govde.dispose();
    super.dispose();
  }

  Future<void> _sar(Future<void> Function() is_) async {
    setState(() => _mesgul = true);
    try {
      await is_();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _redDialogu() async {
    final denetleyici = TextEditingController();
    final gerekce = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Haberi reddet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gerekçe isteğe bağlı ama sonradan işe yarıyor: '
              'hangi tür haberlerin elendiğini görmek hattı düzeltmeyi '
              'kolaylaştırıyor.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: denetleyici,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Gerekçe',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, denetleyici.text.trim()),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );
    if (gerekce != null) {
      await _sar(() => widget.onReddet(gerekce.isEmpty ? null : gerekce));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final h = widget.haber;
    final inceleme = h.durum == 'inceleme';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (h.bagOnayiBekliyor)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF4E0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              child: Row(
                children: [
                  const Icon(
                    Icons.help_outline,
                    size: 15,
                    color: Color(0xFF8A5A00),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'İlçe bağı doğrulanmadı — sözlük teyit etmedi',
                    style: t.textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF8A5A00),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ustSerit(t, h),
                const SizedBox(height: 10),
                if (_acik)
                  TextField(
                    controller: _baslik,
                    maxLines: null,
                    style: t.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Başlık',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  )
                else
                  Text(
                    h.baslik,
                    style: t.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                const SizedBox(height: 8),
                if (_acik) ...[
                  TextField(
                    controller: _spot,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Spot',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _govde,
                    maxLines: 12,
                    minLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Gövde',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ] else if ((h.spot ?? '').isNotEmpty)
                  Text(
                    h.spot!,
                    style: t.textTheme.bodyMedium?.copyWith(
                      color: t.hintColor,
                      height: 1.45,
                    ),
                  ),
                const SizedBox(height: 12),
                _ilceSeridi(t, h),
                const SizedBox(height: 10),
                _kaynakSatiri(t, h),
              ],
            ),
          ),
          const Divider(height: 1),
          _eylemler(t, inceleme),
        ],
      ),
    );
  }

  Widget _ustSerit(ThemeData t, Haber h) {
    return Wrap(
      spacing: 7,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (h.kategoriAd != null)
          _rozet(h.kategoriAd!, const Color(0xFF0D6B5A), dolgulu: true),
        _rozet(
          'önem ${h.onem}',
          h.onem >= 7 ? const Color(0xFFA84A18) : t.hintColor,
        ),
        if (h.diaspora) _rozet('diaspora', const Color(0xFF4A5CB8)),
        _rozet('katman ${h.katman}', t.hintColor),
        Text(
          DateFormat('d MMM HH:mm', 'tr').format(h.olusturuldu),
          style: t.textTheme.labelSmall?.copyWith(color: t.hintColor),
        ),
      ],
    );
  }

  Widget _rozet(String metin, Color renk, {bool dolgulu = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: dolgulu ? renk.withValues(alpha: 0.11) : null,
      border: Border.all(color: renk.withValues(alpha: 0.45)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      metin,
      style: TextStyle(fontSize: 11, color: renk, fontWeight: FontWeight.w600),
    ),
  );

  Widget _ilceSeridi(ThemeData t, Haber h) {
    if (h.ilceler.isEmpty) {
      return Row(
        children: [
          Icon(Icons.public, size: 14, color: t.hintColor),
          const SizedBox(width: 6),
          Text(
            'il düzeyi — ilçe bağı yok',
            style: t.textTheme.labelMedium?.copyWith(color: t.hintColor),
          ),
        ],
      );
    }
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: h.ilceler.map((b) {
        final iyi = b.onaylandi;
        final renk = iyi ? const Color(0xFF0D6B5A) : const Color(0xFFA06000);
        return InputChip(
          avatar: Icon(
            iyi ? Icons.check_circle : Icons.help_outline,
            size: 16,
            color: renk,
          ),
          label: Text(
            '${b.ad}  ·  ${b.kaynakEtiketi}  ${b.guven.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 11.5, color: renk),
          ),
          backgroundColor: renk.withValues(alpha: 0.07),
          side: BorderSide(color: renk.withValues(alpha: 0.4)),
          onPressed: _mesgul
              ? null
              : () => _sar(() => widget.onBagOnayla(b.ilceId, !b.onaylandi)),
          onDeleted: _mesgul
              ? null
              : () => _sar(() => widget.onBagSil(b.ilceId)),
          deleteIcon: const Icon(Icons.close, size: 15),
          tooltip: iyi
              ? 'Onayı kaldırmak için tıkla · çarpı ile bağı sil'
              : 'Onaylamak için tıkla · çarpı ile bağı sil',
        );
      }).toList(),
    );
  }

  Widget _kaynakSatiri(ThemeData t, Haber h) {
    return InkWell(
      onTap: () => launchUrl(
        Uri.parse(h.kaynakUrl),
        mode: LaunchMode.externalApplication,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(Icons.link, size: 14, color: t.hintColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${h.kaynakAdi}${h.yayinci?.isNotEmpty == true ? " · ${h.yayinci}" : ""}',
                style: t.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF0D6B5A),
                  decoration: TextDecoration.underline,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eylemler(ThemeData t, bool inceleme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _mesgul ? null : () => setState(() => _acik = !_acik),
            icon: Icon(
              _acik ? Icons.unfold_less : Icons.edit_outlined,
              size: 17,
            ),
            label: Text(_acik ? 'Kapat' : 'Düzenle'),
          ),
          if (_acik && _degisti)
            TextButton.icon(
              onPressed: _mesgul
                  ? null
                  : () => _sar(() async {
                      await widget.onKaydet(
                        _baslik.text.trim(),
                        _spot.text.trim(),
                        _govde.text.trim(),
                      );
                      if (mounted) setState(() => _degisti = false);
                    }),
              icon: const Icon(Icons.save_outlined, size: 17),
              label: const Text('Kaydet'),
            ),
          const Spacer(),
          if (_mesgul)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (inceleme) ...[
            TextButton(
              onPressed: _redDialogu,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFA84A18),
              ),
              child: const Text('Reddet'),
            ),
            const SizedBox(width: 6),
            FilledButton.icon(
              onPressed: () => _sar(widget.onYayinla),
              icon: const Icon(Icons.publish, size: 17),
              label: const Text('Yayınla'),
            ),
          ] else
            TextButton.icon(
              onPressed: () => _sar(widget.onIncelemeyeAl),
              icon: const Icon(Icons.undo, size: 17),
              label: const Text('İncelemeye al'),
            ),
        ],
      ),
    );
  }
}
