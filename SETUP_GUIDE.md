# 🚀 Notion Save Pro - Detaylı Kurulum Rehberi

## 📋 İçindekiler

1. [Notion API Kurulumu](#1-notion-api-kurulumu)
2. [Veritabanı Oluşturma](#2-veritabanı-oluşturma)
3. [Uygulama Kurulumu](#3-uygulama-kurulumu)
4. [Test ve Kullanım](#4-test-ve-kullanım)

---

## 1. Notion API Kurulumu

### Adım 1.1: Integration Oluştur

1. Tarayıcınızda şu linki açın: https://www.notion.so/my-integrations
2. **"+ New integration"** butonuna tıklayın
3. Formu doldurun:
   - **Name:** "Notion Save Pro" (veya istediğiniz isim)
   - **Associated workspace:** Workspace'inizi seçin
   - **Type:** Internal
4. **"Submit"** butonuna tıklayın

### Adım 1.2: API Key'i Kopyala

1. Yeni oluşturulan integration sayfasında **"Internal Integration Token"** bölümüne gidin
2. **"Show"** butonuna tıklayın
3. Token'ı kopyalayın (şuna benzer: `secret_AbCdEf123456...`)
4. ⚠️ **GÜVENLİ BİR YERDE SAKLAYIN!**

---

## 2. Veritabanı Oluşturma

### Adım 2.1: Ana Veritabanı (Kayıt Yeri)

Bu veritabanına makaleler kaydedilecek.

#### Oluşturma:

1. Notion'da yeni bir sayfa oluşturun
2. Sayfaya isim verin: **"Kaydedilen Makaleler"**
3. `/database` yazıp **"Table - Inline"** seçin

#### Property'ler:

Şu sütunları ekleyin:

| Property Adı | Tip    | Açıklama                |
|--------------|--------|-------------------------|
| Name         | Title  | Makale başlığı (otomatik var) |
| URL          | URL    | Makale linki            |
| Status       | Select | Opsiyonel - Okundu/Okunmadı |

**Status için seçenekler ekleyin:**
- 📖 Okunacak
- ✅ Okundu
- ⭐ Favoriler

#### Veritabanı ID'sini Al:

1. Veritabanı sayfasını tarayıcıda açın
2. URL'ye bakın:
```
https://www.notion.so/workspace/abc123def456?v=...
                              ^^^^^^^^^^^^^
                              Bu kısım Database ID
```
3. `abc123def456` kısmını kopyalayın
4. Not defterine yapıştırın: `TARGET_DATABASE_ID=abc123def456`

#### Integration'ı Bağla:

1. Veritabanı sayfasının sağ üstündeki **"..."** menüsüne tıklayın
2. **"Add connections"** → **"Notion Save Pro"** seçin
3. **"Confirm"** edin

---

### Adım 2.2: Şablonlar Veritabanı

Bu veritabanında şablonlarınızı saklayacaksınız.

#### Oluşturma:

1. Yeni bir sayfa oluşturun: **"Makale Şablonları"**
2. `/database` yazıp **"Table - Inline"** seçin

#### Property:

Sadece **Name** (Title) property'si yeterli.

#### Şablon Sayfaları Oluştur:

Database'de her satır bir şablondur:

| Name                  |
|-----------------------|
| 📚 Genel Makale      |
| 💻 Teknik Yazı       |
| 📰 Haber             |

#### Şablonları Düzenle:

Her satırı açıp içeriği düzenleyin:

**Örnek: "Genel Makale" şablonu:**

```
📚 Genel Makale

## 📝 Özet
[Buraya özet gelecek]

## 🎯 Ana Noktalar
- 

## 💭 Düşüncelerim
[Notlarım]

---
[Makale içeriği buradan başlayacak]
```

#### Veritabanı ID'sini Al:

1. Şablonlar veritabanı sayfasını açın
2. URL'den ID'yi kopyalayın (yukarıdaki gibi)
3. Not edin: `TEMPLATES_DATABASE_ID=xyz789...`

#### Integration'ı Bağla:

Yukarıdaki gibi connection ekleyin.

---

## 3. Uygulama Kurulumu

### Adım 3.1: Flutter Kurulumu (İlk Kez)

Eğer Flutter yüklü değilse:

```bash
# Windows (PowerShell):
# https://docs.flutter.dev/get-started/install/windows

# macOS:
brew install flutter

# Linux:
sudo snap install flutter --classic

# Kontrol:
flutter doctor
```

### Adım 3.2: Projeyi Hazırla

```bash
# Proje klasörüne git
cd notion_save_pro

# Bağımlılıkları yükle
flutter pub get
```

### Adım 3.3: .env Dosyasını Düzenle

`.env` dosyasını bir metin editörü ile açın:

```bash
# Windows:
notepad .env

# macOS/Linux:
nano .env
```

Şu şekilde doldurun:

```env
# Notion API anahtarınız (secret_ ile başlar)
NOTION_API_KEY=secret_AbCdEf123456GhIjKl789MnOpQr

# Ana veritabanı ID (32 karakter)
TARGET_DATABASE_ID=abc123def456ghi789jkl012mno345

# Şablonlar veritabanı ID (32 karakter)
TEMPLATES_DATABASE_ID=xyz789uvw456rst123opq890lmn567
```

**⚠️ Gerçek değerlerinizi yazın!**

### Adım 3.4: APK Oluştur

```bash
# Release APK oluştur
flutter build apk --release

# İşlem bitince APK şurada:
# build/app/outputs/flutter-apk/app-release.apk
```

### Adım 3.5: Telefona Yükle

**Yöntem 1: USB ile (Android Debug Bridge)**

```bash
# USB kablosu ile telefonu bilgisayara bağlayın
# Telefonda "USB Debugging" açık olmalı

# Yükle:
flutter install

# veya:
adb install build/app/outputs/flutter-apk/app-release.apk
```

**Yöntem 2: APK Dosyasını At**

1. `app-release.apk` dosyasını telefona atın (WhatsApp, Email, USB)
2. Telefonda dosyayı açın
3. "Bilinmeyen kaynaklardan yükleme" izni verin
4. Yükle

---

## 4. Test ve Kullanım

### İlk Test

1. **Chrome'u açın** (veya başka tarayıcı)
2. Bir haber sitesine gidin (örn: medium.com)
3. Bir makale açın
4. **Paylaş** butonuna basın
5. **Notion Save Pro** seçin
6. Dialog açılacak:
   - Başlık otomatik gelecek
   - Şablon seçin
   - **Kaydet**'e basın
7. Notion'ı açıp kontrol edin!

### Sorun Varsa

#### "Konfigürasyon Hatası"
```bash
# .env dosyasını kontrol et:
cat .env

# Boş veya hatalıysa düzenle:
nano .env
```

#### "Notion'a bağlanılamadı"
- [ ] API key doğru mu?
- [ ] Integration veritabanlarına bağlı mı?
- [ ] İnternet bağlantınız var mı?
- [ ] Database ID'ler 32 karakter mi?

#### "Şablon bulunamadı"
- [ ] Şablonlar veritabanında en az 1 satır var mı?
- [ ] Integration bağlantısı yapıldı mı?
- [ ] Database ID doğru mu?

### Debug Modu ile Test

```bash
# Uygulamayı debug mode'da çalıştır:
flutter run

# Logları izle:
flutter logs

# Hataları görürsünüz
```

---

## 5. Gelişmiş Ayarlar

### Özel Property Eklemek

`lib/services/notion_service.dart` dosyasını düzenleyin:

```dart
"properties": {
  "Name": {"title": [{"text": {"content": article.title}}]},
  "URL": {"url": article.url},
  
  // Ekstra property'ler:
  "Tags": {
    "multi_select": [
      {"name": "Web"},
      {"name": "Makale"}
    ]
  },
  "Tarih": {
    "date": {"start": DateTime.now().toIso8601String()}
  },
  "Kaynak": {
    "select": {"name": "İnternet"}
  }
}
```

### Scraping Ayarları

`lib/services/web_scraper_service.dart` dosyasında:

```dart
// Maksimum blok sayısını değiştir:
static const int maxBlocks = 80; // 80 → 100 yapabilirsin

// Makale selector'larını özelleştir:
Element? mainContent = document.querySelector('article') ??
                       document.querySelector('.your-custom-class');
```

---

## 6. Güvenlik Önerileri

### Production için:

1. **API Key'i hardcode etmeyin**
   ```dart
   // ❌ YANLIŞ:
   static const String _apiKey = 'secret_123...';
   
   // ✅ DOĞRU:
   static String get apiKey => dotenv.env['NOTION_API_KEY'] ?? '';
   ```

2. **.env dosyasını git'e eklemeyin**
   ```bash
   # .gitignore'a eklenmiş olmalı:
   .env
   .env.local
   ```

3. **Google Play'e yüklerken:**
   - API key'i Firebase Remote Config'de saklayın
   - veya backend API üzerinden alın

---

## 🎉 Tamamlandı!

Artık mobil cihazınızdan Notion'a makale kaydedebilirsiniz!

**Sorular?** Issue açın veya README.md'ye bakın.

---

**⭐ Faydalı olduysa yıldız vermeyi unutmayın!**
