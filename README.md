<p align="center">
  <img src="https://raw.githubusercontent.com/xjanova/hivedownload/main/logo.png" alt="Hive Download" width="150" />
</p>

<h1 align="center">Hive Download</h1>
<p align="center"><b>Smart Media Downloader</b></p>
<p align="center">โปรแกรมเดสก์ท็อปสำหรับ <b>เรียกดู · ดาวน์โหลด · สตรีม · จัดระเบียบ · เปิดดู</b> ซีรี่ส์/หนังสั้นจีนจาก <a href="https://rongyok.com">rongyok.com (โรงหยก)</a></p>

<p align="center">
  <img alt=".NET 9" src="https://img.shields.io/badge/.NET-9.0-512BD4?logo=dotnet&logoColor=white" />
  <img alt="WPF" src="https://img.shields.io/badge/WPF-Windows%2010%2F11-0078D6?logo=windows&logoColor=white" />
  <img alt="SQLite" src="https://img.shields.io/badge/SQLite-Dapper-003B57?logo=sqlite&logoColor=white" />
  <img alt="MVVM" src="https://img.shields.io/badge/MVVM-CommunityToolkit-6E56CF" />
  <img alt="license" src="https://img.shields.io/badge/use-personal%20%2F%20educational-lightgrey" />
</p>

---

> ⚠️ **สำหรับการเรียนรู้และรับชมส่วนตัว (offline) เท่านั้น** — ผู้ใช้มีหน้าที่ปฏิบัติตามกฎหมายลิขสิทธิ์และเงื่อนไขการให้บริการของเว็บไซต์ต้นทาง โปรดเคารพผู้สร้างผลงาน
>
> *For personal / educational use only. Respect copyright and the source site's Terms of Service.*

<br/>

## ✨ ฟีเจอร์

- **🗂️ คลังซีรี่ส์** — ดึงรายการทั้งหมด (~2,300+ เรื่อง) มาแสดงเป็นตารางปก ค้นหา · กรอง (พากย์ไทย/ซับไทย) · จัดเรียง (ล่าสุด/ยอดนิยม/ชื่อเรื่อง)
- **🔍 สแกนหาของใหม่** — ปุ่มเดียวเทียบกับฐานข้อมูล แจ้ง **ซีรี่ส์ใหม่** + **ตอนใหม่** (เรื่องที่เคยโหลด) กดโหลดได้ทันที
- **⬇️ ดาวน์โหลดหลายไฟล์พร้อมกัน** — เลือกทีละตอน / เฉพาะที่ยังไม่มี / ทั้งเรื่อง · ปรับจำนวนพร้อมกัน 1–8 · แถบความคืบหน้า/ความเร็ว · **หยุด–เล่นต่อ (resume)** · ลองใหม่เมื่อพลาด
- **📁 จัดระเบียบอัตโนมัติ** — แยกโฟลเดอร์ตามเรื่อง `ชื่อเรื่อง (พากย์ไทย)/ชื่อ - EP01.mp4` พร้อม `poster.jpg` และ **สารบัญ `index.html`**
- **🎬 เครื่องเล่นในตัว**
  - เล่นต่อเนื่องตามลำดับตอนเป๊ะ ๆ (รอโหลดตอนถัดไปให้ถ้าจำเป็น)
  - **โหมดสตรีม** — ดูได้เลยไม่ต้องเก็บไฟล์ · **โหมดโหลดล่วงหน้า (prefetch)**
  - แตะตอนที่ยังไม่มี = โหลดทันที · ดับเบิลคลิก = สตรีมทันที
  - คอนโทรล **auto-hide** ขณะดู
- **🖼️ พื้นหลังพรีวิวแบบ Netflix** — หน้ารายละเอียดเล่น EP.1 (โหลดไว้ก่อน) วนลูป มีเสียง วิดีโอตั้งคมชัดกลางจอ + พื้นหลังเบลอสลัว ขอบเฟดเนียน
- **🎨 ธีม RGB นีออน** — ไฟสีรุ้งไล่หมุนวนบนพื้นดำ, toggle switch, สกรอลบาร์บางทันสมัย
- **💾 SQLite** — จำรายการ · สถานะการโหลด · การตั้งค่า

<br/>

## 🚀 เริ่มใช้งาน

**สิ่งที่ต้องมี:** Windows 10/11 · [.NET 9 SDK](https://dotnet.microsoft.com/download/dotnet/9.0) · Visual Studio 2022 (17.12+) / 2026 หรือ VS Code / Rider

```bash
git clone https://github.com/xjanova/hivedownload.git
cd hivedownload

# build & run
dotnet run --project src/RongYokDownloader
```

หรือดับเบิลคลิก `RongYokDownloader.sln` แล้วกด **F5** ใน Visual Studio

> ครั้งแรกที่เปิด แท็บ **คลังซีรี่ส์** จะดึงรายการจากเว็บอัตโนมัติ

<br/>

## 🧩 โครงสร้างโปรเจกต์ (MVVM)

```
src/RongYokDownloader/
├─ Models/        Series, Episode, ScanResult, enums
├─ Data/          Db.cs            → SQLite (Dapper): schema + CRUD
├─ Services/
│   ├─ RongYokClient.cs   → ตัวคุยกับเว็บ (3 endpoint)
│   ├─ JsonExtract.cs     → ดึง JSON ที่ฝังในหน้าเว็บ
│   ├─ DownloadManager.cs → คิว + ดาวน์โหลดพร้อมกัน + resume
│   ├─ FileNamer.cs · TocGenerator.cs · SettingsStore.cs
├─ ViewModels/    Catalog / SeriesDetail / Downloads / Library / Player / Settings / Main / WhatsNew
├─ Views/         ไฟล์ .xaml + code-behind ของแต่ละหน้า
├─ Converters/    UrlToImage · ImageLoader · สถานะ ฯลฯ
└─ Themes/        Theme.xaml — ธีม RGB นีออน + toggle/scrollbar
```

**ที่เก็บข้อมูล:** `%LocalAppData%\RongYokDownloader\rongyok.db`
**ที่เก็บวิดีโอ (เริ่มต้น):** `%UserProfile%\Videos\RongYok` (เปลี่ยนได้ในหน้าตั้งค่า)

<br/>

## 🔌 เว็บทำงานอย่างไร

| จุดประสงค์ | Endpoint | ผลลัพธ์ |
|---|---|---|
| รายการทั้งหมด | `GET /category?category=all` | JS ฝัง `seriesData = [...]` (id, title, description, poster) |
| รายชื่อตอน | `GET /watch/?series_id={id}` | `episodes_count` + `episodes[]` |
| ลิงก์วิดีโอ | `GET /watch/get_video.php?series_id={id}&ep={n}` | `{"ok":true,"video_url":"…mp4…"}` |

ไฟล์วิดีโอเป็น **MP4** โฮสต์บน CDN (ลิงก์เซ็นชื่อ หมดอายุ ~24 ชม. โปรแกรมจึงขอลิงก์ใหม่ทุกครั้งที่เริ่มโหลด) — ไม่มีแคปช่า ไม่มี DRM

<br/>

## 🎞️ หมายเหตุเรื่องการเล่นไฟล์

เครื่องเล่นในตัวใช้ WPF `MediaElement` ซึ่งพึ่งตัวถอดรหัสของ Windows:
- **H.264/AAC** เล่นได้ทันที
- **HEVC/H.265** อาจต้องติดตั้ง *HEVC Video Extensions* จาก Microsoft Store
- ต้องการรองรับทุกโคเดก + สตรีมลื่นทุกไฟล์ → เปลี่ยนไปใช้ **LibVLCSharp.WPF** ได้

<br/>

## 🛠️ Tech Stack

`.NET 9` · `WPF` · `CommunityToolkit.Mvvm` · `Microsoft.Data.Sqlite` + `Dapper` · `HttpClient`

<br/>

## ⚖️ Disclaimer

โปรแกรมนี้จัดทำเพื่อการศึกษาและการรับชมส่วนตัว (offline) เท่านั้น ผู้พัฒนาไม่ได้มีส่วนเกี่ยวข้องกับ rongyok.com และไม่รับผิดชอบต่อการนำไปใช้ผิดวัตถุประสงค์ ผู้ใช้ต้องรับผิดชอบการปฏิบัติตามกฎหมายลิขสิทธิ์และเงื่อนไขการให้บริการของเว็บไซต์ต้นทางด้วยตนเอง

*This project is for educational and personal (offline) use only. It is not affiliated with rongyok.com. Users are solely responsible for complying with copyright law and the source site's Terms of Service.*
