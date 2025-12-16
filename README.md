# Tutorial Build APK Flutter `gobtrk` di Windows Tanpa Android Studio (Hanya VS Code)

Dokumen ini menjelaskan langkah demi langkah, dari **nol** sampai jadi **APK**, untuk project Flutter `gobtrk` di Windows **tanpa Android Studio**, hanya pakai **VS Code + terminal**.

---

## A. PERSIAPAN DI WINDOWS (DILAKUKAN SEKALI PER PC)

### 1. Install VS Code

1. Buka: https://code.visualstudio.com/
2. Download versi **Windows** → install seperti biasa (Next, Next, Finish).
3. Setelah terinstall, biarkan dulu. Nanti kita pakai untuk buka project.

---

### 2. Install Git

Flutter butuh Git, jadi sekalian kita install.

1. Buka: https://git-scm.com/downloads
2. Pilih **Windows** → download → install.
3. Saat install, klik **Next** saja terus (pakai pengaturan default sudah aman).

---

### 3. Install Flutter SDK (tanpa Android Studio)

1. Buka dokumentasi Flutter untuk Windows:  
   https://docs.flutter.dev/install/archive
2. Scroll ke bagian Install and set up Flutter → Download the Flutter SDK bundle lalu download Stable (Windows) ZIP.
3. Buat folder misalnya:

   ```text
   C:\flutter
   ```

4. Ekstrak isi file ZIP ke `C:\flutter`  
   (di dalamnya harus ada folder `bin`, `packages`, dll).

#### 3.1 Tambah Flutter ke PATH

Supaya perintah `flutter` bisa dipakai di terminal dari folder mana saja:

1. Di Windows, klik **Start** → ketik `Environment Variables` → pilih:  
   **Edit the system environment variables**
2. Di jendela baru, klik tombol **Environment Variables…**
3. Di bagian **System variables**, cari variable `Path` → klik **Edit**.
4. Klik **New**, masukkan:

   ```text
   C:\flutter\bin
   ```

5. Klik **OK** semua sampai jendela tertutup.
6. Tutup semua jendela Command Prompt / PowerShell kalau ada yang terbuka.

#### 3.2 Cek Flutter

1. Buka **Command Prompt** / **PowerShell** baru.
2. Jalankan:

   ```bash
   flutter --version
   ```

   Kalau muncul versi Flutter, berarti PATH sudah benar.

3. Lalu jalankan:

   ```bash
   flutter doctor
   ```

   Akan muncul daftar checklist.  
   Wajar kalau masih ada tanda **X** terutama di bagian Android / Java, nanti kita bereskan.

---

### 4. Install Java (JDK 17)

Untuk build Android, Flutter pakai Java. Rekomendasi: **OpenJDK / Temurin JDK 17**.

1. Buka: https://adoptium.net/temurin/releases?version=17&mode=filter&os=windows&arch=x64
2. Pilih:
   - **Version**: 17 (LTS)
   - **Operating System**: Windows
   - **Architecture**: x64
3. Download file installer (`.msi`) → jalankan.
4. Saat install, kalau ada opsi:
   - Centang **Add to PATH**
   - Centang **Set JAVA_HOME** (kalau tersedia)
5. Selesai → Close.

#### 4.1 Cek Java

Di Command Prompt / PowerShell:

```bash
java -version
```

Kalau keluar versi 17.x (kurang lebih begitu), berarti Java sudah terinstall dengan benar.

---

### 5. Install Android SDK **tanpa Android Studio**

Bagian ini paling penting supaya bisa build APK **tanpa** Android Studio.

Kita akan:

1. Download **Android Command Line Tools**
2. Taruh di `C:\Android\SDK`
3. Pakai `sdkmanager` untuk download komponen Android (platform, build-tools, dll).

#### 5.1 Download Command Line Tools

1. Buka halaman download Android Studio & tools, lalu cari bagian:  
   **Command line tools only** (untuk Windows).
2. Download file ZIP: `commandlinetools-win-xxxx_latest.zip`.
3. Buat folder:

   ```text
   C:\Android\SDK
   C:\Android\SDK\cmdline-tools
   ```

4. Ekstrak ZIP ke folder:

   ```text
   C:\Android\SDK\cmdline-tools
   ```

   Setelah diekstrak biasanya muncul struktur seperti ini:

   ```text
   C:\Android\SDK\cmdline-tools\cmdline-tools\bin
   ```

5. Rename:

   - Dari:

     ```text
     C:\Android\SDK\cmdline-tools\cmdline-tools
     ```

   - Menjadi:

     ```text
     C:\Android\SDK\cmdline-tools\latest
     ```

   Sehingga struktur akhirnya:

   ```text
   C:\Android\SDK\
       cmdline-tools\
           latest\
               bin\
               ...
   ```

---

#### 5.2 Set Environment Variable ANDROID_SDK_ROOT / ANDROID_HOME

1. Buka lagi **Environment Variables** seperti di langkah Flutter tadi.
2. Di bagian **System variables**:
   - Klik **New…**
     - Variable name: `ANDROID_SDK_ROOT`
     - Variable value: `C:\Android\SDK`
   - (Opsional, tapi bagus kalau ada) Klik **New…** lagi:
     - Variable name: `ANDROID_HOME`
     - Variable value: `C:\Android\SDK`

3. Masih di **System variables**, pilih `Path` → **Edit** → **New**, tambahkan:

   ```text
   C:\Android\SDK\platform-tools
   C:\Android\SDK\cmdline-tools\latest\bin
   ```

4. Klik **OK** semua sampai jendela tertutup.

---

#### 5.3 Download Platform-Tools & Build-Tools dengan sdkmanager

Sekarang kita pakai `sdkmanager` untuk download paket Android yang dibutuhkan.

1. Buka **Command Prompt** biasa (tidak perlu Run as Administrator).
2. Jalankan:

   ```bash
   sdkmanager --licenses
   ```

   - Kalau muncul error `sdkmanager not found`, tutup terminal, buka lagi.
   - Kalau muncul teks lisensi panjang → ketik `y` lalu Enter, ulangi sampai selesai.

3. Install paket utama yang dibutuhkan Flutter:

   ```bash
   sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
   ```

   Keterangan:
   - `platform-tools` → berisi `adb` untuk koneksi ke HP.
   - `platforms;android-34` → Android API level 34 (boleh pakai versi lain kalau mau).
   - `build-tools;34.0.0` → tools untuk build APK.

Tunggu sampai semua paket selesai terdownload dan terinstall.

---

### 6. Hubungkan Flutter dengan Android SDK & Java

Sekarang kita pastikan Flutter “tahu” lokasi Android SDK-nya.

1. Di Command Prompt / PowerShell:

   ```bash
   flutter config --android-sdk "C:\Android\SDK"
   ```

2. Lalu cek lagi dengan:

   ```bash
   flutter doctor
   ```

Perhatikan:

- Bagian **Android toolchain** harus sudah hijau (✅) atau minimal tidak ada error fatal.
- Kalau ada pesan **Android licenses not accepted**, jalankan:

  ```bash
  flutter doctor --android-licenses
  ```

  Lalu jawab `y` untuk semua pertanyaan lisensi.

Jika semua sudah benar, berarti persiapan di Windows selesai.

---

## B. DOWNLOAD & BUKA PROJECT `gobtrk` DI VS CODE

Repo GitHub: `https://github.com/iyadong/gobtrk`  
Ini adalah project Flutter yang ingin kita build menjadi APK.

### 1. Cara 1 (paling gampang): Download ZIP

1. Buka halaman GitHub `gobtrk` di browser.
2. Klik tombol hijau **Code** → pilih **Download ZIP**.
3. Setelah terdownload, ekstrak ZIP ke folder yang mudah diingat, misalnya:

   ```text
   D:\project\gobtrk
   ```

### 2. Buka folder di VS Code

1. Buka **VS Code**.
2. Menu **File → Open Folder…**
3. Pilih folder `gobtrk` hasil ekstrak tadi.
4. Klik **Select Folder**.
5. VS Code akan membuka project tersebut.

### 3. Install extension Flutter & Dart di VS Code

Supaya coding & debugging lebih enak:

1. Di VS Code, klik ikon **Extensions** (ikon kotak-kotak di sisi kiri).
2. Di kotak pencarian ketik **Flutter**.
   - Install extension **Flutter** (biasanya otomatis ikut install **Dart** juga).
3. Pastikan extension **Flutter** dan **Dart** sudah terinstall (status: Enabled).

### 4. Install dependency Flutter

1. Di VS Code, buka **Terminal**:  
   - Menu **View → Terminal**, atau  
   - Tekan tombol ```Ctrl + ` ```.
2. Pastikan path terminal berada di folder project `gobtrk` (di baris prompt terlihat `...\gobtrk>`).
3. Jalankan:

   ```bash
   flutter pub get
   ```

   Ini akan mendownload semua package / library yang dibutuhkan project, sesuai file `pubspec.yaml`.

Kalau `flutter pub get` selesai tanpa error, berarti project siap dijalankan / dibuild.

---

## C. COBA JALANKAN DI HP ANDROID (OPSIONAL, TAPI DISARANKAN)

Langkah ini tidak wajib untuk build APK, tapi bagus untuk memastikan aplikasi berjalan dengan baik di HP.

### 1. Aktifkan Developer Mode & USB Debugging di HP

Secara umum (tiap merk mungkin beda sedikit):

1. Buka **Settings / Pengaturan** di HP.
2. Cari menu **About phone / Tentang ponsel**.
3. Cari **Build number / Nomor bentukan**.
4. Tap **Build number** sekitar 7 kali sampai muncul pesan “You are now a developer”.
5. Kembali ke menu **Settings**, cari **Developer options / Opsi pengembang**.
6. Di dalamnya, aktifkan **USB debugging**.

### 2. Sambungkan HP ke PC

1. Colok HP ke PC dengan kabel USB.
2. Kalau muncul pop-up di HP bertuliskan **Allow USB debugging?** → pilih **Allow / Izinkan**.
3. Kalau muncul pilihan mode USB (Charging / File Transfer / dll), pilih yang mengizinkan transfer data (misalnya **File Transfer**).

### 3. Cek perangkat di Flutter

Di terminal (di folder `gobtrk`):

```bash
flutter devices
```

Jika HP terdeteksi, akan muncul nama perangkat Android di daftar device.

### 4. Jalankan app ke HP

Masih di folder `gobtrk`, jalankan:

```bash
flutter run
```

Tunggu beberapa saat (build pertama biasanya cukup lama).  
Jika berhasil, aplikasi `gobtrk` akan otomatis muncul dan berjalan di HP.

---

## D. BUILD FILE APK (LANGKAH UTAMA)

Sekarang kita buat file APK supaya bisa diinstall di HP mana saja (tanpa VS Code / Flutter).

Di terminal (di dalam folder `gobtrk`):

### 1. Build APK Release

Jalankan:

```bash
flutter build apk --release
```

Tunggu sampai proses selesai.  
Jika berhasil, Flutter akan menampilkan pesan lokasi file APK, biasanya:

```text
build\app\outputs\flutter-apk\app-release.apk
```

Itulah file APK yang siap dibagikan dan diinstall.

### 2. Memindahkan APK ke HP

Beberapa cara:

- **Pakai kabel USB**  
  Sambungkan HP ke PC → copy `app-release.apk` ke memori internal HP → buka file tersebut dari HP → install.

- **Pakai WhatsApp / Telegram / email**  
  Kirim file `app-release.apk` sebagai dokumen, bukan sebagai media/foto.

> Catatan:  
> Di HP, mungkin perlu mengaktifkan izin **Install unknown apps / Install from unknown sources** di pengaturan, supaya bisa install APK di luar Play Store.

---

### 3. (Opsional) Build APK yang lebih kecil per arsitektur

Kalau ingin ukuran APK lebih kecil dan spesifik untuk jenis CPU tertentu (arm64, armeabi-v7a, x86_64):

```bash
flutter build apk --release --split-per-abi
```

Setelah selesai, di folder output biasanya akan ada beberapa file, misalnya:

- `app-armeabi-v7a-release.apk`
- `app-arm64-v8a-release.apk`
- `app-x86_64-release.apk`

Umumnya HP Android modern memakai **arm64-v8a**, jadi file `app-arm64-v8a-release.apk` yang paling sering dipakai.

---

## E. BUILD DI PC WINDOWS LAIN (TANPA ANDROID STUDIO JUGA)

Kalau kamu ingin bisa build APK dari PC lain (misalnya laptop teman / kantor), prinsipnya sama:  
**PC tersebut harus di-setup dulu** (Flutter, Java, Android SDK).

### 1. Di PC lain, ulangi langkah **Persiapan Windows**:

- Install VS Code
- Install Git
- Install Flutter SDK
- Tambahkan `C:\flutter\bin` ke PATH
- Install Java JDK 17
- Install Android SDK via Command Line Tools
- Set environment variable:
  - `ANDROID_SDK_ROOT` = `C:\Android\SDK`
  - (Opsional) `ANDROID_HOME` = `C:\Android\SDK`
- Jalankan:

  ```bash
  flutter config --android-sdk "C:\Android\SDK"
  flutter doctor
  flutter doctor --android-licenses
  ```

Pastikan `flutter doctor` tidak menunjukkan error besar di bagian Android toolchain.

### 2. Copy project `gobtrk` ke PC tersebut

Bisa dengan:

- Download ulang dari GitHub (ZIP / git clone), atau
- Copy dari flashdisk / harddisk eksternal.

Lalu di PC lain:

```bash
cd path\ke\folder\gobtrk
flutter pub get
flutter build apk --release
```

Hasil APK akan muncul di lokasi yang sama:

```text
build\app\outputs\flutter-apk\app-release.apk
```

APK ini bisa kamu copy ke HP yang diinginkan.

> Catatan:  
> Kalau PC lain **hanya ingin menginstall APK** (tidak mau build), cukup kirim file `app-release.apk` dari PC pertama. Tidak perlu install Flutter / Java / SDK.

---

## F. RINGKASAN PERINTAH PENTING

Di dalam folder project `gobtrk`:

```bash
# 1. Ambil semua dependency (sekali setiap update pubspec.yaml)
flutter pub get

# 2. Cek perangkat Android yang terhubung
flutter devices

# 3. Jalankan aplikasi ke HP yang terhubung (debug mode)
flutter run

# 4. Build APK release (siap dibagikan)
flutter build apk --release

# (opsional) Build APK per arsitektur CPU
flutter build apk --release --split-per-abi
```

---

## PENUTUP

Dengan mengikuti langkah A sampai F di atas:

1. PC Windows kamu sudah siap untuk Flutter + Android (tanpa Android Studio).
2. Project `gobtrk` bisa dibuka dan dijalankan di VS Code.
3. Kamu bisa:
   - Menjalankan app langsung ke HP (`flutter run`), dan
   - Membangun file APK release (`flutter build apk --release`).

Kalau nanti saat praktek ada error / pesan merah di terminal, kamu bisa:
- Screenshot error tersebut
- Catat perintah apa yang kamu jalankan
- Lalu cari solusinya atau tanyakan ke asisten (misalnya ChatGPT) dengan menyertakan isi error-nya.

Selamat mencoba dan semoga lancar bangun APK-nya! 🚀
