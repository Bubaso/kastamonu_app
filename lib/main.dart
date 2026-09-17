import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cekirdek/supabase.dart';
import 'ozellikler/inceleme/ekran/giris_ekrani.dart';
import 'ozellikler/inceleme/ekran/inceleme_ekrani.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr');
  if (SupabaseAyar.yapilandirildi) {
    await supabaseBaslat();
  }
  runApp(const ProviderScope(child: KastamonuApp()));
}

class KastamonuApp extends StatelessWidget {
  const KastamonuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kastamonu Haber',
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D6B5A),
          surface: const Color(0xFFF7F8F6),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFD6DDD8)),
          ),
        ),
      ),
      home: const _Kapi(),
    );
  }
}

/// Oturum kapısı. Anahtar yoksa yapılandırma uyarısı, oturum yoksa giriş.
class _Kapi extends StatelessWidget {
  const _Kapi();

  @override
  Widget build(BuildContext context) {
    if (!SupabaseAyar.yapilandirildi) return const _AyarUyarisi();
    return StreamBuilder<AuthState>(
      stream: sb.auth.onAuthStateChange,
      builder: (context, anlik) {
        final oturum = sb.auth.currentSession;
        if (oturum == null) return const GirisEkrani();
        return const IncelemeEkrani();
      },
    );
  }
}

class _AyarUyarisi extends StatelessWidget {
  const _AyarUyarisi();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'SUPABASE_ANON_KEY verilmedi.\n\n'
              'Çalıştırma:\n'
              'flutter run -d chrome --dart-define=SUPABASE_ANON_KEY=...',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
