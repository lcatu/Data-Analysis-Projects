-- 1. BẢNG KHACH_HANG
-- ===============================
CREATE TABLE KHACH_HANG (
    MaKH VARCHAR2(10) PRIMARY KEY,
    HoTen NVARCHAR2(100) NOT NULL,
    SoDienThoai VARCHAR2(15) UNIQUE NOT NULL,
    DiaChi NVARCHAR2(255)
);

-- ===============================
-- 2. BẢNG NHAN_VIEN
-- ===============================
CREATE TABLE NHAN_VIEN (
    MaNV VARCHAR2(10) PRIMARY KEY,
    TenNhanVien NVARCHAR2(100) NOT NULL,
    SoDienThoai VARCHAR2(15) UNIQUE NOT NULL,
    DiaChi NVARCHAR2(255), 
    Luong NUMBER(12, 2)
);

-- ===============================
-- 3. BẢNG LOAI_HANG
-- ===============================
CREATE TABLE LOAI_HANG (
    MaLoai VARCHAR2(10) PRIMARY KEY,
    TenLoai NVARCHAR2(100) NOT NULL
);

-- ===============================
-- 4. BẢNG HANG_HOA
-- ===============================
CREATE TABLE HANG_HOA (
    MaHang VARCHAR2(10) PRIMARY KEY,
    TenHang NVARCHAR2(100) NOT NULL,
    MauMa NVARCHAR2(50),
    TuoiVang NVARCHAR2(50),
    MaLoai VARCHAR2(10) NOT NULL,
    CONSTRAINT fk_hanghoa_loaihang FOREIGN KEY (MaLoai)
        REFERENCES LOAI_HANG(MaLoai)
);

-- ===============================
-- 5. BẢNG THANH_PHAN
-- ===============================
CREATE TABLE THANH_PHAN (
    MaHang VARCHAR2(10),
    ThanhPhan NVARCHAR2(100),
    DonViTinh NVARCHAR2(50),
    TrongLuong NVARCHAR2(50),
    PRIMARY KEY (MaHang, ThanhPhan),
    CONSTRAINT fk_tp_hang FOREIGN KEY (MaHang)
        REFERENCES HANG_HOA(MaHang)
);

-- ===============================
-- 6. BẢNG NHA_CUNG_CAP
-- ===============================
CREATE TABLE NHA_CUNG_CAP (
    MaNCC VARCHAR2(10) PRIMARY KEY,
    TenNCC NVARCHAR2(100) NOT NULL,
    DiaChi NVARCHAR2(255),
    SoDienThoai VARCHAR2(15)
);

-- ===============================
-- 7. BẢNG XUONG_GIA_CONG
-- ===============================
CREATE TABLE XUONG_GIA_CONG (
    MaXuongGC VARCHAR2(10) PRIMARY KEY,
    TenXuongGC NVARCHAR2(100) NOT NULL,
    DiaChi NVARCHAR2(255),
    SoDienThoai VARCHAR2(15)
);

-- ===============================
-- 8. BẢNG HOA_DON_NHAP_HANG
-- ===============================
CREATE TABLE HOA_DON_NHAP_HANG (
    MaHDNH VARCHAR2(10) PRIMARY KEY,
    NgayDatHang DATE NOT NULL,
    NgayNhapDuKien DATE,
    MaNCC VARCHAR2(10) NOT NULL,
    CONSTRAINT fk_hdnh_ncc FOREIGN KEY (MaNCC)
        REFERENCES NHA_CUNG_CAP(MaNCC),
    CONSTRAINT ck_hdnh_ngay CHECK (NgayNhapDuKien IS NULL OR NgayNhapDuKien >= NgayDatHang)
);

-- ===============================
-- 9. BẢNG CHI_TIET_NHAP_HANG
-- ===============================
CREATE TABLE CHI_TIET_NHAP_HANG (
    MaNhap VARCHAR2(10),
    MaHDNH VARCHAR2(10),
    MaHang VARCHAR2(10) NOT NULL,
    SoLuong INT CHECK (SoLuong > 0),
    DonGia NUMBER(18,2) CHECK (DonGia >= 0),
    PRIMARY KEY (MaNhap, MaHDNH),
    CONSTRAINT fk_ctnh_hdnh FOREIGN KEY (MaHDNH)
        REFERENCES HOA_DON_NHAP_HANG(MaHDNH),
    CONSTRAINT fk_ctnh_hang FOREIGN KEY (MaHang)
        REFERENCES HANG_HOA(MaHang)
);

-- ===============================
-- 10. BẢNG HOA_DON_BAN_HANG
-- ===============================
CREATE TABLE HOA_DON_BAN_HANG (
    MaHDBH VARCHAR2(10) PRIMARY KEY,
    NgayBan DATE NOT NULL,
    HinhThucThanhToan NVARCHAR2(50) NOT NULL,
    MaKH VARCHAR2(10) NOT NULL,
    MaNV VARCHAR2(10) NOT NULL,
    CONSTRAINT fk_hdbh_kh FOREIGN KEY (MaKH)
        REFERENCES KHACH_HANG(MaKH),
    CONSTRAINT fk_hdbh_nv FOREIGN KEY (MaNV)
        REFERENCES NHAN_VIEN(MaNV)
);

-- ===============================
-- 11. BẢNG CHI_TIET_BAN_HANG
-- ===============================
CREATE TABLE CHI_TIET_BAN_HANG (
    MaCTBH VARCHAR2(10),
    MaHDBH VARCHAR2(10),
    MaHang VARCHAR2(10) NOT NULL,
    SoLuong INT CHECK (SoLuong > 0),
    DonGia NUMBER(18,2) CHECK (DonGia >= 0),
    PRIMARY KEY (MaCTBH, MaHDBH),
    CONSTRAINT fk_ctbh_hdbh FOREIGN KEY (MaHDBH)
        REFERENCES HOA_DON_BAN_HANG(MaHDBH),
    CONSTRAINT fk_ctbh_hang FOREIGN KEY (MaHang)
        REFERENCES HANG_HOA(MaHang)
);

-- ===============================
-- 12. BẢNG HOA_DON_DOI_TRA
-- ===============================
CREATE TABLE HOA_DON_DOI_TRA (
    MaHDDT VARCHAR2(10) PRIMARY KEY,
    NgayDoiTra DATE NOT NULL,
    HinhThucThanhToan NVARCHAR2(50) NOT NULL,
    MaKH VARCHAR2(10) NOT NULL,
    MaNV VARCHAR2(10) NOT NULL,
    CONSTRAINT fk_hddt_kh FOREIGN KEY (MaKH)
        REFERENCES KHACH_HANG(MaKH),
    CONSTRAINT fk_hddt_nv FOREIGN KEY (MaNV)
        REFERENCES NHAN_VIEN(MaNV)
);

-- ===============================
-- 13. BẢNG CHI_TIET_DOI_TRA
-- ===============================
CREATE TABLE CHI_TIET_DOI_TRA (
    MaCTDT VARCHAR2(10),
    MaHDDT VARCHAR2(10),
    MaHang VARCHAR2(10) NOT NULL,
    SoLuong INT CHECK (SoLuong > 0),
    DonGia NUMBER(18,2) CHECK (DonGia >= 0),
    HaoMon NUMBER(5,4),
    PRIMARY KEY (MaCTDT, MaHDDT),
    CONSTRAINT fk_ctdt_hddt FOREIGN KEY (MaHDDT)
        REFERENCES HOA_DON_DOI_TRA(MaHDDT),
    CONSTRAINT fk_ctdt_hang FOREIGN KEY (MaHang)
        REFERENCES HANG_HOA(MaHang)
);

-- ===============================
-- 14. BẢNG HOA_DON_GIA_CONG
-- ===============================
CREATE TABLE HOA_DON_GIA_CONG (
    MaHDGC VARCHAR2(10) PRIMARY KEY,
    NgayDat DATE NOT NULL,
    NgayNhanDuKien DATE,
    MaXuongGC VARCHAR2(10) NOT NULL,
    CONSTRAINT fk_hdgc_xuong FOREIGN KEY (MaXuongGC)
        REFERENCES XUONG_GIA_CONG(MaXuongGC),
    CONSTRAINT ck_hdgc_ngay CHECK (NgayNhanDuKien IS NULL OR NgayNhanDuKien >= NgayDat)
);

-- ===============================
-- 15. BẢNG CHI_TIET_GIA_CONG
-- ===============================
CREATE TABLE CHI_TIET_GIA_CONG (
    MaCTGC VARCHAR2(10),
    MaHDGC VARCHAR2(10),
    MaHang VARCHAR2(10) NOT NULL,
    SoLuong INT CHECK (SoLuong > 0),
    TienCong NUMBER(18,2) CHECK (TienCong >= 0),
    PRIMARY KEY (MaCTGC, MaHDGC),
    CONSTRAINT fk_ctgc_hdgc FOREIGN KEY (MaHDGC)
        REFERENCES HOA_DON_GIA_CONG(MaHDGC),
    CONSTRAINT fk_ctgc_hang FOREIGN KEY (MaHang)
        REFERENCES HANG_HOA(MaHang)
);
-------------------------------------------------------------------------------------------
--Tạo tablespace
create tablespace space_storage  datafile 'C:\Users\Lenovo\oradata\ORCLQLV\tablespace\tablespace_storagedbf' SIZE
100M  autoextend on next 100M maxsize 500M  extent management local;

create tablespace space_change  datafile 'C:\Users\Lenovo\oradata\ORCLQLV\tablespace\tablespace_changedbf' SIZE
500M  autoextend on next 500M maxsize 4096M  extent management local;


alter table HANG_HOA move tablespace space_storage;
alter table LOAI_HANG move tablespace space_storage;
alter table NHA_CUNG_CAP move tablespace space_storage;
alter table KHACH_HANG move tablespace space_storage;
alter table XUONG_GIA_CONG move tablespace space_storage;
alter table NHAN_VIEN move tablespace space_storage;
alter table HOA_DON_BAN_HANG move tablespace space_change;
alter table CHI_TIET_BAN_HANG move tablespace space_change;
alter table HOA_DON_NHAP_HANG move tablespace space_change;
alter table CHI_TIET_NHAP_HANG move tablespace space_change;
alter table HOA_DON_DOI_TRA move tablespace space_change;
alter table CHI_TIET_DOI_TRA move tablespace space_change;
alter table HOA_DON_GIA_CONG move tablespace space_change;
alter table CHI_TIET_GIA_CONG move tablespace space_change;

---------------------------------------------------------------------
--Tạo và phân quyền
CREATE USER admin_gold IDENTIFIED BY AdminPass123;
GRANT CONNECT, RESOURCE, DBA TO admin_gold;
CREATE ROLE role_quan_ly;
CREATE ROLE role_ban_hang;
CREATE ROLE role_thu_kho;
--A. Phân Quyền cho quản lý
-- Quản lý nhân sự và khách hàng
GRANT SELECT, INSERT, UPDATE, DELETE ON NHAN_VIEN TO role_quan_ly;
GRANT SELECT, INSERT, UPDATE, DELETE ON KHACH_HANG TO role_quan_ly;

-- Quản lý hàng hóa
GRANT SELECT, INSERT, UPDATE, DELETE ON HANG_HOA TO role_quan_ly;
GRANT SELECT, INSERT, UPDATE, DELETE ON LOAI_HANG TO role_quan_ly;

-- Quản lý hóa đơn bán hàng & đổi trả
GRANT SELECT, INSERT, UPDATE, DELETE ON HOA_DON_BAN_HANG TO role_quan_ly;
GRANT SELECT, INSERT, UPDATE, DELETE ON CHI_TIET_BAN_HANG TO role_quan_ly;
GRANT SELECT, INSERT, UPDATE, DELETE ON HOA_DON_DOI_TRA TO role_quan_ly;
GRANT SELECT, INSERT, UPDATE, DELETE ON CHI_TIET_DOI_TRA TO role_quan_ly;

-- Quản lý nhập hàng (Biết giá vốn) & Gia công
GRANT SELECT, INSERT, UPDATE, DELETE ON HOA_DON_NHAP_HANG TO role_quan_ly;
GRANT SELECT, INSERT, UPDATE, DELETE ON CHI_TIET_NHAP_HANG TO role_quan_ly;
GRANT SELECT, INSERT, UPDATE, DELETE ON HOA_DON_GIA_CONG TO role_quan_ly;
GRANT SELECT, INSERT, UPDATE, DELETE ON CHI_TIET_GIA_CONG TO role_quan_ly;
GRANT SELECT, INSERT, UPDATE, DELETE ON NHA_CUNG_CAP TO role_quan_ly;
GRANT SELECT, INSERT, UPDATE, DELETE ON XUONG_GIA_CONG TO role_quan_ly;


--B Phân quyền cho bán hàng
-- 1. Chỉ được XEM hàng hóa (để tư vấn)
GRANT SELECT ON HANG_HOA TO role_ban_hang;
GRANT SELECT ON LOAI_HANG TO role_ban_hang;

-- 2. Được thêm mới/sửa Khách hàng
GRANT SELECT, INSERT, UPDATE ON KHACH_HANG TO role_ban_hang;

-- 3. Được Tạo hóa đơn Bán & Đổi trả (Không được xóa/sửa hóa đơn cũ)
GRANT SELECT, INSERT ON HOA_DON_BAN_HANG TO role_ban_hang;
GRANT SELECT, INSERT ON CHI_TIET_BAN_HANG TO role_ban_hang;
GRANT SELECT, INSERT ON HOA_DON_DOI_TRA TO role_ban_hang;
GRANT SELECT, INSERT ON CHI_TIET_DOI_TRA TO role_ban_hang;

-- 4. Xem danh sách đồng nghiệp
GRANT SELECT ON NHAN_VIEN TO role_ban_hang;

--C Phân quyền cho thủ kho
-- 1. Full quyền với Nhập hàng & Gia công
GRANT SELECT, INSERT, UPDATE, DELETE ON HOA_DON_NHAP_HANG TO role_thu_kho;
GRANT SELECT, INSERT, UPDATE, DELETE ON CHI_TIET_NHAP_HANG TO role_thu_kho;
GRANT SELECT, INSERT, UPDATE, DELETE ON HOA_DON_GIA_CONG TO role_thu_kho;
GRANT SELECT, INSERT, UPDATE, DELETE ON CHI_TIET_GIA_CONG TO role_thu_kho;

-- 2. Quản lý đối tác
GRANT SELECT, INSERT, UPDATE, DELETE ON NHA_CUNG_CAP TO role_thu_kho;
GRANT SELECT, INSERT, UPDATE, DELETE ON XUONG_GIA_CONG TO role_thu_kho;

-- 3. Cập nhật số lượng tồn kho Hàng hóa
GRANT SELECT, INSERT, UPDATE ON HANG_HOA TO role_thu_kho;
GRANT SELECT, INSERT, UPDATE ON LOAI_HANG TO role_thu_kho;


-- TẠO USER CỤ THỂ VÀ GÁN QUYỀN
-- 1. Tạo user Quản lý: Nguyễn Văn An
CREATE USER quanly_anhduc IDENTIFIED BY AnhDucManager123;
GRANT CONNECT TO quanly_anhduc;
GRANT role_quan_ly TO quanly_anhduc;

-- 2. Tạo user Bán hàng: Trần Thị Bình
CREATE USER nv_binhgold IDENTIFIED BY BinhGoldSales456;
GRANT CONNECT TO nv_binhgold;
GRANT role_ban_hang TO nv_binhgold;

-- 3. Tạo user Thủ kho: Lê Văn Cường
CREATE USER kho_cuongthan IDENTIFIED BY CuongThanKho789;
GRANT CONNECT TO kho_cuongthan;
GRANT role_thu_kho TO kho_cuongthan;











------------------------------------------------------------
--10 câu SQL
--1: Hiển thị doanh số của mỗi nhân viên trong tháng 11/2025

SELECT
	nv.MANV
	, nv.TENNHANVIEN 
	, nvl(sum(ctbh.DONGIA * ctbh.SOLUONG), 0) AS DOANHSO
FROM NHAN_VIEN nv 
			LEFT JOIN HOA_DON_BAN_HANG hdbh ON nv.MANV = hdbh.MANV 
                    AND ngayban >= DATE '2025-11-01' 
                    AND ngayban < DATE '2025-12-01' 
			LEFT JOIN CHI_TIET_BAN_HANG ctbh ON ctbh.MAHDBH = hdbh.MAHDBH
GROUP BY nv.MANV, nv.TENNHANVIEN 
ORDER BY DOANHSO desc;




--2: Thống kê top 5 mặt hàng có doanh thu cao nhất trong năm 2023

SELECT 
	hh.MAHANG 
	, hh.TENHANG 
	, sum(ctbh.DONGIA * ctbh.SOLUONG) AS DOANHTHU
FROM HANG_HOA hh 
		JOIN CHI_TIET_BAN_HANG ctbh ON hh.MAHANG = ctbh.MAHANG 
		JOIN HOA_DON_BAN_HANG hdbh ON hdbh.MAHDBH = ctbh.MAHDBH 
				AND hdbh.NGAYBAN >= DATE '2023-01-01'
				AND hdbh.NGAYBAN <  DATE '2024-01-01'
GROUP BY hh.MAHANG, hh.TENHANG 
ORDER BY DOANHTHU DESC 
FETCH FIRST 5 ROWS ONLY;


--3: Thống kê tỷ lệ bị đổi trả theo từng mặt hàng
--Những sản phẩm chưa bán thì không nên đưa vào thống kê tỷ lệ đổi trả.

WITH tb_sl_ban AS (
	SELECT 
		ctbh.MaHang,
		SUM(ctbh.SoLuong) AS sl_ban
	FROM CHI_TIET_BAN_HANG ctbh
	GROUP BY ctbh.MaHang
),
tb_sl_doi AS (
	SELECT 
		ctdt.MaHang,
		SUM(ctdt.SoLuong) AS sl_doi
	FROM CHI_TIET_DOI_TRA ctdt
	GROUP BY ctdt.MaHang
)
SELECT
	hh.MaHang,
	hh.TenHang,
	NVL(d.sl_doi, 0) / b.sl_ban AS pct_doi_tra
FROM HANG_HOA hh
	JOIN tb_sl_ban b ON b.MaHang = hh.MaHang
	LEFT JOIN tb_sl_doi d ON d.MaHang = hh.MaHang
ORDER BY pct_doi_tra DESC;




--4: Tính tổng mức chi tiêu thực của mỗi khách hàng
WITH tb_mua AS (
SELECT 
	MaKH
	, SUM(ctbh.SoLuong * ctbh.DonGia) AS TongMua
FROM HOA_DON_BAN_HANG hdbh JOIN CHI_TIET_BAN_HANG ctbh 
        ON HDBH.MaHDBH = ctbh.MaHDBH
GROUP BY MaKH
),
tb_doi AS (  
SELECT 
	MaKH
	, SUM(ctdt.SoLuong * ctdt.DonGia) AS TongDoi
FROM HOA_DON_DOI_TRA hddt JOIN CHI_TIET_DOI_TRA ctdt
        ON hddt.MaHDDT = ctdt.MaHDDT
GROUP BY MaKH
)
SELECT 
	tbm.MAKH
	, kh.HOTEN 
	, kh.DIACHI 
	, (tbm.TONGMUA - nvl(tbd.TONGDOI, 0)) AS TongChiTieuThucTe
FROM KHACH_HANG kh 
		JOIN tb_mua tbm ON kh.MAKH = tbm.MAKH 
		LEFT JOIN tb_doi tbd ON kh.MAKH = tbd.MAKH 
ORDER BY TongChiTieuThucTe DESC;

--5: Thống kế số lượng tồn kho còn lại của mỗi mặt hàng

WITH sl_nhap AS (
    SELECT 
        ctnh.MaHang,
        SUM(ctnh.SoLuong) AS tong_nhap
    FROM CHI_TIET_NHAP_HANG ctnh
    GROUP BY ctnh.MaHang
),
sl_ban AS (
    SELECT 
        ctbh.MaHang,
        SUM(ctbh.SoLuong) AS tong_ban
    FROM CHI_TIET_BAN_HANG ctbh
    GROUP BY ctbh.MaHang
),
sl_doi AS (
    SELECT 
        ctdt.MaHang,
        SUM(ctdt.SoLuong) AS tong_doi
    FROM CHI_TIET_DOI_TRA ctdt
    GROUP BY ctdt.MaHang
)
SELECT 
    hh.MaHang,
    hh.TenHang,
    NVL(n.tong_nhap, 0)
    - NVL(b.tong_ban, 0)
    + NVL(d.tong_doi, 0) AS TonKho
FROM HANG_HOA hh
LEFT JOIN sl_nhap n ON n.MaHang = hh.MaHang
LEFT JOIN sl_ban  b ON b.MaHang = hh.MaHang
LEFT JOIN sl_doi  d ON d.MaHang = hh.MaHang
ORDER BY TonKho DESC;


--6: Thống kê doanh số theo từng tháng trong năm 2023

SELECT
    EXTRACT(MONTH FROM hdbh.NgayBan) AS Thang,
    SUM(ctbh.SoLuong * ctbh.DonGia) AS DoanhSo
FROM HOA_DON_BAN_HANG hdbh
JOIN CHI_TIET_BAN_HANG ctbh 
        ON ctbh.MaHDBH = hdbh.MaHDBH
WHERE hdbh.NgayBan >= DATE '2023-01-01'
  AND hdbh.NgayBan <  DATE '2024-01-01'
GROUP BY EXTRACT(MONTH FROM hdbh.NgayBan)
ORDER BY Thang;


--7: Những mặt hàng có xu hướng mua tăng lên trong những năm trở lại đây


WITH DoanhSoNam AS (
    SELECT 
        hh.MaHang,
        hh.TenHang,
        EXTRACT(YEAR FROM hdbh.NgayBan) AS Nam,
        SUM(ctbh.SoLuong) AS TongSL
    FROM HANG_HOA hh
    JOIN CHI_TIET_BAN_HANG ctbh
         ON ctbh.MaHang = hh.MaHang
    JOIN HOA_DON_BAN_HANG hdbh
         ON hdbh.MaHDBH = ctbh.MaHDBH
    GROUP BY hh.MaHang, hh.TenHang, EXTRACT(YEAR FROM hdbh.NgayBan)
),
KiemTraTang AS (
    SELECT 
        MaHang,
        TenHang,
        Nam,
        TongSL,
        LEAD(Nam) OVER (PARTITION BY MaHang ORDER BY Nam) AS NamSau,
        LEAD(TongSL) OVER (PARTITION BY MaHang ORDER BY Nam) AS SL_NamSau
    FROM DoanhSoNam
),
ChuKyTang AS (
    SELECT 
        MaHang,
        TenHang
    FROM KiemTraTang
    WHERE SL_NamSau IS NOT NULL
      AND SL_NamSau > TongSL
      AND NamSau = Nam + 1
)
SELECT 
    MaHang,
    TenHang,
    COUNT(mahang) AS SoNamTangLienTiep
FROM ChuKyTang
GROUP BY MaHang, TenHang
ORDER BY SoNamTangLienTiep DESC;


--8: Thống kê những mặt hàng đã từng bán, những lần bán gần nhất cách đây lâu nhất

WITH last_sold AS (
    SELECT 
        ctbh.MaHang
        , MAX(hdbh.NgayBan) AS NgayBanGanNhat
    FROM CHI_TIET_BAN_HANG ctbh
    JOIN HOA_DON_BAN_HANG hdbh 
        ON hdbh.MaHDBH = ctbh.MaHDBH
    GROUP BY ctbh.MaHang
)
SELECT
    hh.MaHang,
    hh.TenHang,
    ls.NgayBanGanNhat,
    TRUNC(SYSDATE - ls.NgayBanGanNhat) AS SoNgayKhongBan
FROM last_sold ls
	JOIN HANG_HOA hh ON hh.MaHang = ls.MaHang
ORDER BY SoNgayKhongBan DESC;


--9: Thống kê những nhà cung cấp nhập số lượng nhiều nhất

SELECT
    ncc.TenNCC,
    SUM(ctnh.SoLuong) AS TongSoLuongNhap
FROM NHA_CUNG_CAP ncc
	JOIN HOA_DON_NHAP_HANG hdnh 
	        ON hdnh.MaNCC = ncc.MaNCC
	JOIN CHI_TIET_NHAP_HANG ctnh
	        ON ctnh.MaHDNH = hdnh.MaHDNH
GROUP BY ncc.TenNCC
ORDER BY TongSoLuongNhap DESC;

--10: Thống kê giá trị trung bình hóa đơn của mỗi khách hàng

WITH tong_hd AS (
    SELECT
        hdbh.MaKH,
        SUM(ctbh.SoLuong * ctbh.DonGia) AS TongTien
    FROM HOA_DON_BAN_HANG hdbh
    JOIN CHI_TIET_BAN_HANG ctbh 
        ON ctbh.MaHDBH = hdbh.MaHDBH
    GROUP BY hdbh.MaKH, hdbh.MaHDBH
)
SELECT
    kh.MaKH,
    kh.HoTen,
    AVG(t.TongTien) AS GiaTriTrungBinhMoiHoaDon
FROM KHACH_HANG kh
JOIN tong_hd t ON t.MaKH = kh.MaKH
GROUP BY kh.MaKH, kh.HoTen
ORDER BY GiaTriTrungBinhMoiHoaDon DESC;




---------------------------- PL/SQL



--1: Viết function trả về số lượng tồn kho của mỗi mặt hàng ở thời điểm hiện tại

create or replace function fnc_tonkho(vr_mahang hang_hoa.mahang%type)
return number
as 
    vr_sl_ton_kho number := 0;
begin 
    WITH sl_nhap AS (
    SELECT 
        ctnh.MaHang,
        SUM(ctnh.SoLuong) AS tong_nhap
    FROM CHI_TIET_NHAP_HANG ctnh
    WHERE ctnh.MaHang = vr_mahang
    GROUP BY ctnh.MaHang
    ),
    sl_ban AS (
        SELECT 
            ctbh.MaHang,
            SUM(ctbh.SoLuong) AS tong_ban
        FROM CHI_TIET_BAN_HANG ctbh
        WHERE ctbh.MaHang = vr_mahang
        GROUP BY ctbh.MaHang
    ),
    sl_doi AS (
        SELECT 
            ctdt.MaHang,
            SUM(ctdt.SoLuong) AS tong_doi
        FROM CHI_TIET_DOI_TRA ctdt
        WHERE ctdt.MaHang = vr_mahang
        GROUP BY ctdt.MaHang
    )
    SELECT 
        NVL(n.tong_nhap, 0)- NVL(b.tong_ban, 0) + NVL(d.tong_doi, 0) AS TonKho
    INTO vr_sl_ton_kho
    FROM hang_hoa hh
    LEFT JOIN sl_nhap n ON n.MaHang = hh.MaHang
    LEFT JOIN sl_ban b ON b.MaHang = hh.MaHang
    LEFT JOIN sl_doi d ON d.MaHang = hh.MaHang
    WHERE hh.MaHang = vr_mahang;
    
    RETURN vr_sl_ton_kho;
END;
/

SELECT MaHang, fnc_tonkho(MaHang) as tonkho
FROM hang_hoa
ORDER BY tonkho desc;

--2: Dùng thủ tục để khi nhập mã khách hàng vào cho biết lịch sử giao dịch của người đó

CREATE OR REPLACE PROCEDURE pr_lich_su_giao_dich_khach (vr_makh IN khach_hang.makh%type) 
IS
    vr_cnt number := 0;
BEGIN
    select count(makh)
    into vr_cnt
    from khach_hang
    where upper(makh) = upper(vr_makh);
    
    if vr_cnt = 0 then
        dbms_output.put_line('Không tìm thấy khách hàng có mã ' || vr_makh || ', vui lòng nhập lại');
        return;
    end if;
    
    FOR r_kh IN (
        SELECT MaKH, HoTen
        FROM KHACH_HANG
        WHERE UPPER(makh) LIKE UPPER(vr_makh)
    ) 
    LOOP
        DBMS_OUTPUT.PUT_LINE('KHÁCH HÀNG: ' || r_kh.MaKH || ' - ' || r_kh.HoTen);
        DBMS_OUTPUT.PUT_LINE(
            RPAD('LOAIHD', 10) ||
            RPAD('MAHD', 15) ||
            RPAD('NGAYGD', 15) ||
            RPAD('TONGTIEN', 15)
        );
        DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
        
        FOR r_ls IN (
            SELECT
                'BÁN' AS LoaiHD,
                hdbh.MaHDBH AS MaHD,
                hdbh.NgayBan AS NgayGD,
                SUM(ctbh.SoLuong * ctbh.DonGia) AS TongTien
            FROM HOA_DON_BAN_HANG hdbh
            JOIN CHI_TIET_BAN_HANG ctbh ON ctbh.MaHDBH = hdbh.MaHDBH
            WHERE hdbh.MaKH = r_kh.MaKH
            GROUP BY hdbh.MaHDBH, hdbh.NgayBan
            
            UNION ALL

            SELECT 
                'ĐỔI/TRẢ' AS LoaiHD,
                hddt.MaHDDT AS MaHD,
                hddt.NgayDoiTra AS NgayGD,
                SUM(ctdt.SoLuong * ctdt.DonGia) AS TongTien
            FROM HOA_DON_DOI_TRA hddt 
            JOIN CHI_TIET_DOI_TRA ctdt ON ctdt.MaHDDT = hddt.MaHDDT
            WHERE hddt.MaKH = r_kh.MaKH
            GROUP BY hddt.MaHDDT, hddt.NgayDoiTra
            ORDER BY NgayGD desc
        ) 
        LOOP
            DBMS_OUTPUT.PUT_LINE(
                rpad(r_ls.LoaiHD, 10)
                || rpad(r_ls.MaHD, 15)
                || rpad(r_ls.NgayGD, 15)
                || rpad(r_ls.TongTien, 15)
            );
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    END LOOP;
END;
/


set serveroutput on
declare 
    vr_makh khach_hang.makh%type := '&vr_makh';
begin
    pr_lich_su_giao_dich_khach(vr_makh);
end;
/

select * from khach_hang;

--3: Nhập vào một mức doanh số mục tiêu, sau đó liệt kê những nhân viên có tổng doanh thu trong năm vượt mức doanh số đó. Nếu doanh thu vượt ngưỡng thì in thông báo khen thưởng



CREATE OR REPLACE PROCEDURE pr_khen_thuong_nhan_vien_theo_doanh_so(
    vr_target IN chi_tiet_ban_hang.dongia%TYPE
)
IS
    v_found BOOLEAN := FALSE;
BEGIN
    FOR rc_nv IN (
        SELECT nv.manv,
               nv.tennhanvien,
               SUM(ctbh.soluong * ctbh.dongia) AS doanhso
        FROM nhan_vien nv
        JOIN hoa_don_ban_hang hdbh 
             ON nv.manv = hdbh.manv
            AND hdbh.ngayban >= DATE '2025-01-01'
            AND hdbh.ngayban <  DATE '2025-04-01'
        JOIN chi_tiet_ban_hang ctbh 
             ON hdbh.mahdbh = ctbh.mahdbh
        GROUP BY nv.manv, nv.tennhanvien
        HAVING SUM(ctbh.soluong * ctbh.dongia) >= vr_target
        ORDER BY doanhso DESC
    )
    LOOP
        -- Gặp dòng đầu tiên → in header
        IF NOT v_found THEN
            DBMS_OUTPUT.PUT_LINE(
                RPAD('MANV', 10) ||
                RPAD('HOTEN', 20) ||
                RPAD('TONGDOANHSO', 15)
            );
            DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
            v_found := TRUE;
        END IF;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(rc_nv.manv, 10) ||
            RPAD(rc_nv.tennhanvien, 20) ||
            RPAD(rc_nv.doanhso, 15)
        );
    END LOOP;

    -- Sau khi loop xong mà chưa có dòng nào
    IF NOT v_found THEN
        DBMS_OUTPUT.PUT_LINE(
            '⚠ Không có nhân viên nào đạt doanh số từ '
            || TO_CHAR(vr_target, 'FM999,999,999,999')
            || ' trở lên.'
        );
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(
            '❌ Lỗi khi thực hiện khen thưởng nhân viên: '
            || SQLERRM
        );
END;
/

set serveroutput on
declare 
    vr_target chi_tiet_ban_hang.dongia%type := &vr_target;
begin
    pr_khen_thuong_nhan_vien_theo_doanh_so(vr_target);
end;
/



--4: Dùng thủ tục in ra danh sách sản phẩm có lượng tồn kho ít hơn mức cảnh báo

CREATE OR REPLACE PROCEDURE pr_canh_bao_ton_kho(
    vr_muc_canh_bao IN chi_tiet_ban_hang.soluong%TYPE
)
IS
    v_found BOOLEAN := FALSE;
BEGIN
    -- 1. Kiểm tra nghiệp vụ: mức cảnh báo không được âm
    IF vr_muc_canh_bao < 0 THEN
        DBMS_OUTPUT.PUT_LINE('❌ Mức cảnh báo tồn kho không hợp lệ (không được âm).');
        RETURN;
    END IF;

    -- 2. Duyệt danh sách hàng hóa dưới mức cảnh báo
    FOR rec IN (
        SELECT mahang, tenhang, tonkho
        FROM (
            SELECT mahang,
                   tenhang,
                   fnc_tonkho(mahang) AS tonkho
            FROM hang_hoa
        )
        WHERE tonkho < vr_muc_canh_bao
        ORDER BY tonkho
    )
    LOOP
        -- In header khi gặp dòng đầu tiên
        IF NOT v_found THEN
            DBMS_OUTPUT.PUT_LINE(
                RPAD('MAHANG', 10) ||
                RPAD('TENHANG', 40) ||
                RPAD('TONKHO', 10)
            );
            DBMS_OUTPUT.PUT_LINE(
                RPAD('-', 60, '-')
            );
            v_found := TRUE;
        END IF;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(rec.mahang, 10) ||
            RPAD(rec.tenhang, 40) ||
            RPAD(rec.tonkho, 10)
        );
    END LOOP;

    -- 3. Không có mặt hàng nào bị cảnh báo
    IF NOT v_found THEN
        DBMS_OUTPUT.PUT_LINE(
            'ℹ Không có mặt hàng nào có tồn kho dưới mức cảnh báo '
            || vr_muc_canh_bao || '.'
        );
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(
            '❌ Lỗi trong quá trình kiểm tra tồn kho: ' || SQLERRM
        );
END;
/


set serveroutput on 
declare 
    vr_muc_ton_kho chi_tiet_ban_hang.soluong%type := &vr_muc_ton_kho;
begin 
    pr_canh_bao_ton_kho(vr_muc_ton_kho);
end;
/


--5: Nhập vào năm, cho biết doanh thu mỗi tháng trong năm đó 


CREATE OR REPLACE PROCEDURE pr_doanh_thu_moi_thang (
    vr_year IN NUMBER
)
IS
    vr_cnt   NUMBER := 0;
    vr_start DATE;
    vr_end   DATE;
BEGIN
    -- 1. Kiểm tra đầu vào hợp lệ
    IF vr_year IS NULL OR vr_year < 1 OR vr_year > 9999 THEN
        DBMS_OUTPUT.PUT_LINE('❌ Năm nhập vào không hợp lệ!');
        RETURN;
    END IF;

    vr_start := TO_DATE(vr_year || '-01-01', 'YYYY-MM-DD');
    vr_end   := ADD_MONTHS(vr_start, 12);

    -- 2. Kiểm tra dữ liệu tồn tại
    SELECT COUNT(mahdbh)
    INTO vr_cnt
    FROM HOA_DON_BAN_HANG
    WHERE NgayBan >= vr_start
      AND NgayBan <  vr_end;

    IF vr_cnt = 0 THEN
        DBMS_OUTPUT.PUT_LINE('⚠ Không có dữ liệu bán hàng cho năm ' || vr_year);
        RETURN;
    END IF;

    -- 3. In tiêu đề
    DBMS_OUTPUT.PUT_LINE(
        RPAD('THANG', 7) || RPAD('DOANH THU', 15)
    );
    DBMS_OUTPUT.PUT_LINE('--------------------');

    -- 4. In doanh thu theo tháng
    FOR rec IN (
        SELECT EXTRACT(MONTH FROM hdbh.NgayBan) AS Thang,
               SUM(ctbh.SoLuong * ctbh.DonGia) AS DoanhSo
        FROM HOA_DON_BAN_HANG hdbh
        JOIN CHI_TIET_BAN_HANG ctbh
             ON ctbh.MaHDBH = hdbh.MaHDBH
        WHERE NgayBan >= vr_start
          AND NgayBan <  vr_end
        GROUP BY EXTRACT(MONTH FROM hdbh.NgayBan)
        ORDER BY Thang
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(rec.Thang, 7) ||
            RPAD(rec.DoanhSo, 15)
        );
    END LOOP;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ Lỗi không xác định: ' || SQLERRM);
END;
/


set serveroutput on
declare
    vr_year number := &vr_year;
begin 
    pr_doanh_thu_moi_thang(vr_year);
end;
/

--6: Dùng hàm để tính giá trị trung bình mỗi hóa đơn bán ra của nhân viên
create or replace function fnc_avg_invoice(vr_manv nhan_vien.manv%type) 
return number
as
    vr_avg_invoice chi_tiet_ban_hang.dongia%type := 0;
begin 
    SELECT nvl(AVG(tong_tien),0)
    INTO vr_avg_invoice
    FROM (
        SELECT hdbh.MAHDBH,
               SUM(ctbh.SOLUONG * ctbh.DONGIA) AS tong_tien
        FROM HOA_DON_BAN_HANG hdbh
        JOIN CHI_TIET_BAN_HANG ctbh ON ctbh.MAHDBH = hdbh.MAHDBH
        WHERE hdbh.MANV = vr_manv
        GROUP BY hdbh.MAHDBH
    );

    return vr_avg_invoice;   
end;
/


--7: Tính mức thưởng của nhân viên Thưởng = Tổng doanh số * Tỷ lệ hoa hồng (%)) theo tháng 
--với % khác nhau:
--với < 100 -> tỷ lệ 0%
--với 100 - 300tr -> tỷ lệ 1%
--với 300 - 500tr -> tỷ lệ 2%
--với > 500tr -> tỷ lệ 3%


create or replace function fnc_thuong_theo_doanh_so(vr_year number, vr_month number, vr_manv nhan_vien.manv%type)
return number 
as
    vr_tong_doanh_so chi_tiet_ban_hang.dongia%type := 0;
begin 

    IF vr_year IS NULL OR vr_year < 1 OR vr_year > 9999 THEN
        RETURN 0;
    END IF;

    IF vr_month IS NULL OR vr_month < 1 OR vr_month > 12 THEN
        RETURN 0;
    END IF;
    
    select 
        nvl(sum(soluong * dongia), 0) as tong_doanh_so
    into vr_tong_doanh_so
    from hoa_don_ban_hang hdbh join chi_tiet_ban_hang ctbh on hdbh.mahdbh = ctbh.mahdbh
    where extract(month from ngayban) = vr_month
        and extract(year from ngayban) = vr_year
        and manv = vr_manv;
        
    IF vr_tong_doanh_so = 0 THEN
        RETURN 0;   -- hoặc RETURN 0
    END IF;
    
    CASE 
        WHEN vr_tong_doanh_so < 100000000 THEN
            RETURN 0;
        WHEN vr_tong_doanh_so < 300000000 THEN
            RETURN vr_tong_doanh_so * 0.01;
        WHEN vr_tong_doanh_so < 500000000 THEN
            RETURN vr_tong_doanh_so * 0.02;
        ELSE
            RETURN vr_tong_doanh_so * 0.03;
    END CASE;

end;
/

select manv, fnc_thuong_theo_doanh_so(2025, 2, manv) as thuong from hoa_don_ban_hang order by thuong desc;
    


--8: Viết function phân loại khách hàng
-- < 100 triệu → Standard
-- 100–300 triệu → Silver
-- 300–500 triệu → Gold
-- >500 triệu → Diamond

create or replace function fnc_phan_loai_kh(vr_makh khach_hang.makh%type, vr_year number)
return varchar2
as
    tong_chi_tieu chi_tiet_ban_hang.dongia%type := 0;
    vr_end date := to_date(vr_year || '-12-31', 'YYYY-MM-DD');
begin 
    IF vr_year IS NULL OR vr_year < 1 OR vr_year > 9999 THEN
        RETURN 'Standard';
    END IF;
    
    select nvl(sum(soluong * dongia), 0)
    into tong_chi_tieu
    from hoa_don_ban_hang hdbh join chi_tiet_ban_hang ctbh on hdbh.mahdbh = ctbh.mahdbh
    where makh = vr_makh
      and hdbh.ngayban <=  vr_end;
    
    case 
        when tong_chi_tieu < 100000000 then
            return 'Standard';
        when tong_chi_tieu < 300000000 then
            return 'Silver';
        when tong_chi_tieu < 500000000 then
            return 'Gold';
        else 
            return 'Diamond';
    end case;
    
end;
/

select makh, fnc_phan_loai_kh(makh, 2025) from khach_hang;
-------------------------------------------------------------
-- TRIGGER LƯU LOGON/LOGOFF
DROP TABLE audit_session_log;


CREATE TABLE audit_session_log (
    log_id NUMBER GENERATED ALWAYS AS IDENTITY,
    session_id VARCHAR2(50),
    event_type VARCHAR2(10),  -- 'LOGON' ho?c 'LOGOFF'
    username VARCHAR2(100),
    ip_address VARCHAR2(100),
    os_user VARCHAR2(100),
    host VARCHAR2(100),
    program VARCHAR2(200),
    event_time TIMESTAMP,     -- Th?i gian c?a s? ki?n (login ho?c logout)
    CONSTRAINT pk_audit_session_log PRIMARY KEY (log_id)
);




CREATE OR REPLACE TRIGGER trg_audit_logon 
AFTER LOGON ON DATABASE
DECLARE 
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO audit_session_log(
        session_id,
        event_type,
        username,
        ip_address,
        os_user,
        host,
        program,
        event_time
    ) VALUES (
        SYS_CONTEXT('USERENV','SESSIONID'),
        'LOGON',  -- <-- Ghi rõ LOGON
        SYS_CONTEXT('USERENV','SESSION_USER'),
        SYS_CONTEXT('USERENV','IP_ADDRESS'),
        SYS_CONTEXT('USERENV','OS_USER'),
        SYS_CONTEXT('USERENV','HOST'),
        SYS_CONTEXT('USERENV','MODULE'),
        SYSTIMESTAMP
    );
    COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
END;
/


CREATE OR REPLACE TRIGGER trg_audit_logoff 
BEFORE LOGOFF ON DATABASE
DECLARE 
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO audit_session_log(
        session_id,
        event_type,
        username,
        ip_address,
        os_user,
        host,
        program,
        event_time
    ) VALUES (
        SYS_CONTEXT('USERENV','SESSIONID'),
        'LOGOFF',  -- <-- Ghi rõ LOGOFF
        SYS_CONTEXT('USERENV','SESSION_USER'),
        SYS_CONTEXT('USERENV','IP_ADDRESS'),
        SYS_CONTEXT('USERENV','OS_USER'),
        SYS_CONTEXT('USERENV','HOST'),
        SYS_CONTEXT('USERENV','MODULE'),
        SYSTIMESTAMP
    );
    COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
END;
/


select * from audit_session_log;

-- trigger lưu thay đổi trong bảng hóa dơn bán hàng



CREATE TABLE AUDIT_LOG (
    AUDIT_ID      NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY,
    AUDIT_DATE    DATE DEFAULT SYSDATE,
    TABLE_NAME    VARCHAR2(100),
    ACTION        VARCHAR2(20),
    USER_ID       VARCHAR2(100),
    MACHINE_NAME  VARCHAR2(100),
    PK_NAME       VARCHAR2(200),
    PK_VALUE      VARCHAR2(4000),
    OLD_DATA      CLOB,
    NEW_DATA      CLOB
);

drop table audit_log;

CREATE OR REPLACE PROCEDURE GenericAudit(
    p_table_name IN VARCHAR2,
    p_pkname     IN VARCHAR2,
    p_pkvalue    IN VARCHAR2,
    p_olddata    IN CLOB,
    p_newdata    IN CLOB
)
AS
    v_action VARCHAR2(20);
BEGIN
    -- Xác định hành động
    IF p_olddata IS NULL AND p_newdata IS NOT NULL THEN
        v_action := 'Insert';
    ELSIF p_olddata IS NOT NULL AND p_newdata IS NULL THEN
        v_action := 'Delete';
    ELSE
        v_action := 'Update';
    END IF;

    INSERT INTO AUDIT_LOG(
        TABLE_NAME, ACTION, USER_ID, MACHINE_NAME,
        PK_NAME, PK_VALUE, OLD_DATA, NEW_DATA
    )
    VALUES(
        p_table_name,
        v_action,
        NVL(SYS_CONTEXT('USERENV','SESSION_USER'), 'UNKNOWN'),
        NVL(SYS_CONTEXT('USERENV','HOST'), 'UNKNOWN'),
        p_pkname,
        p_pkvalue,
        p_olddata,
        p_newdata
    );
END;
/



CREATE OR REPLACE TRIGGER TRG_AUDIT_HOADON
AFTER INSERT OR UPDATE OR DELETE
ON HOA_DON_BAN_HANG
FOR EACH ROW
DECLARE
    v_old   CLOB;
    v_new   CLOB;
BEGIN
    -- OLD DATA (khi UPDATE hoặc DELETE)
    IF UPDATING OR DELETING THEN
        v_old :=
              '<old '
            || 'MAHDBH="' || :OLD.MAHDBH || '" '
            || 'NGAYBAN="' || TO_CHAR(:OLD.NGAYBAN,'YYYY-MM-DD') || '" '
            || 'HINHTHUC="' || :OLD.HINHTHUCTHANHTOAN || '" '
            || 'MAKH="' || :OLD.MAKH || '" '
            || 'MANV="' || :OLD.MANV || '" '
            || '/>';
    END IF;

    -- NEW DATA (khi INSERT hoặc UPDATE)
    IF INSERTING OR UPDATING THEN
        v_new :=
              '<new '
            || 'MAHDBH="' || :NEW.MAHDBH || '" '
            || 'NGAYBAN="' || TO_CHAR(:NEW.NGAYBAN,'YYYY-MM-DD') || '" '
            || 'HINHTHUC="' || :NEW.HINHTHUCTHANHTOAN || '" '
            || 'MAKH="' || :NEW.MAKH || '" '
            || 'MANV="' || :NEW.MANV || '" '
            || '/>';
    END IF;

    -- Gọi thủ tục audit chung
    GenericAudit(
        p_table_name => 'HOA_DON_BAN_HANG',
        p_pkname     => 'MAHDBH',
        p_pkvalue    => COALESCE(:NEW.MAHDBH, :OLD.MAHDBH),
        p_olddata    => v_old,
        p_newdata    => v_new
    );
END;
/

select * from hoa_don_ban_hang;



INSERT INTO HOA_DON_BAN_HANG
VALUES ('HDBH100', SYSDATE, 'Tiền mặt', 'KH0768', 'NV0468');


UPDATE HOA_DON_BAN_HANG
SET HINHTHUCTHANHTOAN = 'Chuyển khoản'
WHERE MAHDBH = 'HDBH100';


DELETE FROM HOA_DON_BAN_HANG
WHERE MAHDBH = 'HDBH100';


SELECT AUDIT_ID,
       TO_CHAR(AUDIT_DATE, 'DD-MON-YYYY HH24:MI:SS') AS AUDIT_DATE,
       TABLE_NAME,
       ACTION,
       USER_ID,
       MACHINE_NAME,
       PK_NAME,
       PK_VALUE,
       OLD_DATA,
       NEW_DATA
FROM AUDIT_LOG
ORDER BY AUDIT_ID asc;




-----------------------------------------------------BACKUP 
--arch_backup.rman
CONFIGURE CONTROLFILE AUTOBACKUP ON;

RUN {
    SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';

    BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL
      FORMAT 'D:\oracle_backup\arch\arch_%d_%T_%U'
      TAG 'ARCH_30MIN';

    DELETE ARCHIVELOG UNTIL TIME "SYSDATE-2";
}

--level0.rman
CONFIGURE CONTROLFILE AUTOBACKUP ON;

RUN {
  CROSSCHECK BACKUP;
  DELETE NOPROMPT EXPIRED BACKUP;
  DELETE NOPROMPT OBSOLETE;

  BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 0 DATABASE
    FORMAT 'D:\oracle_backup\level0\L0_%d_%T_%U'
    TAG 'LEVEL0';

  SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';

  BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL
    FORMAT 'D:\oracle_backup\arch\arch_%d_%T_%U'
    TAG 'ARCH';

  DELETE ARCHIVELOG UNTIL TIME "SYSDATE-2";
}

--level1.rman
CONFIGURE CONTROLFILE AUTOBACKUP ON;

RUN {
  CROSSCHECK BACKUP;
  DELETE NOPROMPT EXPIRED BACKUP;
  DELETE NOPROMPT OBSOLETE;

  BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 1 DATABASE
    FORMAT 'D:\oracle_backup\level1\L1_%d_%T_%U'
    TAG 'LEVEL1_DIFF';

  SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';

  BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL
    FORMAT 'D:\oracle_backup\arch\arch_%d_%T_%U'
    TAG 'ARCH';

  DELETE ARCHIVELOG UNTIL TIME "SYSDATE-2";
}

--run_arch.bat
@echo off
set ORACLE_HOME=C:\users\lenovo\downloads\windows.x64_193000_db_home
set PATH=%ORACLE_HOME%\bin;%PATH%

set LOGDATE=%DATE:~6,4%-%DATE:~3,2%-%DATE:~0,2%

rman target / cmdfile=D:\oracle_backup\arch_backup.rman log=D:\oracle_backup\logs\arch_%LOGDATE%.log

--run_level0.bat
@echo off
set ORACLE_HOME=C:\users\lenovo\downloads\windows.x64_193000_db_home
set PATH=%ORACLE_HOME%\bin;%PATH%

set LOGDATE=%DATE:~6,4%-%DATE:~3,2%-%DATE:~0,2%

rman target / cmdfile=D:\oracle_backup\level0.rman log=D:\oracle_backup\logs\level0_%LOGDATE%.log

exit

--run_level1.bat
@echo off
set ORACLE_HOME=C:\users\lenovo\downloads\windows.x64_193000_db_home
set PATH=%ORACLE_HOME%\bin;%PATH%

set LOGDATE=%DATE:~6,4%-%DATE:~3,2%-%DATE:~0,2%

rman target / cmdfile=D:\oracle_backup\level1.rman log=D:\oracle_backup\logs\level1_%LOGDATE%.log

