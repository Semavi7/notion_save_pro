# 📱 Notion Save Pro

**Chrome eklentisi "Save to Notion"un mobil versiyonu!**

Android'de web sayfalarını Notion'a şablonlarınızla birlikte kaydetmenizi sağlayan Flutter uygulaması.

## ✨ Özellikler

- 🔗 **Herhangi bir uygulamadan paylaş** - Chrome, Firefox, Twitter, Reddit vb.
- 📄 **Şablon desteği** - Önceden hazırladığınız Notion şablonlarını kullanın
- 🎯 **Akıllı parsing** - Makale içeriğini otomatik olarak çıkarır
- 🖼️ **Görsel desteği** - Görselleri de birlikte kaydeder
- ⚡ **Hızlı ve kolay** - Tek tıkla kaydet
- 🎨 **Modern UI** - Şık ve kullanıcı dostu arayüz

## 📋 Gereksinimler

- Flutter SDK (3.0.0 veya üzeri)
- Android Studio veya VS Code
- Notion hesabı
- Notion API Key

## 🚀 Kurulum

### 1. Notion API Ayarları

1. [Notion Integrations](https://www.notion.so/my-integrations) sayfasına gidin
2. "New integration" butonuna tıklayın
3. İsim verin ve "Submit" edin
4. **Internal Integration Token**'ı kopyalayın (secret_... ile başlar)

### 2. Notion Veritabanları

İki veritabanına ihtiyacınız var:

#### A) Ana Veritabanı (Yazıları kaydedeceğiniz yer)
1. Notion'da yeni bir sayfa oluşturun
2. "/database" yazıp "Table" seçin
3. Şu property'leri ekleyin:
   - **Name** (Title) - Makale başlığı
   - **URL** (URL) - Makale linki
   - **Status** (Select) - Opsiyonel, durumu takip için

4. Veritabanı ID'sini alın:
   - Veritabanı sayfasını tarayıcıda açın
   - URL'ye bakın: `notion.so/workspace/DATABASE_ID?v=...`
   - `DATABASE_ID` kısmını kopyalayın

#### B) Şablonlar Veritabanı
1. Yeni bir database daha oluşturun
2. **Name** (Title) property'si ekleyin
3. Her şablon için bir satır ekleyin ve adlandırın
4. Şablon sayfalarını açıp içlerini düzenleyin (başlıklar, emoji, bölümler vs.)
5. Veritabanı ID'sini alın (yukarıdaki gibi)

#### C) Integration'ı Bağlayın
1. Her iki veritabanı sayfasını açın
2. Sağ üstteki "..." menüsüne tıklayın
3. "Connect to" → Oluşturduğunuz integration'ı seçin

### 3. Proje Kurulumu

```bash
# Depoyu klonlayın veya dosyaları indirin
cd notion_save_pro

# Bağımlılıkları yükleyin
flutter pub get

# .env dosyasını düzenleyin
nano .env
```

**.env dosyası:**
```env
NOTION_API_KEY=secret_XXXXXXXXXXXXXXXXXXXXXXXXX
TARGET_DATABASE_ID=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
TEMPLATES_DATABASE_ID=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### 4. APK Oluşturma

```bash
# Release APK oluştur
flutter build apk --release

# APK konumu:
# build/app/outputs/flutter-apk/app-release.apk
```

### 5. Uygulamayı Yükleme

APK dosyasını telefonunuza atıp yükleyin:

```bash
# USB ile bağlıysa direkt yükle
flutter install

# veya
adb install build/app/outputs/flutter-apk/app-release.apk
```

## 📖 Kullanım

1. **Tarayıcıda bir makale açın** (Chrome, Firefox, vb.)
2. **Paylaş butonuna** tıklayın
3. **Notion Save Pro**'yu seçin
4. Başlığı düzenleyin (otomatik gelir)
5. Şablon seçin
6. **Kaydet**'e tıklayın
7. ✅ Notion'da görünür!

## 🎯 Nasıl Çalışır?

```
[Tarayıcı] → Paylaş
    ↓
[Notion Save Pro]
    ↓
Web Scraper → Makaleyi parse et
    ↓
Notion API → Şablon + İçerik → Kaydet
    ↓
✅ Başarılı!
```

### Parse Edilen İçerikler

- ✅ Başlıklar (H1, H2, H3)
- ✅ Paragraflar
- ✅ Görseller
- ✅ Alıntılar (blockquote)
- ✅ Listeler (ul, ol)
- ✅ Kod blokları

## 🛠️ Geliştirme

### Proje Yapısı

```
lib/
├── models/
│   ├── article.dart           # Makale modeli
│   └── notion_template.dart   # Şablon modeli
├── services/
│   ├── notion_service.dart    # Notion API
│   └── web_scraper_service.dart # Web scraping
├── utils/
│   └── app_config.dart        # Konfigürasyon
└── main.dart                  # Ana uygulama
```

### Özelleştirme

#### Scraping Kuralları
`lib/services/web_scraper_service.dart` dosyasında `_parseContent` metodunu düzenleyin.

#### Notion Property'leri
`lib/services/notion_service.dart` dosyasında `_createPage` metodunu düzenleyin:

```dart
"properties": {
  "Name": {"title": [...]},
  "URL": {"url": article.url},
  "Status": {"select": {"name": "Okunacak"}},  // Ekstra property
  "Tags": {"multi_select": [...]},              // Ekstra property
}
```

## 🐛 Sorun Giderme

### "Konfigürasyon Hatası"
- `.env` dosyasını kontrol edin
- API key'in `secret_` ile başladığından emin olun
- Database ID'lerin 32 karakter olduğunu kontrol edin

### "Notion'a bağlanılamadı"
- Integration'ın veritabanlarına bağlı olduğunu kontrol edin
- API key'in geçerli olduğunu test edin
- İnternet bağlantınızı kontrol edin

### "Şablon bulunamadı"
- Şablon veritabanında en az bir satır olmalı
- Integration bağlantısını kontrol edin
- Veritabanı ID'sinin doğru olduğunu kontrol edin

### "Makale içeriği alınamadı"
- Bazı siteler scraping'i engelleyebilir
- CORS hatası olabilir
- Site robot.txt ile engelliyor olabilir

## 📝 Limitler

- Notion API: Saatte **3 request/saniye**
- Tek request'te **100 blok** (şablon + içerik)
- Her blok **2000 karakter** (otomatik bölünür)
- Maksimum **80 içerik bloğu** (şablon için yer bırakılır)

## 🔐 Güvenlik

- ⚠️ `.env` dosyasını **asla** git'e eklemeyin
- API anahtarlarını kimseyle paylaşmayın
- Production'da environment variables kullanın

## 📄 Lisans

MIT License - Özgürce kullanabilirsiniz!

## 🙏 Teşekkürler

- [Save to Notion](https://www.notion.so/integrations/save-to-notion) Chrome eklentisinden ilham alınmıştır
- Flutter ve Notion API topluluğuna teşekkürler

## 📧 İletişim

Sorularınız için issue açabilirsiniz.

---

**⭐ Beğendiyseniz yıldız vermeyi unutmayın!**
