# 📱 Notion Save Pro

**Chrome eklentisi "Save to Notion"un mobil versiyonu!**

Android'de web sayfalarını Notion'a şablonlarınızla birlikte kaydetmenizi sağlayan Flutter uygulaması.

## ✨ Özellikler

- � **OAuth 2.0 Login** - Güvenli Notion hesabı girişi
- 🗂️ **Database Seçimi** - Kendi veritabanlarınızdan seçim yapın
- 📄 **Template Seçimi** - Notion template'lerinizi kullanın
- 🔗 **Herhangi bir uygulamadan paylaş** - Chrome, Firefox, Twitter, Reddit vb.
- 🎯 **Akıllı parsing** - Makale içeriğini otomatik olarak çıkarır
- 🖼️ **Görsel desteği** - Görselleri de birlikte kaydeder
- ⚡ **Hızlı ve kolay** - Tek tıkla kaydet
- 🎨 **Modern UI** - Şık ve kullanıcı dostu arayüz

## 📋 Gereksinimler

- Flutter SDK (3.0.0 veya üzeri)
- Android Studio veya VS Code
- Notion hesabı
- Notion OAuth Public Integration

## 🚀 Kurulum

### 1. Notion OAuth Integration Ayarları

1. [Notion Integrations](https://www.notion.so/my-integrations) sayfasına gidin
2. "New integration" butonuna tıklayın
3. Formu doldurun:
   - **Type:** Public
   - **Name:** "Notion Save Pro"
   - **Redirect URIs:** `https://your-domain.vercel.app/oauth-callback.html`
4. **Capabilities** bölümünde şunları seçin:
   - ✅ Read content
   - ✅ Update content  
   - ✅ Insert content
5. "Submit" edin
6. **OAuth Client ID** ve **OAuth Client Secret**'ı kopyalayın

### 2. Vercel Callback Sayfası (Opsiyonel - kendi domain'iniz varsa)

OAuth callback için bir HTTPS URL'ye ihtiyacınız var. Kendi Vercel domain'inizi oluşturup kullanabilirsiniz.

Kendi domain'inizi kullanmak isterseniz:
1. Vercel'de bir proje oluşturun
2. `oauth-callback.html` dosyasını deploy edin
3. `.env` dosyasında `NOTION_REDIRECT_URI`'yi güncelleyin

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
# OAuth Credentials (Notion Integration'dan alın)
NOTION_CLIENT_ID=your-client-id-here
NOTION_CLIENT_SECRET=secret_your-client-secret-here
NOTION_REDIRECT_URI=https://your-domain.vercel.app/oauth-callback.html
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

### İlk Kurulum (Sadece Bir Kez)

1. **Uygulamayı açın**
2. **"Notion ile Giriş Yap"** butonuna tıklayın
3. Tarayıcıda Notion OAuth sayfası açılır
4. Workspace'inizi seçin ve **"Select pages"** tıklayın
5. Erişim vermek istediğiniz veritabanlarını seçin
6. **"Allow access"** tıklayın
7. Uygulama açılır, **database seçin**
8. **Template seçin** (veritabanınızda template varsa)
9. ✅ Ayarlar kaydedildi!

### Makale Kaydetme

1. **Tarayıcıda bir makale açın** (Chrome, Firefox, vb.)
2. **Paylaş butonuna** tıklayın
3. **Notion Save Pro**'yu seçin
4. Başlığı düzenleyin (otomatik gelir)
5. **Kaydet**'e tıklayın
6. ✅ Seçtiğiniz database ve template ile Notion'da görünür!

## 🎯 Nasıl Çalışır?

### İlk Kurulum Akışı:
```
[Login Screen] → OAuth Login
    ↓
[Browser] → Notion Authorization
    ↓
[Callback] → Token Exchange
    ↓
[Database Selection] → Kullanıcı seçer
    ↓
[Template Selection] → Kullanıcı seçer
    ↓
✅ Ayarlar kaydedildi!
```

### Makale Kaydetme Akışı:
```
[Tarayıcı] → Paylaş
    ↓
[Notion Save Pro]
    ↓
Web Scraper → Makaleyi parse et
    ↓
Notion API → Seçili Database + Template → Kaydet
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
│   ├── article.dart              # Makale modeli
│   ├── notion_database.dart      # Database modeli
│   └── notion_template.dart      # Template modeli
├── screens/
│   ├── login_screen.dart         # OAuth login ekranı
│   ├── database_selection_screen.dart  # Database seçim ekranı
│   └── template_selection_screen.dart  # Template seçim ekranı
├── services/
│   ├── auth_service.dart         # OAuth token yönetimi
│   ├── notion_service.dart       # Notion API
│   └── web_scraper_service.dart  # Web scraping
└── main.dart                     # Ana uygulama
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

### "Login yapamıyorum"
- `.env` dosyasında OAuth credentials'ları kontrol edin
- NOTION_REDIRECT_URI'nin doğru olduğundan emin olun
- İnternet bağlantınızı kontrol edin
- Vercel callback sayfasının çalıştığını test edin

### "Database listesi boş"
- OAuth sırasında database'lere erişim verdiğinizden emin olun
- Notion'da en az bir database oluşturun
- Integration capabilities'de "Read content" aktif mi kontrol edin

### "Template bulunamadı"
- Seçtiğiniz database'de template olmalı
- Template sayfaları düzgün oluşturulmuş olmalı
- Integration'ın template database'e erişimi olmalı

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
- OAuth credentials'ları kimseyle paylaşmayın
- Access token'lar `flutter_secure_storage` ile güvenli şekilde saklanır
- Production'da environment variables kullanın
- Notion OAuth Public Integration kullandığınız için her kullanıcı kendi hesabına bağlanır

## 📄 Lisans

MIT License - Özgürce kullanabilirsiniz!

## 🙏 Teşekkürler

- [Save to Notion](https://www.notion.so/integrations/save-to-notion) Chrome eklentisinden ilham alınmıştır
- Flutter ve Notion API topluluğuna teşekkürler

## 📧 İletişim

Sorularınız için issue açabilirsiniz.

---

**⭐ Beğendiyseniz yıldız vermeyi unutmayın!**
