# 🏅 Gold Store Management Database

> **Oracle DB · PL/SQL · RMAN** — Hệ thống cơ sở dữ liệu quản lý cửa hàng kinh doanh vàng bạc, trang sức

![Oracle](https://img.shields.io/badge/Oracle-19c-F80000?style=for-the-badge&logo=oracle&logoColor=white)
![PL/SQL](https://img.shields.io/badge/PL%2FSQL-Procedural-blue?style=for-the-badge)
![RMAN](https://img.shields.io/badge/RMAN-Backup%20%26%20Recovery-green?style=for-the-badge)
![Grade](https://img.shields.io/badge/Grade-A%2B-gold?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Completed-brightgreen?style=for-the-badge)

---

## 📌 Overview

Hệ thống cơ sở dữ liệu quản lý toàn diện cho cửa hàng kinh doanh vàng bạc trang sức, được thiết kế và triển khai trên **Oracle Database 19c**. Dự án được xây dựng dựa trên khảo sát thực tế từ **Công ty TNHH Kim Lam Hiền** và **Công ty Cổ phần PNJ**, bao gồm thiết kế schema 3 tầng (khái niệm → logic → vật lý), tự động hóa nghiệp vụ qua PL/SQL và chiến lược backup/recovery với RMAN.

| Item | Detail |
|------|--------|
| 📅 Period | 10/2025 – 12/2025 |
| 🎓 Grade | **A+** |
| 👤 Role | Team Leader |
| 🏫 School | Banking Academy of Vietnam |
| 🗄️ Tables | 15 tables |
| 🔧 PL/SQL | 4 Functions · 4 Procedures · 3 Triggers |
| 💾 Backup | RMAN Level 0 + Level 1 + Archivelog |

---

## 🗂️ Repository Structure

```
Gold-Store-Oracle-DB/
│
├── 📁 schema/
│   ├── 01_create_tables.sql          # DDL: Tạo 15 bảng (KHACH_HANG → THANH_PHAN)
│   ├── 02_tablespace.sql             # Tạo space_storage & space_change tablespace
│   └── 03_move_tables.sql            # Phân bổ bảng vào từng tablespace
│
├── 📁 users_and_roles/
│   ├── 01_create_admin.sql           # Tạo c##gold_admin (DBA)
│   ├── 02_create_roles.sql           # Tạo 3 roles: quan_ly, ban_hang, thu_kho
│   ├── 03_grant_permissions.sql      # Phân quyền chi tiết theo từng role
│   └── 04_create_users.sql           # Tạo user thực tế & gán role
│
├── 📁 plsql/
│   ├── functions/
│   │   ├── fnc_tonkho.sql                   # Tính tồn kho: nhập - bán + đổi trả
│   │   ├── fnc_avg_invoice.sql              # Giá trị TB mỗi hóa đơn của nhân viên
│   │   ├── fnc_thuong_theo_doanh_so.sql     # Tính thưởng theo doanh số (4 bậc)
│   │   └── fnc_phan_loai_kh.sql            # Phân loại KH: Standard/Silver/Gold/Diamond
│   │
│   ├── procedures/
│   │   ├── pr_lich_su_giao_dich_khach.sql   # Lịch sử giao dịch của khách hàng
│   │   ├── pr_khen_thuong_nhan_vien.sql     # Xét khen thưởng theo doanh số
│   │   ├── pr_canh_bao_ton_kho.sql          # Cảnh báo mặt hàng tồn kho thấp
│   │   └── pr_doanh_thu_moi_thang.sql       # Thống kê doanh thu theo từng tháng
│   │
│   └── triggers/
│       ├── trg_audit_hoadon.sql      # Ghi log XML mọi thay đổi trên HĐBH
│       ├── trg_audit_logon.sql       # Ghi nhật ký đăng nhập (AUDIT_SESSION_LOG)
│       └── trg_audit_logoff.sql      # Ghi nhật ký đăng xuất (AUDIT_SESSION_LOG)
│
├── 📁 queries/
│   ├── q01_doanh_so_nhan_vien.sql    # Doanh số từng NV tháng 11/2025
│   ├── q02_top5_mat_hang.sql         # Top 5 doanh thu cao nhất năm 2023
│   ├── q03_ty_le_doi_tra.sql         # Tỷ lệ đổi trả theo mặt hàng
│   ├── q04_chi_tieu_khach_hang.sql   # Tổng chi tiêu thực của khách hàng
│   ├── q05_ton_kho_thuc_te.sql       # Tồn kho thực (nhập - bán + đổi)
│   ├── q06_doanh_so_theo_thang.sql   # Doanh số từng tháng năm 2023
│   ├── q07_xu_huong_tang.sql         # Mặt hàng có xu hướng tăng liên tiếp
│   ├── q08_hang_cham_ban.sql         # Mặt hàng lâu không có giao dịch
│   ├── q09_nha_cung_cap.sql          # Số lượng nhập của từng nhà cung cấp
│   └── q10_avg_don_hang.sql          # Giá trị TB mỗi đơn hàng của khách hàng
│
├── 📁 backup/
│   ├── rman/
│   │   ├── level0.rman               # Full backup (Level 0) + archivelog
│   │   ├── level1.rman               # Incremental backup (Level 1 Differential)
│   │   └── arch_backup.rman          # Archivelog backup (mỗi 30 phút)
│   ├── batch/
│   │   ├── run_level0.bat            # Batch file chạy Level 0
│   │   ├── run_level1.bat            # Batch file chạy Level 1
│   │   └── run_arch.bat              # Batch file chạy archivelog backup
│   └── backup_plan.md                # Kế hoạch & lịch backup tự động
│
└── README.md
```

---

## 🗄️ Database Schema

### 15 Tables — Thiết kế mức vật lý

```
┌──────────────────────────────────────────────────────────────┐
│                      MASTER TABLES                           │
├──────────────┬───────────────┬──────────────┬───────────────┤
│  KHACH_HANG  │  NHAN_VIEN    │  HANG_HOA    │  LOAI_HANG    │
│  ──────────  │  ──────────   │  ──────────  │  ──────────   │
│  MaKH (PK)   │  MaNV (PK)    │  MaHang (PK) │  MaLoai (PK)  │
│  HoTen       │  TenNhanVien  │  TenHang     │  TenLoai      │
│  SoDienThoai │  SoDienThoai  │  MauMa       │               │
│  DiaChi      │  DiaChi       │  TuoiVang    │               │
│              │  Luong        │  MaLoai (FK) │               │
└──────────────┴───────────────┴──────────────┴───────────────┘

┌────────────────────┬───────────────────────────────────────────────┐
│  NHA_CUNG_CAP      │  XUONG_GIA_CONG      │  THANH_PHAN (weak)    │
│  MaNCC (PK)        │  MaXuongGC (PK)      │  MaHang (PK, FK)      │
│  TenNCC            │  TenXuongGC          │  ThanhPhan (PK)       │
│  DiaChi            │  DiaChi              │  DonViTinh            │
│  SoDienThoai       │  SoDienThoai         │  TrongLuong           │
└────────────────────┴──────────────────────┴───────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                     TRANSACTION TABLES                            │
├──────────────────────┬───────────────────────────────────────────┤
│  HOA_DON_BAN_HANG    │  HOA_DON_DOI_TRA                         │
│  MaHDBH (PK)         │  MaHDDT (PK)                             │
│  NgayBan             │  NgayDoiTra                              │
│  HinhThucThanhToan   │  HinhThucThanhToan                       │
│  MaKH (FK), MaNV(FK) │  MaKH (FK), MaNV (FK)                   │
├──────────────────────┼───────────────────────────────────────────┤
│  HOA_DON_GIA_CONG    │  HOA_DON_NHAP_HANG                       │
│  MaHDGC (PK)         │  MaHDNH (PK)                             │
│  NgayDat             │  NgayDatHang                             │
│  NgayNhanDuKien      │  NgayNhapDuKien                          │
│  MaXuongGC (FK)      │  MaNCC (FK)                              │
└──────────────────────┴───────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                       DETAIL TABLES                               │
├──────────────────┬──────────────────┬─────────────────────────── ┤
│  CHI_TIET_BAN    │  CHI_TIET_DOI    │  CHI_TIET_GIA_CONG        │
│  MaCTBH (PK)     │  MaCTDT (PK)     │  MaCTGC (PK)              │
│  MaHDBH (FK,PK)  │  MaHDDT (FK,PK)  │  MaHDGC (FK,PK)           │
│  MaHang (FK)     │  MaHang (FK)     │  MaHang (FK)              │
│  SoLuong, DonGia │  SoLuong, DonGia │  SoLuong, TienCong        │
│                  │  HaoMon          │                           │
├──────────────────┴──────────────────┴────────────────────────────┤
│  CHI_TIET_NHAP_HANG                                               │
│  MaNhap (PK), MaHDNH (FK,PK), MaHang (FK), SoLuong, DonGia      │
└──────────────────────────────────────────────────────────────────┘
```

### Tablespace Strategy

| Tablespace | Dung lượng | Bảng chứa |
|------------|------------|-----------|
| `space_storage` | 100MB → max 500MB | HANG_HOA, LOAI_HANG, NHA_CUNG_CAP, KHACH_HANG, XUONG_GIA_CONG, NHAN_VIEN |
| `space_change` | 500MB → max 4GB | HOA_DON_BAN_HANG, HOA_DON_DOI_TRA, HOA_DON_GIA_CONG, HOA_DON_NHAP_HANG, CHI_TIET_* |

---

## 🔐 User & Role Management

```
c##gold_admin  (DBA — Chủ cửa hàng: toàn quyền)
     │
     ├── c##role_quan_ly  →  SELECT/INSERT/UPDATE/DELETE toàn bộ bảng
     │        └── c##quanly_an
     │
     ├── c##role_ban_hang →  SELECT hàng hóa · INSERT/SELECT hóa đơn bán & đổi
     │        └── c##nv_binh         (KHÔNG thấy giá vốn / nhập hàng)
     │
     └── c##role_thu_kho  →  Quản lý nhập hàng, gia công, NCC, tồn kho
              └── c##kho_cuong
```

> 💡 **Bảo mật đặc thù:** Nhân viên bán hàng không được truy cập bảng nhập hàng → bảo vệ thông tin lợi nhuận thực tế.

---

## ⚙️ PL/SQL Components

### Functions

| Function | Mô tả | Logic |
|----------|-------|-------|
| `fnc_tonkho(MaHang)` | Tính tồn kho của mặt hàng | `Σ nhập − Σ bán + Σ đổi trả` |
| `fnc_avg_invoice(MaNV)` | Giá trị TB mỗi hóa đơn của NV | `AVG(SUM DonGia × SoLuong per HDBH)` |
| `fnc_thuong_theo_doanh_so(year, month, MaNV)` | Tính mức thưởng | `< 100M: 0%` · `< 300M: 1%` · `< 500M: 2%` · `≥ 500M: 3%` |
| `fnc_phan_loai_kh(MaKH, year)` | Phân hạng khách hàng | `< 100M: Standard` · `< 300M: Silver` · `< 500M: Gold` · `≥ 500M: Diamond` |

### Stored Procedures

| Procedure | Mô tả |
|-----------|-------|
| `pr_lich_su_giao_dich_khach(MaKH)` | Liệt kê toàn bộ giao dịch mua & đổi/trả của KH, sắp xếp theo ngày |
| `pr_khen_thuong_nhan_vien_theo_doanh_so(target)` | Danh sách NV đạt/vượt ngưỡng doanh số Q1/2025 |
| `pr_canh_bao_ton_kho(muc_canh_bao)` | Liệt kê mặt hàng có tồn kho < ngưỡng (dùng `fnc_tonkho`) |
| `pr_doanh_thu_moi_thang(year)` | Thống kê doanh thu GROUP BY tháng trong năm chỉ định |

### Triggers

| Trigger | Sự kiện | Mục đích |
|---------|---------|----------|
| `TRG_AUDIT_HOADON` | AFTER INSERT/UPDATE/DELETE on HOA_DON_BAN_HANG | Ghi log XML old/new data vào bảng audit |
| `trg_audit_logon` | AFTER LOGON ON DATABASE | Ghi nhận session_id, username, IP, host vào `AUDIT_SESSION_LOG` |
| `trg_audit_logoff` | BEFORE LOGOFF ON DATABASE | Ghi nhật ký kết thúc phiên làm việc |

---

## 📊 SQL Queries — 10 Business Reports

| # | Tên | Mục đích nghiệp vụ |
|---|-----|-------------------|
| 1 | Doanh số NV tháng 11/2025 | Đánh giá hiệu quả lao động, xét thưởng |
| 2 | Top 5 mặt hàng doanh thu cao nhất 2023 | Nhận diện sản phẩm chủ lực |
| 3 | Tỷ lệ đổi trả theo mặt hàng | Đánh giá chất lượng, phân tích nhà cung cấp |
| 4 | Tổng chi tiêu thực của KH | Xây dựng chương trình thành viên (sau trừ đổi trả) |
| 5 | Tồn kho thực tế từng mặt hàng | Kiểm kê định kỳ, lập kế hoạch nhập hàng |
| 6 | Doanh số theo tháng năm 2023 | Nhận diện mùa vụ, ngày Thần Tài |
| 7 | Mặt hàng xu hướng mua tăng | Tối ưu danh mục, chiến lược marketing |
| 8 | Mặt hàng lâu không bán | Xử lý hàng tồn kho chậm luân chuyển |
| 9 | Số lượng nhập theo NCC | Đánh giá năng lực cung ứng |
| 10 | Giá trị TB đơn hàng của KH | Phân tích hành vi tiêu dùng, phân khúc KH |

---

## 💾 Backup Strategy (RMAN + Task Scheduler)

```
Lịch sao lưu tự động (Windows Task Scheduler)
┌──────────────────┬──────────────────────────────────┬──────────────┐
│ Type             │ Schedule                         │ Batch file   │
├──────────────────┼──────────────────────────────────┼──────────────┤
│ Level 0 (Full)   │ Thứ 4 & Chủ Nhật — 22:00        │ run_level0   │
│ Level 1 (Incr.)  │ Mỗi ngày còn lại — 22:00        │ run_level1   │
│ Archivelog       │ Mỗi 30 phút                      │ run_arch     │
└──────────────────┴──────────────────────────────────┴──────────────┘

Cấu trúc thư mục:
D:\oracle_backup\
  ├── level0\   ← Full backup (~350 KB/file)
  ├── level1\   ← Incremental (~2 KB/file)
  ├── arch\     ← Archivelog (~4-5 KB mỗi 30 phút)
  └── logs\     ← RMAN execution logs
```

Recovery path: `Level 0 → Apply Level 1 → Apply Archivelog → Point-in-Time Recovery`

---

## 🚀 Getting Started

### Prerequisites
- Oracle Database 19c
- SQL*Plus hoặc Oracle SQL Developer
- Windows OS (Task Scheduler cho auto backup)

### Setup

```sql
-- 1. Tạo tablespace
@schema/02_tablespace.sql

-- 2. Tạo 15 bảng
@schema/01_create_tables.sql

-- 3. Phân bổ bảng vào tablespace
@schema/03_move_tables.sql

-- 4. Tạo users và roles
@users_and_roles/01_create_admin.sql
@users_and_roles/02_create_roles.sql
@users_and_roles/03_grant_permissions.sql
@users_and_roles/04_create_users.sql

-- 5. Deploy PL/SQL functions
@plsql/functions/fnc_tonkho.sql
@plsql/functions/fnc_avg_invoice.sql
@plsql/functions/fnc_thuong_theo_doanh_so.sql
@plsql/functions/fnc_phan_loai_kh.sql

-- 6. Deploy procedures & triggers
@plsql/procedures/pr_lich_su_giao_dich_khach.sql
@plsql/procedures/pr_khen_thuong_nhan_vien.sql
@plsql/procedures/pr_canh_bao_ton_kho.sql
@plsql/procedures/pr_doanh_thu_moi_thang.sql
@plsql/triggers/trg_audit_hoadon.sql
@plsql/triggers/trg_audit_logon.sql
@plsql/triggers/trg_audit_logoff.sql
```

### Quick Test

```sql
-- Tồn kho mặt hàng
SELECT fnc_tonkho('MaHang001') AS TonKho FROM dual;

-- Phân loại khách hàng
SELECT fnc_phan_loai_kh('KH001', 2023) AS HangKH FROM dual;

-- Lịch sử giao dịch
EXEC pr_lich_su_giao_dich_khach('KH001');

-- Cảnh báo tồn kho dưới 5 sản phẩm
EXEC pr_canh_bao_ton_kho(5);

-- Doanh thu theo tháng năm 2023
EXEC pr_doanh_thu_moi_thang(2023);
```

---

## 🛠️ Tech Stack

| Category | Technology |
|----------|------------|
| Database | Oracle Database 19c |
| Language | SQL · PL/SQL |
| Backup & Recovery | RMAN (Recovery Manager) |
| Automation | Windows Task Scheduler · `.bat` scripts |
| DB Design | ERD · 3NF Normalization · 3-tier schema |
| Tools | Oracle SQL Developer · SQL*Plus · DBCA |

---

**Giảng viên hướng dẫn:** ThS. Nguyễn Thị Thu Trang  
**Học viện Ngân hàng — Khoa Công nghệ Thông tin & Kinh tế Số**

---

## 👤 Author

**Lê Chí Anh Tú** — MIS Student @ Banking Academy of Vietnam  
🎓 Expected Graduation: 2027 &nbsp;|&nbsp; 📊 GPA: 3.7/4.0  
🔗 [GitHub](https://github.com/lcatu)

---

<p align="center"><i>Part of my Data Analytics Portfolio — <a href="https://github.com/lcatu">view all projects</a></i></p>
