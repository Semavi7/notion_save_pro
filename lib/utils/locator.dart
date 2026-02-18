import 'package:get_it/get_it.dart';
import '../services/auth_service.dart';
import '../services/notion_service.dart';
import '../services/web_scraper_service.dart';

/// Global service locator nesnesi
final locator = GetIt.instance;

/// Uygulamanın başında bir kez çağrılır.
/// Tüm servisler Singleton olarak kaydedilir:
/// İlk kullanımda oluşturulur, sonraki çağrılarda aynı nesne döner.
void setupLocator() {
  // AuthService — tüm uygulama boyunca tek bir instance
  locator.registerLazySingleton<AuthService>(() => AuthService());

  // WebScraperService — bağımsız, AuthService gerektirmiyor
  locator.registerLazySingleton<WebScraperService>(() => WebScraperService());

  // NotionService — AuthService'e bağımlı, locator üzerinden alır
  locator.registerLazySingleton<NotionService>(() => NotionService());
}
