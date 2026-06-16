# Dự án ETL SSIS - WideWorldImposter

## Mô tả dự án
Dự án này triển khai quy trình ETL (Extract, Transform, Load) cho kho dữ liệu Wide World Importers sử dụng SQL Server Integration Services (SSIS). Dự án bao gồm việc tải dữ liệu từ nhiều nguồn (Excel, SQL Server, PostgreSQL) vào staging area, sau đó populate các bảng dimension và fact trong data warehouse.

## Kiến trúc tổng quan
- **Master Package**: `Master_ETL.dtsx` - Điều phối toàn bộ quy trình ETL
- **Staging**: `Load_Staging.dtsx` - Tải dữ liệu từ nguồn vào staging area
- **Dimensions**: 5 package tải các bảng dimension (Product, Supplier, Customer, Employee, City)
- **Facts**: 3 package tải các bảng fact (Sale, Purchase, Inventory)
- **Aggregation**: `Load_Agg_Fact.dtsx` - Tạo các bảng tổng hợp

## Yêu cầu hệ thống
- SQL Server (có thể là SQL Server Express)
- SQL Server Integration Services (SSIS)
- Visual Studio với SQL Server Data Tools (SSDT) hoặc Visual Studio 2019+
- Microsoft Access Database Engine 2016 Redistributable (cho Excel)
- PostgreSQL ODBC driver
- ODBC DSN tên `postgres_ssis` cấu hình kết nối đến PostgreSQL

## Cài đặt
1. Clone hoặc tải dự án về máy
2. Mở file `WideWorldImposter.sln` trong Visual Studio
3. Kiểm tra các connection managers trong từng package:
   - SQL Server: `localhost` (có thể cần thay đổi nếu không dùng local)
   - Excel: `D:\ssms2postgre\file backup\application.xlsx`
   - PostgreSQL: DSN `postgres_ssis`

## Chạy dự án
### Chạy toàn bộ ETL
1. Mở `Master_ETL.dtsx` trong Visual Studio
2. Nhấn F5 hoặc click "Start" để chạy
3. Theo dõi tiến trình trong Execution Results

### Chạy từng package riêng lẻ
1. Mở package mong muốn (vd: `Load_Staging.dtsx`)
2. Nhấn F5 để chạy
3. Kiểm tra kết quả trong database đích

## Chi tiết các package

### Master_ETL.dtsx
Điều phối 10 package con theo thứ tự:
1. Load_Staging
2. Load_Dim_Product
3. Load_Dim_Supplier
4. Load_Dim_Customer
5. Load_Dim_Employee
6. Load_Dim_City
7. Load_Fact_Sale
8. Load_Fact_Purchase
9. Load_Fact_Inventory
10. Load_Agg_Fact

### Load_Staging.dtsx
- Nguồn: Excel, SQL Server, PostgreSQL
- Đích: `wwi_staging_area`
- Tải dữ liệu thô từ các hệ thống nguồn

### Các package Dimension
- **Load_Dim_Product.dtsx**: Tải bảng sản phẩm
- **Load_Dim_Supplier.dtsx**: Tải bảng nhà cung cấp (SCD Type 2)
- **Load_Dim_Customer.dtsx**: Tải bảng khách hàng
- **Load_Dim_Employee.dtsx**: Tải bảng nhân viên
- **Load_Dim_City.dtsx**: Tải bảng thành phố

### Các package Fact
- **Load_Fact_Sale.dtsx**: Tải dữ liệu bán hàng
- **Load_Fact_Purchase.dtsx**: Tải dữ liệu mua hàng
- **Load_Fact_Inventory.dtsx**: Tải dữ liệu tồn kho

### Load_Agg_Fact.dtsx
Tạo 3 bảng tổng hợp:
- AGG_INVENTORY_WEEKLY
- AGG_SALES_DAILY
- AGG_SALES_PRODUCT_CITY_DAILY

## Cấu trúc database
- **Staging**: `wwi_staging_area`
- **Data Warehouse**: `wwi_data_warehouse`
- **Financial**: `financial_data_warehouse` (dùng cho supplier)

## Lưu ý quan trọng
- Đảm bảo đường dẫn Excel file chính xác
- Kiểm tra DSN PostgreSQL được cấu hình đúng
- Nếu chạy trên server khác localhost, cập nhật connection strings
- Package sử dụng Integrated Security, đảm bảo quyền truy cập database
- Một số package có SCD (Slowly Changing Dimension) logic

## Triển khai production
1. Build project thành file .ispac
2. Deploy lên SSIS Catalog trong SQL Server
3. Tạo Environment và cấu hình connection strings
4. Lên lịch chạy bằng SQL Server Agent

## Troubleshooting
- Nếu lỗi kết nối Excel: cài đặt Access Database Engine
- Nếu lỗi PostgreSQL: kiểm tra DSN và driver ODBC
- Nếu lỗi permission: chạy Visual Studio as Administrator hoặc cấu hình SQL login

## Liên hệ
Dự án học thuật - Khoa CNTT, Học viện Ngân hàng