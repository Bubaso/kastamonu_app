import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'cekirdek/supabase.dart';
import 'cekirdek/tema.dart';
import 'cekirdek/yonlendirme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Adres çubuğunda # olmasın: /haber/slug gerçek bir yol olmalı.
  // Haber portalında paylaşılan bağlantı ve arama motoru indekslemesi
  // buna bağlı — Flutter'ın varsayılan hash yönlendirmesiyle her adres
  // ana sayfaya düşüyordu.
  usePathUrlStrategy();
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
    if (!SupabaseAyar.yapilandirildi) return const _AyarUyarisi();
    return MaterialApp.router(
      title: 'Kastamonu Haber',
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: Tema.olustur(),
      routerConfig: yonlendirici,
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
              'Çalıştırma: ./calistir.sh',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
