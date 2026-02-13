# 🚀 Notion Save Pro - Detaylı Kurulum Rehberi

## 📋 İçindekiler

1. [Notion OAuth Integration Kurulumu](#1-notion-oauth-integration-kurulumu)
2. [Vercel Callback Sayfası (Opsiyonel)](#2-vercel-callback-sayfası-opsiyonel)
3. [Uygulama Kurulumu](#3-uygulama-kurulumu)
4. [Test ve Kullanım](#4-test-ve-kullanım)

---

## 1. Notion OAuth Integration Kurulumu

### Adım 1.1: Public Integration Oluştur

1. Tarayıcınızda şu linki açın: https://www.notion.so/my-integrations
2. **"+ New integration"** butonuna tıklayın
3. Formu doldurun:
   - **Name:** "Notion Save Pro" (veya istediğiniz isim)
   - **Associated workspace:** Workspace'inizi seçin
   - **Type:** **Public** (ÖNEMLİ!)
4. **"Submit"** butonuna tıklayın

### Adım 1.2: OAuth Ayarları

1. Integration sayfasında **"OAuth Domain & URIs"** bölümüne gidin
2. **Redirect URIs** kısmına şunu ekleyin:
   ```
   https://your-domain.vercel.app/oauth-callback.html
   ```
3. **"Save changes"** tıklayın

### Adım 1.3: Capabilities Ayarları

1. **"Capabilities"** sekmesine gidin
2. Şu izinleri aktif edin:
   - ✅ **Read content**
   - ✅ **Update content**
   - ✅ **Insert content**
3. **"Save changes"** tıklayın

### Adım 1.4: OAuth Credentials'ı Kopyala

1. **"Secrets"** sekmesine gidin
2. **OAuth client ID** ve **OAuth client secret**'ı kopyalayın
3. ⚠️ **GÜVENLİ BİR YERDE SAKLAYIN!**

---

## 2. Vercel Callback Sayfası (Opsiyonel)

**Not:** Kendi Vercel domain'inizi oluşturup kullanabilirsiniz. Kendi domain'inizi kullanmak isterseniz:

### Adım 2.1: oauth-callback.html Oluştur

Bu sayfayı bir dizinde oluşturun ve Vercel'e deploy edin:

**Dosya: `oauth-callback.html`**

```html
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Notion OAuth - Giriş Yapılıyor</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            text-align: center;
            padding: 40px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 20px;
            backdrop-filter: blur(10px);
        }
        .spinner {
            border: 4px solid rgba(255, 255, 255, 0.3);
            border-top: 4px solid white;
            border-radius: 50%;
            width: 50px;
            height: 50px;
            animation: spin 1s linear infinite;
            margin: 20px auto;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        h1 { margin: 0 0 10px 0; font-size: 24px; }
        p { margin: 5px 0; opacity: 0.9; }
        .error {
            background: #ff4444;
            padding: 20px;
            border-radius: 10px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1 id="title">🔐 Notion ile Giriş</h1>
        <div class="spinner" id="spinner"></div>
        <p id="message">Yönlendiriliyorsunuz...</p>
        <div id="error-container"></div>
    </div>

    <script>
        // URL parametrelerini parse et
        const urlParams = new URLSearchParams(window.location.search);
        const code = urlParams.get('code');
        const error = urlParams.get('error');
        const errorDescription = urlParams.get('error_description');

        const titleEl = document.getElementById('title');
        const messageEl = document.getElementById('message');
        const spinnerEl = document.getElementById('spinner');
        const errorContainer = document.getElementById('error-container');

        if (error) {
            // Hata durumu
            titleEl.textContent = '❌ Giriş Başarısız';
            messageEl.textContent = 'Bir hata oluştu';
            spinnerEl.style.display = 'none';
            
            const errorDiv = document.createElement('div');
            errorDiv.className = 'error';
            errorDiv.innerHTML = `
                <strong>Hata:</strong> ${error}<br>
                ${errorDescription ? `<small>${errorDescription}</small>` : ''}
            `;
            errorContainer.appendChild(errorDiv);
            
            console.error('OAuth Error:', error, errorDescription);
        } else if (code) {
            // Başarılı - Uygulamaya deep link ile yönlendir
            messageEl.textContent = 'Uygulama açılıyor...';
            
            console.log('✅ Authorization code received:', code);
            
            // Deep link ile uygulamayı aç
            const deepLink = `notionsavepro://oauth?code=${encodeURIComponent(code)}`;
            
            // Uygulamayı açmayı dene
            window.location.href = deepLink;
            
            // Eğer uygulama yüklü değilse kullanıcıya bilgi ver
            setTimeout(() => {
                messageEl.textContent = 'Uygulama açılmadı mı?';
                const infoP = document.createElement('p');
                infoP.innerHTML = '<small>Notion Save Pro uygulamasını açın ve tekrar deneyin.</small>';
                errorContainer.appendChild(infoP);
            }, 3000);
        } else {
            // Ne code ne de error var - beklenmeyen durum
            titleEl.textContent = '⚠️ Beklenmeyen Durum';
            messageEl.textContent = 'OAuth parametreleri bulunamadı';
            spinnerEl.style.display = 'none';
            console.warn('No code or error parameter found in URL');
        }
    </script>
</body>
</html>
```

**Özellikler:**
- ✅ Modern ve şık tasarım
- ✅ Loading animasyonu
- ✅ Hata durumlarında açıklayıcı mesajlar
- ✅ Mobil uyumlu
- ✅ Deep link ile otomatik yönlendirme
- ✅ Eğer uygulama açılmazsa bilgilendirme

### Adım 2.2: Vercel'e Deploy Et

1. Vercel hesabı oluşturun: https://vercel.com
2. Dosyayı deploy edin
3. HTTPS URL'yi not edin
4. `.env` dosyasında `NOTION_REDIRECT_URI`'yi güncelleyin
5. Notion Integration ayarlarında redirect URI'yi güncelleyin

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
# Notion OAuth Credentials (Integration'dan kopyalayın)
NOTION_CLIENT_ID=your-client-id-here
NOTION_CLIENT_SECRET=secret_your-client-secret-here

# OAuth Redirect URI (Vercel URL veya kendi domain'iniz)
NOTION_REDIRECT_URI=https://your-domain.vercel.app/oauth-callback.html
```

**⚠️ Kendi OAuth credentials'larınızı yazın!**

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

**İlk Kurulum:**

1. **Uygulamayı açın**
2. **"Notion ile Giriş Yap"** butonuna tıklayın
3. Tarayıcı açılır, Notion OAuth sayfası görünür
4. Workspace'inizi seçin
5. **"Select pages"** tıklayın
6. Erişim vermek istediğiniz database'leri seçin
7. **"Allow access"** tıklayın
8. Uygulama açılır
9. **Database seçin** (kaydetmek istediğiniz database)
10. **Template seçin** (varsa)
11. ✅ Kurulum tamamlandı!

**Makale Kaydetme:**

1. **Chrome'u açın** (veya başka tarayıcı)
2. Bir haber sitesine gidin (örn: medium.com)
3. Bir makale açın
4. **Paylaş** butonuna basın
5. **Notion Save Pro** seçin
6. Dialog açılacak:
   - Başlık otomatik gelecek
   - **Kaydet**'e basın (seçili database ve template kullanılır)
7. Notion'ı açıp kontrol edin!

### Sorun Varsa

#### "Login yapamıyorum"
```bash
# .env dosyasını kontrol et:
cat .env

# OAuth credentials kontrol et
```
- [ ] NOTION_CLIENT_ID ve CLIENT_SECRET doğru mu?
- [ ] NOTION_REDIRECT_URI doğru mu?
- [ ] Vercel callback sayfası çalışıyor mu?
- [ ] İnternet bağlantınız var mı?

#### "Database listesi boş"
- [ ] OAuth sırasında database'lere erişim verdiniz mi?
- [ ] Notion'da en az bir database var mı?
- [ ] Integration capabilities'de "Read content" aktif mi?
- [ ] Workspace'de database'ler mevcut mu?

#### "Template bulunamadı"
- [ ] Seçtiğiniz database'de template sayfaları var mı?
- [ ] Template'ler düzgün oluşturulmuş mu?
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
