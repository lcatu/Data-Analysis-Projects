# BÁNG CÁO CHI TIẾT QUY TRÌNH ĐỔ DỮ LIỆU VÀO STAGING
## Dự án WideWorldImposter - Package Load_Staging.dtsx

---

## PHẦN I: CONTROL FLOW CHUNG CHO LOAD_STAGING

### Tổng quan

Package `Load_Staging.dtsx` là bước đầu tiên trong quy trình ETL, chịu trách nhiệm nạp dữ liệu từ **3 nguồn khác nhau** (Excel, SQL Server, PostgreSQL) vào vùng **Staging Area** (cơ sở dữ liệu trung gian `wwi_staging_area`).

Mục tiêu của Staging Area:
- Lưu trữ dữ liệu **thô (raw)** từ các hệ thống nguồn mà không biến đổi
- Cung cấp điểm kiểm tra dữ liệu trước khi xử lý tiếp
- Cho phép audit trail (truy dõi nguồn gốc dữ liệu)
- Tách biệt việc truy cập các hệ thống nguồn với xử lý dữ liệu

### Các bước Control Flow

**Bước 1 – Sequence Application (Excel)**: 
- Execute SQL Task: Xóa/Chuẩn bị bảng Staging (TRUNCATE TABLE)
- Data Flow Task: Nạp dữ liệu từ Excel (4 Data Flow cho các bảng khác nhau)
- Execute SQL Task: Kiểm tra/validate dữ liệu sau load

**Bước 2 – Sequence SQL Server (Staging Database)**:
- Execute SQL Task: Xóa/Chuẩn bị bảng Staging
- Data Flow Task: Nạp dữ liệu từ SQL Server (4 Data Flow cho các bảng)
- Execute SQL Task: Kiểm tra dữ liệu

**Bước 3 – Sequence SQL Server (purchasing&sales Database)**:
- Execute SQL Task: Xóa/Chuẩn bị bảng
- Execute SQL Task: Pre-processing (nếu cần)
- Data Flow Task: Nạp Invoices, InvoiceLines, v.v. (6 Data Flow)
- Execute SQL Task: Post-processing, validate

**Bước 4 – Sequence PostgreSQL**:
- Data Flow Task: Nạp dữ liệu từ PostgreSQL (6 Data Flow cho các bảng kho)
- Execute SQL Task: Validate, update statistics
- Execute SQL Task: Final cleanup nếu cần

**Ghi chú**: Load_Staging **không sử dụng Lineage logging** như các Dimension/Fact package. Thay vào đó, nó tập trung vào việc nạp dữ liệu thô từ 3 nguồn một cách nhanh và hiệu quả.

---

## PHẦN II: DATA FLOW CHI TIẾT - LOAD STAGING TỪ CÁC NGUỒN

> **[Chèn ảnh: Load_Staging.dtsx - Data Flow Task Designer - Toàn bộ luồng từ 3 nguồn khác nhau → Data Conversion (nếu cần) → 3 Destination tương ứng]**

---

## A. NGUỒN 1: EXCEL - BẢNG EMPLOYEES (application.xlsx)

### Tổng quan

Bảng `Employees` chứa dữ liệu nhân viên được quản lý trong file Excel `application.xlsx`. Dữ liệu này được nạp vào bảng Staging để tích hợp với dữ liệu nhân viên từ các hệ thống khác (SQL Server).

**Đặc điểm của Excel:**
- Dữ liệu được quản lý bằng tay (manual entry), có thể có sai sót định dạng
- File được lưu tại `D:\ssms2postgre\file backup\application.xlsx`
- Dữ liệu cập nhật theo định kỳ, không real-time
- Cần xử lý kiểu dữ liệu (Excel có thể lưu trữ số/text không rõ ràng)

### Data Flow Task – Luồng xử lý dữ liệu

> **[Chèn ảnh: Load_Staging (Excel Source) - Data Flow Designer - Excel Source → Data Conversion → OLE DB Destination (Staging)]**

**Bước 1 – Excel Source: "Read Employees from Excel"**

**Ý nghĩa:** Đọc dữ liệu nhân viên từ sheet `Employees` trong file Excel.

**Cấu hình Connection Manager:**
- **Type:** Excel Connection Manager
- **File Path:** `D:\ssms2postgre\file backup\application.xlsx`
- **Sheet Name:** `Employees` (hoặc `$Employees$` tuỳ theo cấu hình)
- **First Row as Column Names:** Bật (để lấy header làm tên cột)

**SQL Query hoặc Range:**

Nếu sử dụng SQL mode:
```sql
SELECT * FROM [Employees$]
```

Hoặc nếu sử dụng Range:
```
Employees$A1:H1000
```

**Dữ liệu đầu ra:**

```
Columns from Excel:
- EmployeeID           (số nguyên, cột A)
- EmployeeName         (text, cột B)
- JobTitle             (text, cột C)
- DepartmentName       (text, cột D)
- ManagerEmployeeID    (số nguyên hoặc trống, cột E)
- HireDate             (date, cột F)
- Salary               (tiền tệ, cột G)
- IsActive             (boolean/text "Y"/"N", cột H)
```

**Thách thức khi đọc Excel:**
- Kiểu dữ liệu không rõ ràng: Excel có thể lưu số dưới dạng text
- Giá trị rỗng: Có thể là NULL, trống, hoặc space
- Định dạng ngày: Có thể khác nhau giữa các cell (DD/MM/YYYY vs MM/DD/YYYY)
- Dữ liệu ngoài range: Nếu thêm dòng mới, có thể không được đọc nếu vượt range cố định

> **[Chèn ảnh: Excel Source component - Cửa sổ Preview cho thấy dữ liệu từ Excel]**

**Bước 2 – Data Conversion: "Convert Data Types"**

**Ý nghĩa:** Chuyển đổi kiểu dữ liệu từ Excel (thường là text/variant) sang kiểu SQL chuẩn (int, bigint, datetime, float, v.v.), đảm bảo dữ liệu vào Staging có định dạng chính xác.

**Chuyển đổi cần thiết:**

```
EmployeeID (Excel: text) → INT
  → Ví dụ: "001" → 1
  → Lợi ích: Cho phép join với bảng khác dùng kiểu INT

EmployeeName (Excel: text) → VARCHAR(255)
  → Giữ nguyên, xóa leading/trailing spaces

JobTitle (Excel: text) → VARCHAR(100)
  → Chuẩn hóa (TRIM, UPPER, v.v. nếu cần)

DepartmentName (Excel: text) → VARCHAR(100)
  → Chuẩn hóa

ManagerEmployeeID (Excel: text/trống) → INT (cho phép NULL)
  → Nếu trống → NULL

HireDate (Excel: date serial) → DATE
  → Excel lưu ngày dưới dạng số (date serial), cần convert sang DATE
  → Ví dụ: 44964 → 2023-01-15

Salary (Excel: currency format) → DECIMAL(10,2)
  → Loại bỏ ký hiệu $ nếu có, chuyển sang số thập phân

IsActive (Excel: text "Y"/"N") → BIT (0/1)
  → "Y" → 1, "N" → 0
  → Cho phép tính toán logic dễ dàng
```

> **[Chèn ảnh: Data Conversion component - Conversion tab hiển thị các chuyển đổi]**

**Bước 3 – Derived Column: "Add Metadata"** (tùy chọn)

**Ý nghĩa:** Bổ sung các cột metadata để theo dõi dữ liệu từ Excel.

```
source_system = "Excel"
source_file = "application.xlsx"
load_date = GETDATE()
batch_id = @BatchID
record_hash = HASHBYTES('MD5', CONCAT(EmployeeID, EmployeeName, HireDate))
  → Dùng để phát hiện dữ liệu trùng lặp hoặc bị thay đổi
```

> **[Chèn ảnh: Derived Column - Expression Editor]**

**Bước 4 – OLE DB Destination: "Insert into Staging.Employees"**

**Ý nghĩa:** Chèn dữ liệu đã chuẩn hóa vào bảng `Staging.Employees`.

**Cấu hình:**
- **Connection Manager:** wwi_staging_area (SQL Server OLE DB)
- **Table:** `[dbo].[Employees]` hoặc `[Staging].[Employees]`
- **Data Access Mode:** Table or view
- **Truncate table:** Bật (nếu muốn xóa dữ liệu cũ trước khi nạp) hoặc Tắt (nếu muốn append)

**Mapping cột:**

```sql
INSERT INTO [Staging].[Employees]
(
    wwi_employee_id,        -- EmployeeID
    employee_name,          -- EmployeeName
    job_title,              -- JobTitle
    department_name,        -- DepartmentName
    manager_employee_id,    -- ManagerEmployeeID
    hire_date,              -- HireDate
    salary,                 -- Salary
    is_active,              -- IsActive
    source_system,          -- "Excel"
    source_file,            -- "application.xlsx"
    load_date,              -- GETDATE()
    batch_id                -- @BatchID
)
VALUES (...)
```

> **[Chèn ảnh: OLE DB Destination - Mapping Input Columns to Destination Columns]**

**Xử lý lỗi:**
- Nếu Excel file không tồn tại → Error kết nối
- Nếu sheet `Employees` không tồn tại → Error
- Nếu kiểu dữ liệu không thể convert (ví dụ text không thể convert sang INT) → Dòng lỗi, ghi vào Error Output
- Nếu primary key trùng → Constraint violation, ghi vào Error Output

---

## B. NGUỒN 2: SQL SERVER - BẢNG INVOICES (purchasing&sales database)

### Tổng quan

Bảng `Invoices` chứa dữ liệu header hóa đơn bán hàng từ cơ sở dữ liệu `purchasing&sales` trên SQL Server. Dữ liệu này được nạp vào Staging trước khi xử lý các dòng hóa đơn (InvoiceLines).

**Đặc điểm của SQL Server:**
- Dữ liệu thường có định dạng chuẩn, kiểu dữ liệu rõ ràng
- Có thể query trực tiếp, không cần convert kiểu
- Dữ liệu real-time hoặc gần real-time từ hệ thống giao dịch
- Có thể lọc/filter dữ liệu ngay tại source (lấy chỉ dữ liệu cần thiết)

### Data Flow Task – Luồng xử lý dữ liệu

> **[Chèn ảnh: Load_Staging (SQL Server Source) - Data Flow Designer - OLE DB Source → OLE DB Destination (Staging)]**

**Bước 1 – OLE DB Source: "Read Invoices from SQL Server"**

**Ý nghĩa:** Đọc dữ liệu hóa đơn từ bảng `Sales.Invoices` trong cơ sở dữ liệu `purchasing&sales`.

**Cấu hình Connection Manager:**
- **Type:** OLE DB Connection Manager
- **Server:** localhost (hoặc tên server)
- **Database:** purchasing&sales
- **Authentication:** Integrated Security (Windows Authentication) hoặc SQL Server Authentication
- **Provider:** SQL Server Native Client 11.0 (hoặc phiên bản tương đương)

**SQL Query:**

```sql
SELECT 
    InvoiceID                   AS wwi_invoice_id,
    CustomerID                  AS wwi_customer_id,
    InvoiceDate                 AS invoice_date,
    DueDate                     AS due_date,
    DeliveryDate                AS delivery_date,
    SalesPersonID               AS salesperson_id,
    ContactPersonID             AS contact_person_id,
    BillingAddressID            AS billing_address_id,
    ShippingAddressID           AS shipping_address_id,
    InvoiceLineCount            AS invoice_line_count,
    TotalDryItems               AS total_dry_items,
    TotalChillerItems           AS total_chiller_items,
    Comments                    AS comments,
    DeliveryInstructions        AS delivery_instructions,
    InternalComments            AS internal_comments,
    PickingCompletedWhen        AS picking_completed_when,
    PaymentMethod               AS payment_method,
    AccountsPersonID            AS accounts_person_id,
    LastEditedBy                AS last_edited_by,
    LastEditedWhen              AS last_edited_when,
    ConfirmedDeliveryTime       AS confirmed_delivery_time
FROM Sales.Invoices
WHERE ValidFrom <= GETDATE()
    AND (ValidTo IS NULL OR ValidTo > GETDATE())
    AND IsDeleted = 0
ORDER BY InvoiceID
```

**Ghi chú:**
- **WHERE clause (lọc dữ liệu):**
  - `ValidFrom <= GETDATE()` — Chỉ lấy bản ghi đã bắt đầu có hiệu lực
  - `ValidTo IS NULL OR ValidTo > GETDATE()` — Chỉ lấy bản ghi hiện còn hiệu lực (nếu bảng nguồn áp dụng SCD Type 2)
  - `IsDeleted = 0` — Loại bỏ bản ghi đã bị xóa (soft delete)
- **ORDER BY InvoiceID** — Sắp xếp để dễ kiểm tra và audit

**Lợi ích lọc ở source:**
- Giảm lượng dữ liệu truyền qua mạng
- Tăng hiệu suất ETL
- Rõ ràng về dữ liệu nào được tải

> **[Chèn ảnh: OLE DB Source (SQL Server) - Cửa sổ SQL Command editor với WHERE clause]**

**Bước 2 – Data Type Check (nếu cần)**

**Ý nghĩa:** 

Nếu kiểu dữ liệu từ SQL Server khác với kiểu trong Staging, có thể cần Derived Column hoặc Data Conversion để chuẩn hóa.

**Ví dụ chuyển đổi phổ biến:**

```
InvoiceDate (SQL Server: DATETIME2) → DATE
  → CAST(InvoiceDate AS DATE)
  → Lợi ích: Tiết kiệm bộ nhớ, loại bỏ time component nếu không cần

PaymentMethod (SQL Server: VARCHAR(10)) → VARCHAR(50)
  → Nếu cần mở rộng độ dài cho future data

Comments (SQL Server: NVARCHAR(MAX)) → VARCHAR(1000) hoặc VARCHAR(MAX)
  → Quyết định dựa trên nhu cầu lưu trữ (Staging có thể không cần full text)
```

> **[Chèn ảnh: Derived Column - Expression Editor (nếu cần)]**

**Bước 3 – Derived Column: "Add Metadata"**

**Ý nghĩa:** Bổ sung thông tin source để audit.

```
source_system = "SQL Server"
source_database = "purchasing&sales"
source_table = "Sales.Invoices"
load_date = GETDATE()
batch_id = @BatchID
```

> **[Chèn ảnh: Derived Column - Add Metadata]**

**Bước 4 – OLE DB Destination: "Insert into Staging.Invoices"**

**Ý nghĩa:** Chèn dữ liệu hóa đơn vào bảng Staging.

**Cấu hình:**
- **Connection Manager:** wwi_staging_area
- **Table:** `[dbo].[Invoices]`
- **Truncate table:** Tùy theo chiến lược (Full reload vs Incremental)
  - Full reload: Truncate trước khi nạp (nạp lại toàn bộ mỗi lần)
  - Incremental: Không truncate, có thể dùng MERGE hoặc DELETE-INSERT để cập nhật

**Mapping cột:**

```sql
INSERT INTO [Staging].[Invoices]
(
    wwi_invoice_id,
    wwi_customer_id,
    invoice_date,
    due_date,
    delivery_date,
    salesperson_id,
    contact_person_id,
    billing_address_id,
    shipping_address_id,
    invoice_line_count,
    total_dry_items,
    total_chiller_items,
    comments,
    delivery_instructions,
    internal_comments,
    picking_completed_when,
    payment_method,
    accounts_person_id,
    last_edited_by,
    last_edited_when,
    confirmed_delivery_time,
    source_system,
    source_database,
    source_table,
    load_date,
    batch_id
)
VALUES (...)
```

**Xử lý lỗi:**
- Nếu SQL Server database không accessible → Error kết nối
- Nếu query không hợp lệ → Parse error
- Nếu dữ liệu quá lớn (ví dụ Comments chứa text rất dài) → Truncation error, có thể ghi vào Error Output

> **[Chèn ảnh: OLE DB Destination - Mapping cột]**

---

## C. NGUỒN 3: POSTGRESQL - BẢNG STOCK_ITEMS (PostgreSQL Warehouse Database)

### Tổng quan

Bảng `Stock_Items` chứa dữ liệu sản phẩm được quản lý trong cơ sở dữ liệu PostgreSQL (hệ thống kho bên ngoài). Dữ liệu này được nạp vào Staging để tích hợp với dữ liệu sản phẩm từ SQL Server.

**Đặc điểm của PostgreSQL:**
- Cơ sở dữ liệu mã nguồn mở, có định dạng khác SQL Server (kiểu dữ liệu, hàm, v.v.)
- Truy cập thông qua ODBC Driver cho PostgreSQL
- Cần cấu hình DSN (Data Source Name) trước
- Dữ liệu có thể có mã hóa UTF-8 khác SQL Server

### Data Flow Task – Luồng xử lý dữ liệu

> **[Chèn ảnh: Load_Staging (PostgreSQL Source) - Data Flow Designer - ODBC Source → Data Conversion → OLE DB Destination (Staging)]**

**Bước 1 – ODBC Source: "Read Stock Items from PostgreSQL"**

**Ý nghĩa:** Đọc dữ liệu sản phẩm từ bảng `stock_items` trong PostgreSQL thông qua ODBC driver.

**Cấu hình Connection Manager:**
- **Type:** ODBC Connection Manager
- **DSN (Data Source Name):** postgres_ssis (tên DSN đã được cấu hình trên máy)
- **Database:** warehouse_db (hoặc tên database PostgreSQL)
- **User/Password:** Thông tin đăng nhập PostgreSQL

**SQL Query:**

```sql
SELECT 
    stock_item_id,                  -- ID sản phẩm
    stock_item_name,                -- Tên sản phẩm
    category_name,                  -- Danh mục sản phẩm
    brand_name,                     -- Thương hiệu
    supplier_id,                    -- ID nhà cung cấp
    unit_price,                     -- Giá bán lẻ
    unit_cost,                      -- Giá vốn
    reorder_level,                  -- Mức đặt hàng lại
    reorder_quantity,               -- Số lượng đặt hàng lại
    quantity_on_hand,               -- Tồn kho hiện tại
    last_stock_check_date,          -- Ngày kiểm kho cuối
    discontinued_flag,              -- Flag hàng khai trừ (0/1)
    created_at,                     -- Ngày tạo
    updated_at                      -- Ngày cập nhật cuối
FROM public.stock_items
WHERE discontinued_flag = 0
    AND created_at >= DATE_TRUNC('day', NOW() - INTERVAL '30 days')
ORDER BY stock_item_id
```

**Ghi chú:**
- **WHERE clause (lọc):**
  - `discontinued_flag = 0` — Chỉ lấy sản phẩm còn bán (không khai trừ)
  - `created_at >= DATE_TRUNC('day', NOW() - INTERVAL '30 days')` — Lấy sản phẩm được tạo/cập nhật trong 30 ngày gần nhất (incremental load)
- **Hàm PostgreSQL:**
  - `DATE_TRUNC()` — Hàm riêng của PostgreSQL (khác với SQL Server DATEPART)
  - `NOW()` — Hàm lấy thời gian hiện tại (tương đương GETDATE() trong SQL Server)
  - `INTERVAL '30 days'` — Cách PostgreSQL biểu diễn khoảng thời gian

**Thách thức với PostgreSQL:**
- Cú pháp SQL khác SQL Server (cần chuyển đổi query)
- Encoding: PostgreSQL thường dùng UTF-8, SQL Server có thể dùng encoding khác → cần xử lý ký tự đặc biệt
- Kiểu dữ liệu: `TIMESTAMP`, `SMALLINT`, `NUMERIC`, v.v. khác SQL Server

> **[Chèn ảnh: ODBC Source - SQL Command editor với syntax PostgreSQL]**

**Bước 2 – Data Conversion: "Convert PostgreSQL Data Types"**

**Ý nghĩa:** Chuyển đổi kiểu dữ liệu từ PostgreSQL sang SQL Server để đảm bảo tương thích trong Staging.

**Chuyển đổi cần thiết:**

```
stock_item_id (PostgreSQL: INTEGER) → INT
  → Giữ nguyên

stock_item_name (PostgreSQL: TEXT) → VARCHAR(255)
  → Nếu TEXT chứa UTF-8, đảm bảo VARCHAR hoặc NVARCHAR hỗ trợ Unicode

category_name (PostgreSQL: VARCHAR(50)) → VARCHAR(100)
  → Mở rộng để tương thích SQL Server schema

unit_price (PostgreSQL: NUMERIC(10,2)) → DECIMAL(10,2)
  → Chuyển đổi định dạng số thập phân

quantity_on_hand (PostgreSQL: NUMERIC) → DECIMAL(10,2)
  → Nếu PostgreSQL cho phép number lớn tùy ý, cần định rõ precision

last_stock_check_date (PostgreSQL: DATE) → DATE
  → Giữ nguyên, không cần TIME component

discontinued_flag (PostgreSQL: SMALLINT 0/1) → BIT
  → Chuyển 0 → false, 1 → true (hoặc giữ nguyên INT 0/1)

created_at (PostgreSQL: TIMESTAMP) → DATETIME2
  → Chuyển đổi timestamp PostgreSQL sang DATETIME2 SQL Server
  
updated_at (PostgreSQL: TIMESTAMP) → DATETIME2
  → Tương tự created_at
```

> **[Chèn ảnh: Data Conversion - Conversion tab]**

**Bước 3 – Character Map / Encoding Fix (nếu cần)**

**Ý nghĩa:** Xử lý ký tự đặc biệt hoặc encoding khác nhau.

**Ghi chú:** Nếu dữ liệu từ PostgreSQL chứa ký tự Việt Nam (ả, ế, ữ, v.v.), cần đảm bảo:
- ODBC Driver được cấu hình với UTF-8 encoding
- SQL Server Database/Table được cấu hình hỗ trợ NVARCHAR (Unicode)
- Không dùng VARCHAR (chỉ hỗ trợ 1 code page)

> **[Chèn ảnh: Advanced ODBC settings - Character Set configuration]**

**Bước 4 – Derived Column: "Add Metadata"**

**Ý nghĩa:** Bổ sung thông tin source.

```
source_system = "PostgreSQL"
source_database = "warehouse_db"
source_table = "public.stock_items"
load_date = GETDATE()
batch_id = @BatchID
pg_sync_timestamp = updated_at
  → Ghi nhận thời điểm cập nhật từ PostgreSQL, dùng cho next incremental load
```

> **[Chèn ảnh: Derived Column - Add Metadata]**

**Bước 5 – OLE DB Destination: "Insert into Staging.StockItems"**

**Ý nghĩa:** Chèn dữ liệu sản phẩm từ PostgreSQL vào Staging.

**Cấu hình:**
- **Connection Manager:** wwi_staging_area
- **Table:** `[dbo].[StockItems]`
- **Truncate table:** Tùy chiến lược (Full reload vs Incremental)

**Mapping cột:**

```sql
INSERT INTO [Staging].[StockItems]
(
    stock_item_id,
    stock_item_name,
    category_name,
    brand_name,
    supplier_id,
    unit_price,
    unit_cost,
    reorder_level,
    reorder_quantity,
    quantity_on_hand,
    last_stock_check_date,
    discontinued_flag,
    created_at,
    updated_at,
    source_system,
    source_database,
    source_table,
    load_date,
    batch_id,
    pg_sync_timestamp
)
VALUES (...)
```

**Xử lý lỗi:**
- Nếu ODBC DSN không tồn tại → Error kết nối
- Nếu credentials sai → Authentication error
- Nếu PostgreSQL server down → Timeout error
- Nếu encoding khác nhau gây corrupted data → Dòng lỗi hoặc Truncation warning

> **[Chèn ảnh: OLE DB Destination - Mapping cột]**

---

## PHẦN III: CẤU TRÚC BẢNG STAGING

### Bảng Staging.Employees

```sql
CREATE TABLE [dbo].[Employees] (
    employee_key INT IDENTITY(1,1) PRIMARY KEY,
    wwi_employee_id INT,
    employee_name VARCHAR(255),
    job_title VARCHAR(100),
    department_name VARCHAR(100),
    manager_employee_id INT NULL,
    hire_date DATE,
    salary DECIMAL(10,2),
    is_active BIT,
    source_system VARCHAR(50),
    source_file VARCHAR(255),
    load_date DATETIME2,
    batch_id INT
);

-- Ghi chú:
-- employee_key: Surrogate key để dễ track trong kho dữ liệu
-- wwi_employee_id: ID gốc từ source (Excel)
-- source_system, source_file, load_date, batch_id: Metadata để audit
```

### Bảng Staging.Invoices

```sql
CREATE TABLE [dbo].[Invoices] (
    invoice_key INT IDENTITY(1,1) PRIMARY KEY,
    wwi_invoice_id INT,
    wwi_customer_id INT,
    invoice_date DATE,
    due_date DATE,
    delivery_date DATE,
    salesperson_id INT,
    contact_person_id INT NULL,
    billing_address_id INT NULL,
    shipping_address_id INT NULL,
    invoice_line_count INT,
    total_dry_items INT,
    total_chiller_items INT,
    comments NVARCHAR(MAX) NULL,
    delivery_instructions NVARCHAR(MAX) NULL,
    payment_method VARCHAR(50),
    confirmed_delivery_time DATETIME2 NULL,
    source_system VARCHAR(50),
    source_database VARCHAR(100),
    source_table VARCHAR(100),
    load_date DATETIME2,
    batch_id INT
);

-- Ghi chú:
-- invoice_key: Surrogate key
-- wwi_invoice_id, wwi_customer_id: ID gốc từ source (SQL Server)
-- Các trường ngày tháng đã convert thành DATE (không cần TIME)
```

### Bảng Staging.StockItems

```sql
CREATE TABLE [dbo].[StockItems] (
    stock_item_key INT IDENTITY(1,1) PRIMARY KEY,
    stock_item_id INT,
    stock_item_name VARCHAR(255),
    category_name VARCHAR(100),
    brand_name VARCHAR(100),
    supplier_id INT,
    unit_price DECIMAL(10,2),
    unit_cost DECIMAL(10,2),
    reorder_level DECIMAL(10,2),
    reorder_quantity DECIMAL(10,2),
    quantity_on_hand DECIMAL(10,2),
    last_stock_check_date DATE,
    discontinued_flag BIT,
    created_at DATETIME2,
    updated_at DATETIME2,
    source_system VARCHAR(50),
    source_database VARCHAR(100),
    source_table VARCHAR(100),
    load_date DATETIME2,
    batch_id INT,
    pg_sync_timestamp DATETIME2
);

-- Ghi chú:
-- stock_item_key: Surrogate key
-- stock_item_id: ID gốc từ source (PostgreSQL)
-- pg_sync_timestamp: Lưu trữ updated_at từ PostgreSQL, dùng cho incremental load tiếp theo
```

---

## PHẦN IV: CÔNG THỨC TÍNH TOÁN TRONG DATA FLOW

### Derived Column - Metadata (chung cho cả 3 bảng)

**Công thức tạo Batch ID:**

```
batch_id = YEAR(GETDATE()) * 1000000 
         + MONTH(GETDATE()) * 10000 
         + DAY(GETDATE()) * 100 
         + DATEPART(HOUR, GETDATE())

Ví dụ: Nếu chạy ETL lúc 21/05/2026 09:30 → batch_id = 20260521 09 = 2026052109
Lợi ích: Dễ nhận ra khi ETL được chạy, hỗ trợ audit trail
```

**Công thức Hash Record (tùy chọn, dùng để phát hiện thay đổi):**

```
record_hash = HASHBYTES('MD5', CONCAT(
    CAST(wwi_employee_id AS VARCHAR),
    '|',
    employee_name,
    '|',
    CAST(hire_date AS VARCHAR)
))

Ví dụ: Nếu employee_id=1, name="John Doe", hire_date=2020-01-15
→ Hash = MD5("1|John Doe|2020-01-15") = "a1b2c3d4e5f6..."
Lợi ích: So sánh hash của dữ liệu cũ vs mới để phát hiện dữ liệu có thay đổi không
```

---

## PHẦN V: SO SÁNH 3 NGUỒN

| Đặc điểm | Excel | SQL Server | PostgreSQL |
|---------|-------|-----------|-----------|
| **Định dạng** | File bảng tính | Cơ sở dữ liệu quan hệ | Cơ sở dữ liệu quan hệ |
| **Kết nối** | Excel Connection Manager | OLE DB Connection Manager | ODBC Driver |
| **Kiểu dữ liệu** | Không rõ ràng, thường là Text/Variant | Rõ ràng, chuẩn SQL Server | Rõ ràng, chuẩn PostgreSQL |
| **Cần Convert** | Có, thường phức tạp | Ít, có thể nạp trực tiếp | Có, khác SQL Server |
| **Encoding** | Phụ thuộc Excel version (ANSI/UTF-8) | SQL Server encoding | UTF-8 (mặc định) |
| **Query/Filter** | Giới hạn, SELECT từ sheet | SQL query đầy đủ | SQL query PostgreSQL |
| **Incremental Load** | Khó (không có timestamp) | Dễ (có last_edited_when) | Dễ (có updated_at) |
| **Thách thức chính** | Dữ liệu không sạch, manual entry | Schema phức tạp có thể | Syntax khác, encoding |
| **Tốc độ** | Chậm (file I/O) | Nhanh (network query) | Trung bình (ODBC overhead) |

---

## PHẦN VI: KIỂM CHỨNG DỮ LIỆU SAU KHI LOAD STAGING

Sau khi load xong, có thể chạy các câu SQL kiểm chứng:

```sql
-- Kiểm tra số lượng dòng load từ mỗi bảng
SELECT 
    'Employees' as table_name, COUNT(*) as record_count FROM [Staging].[Employees]
UNION ALL
SELECT 
    'Invoices' as table_name, COUNT(*) as record_count FROM [Staging].[Invoices]
UNION ALL
SELECT 
    'StockItems' as table_name, COUNT(*) as record_count FROM [Staging].[StockItems]
;

-- Kiểm tra dữ liệu NULL (nên có từ 0-5% NULL nếu bình thường)
SELECT 
    column_name,
    COUNT(*) as null_count,
    CAST(100.0 * COUNT(*) / (SELECT COUNT(*) FROM [Staging].[Employees]) AS DECIMAL(5,2)) as null_percent
FROM [Staging].[Employees]
WHERE employee_name IS NULL OR hire_date IS NULL OR salary IS NULL
GROUP BY column_name;

-- Kiểm tra dữ liệu duplicate
SELECT 
    wwi_employee_id,
    COUNT(*) as duplicate_count
FROM [Staging].[Employees]
GROUP BY wwi_employee_id
HAVING COUNT(*) > 1;

-- Kiểm tra load_date
SELECT 
    MIN(load_date) as earliest_load,
    MAX(load_date) as latest_load,
    COUNT(DISTINCT batch_id) as total_batches
FROM [Staging].[Employees];
```

---

**HẾT BÁNG CÁO LOAD STAGING CHI TIẾT**
