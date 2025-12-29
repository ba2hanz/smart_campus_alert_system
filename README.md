# 🏫 Akıllı Kampüs Bildirim Sistemi (Smart Campus Alert System)

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-039BE5?style=for-the-badge&logo=Firebase&logoColor=white)
![Google Maps](https://img.shields.io/badge/Google_Maps-4285F4?style=for-the-badge&logo=google-maps&logoColor=white)

Üniversite kampüslerinde yaşanan sorunların (teknik, güvenlik, sağlık, çevre vb.) konum tabanlı olarak bildirilmesini, yönetim tarafından takip edilmesini ve çözüme kavuşturulmasını sağlayan kapsamlı bir mobil uygulamadır.

## 📱 Özellikler

### 👤 Kullanıcı (Öğrenci/Personel) Modülü
* **Olay Bildirimi:** Fotoğraf, başlık, açıklama ve tür seçerek sorun bildirme.
* **Konum Bazlı İşlem:** Google Maps entegrasyonu ile olayın yerini haritada işaretleme.
* **Durum Takibi:** Bildirilen sorunların durumunu (Açık, İnceleniyor, Çözüldü) takip etme.
* **Bildirimler:** Takip edilen olayların durumu değiştiğinde anlık **Push Bildirim (FCM)** alma.
* **Profil Yönetimi:** Bildirim tercihleri (Genel, Kayıp/Buluntu vb.) ve kişisel bilgi güncelleme.
* **Filtreleme:** Harita üzerinde olay türüne veya duruma göre filtreleme.

### 🛡️ Yönetici (Admin) Modülü
* **Dashboard:** Tüm bildirimleri liste halinde görme ve filtreleme.
* **Durum Yönetimi:** Olayların durumunu güncelleme (örn: Açık -> Çözüldü).
* **Müdahale:** Bildirim açıklamalarını düzenleme veya gereksiz bildirimleri silme.
* **Duyuru Sistemi:** Tüm kampüse veya sadece belirli bir olayı takip edenlere **bildirim gönderme**.
* **Admin Haritası:** Normal kullanıcıların göremediği "İnceleniyor" aşamasındaki bildirimleri haritada görüntüleme.

## 📸 Ekran Görüntüleri

| Giriş Ekranı | Ana Sayfa | Harita Görünümü |
| :---: | :---: | :---: |
| <img src="screenshots/login.png" width="200"/> | <img src="screenshots/home.png" width="200"/> | <img src="screenshots/map.png" width="200"/> |

| Olay Detayı | Admin Paneli | Profil & Ayarlar |
| :---: | :---: | :---: |
| <img src="screenshots/detail.png" width="200"/> | <img src="screenshots/admin.png" width="200"/> | <img src="screenshots/profile.png" width="200"/> |

*(Not: Ekran görüntülerini projenizin ana dizininde `screenshots` klasörü açıp içine ekleyin.)*

## 🛠️ Kullanılan Teknolojiler

* **Flutter & Dart:** UI ve logic geliştirme.
* **Firebase Authentication:** Kullanıcı girişi ve rol yönetimi (Admin/User).
* **Cloud Firestore:** Gerçek zamanlı veritabanı.
* **Firebase Cloud Messaging (FCM):** Push bildirimleri (HTTP v1 API).
* **Google Maps Flutter:** Harita entegrasyonu.
* **Provider / StreamBuilder:** State yönetimi.

## 🚀 Kurulum

Projeyi yerel ortamınızda çalıştırmak için aşağıdaki adımları izleyin:

1.  **Projeyi Klonlayın:**
    ```bash
    git clone [https://github.com/ba2hanz/smart-campus-alert.git](https://github.com/ba2hanz/smart-campus-alert.git)
    cd smart-campus-alert
    ```

2.  **Paketleri Yükleyin:**
    ```bash
    flutter pub get
    ```

3.  **Firebase Kurulumu:**
    * Firebase konsolunda yeni bir proje oluşturun.
    * `google-services.json` dosyasını indirip `android/app/` klasörüne atın.
    * Authentication (Email/Password) ve Firestore veritabanını aktif edin.

4.  **Admin Bildirim Yetkisi (Önemli):**
    * Firebase Console -> Project Settings -> Service Accounts sekmesinden yeni bir `private key` oluşturun.
    * İnen dosyanın adını `service_account.json` olarak değiştirin.
    * Bu dosyayı projenin `assets/` klasörüne ekleyin.

5.  **Google Maps API:**
    * Google Cloud Console'dan bir API Key alın.
    * `android/app/src/main/AndroidManifest.xml` dosyasına ekleyin.

6.  **Çalıştırın:**
    ```bash
    flutter run
    ```

## 🔐 Rol Yönetimi (Admin Olma)
Varsayılan olarak yeni kayıt olan herkes **User** rolündedir. Bir kullanıcıyı Admin yapmak için:
1.  Firebase Console -> Firestore Database'e gidin.
2.  `users` koleksiyonunu bulun.
3.  İlgili kullanıcının dökümanındaki `role` alanını `admin` olarak güncelleyin.

## 🤝 Katkıda Bulunma
1.  Bu repoyu fork edin.
2.  Yeni bir feature branch oluşturun (`git checkout -b feature/YeniOzellik`).
3.  Değişikliklerinizi commit edin (`git commit -m 'Yeni özellik eklendi'`).
4.  Branch'inizi pushlayın (`git push origin feature/YeniOzellik`).
5.  Pull Request oluşturun.

## 📄 Lisans
Bu proje [MIT](LICENSE) lisansı ile lisanslanmıştır.
