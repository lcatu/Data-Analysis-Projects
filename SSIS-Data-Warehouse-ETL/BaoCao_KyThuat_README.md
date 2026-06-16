# Báo cáo kỹ thuật SSIS ETL cho dự án WideWorldImposter

## 1. Tổng quan giải pháp
- Mục tiêu: Xây dựng quy trình ETL cho kho dữ liệu Wide World Importers bằng SSIS.
- Kiến trúc: `Master_ETL.dtsx` điều phối toàn bộ dòng dữ liệu, gồm:
  1. `Load_Staging.dtsx`
  2. `Load_Dim_Product.dtsx`
  3. `Load_Dim_Supplier.dtsx`
  4. `Load_Dim_Customer.dtsx`
  5. `Load_Dim_Employee.dtsx`
  6. `Load_Dim_City.dtsx`
  7. `Load_Fact_Sale.dtsx`
  8. `Load_Fact_Purchase.dtsx`
  9. `Load_Fact_Inventory.dtsx`
  10. `Load_Agg_Fact.dtsx`

## 2. Kiến trúc dữ liệu
- Source:
  - Excel: `D:\ssms2postgre\file backup\application.xlsx`
  - SQL Server `localhost`
  - PostgreSQL qua ODBC DSN `postgres_ssis`
- Staging:
  - Database `wwi_staging_area`
- Data Warehouse:
  - `wwi_data_warehouse`
  - Lưu ý: `Load_Dim_Supplier.dtsx` có thêm connection manager tới `financial_data_warehouse`
- Aggregation:
  - Bảng `dbo.AGG_INVENTORY_WEEKLY`
  - Bảng `dbo.AGG_SALES_DAILY`
  - Bảng `dbo.AGG_SALES_PRODUCT_CITY_DAILY`

## 3. Chi tiết `Master_ETL.dtsx`
- Là master package điều phối các gói con.
- Sử dụng 10 Execute Package Task.
- Luồng thực thi được xây dựng bằng Precedence Constraints:
  - `Load_Staging` → `Load_Dim_Product`
  - `Load_Dim_Product` → `Load_Dim_Supplier`
  - `Load_Dim_Supplier` → `Load_Dim_Customer`
  - `Load_Dim_Customer` → `Load_Dim_Employee`
  - `Load_Dim_Employee` → `Load_Dim_City`
  - `Load_Dim_City` → `Load_Fact_Sale`
  - `Load_Fact_Sale` → `Load_Fact_Purchase`
  - `Load_Fact_Purchase` → `Load_Fact_Inventory`
  - `Load_Fact_Inventory` → `Load_Agg_Fact`

## 4. `Load_Staging.dtsx`
#### Kết nối
- Excel: `Provider=Microsoft.ACE.OLEDB.16.0;Data Source=D:\ssms2postgre\file backup\application.xlsx;Extended Properties="EXCEL 12.0 XML;HDR=YES";`
- PostgreSQL: `uid=postgres;Dsn=postgres_ssis;`
- SQL Server:
  - `Data Source=localhost;Initial Catalog=purchasing&sales;...`
  - `Data Source=localhost;Initial Catalog=sales_purchasing;...`
  - `Data Source=localhost;Initial Catalog=wwi_data_warehouse;...`
  - `Data Source=localhost;Initial Catalog=wwi_staging_area;...`

#### Nguồn dữ liệu xử lý
- Excel worksheets trong file `application.xlsx`
- SQL Server tables trong các DB nguồn `purchasing&sales`, `sales_purchasing`
- PostgreSQL tables:
  - `warehouse.stockitemholdings`
  - `warehouse.colors`
  - `warehouse.stockitemstockgroups`
  - `warehouse.stockitemtransactions`
  - `warehouse.packagetypes`
  - `warehouse.stockgroups`
  - `warehouse.stockitems`

#### Vai trò
- Tải dữ liệu đầu vào vào staging area.
- Chuẩn bị dữ liệu cho các package dimensions và facts tiếp theo.

## 5. Các package dimension
#### `Load_Dim_City.dtsx`
- Nguồn: `Application.Cities`, `Application.StateProvinces`, `Application.Countries`
- Mục tiêu: populate `DIM_CITY`
- Cơ chế: dùng SCD Type 2 / lookup kiểm tra tồn tại và cập nhật dòng cũ nếu cần.

#### `Load_Dim_Customer.dtsx`
- Nguồn: `Sales.Customers`, `Sales.BuyingGroups`, `Sales.CustomerCategories`, `Application.People`, và join nội bộ `Sales.Customers`
- Mục tiêu: populate `DIM_CUSTOMER`
- Cơ chế: SCD Type 2 với xử lý thay đổi cấu trúc khách hàng/reseller.

#### `Load_Dim_Employee.dtsx`
- Nguồn: `Application.People`
- Mục tiêu: populate `DIM_EMPLOYEE`
- Cơ chế: load theo thuộc tính nhân viên, dùng lookup đối chiếu.

#### `Load_Dim_Product.dtsx`
- Nguồn: `Warehouse.StockItems`, `Warehouse.Colors`, `Warehouse.PackageTypes`
- Mục tiêu: populate `DIM_PRODUCT`
- Cơ chế: lookup và cập nhật/insert mới.

#### `Load_Dim_Supplier.dtsx`
- Nguồn: `Purchasing.Suppliers`, `Purchasing.SupplierCategories`
- Mục tiêu: populate `DIM_SUPPLIER`
- Cơ chế:
  - `OLE DB Command` cập nhật `valid_to` cho phiên bản cũ khi có thay đổi
  - `INSERT` bản ghi mới
  - `UPDATE` các giá trị hiện tại nếu chỉ có thay đổi thuộc tính không cần tạo bản ghi mới
- Thuộc tính đặc thù: `wwi_supplier_id`, `supplier_name`, `supplier_category`, `payment_days`, `valid_from`, `valid_to`, `is_current`

## 6. Các package fact
#### `Load_Fact_Inventory.dtsx`
- Nguồn:
  - `Warehouse.StockItemTransactions`
  - `Warehouse.StockItemHoldings`
- Tiền xử lý:
  - Derived Column tạo `date_key`
  - Derived Column tính `lineage_key`
- Lookup:
  - `DIM_DATE` trên `date_key`
  - `DIM_PRODUCT` trên `product_key`
- Mục tiêu: load `FACT_INVENTORY`

#### `Load_Fact_Purchase.dtsx`
- Nguồn:
  - `Purchasing.PurchaseOrders`
  - `Purchasing.PurchaseOrderLines`
  - `Warehouse.StockItems`
- Lookup:
  - `DIM_PRODUCT`
  - `DIM_SUPPLIER`
- Mục tiêu: load `FACT_PURCHASE`

#### `Load_Fact_Sale.dtsx`
- Nguồn:
  - `Sales.InvoiceLines`
  - `Sales.Invoices`
  - `Sales.Customers`
  - `Sales.Orders`
- Lookup:
  - `DIM_CITY`
  - `DIM_CUSTOMER`
  - `DIM_DATE`
  - `DIM_EMPLOYEE`
  - `DIM_PRODUCT`
- Mục tiêu: load `FACT_SALES`

## 7. `Load_Agg_Fact.dtsx`
- Chạy 3 Execute SQL Task nối tiếp để xây dựng các bảng tổng hợp:
  1. `AGG_INVENTORY_WEEKLY`
     - tổng `total_qty_in`, `total_qty_out`, `net_change`, `count_transactions`
     - group by `year`, `week_of_year`, `product_key`
  2. `AGG_SALES_DAILY`
     - tổng `quantity`, `tax_amount`, `total_including_tax`, `line_profit`
     - tính `avg_order_value`, `count_invoices`, `count_distinct_products`
     - group by `date_key`
  3. `AGG_SALES_PRODUCT_CITY_DAILY`
     - tổng theo `date_key`, `product_key`, `city_key`
     - group by `date_key`, `product_key`, `city_key`

## 8. Kết nối và phụ thuộc triển khai
- Tất cả package hầu hết dùng SQL Server `localhost` với `Integrated Security=SSPI`.
- `Load_Staging.dtsx` phụ thuộc:
  - driver OLE DB `Microsoft.ACE.OLEDB.16.0` cho Excel
  - ODBC DSN `postgres_ssis` cho PostgreSQL
- `Project.params` hiện tại trống, nghĩa là:
  - không dùng parameter hóa project-level
  - connection string/đường dẫn được lưu cứng trong package
- Lưu ý đặc biệt:
  - `Load_Dim_Supplier.dtsx` dùng thêm connection manager `localhost.financial_data_warehouse`
  - Các package khác chủ yếu dùng `wwi_data_warehouse` và `wwi_staging_area`

## 9. Hướng dẫn chạy / triển khai
1. Mở project SSIS trong Visual Studio / SSDT.
2. Kiểm tra tồn tại các connection managers:
   - Excel file `D:\ssms2postgre\file backup\application.xlsx`
   - ODBC DSN `postgres_ssis`
   - SQL Server `localhost`
3. Chạy thử `Load_Staging.dtsx` riêng để xác nhận data source.
4. Chạy `Master_ETL.dtsx` để thực hiện toàn bộ luồng.
5. Nếu cần triển khai:
   - build project thành `.ispac`
   - deploy lên SSIS Catalog
   - tạo environment và cấu hình connection string nếu muốn tách môi trường.

## 10. Nhận xét quan trọng
- Báo cáo được tổng hợp trực tiếp từ nội dung file SSIS XML `.dtsx`.
- Không có file DDL bảng chi tiết trong workspace nên:
  - cấu trúc bảng chỉ suy ra từ tên source/destination và biến đổi
  - không thể xác nhận mọi column type/khóa chính
- Nếu cần hoàn chỉnh hơn, nên bổ sung:
  - schema DDL `CREATE TABLE`
  - documentation về staging table
  - thông tin về môi trường triển khai SSIS Catalog

## 11. Kết luận
- Dự án có thiết kế ETL rõ ràng:
  - `Load_Staging` làm tiền xử lý
  - dimension load trước fact load
  - aggregations build cuối cùng
- Công nghệ chính:
  - SSIS package
  - OLE DB / ODBC
  - Excel/SQL Server/PostgreSQL
- Điểm cần kiểm tra khi triển khai:
  - driver Excel
  - DSN PostgreSQL
  - tính nhất quán database `financial_data_warehouse` vs `wwi_data_warehouse`

Nếu bạn cần, tôi có thể tiếp tục tạo `README` chi tiết triển khai hoặc tóm tắt thiết kế bảng dựa trên các package này.