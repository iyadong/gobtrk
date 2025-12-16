# gobtrk

Project ini adalah aplikasi Flutter.  
README ini dibuat khusus untuk membantu pengguna awam menjalankan project ini di **Windows** menggunakan **VS Code**, tanpa Android Studio.

---

## 1. Prasyarat (yang harus diinstall)

Sebelum menjalankan project, pastikan sudah menginstall:

1. **Git for Windows**  
   Dipakai untuk perintah `git clone`.

2. **Visual Studio Code (VS Code)**  
   Dipakai sebagai code editor.

3. **Flutter SDK**  
   Dipakai untuk menjalankan dan build aplikasi.

4. **Visual Studio 2022 (Desktop development with C++)**  
   Dibutuhkan Flutter untuk build aplikasi **Windows desktop**.

---

## 2. Install langkah demi langkah

### 2.1. Install Git

1. Download **Git for Windows** dari website resminya.
2. Jalankan installer, saat ada pilihan aneh–aneh cukup klik **Next** / setting default.

### 2.2. Install Visual Studio Code

1. Download **Visual Studio Code**.
2. Install seperti biasa (Next–Next–Finish).

### 2.3. Pasang Flutter lewat VS Code (cara gampang)

1. Buka **VS Code**
2. Buka menu **Extensions** (ikon kotak di sidebar kiri)
3. Cari dan install extension:
   - **Flutter**
   - (otomatis akan menginstall **Dart** juga)
4. Tekan **Ctrl + Shift + P**
5. Ketik: `Flutter: New Project`
6. Pilih **Download SDK** → pilih folder tempat menyimpan Flutter (misal: `C:\src\flutter`)
7. Setelah download selesai, pilih opsi untuk **Add Flutter SDK to PATH** (kalau muncul).
8. Tutup & buka lagi VS Code / terminal.

Cek apakah Flutter sudah terinstall dengan benar:

```powershell
flutter --version
flutter doctor -v
