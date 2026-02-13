# 📁 Notion Save Pro - Proje Yapısı

## 🗂️ Klasör Organizasyonu

```
notion_save_pro/
│
├── 📄 .env                          # API anahtarları (GİZLİ - düzenleyin!)
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
│   │   └── 📄 notion_template.dart  # Şablon modeli
│   │
│   ├── 📂 services/                 # Servis katmanı
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
            ├── 📄 AndroidManifest.xml # Uygulama izinleri ve intent'ler
            └── 📂 res/values/
                └── 📄 styles.xml     # Android temaları
```

---

## 📄 Dosya Açıklamaları

### 🔧 Konfigürasyon Dosyaları

#### `.env`
```env
NOTION_API_KEY=secret_...
TARGET_DATABASE_ID=...
TEMPLATES_DATABASE_ID=...
```
**Amaç:** API anahtarlarını ve database ID'lerini saklar  
**⚠️ ÖNEMLİ:** Bu dosyayı düzenleyip kendi bilgilerinizi girin!

#### `pubspec.yaml`
**Amaç:** Flutter proje ayarları ve bağımlılıklar
**İçerir:**
- `http` - HTTP istekleri için
- `receive_sharing_intent` - Paylaşım intent'lerini almak için
- `fluttertoast` - Toast mesajları için
- `html` - HTML parsing için
- `google_fonts` - Estetik fontlar için
- `flutter_dotenv` - .env dosyası desteği için

---

### 💻 Kaynak Kod (lib/)

#### `main.dart` (398 satır)
**Ana uygulama dosyası**

**İçerik:**
- `NotionSaveProApp` - Material app wrapper
- `SaveHandler` - Paylaşım yöneticisi
- `_SaveHandlerState` - State management

**Sorumluluklar:**
- Paylaşım intent'lerini dinleme
- Save dialog'u gösterme
- Şablonları listeleme
- Kaydetme işlemini koordine etme
- Hata yönetimi

**Ana metodlar:**
```dart
_initializeApp()        // Başlatma
_setupSharingIntent()   // Intent dinleyici
_handleSharedUrl()      // URL işleme
_saveToNotion()         // Kaydetme
_showSaveDialog()       // UI dialog
```

---

#### `models/article.dart` (17 satır)
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

#### `models/notion_template.dart` (33 satır)
**Şablon veri modeli**

```dart
class NotionTemplate {
  final String id;    // Notion page ID
  final String name;  // Şablon adı
  
  factory NotionTemplate.fromJson(Map<String, dynamic> json)
}
```

**Amaç:** Notion'dan gelen şablon verilerini parse eder

---

#### `services/notion_service.dart` (235 satır)
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

#### `services/web_scraper_service.dart` (387 satır)
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

#### `utils/app_config.dart` (30 satır)
**Konfigürasyon yöneticisi**

**Metodlar:**
```dart
static String get notionApiKey           // API key
static String get targetDatabaseId       // Ana DB ID
static String get templatesDatabaseId    // Şablon DB ID
static bool get isValid                  // Validasyon
static Map<String, String> get headers   // HTTP headers
static String get configErrorMessage     // Hata mesajı
```

**Amaç:** .env dosyasından konfigürasyonu yönetir

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

#### `android/app/src/main/AndroidManifest.xml` (54 satır)
**Uygulama izinleri ve intent filter'ları**

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

### Kaydetme İşlemi Akışı:

```
1. [Tarayıcı] → Paylaş butonu
   ↓
2. [Android] → Intent filter yakalar
   ↓
3. [main.dart] → ReceiveSharingIntent.getTextStream()
   ↓
4. [SaveHandler] → _handleSharedUrl(url)
   ↓
5. [WebScraperService] → scrapeArticle(url)
   ├── HTML fetch
   ├── Title extraction
   ├── Content parsing
   └── Notion blokları oluştur
   ↓
6. [NotionService] → savePage(article, template)
   ├── getTemplateBlocks(templateId)
   ├── Blokları birleştir
   ├── _createPage() → İlk 100 blok
   └── _appendBlocks() → Kalan bloklar
   ↓
7. [Notion API] → Sayfa oluşturuldu ✅
   ↓
8. [UI] → Toast: "Başarıyla kaydedildi!"
   ↓
9. [App] → SystemNavigator.pop() → Kapat
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
| Dart (lib/) | 6 | ~1200 |
| Android | 3 | ~135 |
| Konfigürasyon | 4 | ~100 |
| Dokümantasyon | 3 | ~500 |
| **TOPLAM** | **16** | **~1935** |

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
