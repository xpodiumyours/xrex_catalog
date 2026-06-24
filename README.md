# XRex Asistan (X-CA)

XRex, VitrinX ekosistemi için geliştirilen, tamamen cihaz içi (on-device) çalışan, akıllı ve masrafsız bir katalog taslak asistanıdır.

## 🚀 Temel Felsefe ve Kurallar

- **Sıfır Maliyet:** Ücretli API (OpenAI, Gemini vb.) kullanılmaz.
- **Gizlilik ve Hız:** Tüm işlemler internete ihtiyaç duymadan cihaz içinde gerçekleşir.
- **Bağımsızlık:** VitrinX çekirdek koduna dokunmadan, bir "akıllı modül" olarak çalışır.
- **Diyalog Odaklı:** Kullanıcı karmaşık formlarla değil, bir asistanla sohbet ederek kataloğunu oluşturur.

---

## 🛠️ Teknik Özellikler

### 1. Akıllı Analiz Motoru (Shelf-Aware Engine)
- **Nesne Algılama:** Görseldeki ürün bölgelerini Google ML Kit ile tespit eder.
- **Gelişmiş OCR:** Metinleri okur ve raf hiyerarşisine (Ürün üstte, fiyat altta) göre otomatik ilişkilendirir.
- **Marka Bilinci:** Ülker, Eti, Biscolata gibi markaları tanıyarak eksik ürün isimlerini tamamlar.
- **Gürültü Filtresi:** Reklam metinlerini ve teknik kodları ayıklayarak temiz veri sunar.

### 2. Diyalog Arayüzü (Chat UI)
- **X-CA Asistan:** Kullanıcıyı karşılar, fotoğrafları analiz eder ve sonuçları sohbette kartlar halinde sunar.
- **Hızlı Yanıtlar (Quick Replies):** "Fotoğraf Yükle", "Kategorize Et", "JSON Al" gibi butonlarla hızlı akış.
- **Dinamik Güncelleme:** Sohbet üzerinden "Fiyatı 50 TL yap" gibi doğal dil komutlarını (Regex-based) anlar.

### 3. Çıktı ve Entegrasyon
- **JSON Export:** VitrinX'in anında okuyabileceği standartlaştırılmış ürün şeması üretir.
- **Çoklu Platform:** Android ve Windows üzerinde tam performanslı çalışma.

---

## 📅 Gelişim Fazları

### ✅ Faz 1: "Gör ve Tanı" (Tamamlandı)
- Cihaz içi OCR ve Nesne Algılama entegrasyonu.
- Chatbot arayüzü ve temel mesajlaşma yapısı.
- Ürün listeleme ve manuel düzenleme ekranları.

### 🔄 Faz 2: "Zeka ve Bağlam" (Devam Ediyor)
- Karmaşık doğal dil komutlarının (Niyet Tanıma) güçlendirilmesi.
- Akıllı kategorizasyon mantığının (Sektör bazlı) derinleştirilmesi.
- VitrinX Asistanı ile tam senkronizasyon modellerinin kurulması.

### 🎯 Faz 3: "Ekosistem Entegrasyonu"
- Oluşturulan taslakların VitrinX mağaza yönetim paneline tek tıkla aktarılması.
- Çevrimdışı yerel veritabanı ile geçmiş katalogların saklanması.

---

## 📦 Kurulum ve Çalıştırma

```bash
# Bağımlılıkları çek
flutter pub get

# Android Emulator veya Cihazda çalıştır
flutter run
```

*Not: ML Kit modellerinin ilk kurulumda cihaz içine indirilmesi için internet bağlantısı gerekebilir. Sonrasında tamamen offline çalışır.*
