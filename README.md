# gobtrk

Project ini adalah aplikasi **Flutter**.  
README ini berisi **tutorial lengkap dari 0** untuk menjalankan project ini di **Windows** menggunakan **Visual Studio Code (VS Code)** **tanpa Android Studio**.

---

## 1. Apa yang akan kita lakukan?

Tujuan tutorial ini:

1. Install semua alat yang dibutuhkan:
   - Git
   - VS Code
   - Flutter SDK
   - Visual Studio 2022 (untuk build app Windows)
2. Download (clone) project ini dari GitHub.
3. Jalankan aplikasi sebagai **aplikasi Windows (desktop)**.
4. (Opsional) Build versi **release** untuk dibagikan ke orang lain.

---

## 2. Perangkat & Sistem Operasi

Tutorial ini dibuat untuk:

- Sistem operasi: **Windows 10 / Windows 11 (64-bit)**
- Arsitektur: **64-bit**

Kalau kamu pakai sistem lain (Linux/MacOS), langkah besarnya mirip tapi detail install Flutter & toolchain beda.

---

## 3. Software yang Wajib Diinstall

Sebelum jalanin project, kamu perlu install ini:

1. **Git for Windows**  
   Supaya bisa pakai perintah `git clone` untuk mengambil project dari GitHub.

2. **Visual Studio Code (VS Code)**  
   Code editor yang akan kita pakai untuk ngedit & buka project.

3. **Flutter SDK**  
   Framework yang dipakai project ini.

4. **Visual Studio 2022 (Desktop development with C++)**  
   Ini bukan VS Code. Ini diperlukan untuk build aplikasi **Windows desktop** dari Flutter.

> Jangan khawatir, semua ini cukup diinstall **sekali saja**.  
> Nanti ke depannya, kalau mau coba project Flutter lain, tinggal ulang langkah dari bagian clone projectnya saja.

---

## 4. Langkah Install dari 0

### 4.1. Install Git for Windows

1. Buka website **Git for Windows**.
2. Download instalernya.
3. Jalankan file installer Git.
4. Saat proses install, kalau bingung pilih apa → pakai setting **default saja** (tinggal klik **Next** terus sampai selesai).

Untuk mengecek Git sudah terinstall:

1. Buka **Command Prompt** atau **PowerShell**.
2. Ketik:

   ```bash
   git --version
