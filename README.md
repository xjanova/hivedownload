<p align="center">
  <img src="https://raw.githubusercontent.com/xjanova/netwixmobile/main/mobile/assets/brand/netwix-wordmark.png" alt="NetWix" width="360" />
</p>

<h1 align="center">NetWix — Mobile App</h1>
<p align="center"><b>สตรีมภาพยนตร์ · ซีรีส์ · ซีรีส์แนวตั้ง · อนิเมะ</b><br/>แอป Android อย่างเป็นทางการของ <a href="https://netwix.online">netwix.online</a></p>

<p align="center">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter&logoColor=white" />
  <img alt="Android" src="https://img.shields.io/badge/Android-7.0%2B-3DDC84?logo=android&logoColor=white" />
  <img alt="backend" src="https://img.shields.io/badge/backend-netwix.online-B026FF" />
  <img alt="updates" src="https://img.shields.io/badge/updates-in--app%20OTA-FF2D55" />
</p>

---

แอปมือถือของ **NetWix** — ดึงเนื้อหาและสตรีมทั้งหมดจาก `netwix.online` (`/api/app/*`)
เล่นได้ทั้ง **MP4** และ **HLS** ทุกเรื่องดูฟรี · **Pro (129฿/เดือน) แค่ตัดโฆษณา**

## ✨ ฟีเจอร์

- **คลังเต็ม** — ภาพยนตร์ · ซีรีส์ · ซีรีส์แนวตั้ง · อนิเมะ (ซิงก์ตรงกับเว็บผ่าน home rails + หมวด)
- **เล่นทันที** — สตรีม MP4/HLS · พรีวิว EP1 อัตโนมัติแบบ Netflix · โหมดเต็มจอ
- **สมาชิก** — ล็อกอินผ่านเว็บ NetWix (Google / LINE / อีเมล) ด้วย deep link `netwix://`
- **เหรียญ & Pro** — สะสมเหรียญปลดล็อกตอน · ชวนเพื่อนรับ Pro ฟรี · Pro ตัดโฆษณา
- **อัปเดตในแอป (OTA)** — โหลดเวอร์ชันล่าสุดจาก netwix.online มาติดตั้งทับให้เอง

## 🚀 พัฒนา / รัน

ต้องมี [Flutter 3.41+](https://docs.flutter.dev/get-started/install) + Android SDK

```bash
git clone https://github.com/xjanova/netwixmobile.git
cd netwixmobile/mobile

flutter pub get
flutter run                 # debug บนอุปกรณ์ / emulator
flutter build apk --release
```

โค้ดแอปทั้งหมดอยู่ใน **`mobile/`** (Flutter) · Backend เป็น Laravel ที่ `netwix.online` (repo แยก `xjanova/netwix`)

## 📦 ออกเวอร์ชัน (release + OTA)

`mobile/pubspec.yaml` → `version:` คือ single source of truth และเป็น **semver ล้วน** (เช่น `1.0.0` — ไม่มี `+build`)

- **อัตโนมัติ:** merge PR เข้า `main` พร้อม label `release:patch|minor|major` → *Auto Version Bump* จะ bump + tag + สั่ง build
- **ด้วยมือ:** แก้ `version:` ใน pubspec แล้ว `git tag vX.Y.Z && git push origin main vX.Y.Z`

CI (`android-release.yml`) build APK ที่เซ็นด้วย keystore แล้วเผยแพร่เป็น Release —
จากนั้น **netwix.online จะ mirror ไฟล์มาเก็บที่โดเมนเราเอง** และแอปเช็ก/โหลดผ่าน
`GET /api/app/version` + `/download/apk` (ตัวแอปไม่แตะ GitHub เลย · `applicationId com.netwix.app` + signing key คงที่ตลอด)

## 🧱 Stack

`Flutter` · `Dio` · `Provider` · `video_player` · `sqflite` · `ota_update`
แบรนด์นีออน `#FF2D55 → #B026FF` · ฟอนต์ **Kanit**

## ⚖️ Disclaimer

สำหรับการรับชมส่วนตัวเท่านั้น — เนื้อหาทั้งหมดให้บริการผ่าน **netwix.online**
