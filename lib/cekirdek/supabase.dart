import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase bağlantı ayarları.
///
/// Buradaki anahtar **anon** anahtarıdır, service_role DEĞİL. Flutter Web'de
/// paket tarayıcıya iniyor; service_role anahtarı RLS'i tümden atladığı için
/// oraya konulamaz — herkese açık olurdu. Panelin yetkisi anahtardan değil,
/// açtığı oturumdan geliyor (bkz. migration 0002).
class SupabaseAyar {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vcwgcvzqdnjyoitdfhma.supabase.co',
  );

  /// `--dart-define=SUPABASE_ANON_KEY=...` ile veriliyor.
  ///
  /// Supabase bu anahtarı artık "publishable key" diye adlandırıyor; eski
  /// anon anahtarı da aynı alanda geçerli. Adı ne olursa olsun bu anahtar
  /// **yayımlanmak üzere** tasarlandı — tarayıcıda görünmesi sorun değil,
  /// çünkü tek başına RLS'i aşamıyor.
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get yapilandirildi => anonKey.isNotEmpty;
}

SupabaseClient get sb => Supabase.instance.client;

Future<void> supabaseBaslat() async {
  await Supabase.initialize(
    url: SupabaseAyar.url,
    publishableKey: SupabaseAyar.anonKey,
  );
}
