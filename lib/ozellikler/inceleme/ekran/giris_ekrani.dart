import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../cekirdek/supabase.dart';

/// Panel girişi.
///
/// Panelin yetkisi anahtardan değil oturumdan geliyor: uygulama **anon**
/// anahtarıyla açılıyor ve o anahtarla yalnızca yayındaki haber görülüyor.
/// İnceleme masasını görebilmek için `authenticated` rolüne geçmek gerek.
class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  final _eposta = TextEditingController();
  final _parola = TextEditingController();
  bool _mesgul = false;
  String? _hata;

  @override
  void dispose() {
    _eposta.dispose();
    _parola.dispose();
    super.dispose();
  }

  Future<void> _girisYap() async {
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      await sb.auth.signInWithPassword(
        email: _eposta.text.trim(),
        password: _parola.text,
      );
    } on AuthException catch (e) {
      setState(() => _hata = e.message);
    } catch (e) {
      setState(() => _hata = '$e');
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Kastamonu Haber',
                  style: t.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Editör paneli',
                  style: t.textTheme.bodyMedium?.copyWith(color: t.hintColor),
                ),
                const SizedBox(height: 26),
                TextField(
                  controller: _eposta,
                  autofillHints: const [AutofillHints.email],
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-posta',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _parola,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _girisYap(),
                  decoration: const InputDecoration(
                    labelText: 'Parola',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_hata != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _hata!,
                    style: TextStyle(color: t.colorScheme.error, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _mesgul ? null : _girisYap,
                    child: _mesgul
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Giriş'),
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
