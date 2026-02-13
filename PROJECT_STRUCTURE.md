# 📁 Notion Save Pro - Proje Yapısı

## 🗂️ Klasör Organizasyonu

```
notion_save_pro/
│
├── 📄 .env                          # OAuth credentials (GİZLİ - düzenleyin!)
├── 📄 .gitignore                    # Git ignore kuralları
├── 📄 pubspec.yaml                  # Flutter bağımlılıkları
├── 📄 README.md                     # Proje dokümantasyonu
├── 📄 SETUP_GUIDE.md                # Detaylı kurulum rehberi
├── 📄 PROJECT_STRUCTURE.md          # Bu dosya
│
├── 📂 lib/                          # Ana kaynak kodu
│   ├── 📄 main.dart                 # Uygulama giriş noktası
│   │
│   ├── 📂 models/                   # Veri modelleri
│   │   ├── 📄 article.dart          # Makale modeli
│   │   ├── 📄 notion_database.dart  # Database modeli
│   │   └── 📄 notion_template.dart  # Template modeli
│   │
│   ├── 📂 screens/                  # UI ekranları
│   │   ├── 📄 login_screen.dart     # OAuth login ekranı
│   │   ├── 📄 database_selection_screen.dart # Database seçim
│   │   └── 📄 template_selection_screen.dart # Template seçim
│   │
│   ├── 📂 services/                 # Servis katmanı
│   │   ├── 📄 auth_service.dart     # OAuth token yönetimi
│   │   ├── 📄 notion_service.dart   # Notion API iletişimi
│   │   └── 📄 web_scraper_service.dart # Web scraping
│   │
│   └── 📂 utils/                    # Yardımcı sınıflar
│       └── 📄 app_config.dart       # Konfigürasyon yönetimi
│
└── 📂 android/                      # Android platform kodu
    └── 📂 app/
        ├── 📄 build.gradle          # Android build ayarları
        └── 📂 src/main/
            ├── 📄 AndroidManifest.xml # Uygulama izinleri ve deep links
            └── 📂 res/values/
                └── 📄 styles.xml     # Android temaları
```

---

## 📄 Dosya Açıklamaları

### 🔧 Konfigürasyon Dosyaları

#### `.env`
```env
NOTION_CLIENT_ID=...
NOTION_CLIENT_SECRET=secret_...
NOTION_REDIRECT_URI=https://...
```
**Amaç:** OAuth credentials'larını saklar  
**⚠️ ÖNEMLİ:** Bu dosyayı düzenleyip kendi OAuth bilgilerinizi girin!

#### `pubspec.yaml`
**Amaç:** Flutter proje ayarları ve bağımlılıklar
**İçerir:**
- `http` - HTTP istekleri için
- `flutter_secure_storage` - OAuth token'ları güvenli saklamak için
- `url_launcher` - OAuth tarayıcısını açmak için
- `app_links` - Deep link handling için
- `shared_preferences` - Kullanıcı tercihlerini saklamak için
- `receive_sharing_intent` - Paylaşım intent'lerini almak için
- `fluttertoast` - Toast mesajları için
- `html` - HTML parsing için
- `google_fonts` - Estetik fontlar için
- `flutter_dotenv` - .env dosyası desteği için

---

### 💻 Kaynak Kod (lib/)

#### `main.dart`
**Ana uygulama dosyası**

**İçerik:**
- `NotionSaveProApp` - Material app wrapper
- `SplashScreen` - Başlangıç ekranı ve yönlendirme
- `SaveHandler` - Paylaşım yöneticisi
- Routes - /login, /database-selection, /template-selection, /home

**Sorumluluklar:**
- OAuth durumunu kontrol etme
- Login ekranına veya ana ekrana yönlendirme
- Paylaşım intent'lerini dinleme
- URL işleme ve kaydetme

---

#### `screens/login_screen.dart`
**OAuth login ekranı**

**İçerik:**
- OAuth login butonu
- Deep link callback handling
- Token exchange işlemi

**Ana metodlar:**
```dart
_launchOAuth()          // Tarayıcıda OAuth sayfasını açar
_handleOAuthCallback()  // Deep link'i dinler
_processOAuthCallback() // Token exchange yapar
```

---

#### `screens/database_selection_screen.dart`
**Database seçim ekranı**

**İçerik:**
- Kullanıcının database'lerini listeler
- Database seçimi
- Seçimi kaydetme

**Ana metodlar:**
```dart
_loadDatabases()     // Notion'dan database'leri çeker
_selectDatabase()    // Database'i seçer ve kaydeder
```

---

#### `screens/template_selection_screen.dart`
**Template seçim ekranı**

**İçerik:**
- Seçili database'in template'lerini listeler
- Template seçimi
- Seçimi kaydetme

**Ana metodlar:**
```dart
_loadTemplates()     // Database'den template'leri çeker
_selectTemplate()    // Template'i seçer ve kaydeder
```

---

#### `models/notion_database.dart`
**Database veri modeli**

```dart
class NotionDatabase {
  final String id;     // Database ID
  final String title;  // Database adı
  final String? icon;  // Database ikon (emoji)
  
  factory NotionDatabase.fromJson(Map<String, dynamic> json)
}
```

---

#### `models/article.dart`
**Makale veri modeli**

```dart
class Article {
  final String url;           // Makale URL'i
  final String title;         // Başlık
  final String? description;  // Açıklama (opsiyonel)
  final String? imageUrl;     // Kapak görseli (opsiyonel)
  final List<Map<String, dynamic>> blocks; // Notion blokları
}
```

---

#### `models/notion_template.dart`
**Template veri modeli**

```dart
class NotionTemplate {
  final String id;    // Template page ID
  final String name;  // Template adı
  
  factory NotionTemplate.fromJson(Map<String, dynamic> json)
}
```

**Amaç:** Notion'dan gelen template verilerini parse eder

---

#### `services/auth_service.dart`
**OAuth token ve tercih yönetimi servisi**

**Ana metodlar:**

| Metod | Açıklama |
|-------|----------|
| `exchangeCodeForToken(code)` | OAuth code'u token'a çevirir |
| `getAccessToken()` | Kayıtlı access token''ı getirir |
| `isLoggedIn()` | Kullanıcı giriş yapmış mı kontrol |
| `logout()` | Çıkış yap, token'ları temizle |
| `saveSelectedDatabaseId()` | Seçili database ID'sini kaydet |
| `getSelectedDatabaseId()` | Seçili database ID'sini getir |
| `saveSelectedTemplateId()` | Seçili template ID'sini kaydet |
| `getSelectedTemplateId()` | Seçili template ID'sini getir |

**Özellikler:**
- ✅ `flutter_secure_storage` ile güvenli token saklama
- ✅ `shared_preferences` ile kullanıcı tercihleri
- ✅ Otomatik token yönetimi

**Token Exchange Flow:**
```dart
1. OAuth callback code alır
2. Notion'a POST isteği (code + client_id + client_secret)
3. Access token alır
4. Secure storage'a kaydeder
```

---

#### `services/notion_service.dart`
**Notion API servisi**

**Ana metodlar:**

| Metod | Açıklama |
|-------|----------|
| `getTemplates()` | Şablonları listeler |
| `getTemplateBlocks(pageId)` | Şablon içeriğini getirir |
| `savePage(article, templateId)` | Makaleyi Notion'a kaydeder |
| `_cleanBlock(block)` | Blokları temizler |
| `_createPage(article, blocks)` | Sayfa oluşturur |
| `_appendBlocks(pageId, blocks)` | Ek bloklar ekler |

**Özellikler:**
- ✅ Şablon + içerik birleştirme
- ✅ 100+ blok desteği (batch işleme)
- ✅ Rate limiting (3 req/sec)
- ✅ Hata yönetimi
- ✅ Blok temizleme (ID'leri sil)

**API Endpoint'leri:**
```
POST /v1/databases/{id}/query      → Şablonları listele
GET  /v1/blocks/{id}/children      → Blokları getir
POST /v1/pages                     → Sayfa oluştur
PATCH /v1/blocks/{id}/children     → Blok ekle
```

---

#### `services/web_scraper_service.dart`
**Web scraping servisi**

**Ana metodlar:**

| Metod | Açıklama |
|-------|----------|
| `scrapeArticle(url)` | URL'den makale çıkarır |
| `_extractTitle()` | Başlık bulur (OG tags, title, h1) |
| `_extractDescription()` | Açıklama bulur |
| `_extractImage()` | Kapak görseli bulur |
| `_parseContent()` | İçeriği Notion bloklarına çevirir |
| `_elementToNotionBlock()` | HTML → Notion blok |

**Parse edilen elementler:**
- `<p>` → paragraph
- `<h1>, <h2>` → heading_2
- `<h3>, <h4>` → heading_3
- `<blockquote>` → quote
- `<ul>, <ol>` → list items
- `<img>` → image block
- `<pre>, <code>` → code block

**Özellikler:**
- ✅ Akıllı içerik bulma (article, main tags)
- ✅ İstenmeyen içerik filtreleme (nav, ads)
- ✅ Göreceli URL çözme
- ✅ 2000+ karakter metinleri bölme
- ✅ Meta tag desteği (Open Graph, Twitter)

**Limitler:**
```dart
maxBlocks = 80        // Şablon için yer bırakır
maxTextLength = 1900  // Notion limit: 2000
```

---

#### `utils/app_config.dart`
**OAuth konfigürasyon yöneticisi**

**Metodlar:**
```dart
static String get notionClientId        // OAuth Client ID
static String get notionClientSecret    // OAuth Client Secret
static String get notionRedirectUri     // OAuth Redirect URI
static bool get isValid                 // Validasyon
static String get configErrorMessage    // Hata mesajı
```

**Amaç:** .env dosyasından OAuth konfigürasyonunu yönetir

---

### 📱 Android Dosyaları

#### `android/app/build.gradle` (60 satır)
**Android build ayarları**

```gradle
minSdkVersion 21      // Android 5.0+
targetSdk 34          // Android 14
applicationId "com.notionsavepro.app"
```

---

#### `android/app/src/main/AndroidManifest.xml`
**Uygulama izinleri ve intent filter'ları + deep links**

**İzinler:**
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

**Intent Filters:**
```xml
<!-- Metin paylaşımı -->
<intent-filter>
    <action android:name="android.intent.action.SEND"/>
    <data android:mimeType="text/plain"/>
</intent-filter>

<!-- OAuth deep link -->
<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <data android:scheme="notionsavepro" android:host="oauth"/>
</intent-filter>
```

**Launch mode:**
```xml
android:launchMode="singleTask"  // Her paylaşımda yeni instance oluşmasın
```

---

#### `android/app/src/main/res/values/styles.xml` (21 satır)
**Android temaları**

```xml
<style name="LaunchTheme">
    <!-- Transparan arka plan -->
    <item name="android:windowIsTranslucent">true</item>
    <item name="android:windowBackground">@android:color/transparent</item>
</style>
```

**Amaç:** Uygulama açılırken transparan dialog gibi görünür

---

## 🔄 Veri Akışı

### İlk Kurulum Akışı:

```
1. [Uygulama Açılır] → SplashScreen
   ↓
2. [Token Kontrol] → AuthService.isLoggedIn()
   ↓
3a. Token YOK → LoginScreen
   ↓
4. [Login Butonu] → OAuth URL oluştur
   ↓
5. [Tarayıcı] → Notion OAuth sayfası
   ↓
6. [Kullanıcı] → Workspace seç, database'lere erişim ver
   ↓
7. [Notion] → Vercel callback: ?code=XXX
   ↓
8. [Vercel] → notionsavepro://oauth?code=XXX
   ↓
9. [Deep Link] → Uygulama açılır
   ↓
10. [LoginScreen] → AuthService.exchangeCodeForToken()
   ↓
11. [Token Kaydedildi] → DatabaseSelectionScreen
   ↓
12. [NotionService] → searchDatabases()
   ↓
13. [Kullanıcı] → Database seçer
   ↓
14. [AuthService] → Database ID kaydedilir
   ↓
15. [TemplateSelectionScreen] → getDatabaseTemplates()
   ↓
16. [Kullanıcı] → Template seçer (opsiyonel)
   ↓
17. [AuthService] → Template ID kaydedilir
   ↓
18. ✅ Kurulum tamamlandı → SaveHandler (home)
```

### Sonraki Açılışlar:

```
1. [Uygulama Açılır] → SplashScreen
   ↓
2. [Token Kontrol] → Token VAR
   ↓
3. ✅ Direk SaveHandler'a yönlendir
```

### Makale Kaydetme İşlemi Akışı:

```
1. [Tarayıcı] → Paylaş butonu
   ↓
2. [Android] → Intent filter yakalar
   ↓
3. [SaveHandler] → ReceiveSharingIntent.getTextStream()
   ↓
4. [SaveHandler] → _handleSharedUrl(url)
   ↓
5. [WebScraperService] → scrapeArticle(url)
   ├── HTML fetch
   ├── Title extraction
   ├── Content parsing
   └── Notion blokları oluştur
   ↓
6. [Dialog] → Başlık düzenleme, Kaydet butonu
   ↓
7. [NotionService] → savePage(article)
   ├── AuthService'den database ID al
   ├── AuthService'den template ID al
   ├── getTemplateBlocks(templateId) (varsa)
   ├── Blokları birleştir
   ├── _createPage() → İlk 100 blok
   └── _appendBlocks() → Kalan bloklar
   ↓
8. [Notion API] → Sayfa oluşturuldu ✅
   ↓
9. [UI] → Toast: "Başarıyla kaydedildi!"
   ↓
10. [App] → SystemNavigator.pop() → Kapat
```

---

## 🎯 Özelleştirme Rehberi

### 1. Yeni Notion Property Eklemek

`lib/services/notion_service.dart` → `_createPage()`:

```dart
"properties": {
  "Name": {...},
  "URL": {...},
  
  // YENİ PROPERTY:
  "Tags": {
    "multi_select": [
      {"name": "Web"},
      {"name": "Makale"}
    ]
  }
}
```

### 2. Scraping Kurallarını Değiştirmek

`lib/services/web_scraper_service.dart` → `_parseContent()`:

```dart
// Özel CSS selector kullan:
Element? mainContent = document.querySelector('.custom-article-class');

// Yeni element tipi ekle:
case 'table':
  return _createTableBlock(element);
```

### 3. UI Değiştirmek

`lib/main.dart` → `_showSaveDialog()`:

```dart
// Dialog stilini değiştir:
shape: RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(20),  // 16 → 20
),
```

### 4. Scraping Limitlerini Artırmak

`lib/services/web_scraper_service.dart`:

```dart
static const int maxBlocks = 80;      // → 100 yapabilirsin
static const int maxTextLength = 1900; // → 2000 maksimum
```

---

## 🐛 Debug İpuçları

### Logları Görmek

```bash
# Uygulamayı debug mode'da çalıştır:
flutter run

# Logları izle:
flutter logs

# Sadece hataları filtrele:
flutter logs | grep "Error"
```

### API İsteklerini İzlemek

`lib/services/notion_service.dart` içinde print ekle:

```dart
print('📤 Request: $url');
print('📄 Body: $body');
print('📥 Response: ${response.statusCode}');
print('📄 Data: ${response.body}');
```

---

## 📊 Kod İstatistikleri

| Kategori | Dosya Sayısı | Toplam Satır |
|----------|--------------|--------------|
| Dart - Models | 3 | ~100 |
| Dart - Screens | 3 | ~400 |
| Dart - Services | 3 | ~700 |
| Dart - Utils | 1 | ~50 |
| Dart - Main | 1 | ~250 |
| Android | 3 | ~150 |
| Konfigürasyon | 4 | ~100 |
| Dokümantasyon | 3 | ~600 |
| **TOPLAM** | **21** | **~2350** |

---

## 🎓 Öğrenme Kaynakları

### Flutter:
- [Flutter Docs](https://docs.flutter.dev/)
- [Dart Docs](https://dart.dev/guides)

### Notion API:
- [Notion API Docs](https://developers.notion.com/)
- [API Reference](https://developers.notion.com/reference/intro)

### HTML Parsing:
- [html package](https://pub.dev/packages/html)
- [CSS Selectors](https://www.w3schools.com/cssref/css_selectors.php)

---

**🎉 Proje yapısını anladınız! Artık özelleştirebilirsiniz.**
