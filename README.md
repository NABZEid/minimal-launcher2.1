# Minimal Launcher v0.200.1

Launcher Android minimalis (Flutter, Material 3) dengan tema gelap OLED dan terang.

## Build APK lewat GitHub (tanpa install apa pun di komputer)
1. Buat repository baru di GitHub, lalu unggah seluruh isi folder ini
   (pastikan folder `.github/workflows/build-apk.yml` ikut terunggah).
2. Buka tab **Actions** -> **Build APK** -> **Run workflow**.
3. Setelah selesai (sekitar 5-8 menit), unduh APK dari tab **Releases**
   atau dari bagian **Artifacts** pada run tersebut.

Jika langkah Release gagal dengan error 403: Settings -> Actions -> General ->
Workflow permissions -> pilih **Read and write permissions**.

## Build lokal
    flutter create --platforms=android --org com.minimal --project-name minimal_launcher .
    # tambahkan kategori HOME dan DEFAULT pada intent-filter LAUNCHER di AndroidManifest.xml
    flutter run --profile

## Menjadikan default launcher
Pengaturan -> Aplikasi -> Aplikasi default -> Aplikasi layar utama -> Minimal Launcher.
