# 📦 Wide World Importers — Data Warehouse & ETL Pipeline

<div align="center">

![SSIS](https://img.shields.io/badge/SSIS-SQL%20Server%20Integration%20Services-CC2927?style=for-the-badge&logo=microsoft-sql-server&logoColor=white)
![SQL Server](https://img.shields.io/badge/SQL%20Server-T--SQL-CC2927?style=for-the-badge&logo=microsoft-sql-server&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Source-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)
![Excel](https://img.shields.io/badge/Excel-Source-217346?style=for-the-badge&logo=microsoft-excel&logoColor=white)
![Grade](https://img.shields.io/badge/Grade-A%2B-gold?style=for-the-badge)

**Xây dựng kho dữ liệu theo mô hình Star Schema và pipeline ETL tự động bằng SSIS**  
*Banking Academy of Vietnam — Data Warehouse | 2026*

</div>

---

## 📌 Overview

Dự án thiết kế và triển khai hệ thống **Data Warehouse** cho bộ dữ liệu Wide World Importers — một công ty nhập khẩu và phân phối hàng hóa. Toàn bộ pipeline ETL được xây dựng bằng **SQL Server Integration Services (SSIS)**, tích hợp dữ liệu từ ba nguồn khác nhau vào một kho dữ liệu tập trung phục vụ phân tích đa chiều.

| Item | Detail |
|------|--------|
| 📅 Period | 03/2026 – 05/2026 |
| 🎓 Grade | **A+** |
| 👤 Role | Team Leader |
| 🏫 School | Banking Academy of Vietnam |
| 📐 Schema | Star Schema |
| 📊 Dimensions | 5 bảng DIM (+ 1 DIM_DATE) |
| 📈 Facts | 3 bảng FACT |
| 🔄 ETL | 11 packages SSIS |
| 🔁 SCD | Slowly Changing Dimension Type 2 |

---

## 🏛️ Kiến trúc Kho Dữ Liệu

Hệ thống được xây dựng theo mô hình **ETL ba tầng**:

```
[Nguồn dữ liệu]        [Staging Area]         [Data Warehouse]
  Excel (.xlsx)    →   wwi_staging_area    →   wwi_data_warehouse
  SQL Server OLTP                              financial_data_warehouse
  PostgreSQL
```

| Tầng | Database | Vai trò |
|------|----------|---------|
| **Nguồn** | `purchasing&sales`, `sales_purchasing`, Excel, PostgreSQL | Dữ liệu giao dịch thô từ nhiều hệ thống |
| **Staging** | `wwi_staging_area` | Vùng trung gian — làm sạch, chuẩn hóa và tích hợp |
| **Data Warehouse** | `wwi_data_warehouse`, `financial_data_warehouse` | Kho dữ liệu phân tích cuối cùng (Star Schema) |

---

## 📐 Star Schema — Thiết kế bảng DIM và FACT

### Sơ đồ tổng quan

```
                        ┌─────────────┐
                        │  DIM_DATE   │
                        │  (date_key) │
                        └──────┬──────┘
                               │
┌──────────────┐    ┌──────────┴───────────┐    ┌───────────────┐
│ DIM_CUSTOMER │    │      FACT_SALE        │    │  DIM_PRODUCT  │
│(customer_key)├────┤  invoice_line_id (PK) ├────┤ (product_key) │
└──────────────┘    │  customer_key   (FK)  │    └───────────────┘
                    │  product_key    (FK)  │
┌──────────────┐    │  employee_key   (FK)  │    ┌─────────────┐
│ DIM_EMPLOYEE │    │  date_key       (FK)  │    │  DIM_CITY   │
│(employee_key)├────┤  city_key       (FK)  ├────┤  (city_key) │
└──────────────┘    │  quantity             │    └─────────────┘
                    │  unit_price           │
                    │  net_sales_amount     │
                    │  gross_profit_amount  │
                    └───────────────────────┘

                    ┌───────────────────────┐
                    │     FACT_PURCHASE      │
┌──────────────┐    │  purchase_order_line  │    ┌───────────────┐
│ DIM_SUPPLIER ├────┤  supplier_key   (FK)  ├────┤  DIM_PRODUCT  │
│(supplier_key)│    │  product_key    (FK)  │    │ (product_key) │
└──────────────┘    │  date_key       (FK)  │    └───────────────┘
                    │  ordered_quantity     │
                    │  received_quantity    │
                    │  purchase_amount      │
                    │  variance_amount      │
                    │  delivery_days        │
                    └───────────────────────┘

                    ┌───────────────────────┐
                    │    FACT_INVENTORY      │
                    │  transaction_id  (PK) │
                    │  product_key    (FK)  │
                    │  date_key       (FK)  │
                    │  customer_key   (FK)  │
                    │  supplier_key   (FK)  │
                    │  quantity_in          │
                    │  quantity_out         │
                    │  transaction_value    │
                    │  stock_value          │
                    └───────────────────────┘
```

---

## 🗂️ Chi tiết các bảng DIMENSION

### DIM_PRODUCT — Bảng chiều Sản phẩm

| Cột | Kiểu | Ghi chú |
|-----|------|---------|
| `product_key` | int (IDENTITY) | 🔑 Surrogate Key |
| `wwi_stock_item_id` | int | Business Key từ nguồn |
| `stock_item_name` | nvarchar(255) | Tên sản phẩm |
| `color` | nvarchar(20) | Màu sắc |
| `selling_package` | nvarchar(50) | Đơn vị đóng gói bán lẻ |
| `buying_package` | nvarchar(50) | Đơn vị đóng gói mua |
| `brand` | nvarchar(50) | Thương hiệu |
| `size` | nvarchar(20) | Kích thước |
| `unit_price` | decimal(18,2) | Đơn giá bán |
| `tax_rate` | decimal(18,3) | Thuế suất |
| `is_chiller_stock` | bit | Hàng lạnh |
| `package_type` | nvarchar(50) | Loại đóng gói |
| `leading_supplier_id` | int | FK → DIM_SUPPLIER |
| `valid_from` | datetime | SCD Type 2 — bắt đầu hiệu lực |
| `valid_to` | datetime | SCD Type 2 — kết thúc (NULL = hiện tại) |
| `is_current` | int | 1 = bản ghi hiện hành |
| `lineage_key` | int | Audit tracking |

**Nguồn:** `Warehouse.StockItems`, `Colors`, `PackageTypes`

---

### DIM_SUPPLIER — Bảng chiều Nhà cung cấp

| Cột | Kiểu | Ghi chú |
|-----|------|---------|
| `supplier_key` | int (IDENTITY) | 🔑 Surrogate Key |
| `wwi_supplier_id` | int | Business Key từ nguồn |
| `supplier_name` | nvarchar(255) | Tên nhà cung cấp |
| `supplier_category` | nvarchar(255) | Loại nhà cung cấp |
| `payment_days` | int | Số ngày thanh toán (từ financial_data_warehouse) |
| `valid_from` | datetime | SCD Type 2 |
| `valid_to` | datetime | SCD Type 2 |
| `is_current` | int | 1 = hiện hành |
| `lineage_key` | int | Audit tracking |

**Nguồn:** `Purchasing.Suppliers`, `SupplierCategories`, `financial_data_warehouse`  
> 💡 **Điểm đặc biệt:** Package này tích hợp thêm dữ liệu tài chính từ `financial_data_warehouse` để làm giàu thông tin nhà cung cấp.

---

### DIM_CUSTOMER — Bảng chiều Khách hàng

| Cột | Kiểu | Ghi chú |
|-----|------|---------|
| `customer_key` | int (IDENTITY) | 🔑 Surrogate Key |
| `wwi_customer_id` | int | Business Key từ nguồn |
| `customer_name` | nvarchar(255) | Tên khách hàng |
| `bill_to_customer` | nvarchar(255) | Khách hàng nhận hóa đơn |
| `customer_category` | nvarchar(255) | Phân loại khách hàng |
| `buying_group` | nvarchar(255) | Nhóm mua hàng |
| `primary_contact` | nvarchar(255) | Người liên hệ chính |
| `postal_code` | nvarchar(255) | Mã bưu chính |
| `valid_from` | datetime | SCD Type 2 |
| `valid_to` | datetime | SCD Type 2 |
| `is_current` | int | 1 = hiện hành |
| `lineage_key` | int | Audit tracking |

**Nguồn:** `Sales.Customers`, `BuyingGroups`, `CustomerCategories`, `Application.People`

---

### DIM_EMPLOYEE — Bảng chiều Nhân viên

| Cột | Kiểu | Ghi chú |
|-----|------|---------|
| `employee_key` | int (IDENTITY) | 🔑 Surrogate Key |
| `wwi_employee_id` | int | Business Key từ nguồn |
| `employee_name` | nvarchar(255) | Tên nhân viên |
| `preferred_name` | nvarchar(255) | Tên gọi thường dùng |
| `is_salesperson` | bit | Có phải nhân viên bán hàng |
| `valid_from` | datetime | SCD Type 2 |
| `valid_to` | datetime | SCD Type 2 |
| `is_current` | int | 1 = hiện hành |
| `lineage_key` | int | Audit tracking |

**Nguồn:** `Application.People`

---

### DIM_CITY — Bảng chiều Thành phố

| Cột | Kiểu | Ghi chú |
|-----|------|---------|
| `city_key` | int (IDENTITY) | 🔑 Surrogate Key |
| `wwi_city_id` | int | Business Key từ nguồn |
| `city_name` | nvarchar(255) | Tên thành phố |
| `state_province` | nvarchar(255) | Tỉnh/Bang |
| `country` | nvarchar(60) | Quốc gia |
| `continent` | nvarchar(30) | Châu lục |
| `sales_territory` | nvarchar(255) | Khu vực kinh doanh |
| `region` | nvarchar(30) | Vùng |
| `subregion` | nvarchar(30) | Tiểu vùng |
| `latest_recorded_population` | int | Dân số ghi nhận gần nhất |
| `valid_from` | datetime | SCD Type 2 |
| `valid_to` | datetime | SCD Type 2 |
| `is_current` | int | 1 = hiện hành |
| `lineage_key` | int | Audit tracking |

**Nguồn:** `Application.Cities`, `StateProvinces`, `Countries` (từ Excel)

---

## 📈 Chi tiết các bảng FACT

### FACT_SALE — Bảng sự kiện Bán hàng

Ghi nhận chi tiết từng dòng hóa đơn bán hàng, phục vụ phân tích doanh số đa chiều.

| Cột | Kiểu | Ghi chú |
|-----|------|---------|
| `invoice_line_id` | int | 🔑 Natural Key |
| `invoice_id` | int | Mã hóa đơn |
| `product_key` | int | 🔗 FK → DIM_PRODUCT |
| `customer_key` | int | 🔗 FK → DIM_CUSTOMER |
| `employee_key` | int | 🔗 FK → DIM_EMPLOYEE (salesperson) |
| `date_key` | int | 🔗 FK → DIM_DATE |
| `city_key` | int | 🔗 FK → DIM_CITY |
| `quantity` | int | Số lượng bán |
| `unit_price` | decimal(18,2) | Đơn giá |
| `line_total` | decimal(18,2) | Thành tiền gốc |
| `discount_percent` | decimal(18,3) | Tỉ lệ chiết khấu (%) |
| `discount_amount` | decimal(18,2) | Số tiền chiết khấu |
| `net_sales_amount` | decimal(18,2) | Doanh thu thực (sau chiết khấu) |
| `gross_profit_amount` | decimal(18,2) | Lợi nhuận gộp |
| `lineage_key` | int | Audit tracking |

**Nguồn:** `Sales.InvoiceLines` JOIN `Sales.Invoices`

**Metrics được tính:**
- `discount_amount = unit_price × quantity × (discount_percent / 100)`
- `net_sales_amount = line_total − discount_amount`
- `gross_profit_amount = net_sales_amount − (unit_cost × quantity)`

---

### FACT_PURCHASE — Bảng sự kiện Mua hàng

Ghi nhận chi tiết từng dòng đơn mua hàng, phục vụ phân tích chi phí và hiệu suất nhà cung cấp.

| Cột | Kiểu | Ghi chú |
|-----|------|---------|
| `purchase_order_line_id` | int | 🔑 Natural Key |
| `purchase_order_id` | int | Mã đơn mua hàng |
| `product_key` | int | 🔗 FK → DIM_PRODUCT |
| `supplier_key` | int | 🔗 FK → DIM_SUPPLIER |
| `date_key` | int | 🔗 FK → DIM_DATE (order_date) |
| `ordered_quantity` | int | Số lượng đặt mua |
| `received_quantity` | int | Số lượng thực nhận |
| `unit_price` | decimal(18,2) | Đơn giá mua |
| `purchase_amount` | decimal(18,2) | Giá trị đặt mua dự kiến |
| `received_amount` | decimal(18,2) | Giá trị thực nhận |
| `variance_amount` | decimal(18,2) | Chênh lệch tài chính (nhận − đặt) |
| `variance_qty` | int | Chênh lệch số lượng |
| `delivery_days` | int | Số ngày giao hàng (SLA) |
| `lineage_key` | int | Audit tracking |

**Nguồn:** `Purchasing.PurchaseOrderLines` JOIN `Purchasing.PurchaseOrders`

**Metrics được tính:**
- `purchase_amount = ordered_quantity × unit_price`
- `variance_amount = (received_quantity − ordered_quantity) × unit_price`
- `delivery_days = DATEDIFF(DAY, order_date, delivery_date)`

---

### FACT_INVENTORY — Bảng sự kiện Tồn kho

Ghi nhận từng giao dịch nhập/xuất kho, phục vụ phân tích vòng quay tồn kho và báo cáo tài chính.

| Cột | Kiểu | Ghi chú |
|-----|------|---------|
| `stock_item_transaction_id` | int | 🔑 Natural Key |
| `product_key` | int | 🔗 FK → DIM_PRODUCT |
| `date_key` | int | 🔗 FK → DIM_DATE |
| `customer_key` | int | 🔗 FK → DIM_CUSTOMER (nếu giao dịch xuất bán) |
| `supplier_key` | int | 🔗 FK → DIM_SUPPLIER (nếu giao dịch nhập mua) |
| `transaction_type_id` | int | Loại giao dịch (1=nhập, 2=xuất) |
| `quantity` | int | Số lượng giao dịch |
| `unit_price` | decimal(18,2) | Đơn giá |
| `quantity_in` | int | Số lượng nhập kho |
| `quantity_out` | int | Số lượng xuất kho |
| `transaction_value` | decimal(18,2) | Giá trị giao dịch |
| `quantity_on_hand` | int | Tồn kho tại thời điểm giao dịch |
| `stock_value` | decimal(18,2) | Giá trị tồn kho tài chính |
| `holding_location` | nvarchar(20) | Vị trí lưu kho (bin_location) |
| `lineage_key` | int | Audit tracking |

**Nguồn:** `Warehouse.StockItemTransactions` LEFT JOIN `Warehouse.StockItemHoldings`

**Metrics được tính:**
- `quantity_in = CASE WHEN transaction_type_id = 1 THEN quantity ELSE 0 END`
- `quantity_out = CASE WHEN transaction_type_id = 2 THEN ABS(quantity) ELSE 0 END`
- `stock_value = quantity_on_hand × unit_cost`

---

## 🔄 Luồng đổ dữ liệu ETL

### Thứ tự thực thi (Master_ETL.dtsx)

```
Load_Staging
    ↓ (Success)
Load_Dim_Product
    ↓ (Success)
Load_Dim_Supplier
    ↓ (Success)
Load_Dim_Customer
    ↓ (Success)
Load_Dim_Employee
    ↓ (Success)
Load_Dim_City
    ↓ (Success)
Load_Fact_Sale
    ↓ (Success)
Load_Fact_Purchase
    ↓ (Success)
Load_Fact_Inventory
    ↓ (Success)
Load_Agg_Fact
```

> **Tại sao theo thứ tự này?** Staging phải chạy trước để có dữ liệu thô. Dimensions phải nạp trước Facts vì Facts cần tra cứu (Lookup) surrogate keys từ các bảng DIM. Aggregations chạy sau cùng vì cần tổng hợp từ Facts.

---

### Pattern xử lý Dimension — SCD Type 2

Tất cả 5 package DIM đều áp dụng pattern chuẩn sau:

```
OLE DB Source          →  đọc dữ liệu từ Staging
    ↓
Slowly Changing Dim    →  phân loại bản ghi
    ↓            ↓              ↓
  New        Changed       Unchanged
  Records    Records       Records
    ↓            ↓              ↓
            Derived Col       OLE DB Command
            (valid_from,      (UPDATE inferred
            is_current=1)      members)
            OLE DB Command
            (UPDATE valid_to
            bản ghi cũ)
    ↓            ↓
         Union All
              ↓
         Derived Col
         (lineage_key,
          valid_from)
              ↓
         OLE DB Destination
         (INSERT vào DIM_*)
```

**SCD Type 2 đảm bảo:**
- Expire bản ghi cũ: `SET valid_to = GETDATE(), is_current = 0`
- Insert bản ghi mới: `valid_from = GETDATE(), valid_to = NULL, is_current = 1`
- Bảo toàn toàn bộ lịch sử thay đổi

---

### Luồng dữ liệu tổng thể

```
📁 NGUỒN DỮ LIỆU
├── 📊 application.xlsx (Excel ACE.OLEDB.16.0)
│   └── Cities, StateProvinces, Countries, People
├── 🗄️ SQL Server OLTP (purchasing&sales, sales_purchasing)
│   └── Customers, Suppliers, StockItems, Invoices, PurchaseOrders, ...
└── 🐘 PostgreSQL (DSN: postgres_ssis)
    └── StockItemHoldings, Colors, PackageTypes
          ↓ Load_Staging
🔄 STAGING AREA (wwi_staging_area)
    ↓ Load_Dim_*                     ↓ Load_Fact_* (Lookup → DIM keys)
🏛️ DATA WAREHOUSE (wwi_data_warehouse)
├── 📍 DIM_CITY, DIM_CUSTOMER, DIM_EMPLOYEE, DIM_PRODUCT, DIM_SUPPLIER
├── 📈 FACT_SALE, FACT_PURCHASE, FACT_INVENTORY
└── 📊 AGG_SALES_DAILY, AGG_INVENTORY_WEEKLY, AGG_SALES_PRODUCT_CITY_DAILY
```

---

## 📊 Bảng tổng hợp (Aggregations)

| Bảng | Mục đích | Nhóm theo |
|------|----------|-----------|
| `AGG_SALES_DAILY` | Tổng doanh thu, lợi nhuận theo ngày | `date_key` |
| `AGG_INVENTORY_WEEKLY` | Tổng nhập/xuất kho theo tuần | `year_number`, `week_of_year`, `product_key` |
| `AGG_SALES_PRODUCT_CITY_DAILY` | Doanh thu theo sản phẩm × thành phố × ngày | `date_key`, `product_key`, `city_key` |

---

## 🗂️ Project Structure

```
SSIS-Data-Warehouse-ETL/
│
├── 📄 README.md
│
└── 📁 SSIS-Project/
    ├── 🔧 Master_ETL.dtsx              # Package điều phối tổng thể
    ├── 🔧 Load_Staging.dtsx            # Nạp dữ liệu thô vào Staging (~1.1MB)
    │
    ├── 📍 Load_Dim_City.dtsx           # SCD Type 2 — bảng chiều thành phố
    ├── 👥 Load_Dim_Customer.dtsx       # SCD Type 2 — bảng chiều khách hàng
    ├── 👤 Load_Dim_Employee.dtsx       # SCD Type 2 — bảng chiều nhân viên
    ├── 📦 Load_Dim_Product.dtsx        # SCD Type 2 — bảng chiều sản phẩm
    ├── 🏭 Load_Dim_Supplier.dtsx       # SCD Type 2 — bảng chiều nhà cung cấp
    │
    ├── 💰 Load_Fact_Sale.dtsx          # Bảng sự kiện bán hàng
    ├── 🛒 Load_Fact_Purchase.dtsx      # Bảng sự kiện mua hàng
    ├── 📦 Load_Fact_Inventory.dtsx     # Bảng sự kiện tồn kho
    ├── 📊 Load_Agg_Fact.dtsx           # Tạo các bảng tổng hợp AGG_*
    │
    ├── WideWorldImposter.sln           # Visual Studio solution file
    ├── WideWorldImposter.dtproj        # SSIS project file
    └── bin/Development/
        └── WideWorldImposter.ispac     # Deployment package
```

---

## 🛠️ Tech Stack

| Category | Technology |
|----------|------------|
| ETL Tool | SQL Server Integration Services (SSIS) 17.0 |
| Database | SQL Server (Data Warehouse + Staging) |
| Source DB | SQL Server OLTP, PostgreSQL |
| Source File | Microsoft Excel (.xlsx) |
| DW Design | Star Schema, SCD Type 2 |
| IDE | Visual Studio 2022 + SQL Server Data Tools (SSDT) |
| Drivers | ACE.OLEDB.16.0 (Excel), ODBC (PostgreSQL) |

---

## 🚀 Getting Started

### Prerequisites
- SQL Server (Express hoặc Standard)
- SQL Server Integration Services (SSIS)
- Visual Studio 2019+ với SSDT
- Microsoft Access Database Engine 2016 Redistributable
- PostgreSQL ODBC driver + DSN `postgres_ssis`

### Setup
```
1. Clone repo
2. Mở file SSIS-Project/WideWorldImposter.sln trong Visual Studio
3. Tạo các databases: wwi_staging_area, wwi_data_warehouse, financial_data_warehouse
4. Cập nhật Connection Managers:
   - SQL Server: localhost
   - Excel: đường dẫn đến file application.xlsx
   - PostgreSQL: DSN postgres_ssis
5. Chạy Master_ETL.dtsx để khởi động toàn bộ pipeline
```

---

## 📋 Thống kê

| Chỉ tiêu | Giá trị |
|---------|---------|
| Tổng số SSIS package | 11 (1 Master + 10 Child) |
| Số bảng Dimension | 5 + 1 DIM_DATE |
| Số bảng Fact | 3 |
| Số bảng Aggregation | 3 |
| Kỹ thuật SCD | Type 2 (lưu toàn bộ lịch sử) |
| Nguồn dữ liệu | Excel + SQL Server + PostgreSQL |
| Cơ chế audit | Integration.Lineage table |

---

## 🏫 About

| | |
|---|---|
| **Course** | Data Warehouse (Kho Dữ Liệu) |
| **Institution** | Banking Academy of Vietnam (Học viện Ngân hàng) |
| **Role** | Team Leader |
| **Period** | 03/2026 – 05/2026 |
| **Grade** | A+ |

---

## 👤 Author

**Lê Chí Anh Tú** — MIS Student @ Banking Academy of Vietnam  
🎓 Expected Graduation: 2027 &nbsp;|&nbsp; 📊 GPA: 3.7/4.0  
🔗 [GitHub](https://github.com/lcatu)

---

<p align="center"><i>Part of my Data Analytics Portfolio — <a href="https://github.com/lcatu">view all projects</a></i></p>