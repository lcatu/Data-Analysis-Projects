# HƯỚNG DẪN CHI TIẾT CÁC BƯỚC ĐỔ DỮ LIỆU TRONG SSIS
## Dự án WideWorldImposter

---

## PHẦN 1: CÁC BƯỚC ĐỔ DỮ LIỆU VÀO STAGING

### Bước 1: Tạo Connection Manager cho SQL Server

**Mục tiêu:** Kết nối đến cơ sở dữ liệu SQL Server chứa dữ liệu nguồn

**Cách thực hiện:**
1. Mở SSIS Package trong Visual Studio
2. Chuột phải vào vùng **Connection Managers** ở dưới cùng
3. Chọn **New OLE DB Connection...**
4. Nhấp **New...**
5. Trong hộp thoại **Configure OLE DB Connection Manager**:
   - **Server name:** localhost (hoặc tên server thực tế)
   - **Authentication:** Chọn **Use Windows Authentication** (Integrated Security)
   - **Database:** Chọn database nguồn (ví dụ: `purchasing&sales`)
6. Nhấp **Test Connection** để kiểm tra
7. Nhấp **OK**

**Kết quả:** Một connection manager OLE DB được tạo, có thể được sử dụng cho các component OLE DB Source và OLE DB Destination

---

### Bước 2: Tạo Connection Manager cho Excel

**Mục tiêu:** Kết nối đến file Excel chứa dữ liệu ứng dụng

**Cách thực hiện:**
1. Chuột phải vào vùng **Connection Managers**
2. Chọn **New Connection...**
3. Chọn loại kết nối **EXCEL**
4. Nhấp **Add**
5. Trong hộp thoại **Excel Connection Manager Editor**:
   - **File path:** Nhập đường dẫn đầy đủ: `D:\ssms2postgre\file backup\application.xlsx`
   - **Excel version:** Chọn **Excel 2007-365** (hoặc phiên bản phù hợp)
   - **First row has column names:** Đánh dấu checkbox này
6. Nhấp **OK**

**Kết quả:** Connection manager Excel được tạo, cho phép đọc dữ liệu từ các worksheet trong file Excel

---

### Bước 3: Tạo Connection Manager cho PostgreSQL

**Mục tiêu:** Kết nối đến cơ sở dữ liệu PostgreSQL

**Cách thực hiện:**
1. Chuột phải vào vùng **Connection Managers**
2. Chọn **New Connection...**
3. Chọn loại kết nối **ODBC**
4. Nhấp **Add**
5. Trong hộp thoại **ODBC Connection Manager Editor**:
   - **Connection name:** postgres_ssis
   - **Use DSN:** Chọn `postgres_ssis` từ dropdown (DSN phải được cấu hình trước trong ODBC Data Source Administrator)
   - Nhập **User name** và **Password** nếu cần
6. Nhấp **OK**

**Lưu ý:** DSN `postgres_ssis` phải được cấu hình trước trong Windows ODBC Data Source Administrator

---

### Bước 4: Tạo Connection Manager cho Staging Database

**Mục tiêu:** Kết nối đến cơ sở dữ liệu Staging nơi sẽ lưu trữ dữ liệu tạm

**Cách thực hiện:**
1. Chuột phải vào vùng **Connection Managers**
2. Chọn **New OLE DB Connection...**
3. Nhấp **New...**
4. Trong hộp thoại **Configure OLE DB Connection Manager**:
   - **Server name:** localhost
   - **Authentication:** Chọn **Use Windows Authentication**
   - **Database:** Chọn `wwi_staging_area`
5. Nhấp **Test Connection**
6. Nhấp **OK**

**Kết quả:** Connection manager cho Staging được tạo

---

### Bước 5: Tạo Connection Manager cho Data Warehouse

**Mục tiêu:** Kết nối đến kho dữ liệu chính

**Cách thực hiện:**
1. Chuột phải vào vùng **Connection Managers**
2. Chọn **New OLE DB Connection...**
3. Nhấp **New...**
4. Trong hộp thoại **Configure OLE DB Connection Manager**:
   - **Server name:** localhost
   - **Authentication:** Chọn **Use Windows Authentication**
   - **Database:** Chọn `wwi_data_warehouse`
5. Nhấp **Test Connection**
6. Nhấp **OK**

**Kết quả:** Connection manager cho Data Warehouse được tạo

---

### Bước 6: Thêm Data Flow Task vào Package

**Mục tiêu:** Tạo container chứa các component xử lý dữ liệu

**Cách thực hiện:**
1. Kéo component **Data Flow Task** từ **SSIS Toolbox** vào vùng **Design**
2. Đặt tên task: `Load Staging Data`
3. Nhấp đúp vào component để mở **Data Flow Designer**

**Kết quả:** Một Data Flow Task được tạo, sẵn sàng thêm các component

---

### Bước 7: Thêm OLE DB Source cho bảng SQL Server

**Mục tiêu:** Đọc dữ liệu từ bảng nguồn trong SQL Server

**Cách thực hiện:**
1. Trong Data Flow Designer, kéo **OLE DB Source** từ SSIS Toolbox
2. Đặt tên: `Source - Purchasing`
3. Nhấp đúp vào component
4. Trong hộp thoại **OLE DB Source Editor**:
   - **Connection manager:** Chọn connection manager SQL Server (ví dụ: `purchasing&sales`)
   - **Data access mode:** Chọn **Table or view**
   - **Name of the table or the view:** Chọn bảng từ dropdown (ví dụ: `[Purchasing].[Suppliers]`)
5. Nhấp tab **Columns** để xem các cột được chọn
6. Nhấp **OK**

**Kết quả:** Component OLE DB Source được cấu hình, sẵn sàng đọc dữ liệu từ bảng

---

### Bước 8: Thêm OLE DB Destination cho Staging

**Mục tiêu:** Ghi dữ liệu vào bảng Staging

**Cách thực hiện:**
1. Trong Data Flow Designer, kéo **OLE DB Destination** từ SSIS Toolbox
2. Đặt tên: `Destination - Staging`
3. Kéo mũi tên kết nối từ **OLE DB Source** đến **OLE DB Destination**
4. Nhấp đúp vào OLE DB Destination
5. Trong hộp thoại **OLE DB Destination Editor**:
   - **Connection manager:** Chọn connection manager Staging (`wwi_staging_area`)
   - **Data access mode:** Chọn **Table or view**
   - **Name of the table or the view:** Chọn hoặc nhập tên bảng đích (ví dụ: `[dbo].[Suppliers]`)
6. Nhấp tab **Mappings** để kiểm tra ánh xạ cột
7. Nhấp **OK**

**Kết quả:** Dữ liệu từ SQL Server sẽ được ghi vào Staging

---

### Bước 9: Lặp lại cho các bảng khác

**Mục tiêu:** Tải tất cả dữ liệu vào Staging

**Cách thực hiện:**
1. Thêm các Data Flow Task khác cho các bảng tiếp theo
2. Hoặc trong cùng một Data Flow Task, thêm thêm các cặp Source - Destination
3. Lặp lại các bước 7-8 cho từng bảng cần nạp (ví dụ: Customers, Orders, Invoices, v.v.)

**Lưu ý:** Có thể tạo một Data Flow Task lớn với nhiều Source - Destination, hoặc tạo nhiều task riêng lẻ để dễ quản lý và debug

---

### Bước 10: Chạy Package Load_Staging để kiểm tra

**Mục tiêu:** Xác nhận rằng dữ liệu đã được nạp thành công vào Staging

**Cách thực hiện:**
1. Nhấp **F5** hoặc chọn **Debug > Start Debugging**
2. Theo dõi thực thi trong tab **Execution Results**
3. Kiểm tra số lượng hàng được xử lý: `Row count`
4. Nếu thành công, sẽ thấy trạng thái xanh (Success)
5. Mở SQL Server Management Studio để xác nhận dữ liệu trong `wwi_staging_area`

**Kết quả:** Package Load_Staging chạy thành công, dữ liệu đã được nạp vào Staging

---

## PHẦN 2: CÁC BƯỚC XÂY DỰNG BẢNG DIMENSION

### Bước 11: Tạo Package Load_Dim_Product

**Mục tiêu:** Xây dựng bảng chiều sản phẩm

**Cách thực hiện:**
1. Tạo Package mới: **File > New > Integration Services Package**
2. Đặt tên: `Load_Dim_Product.dtsx`
3. Thêm các Connection Managers cần thiết (Staging và Data Warehouse)
4. Thêm một **Data Flow Task**

---

### Bước 12: Thêm OLE DB Source cho Staging

**Mục tiêu:** Đọc dữ liệu sản phẩm từ Staging

**Cách thực hiện:**
1. Trong Data Flow Designer, kéo **OLE DB Source**
2. Đặt tên: `Source - Staging Products`
3. Nhấp đúp để cấu hình
4. Chọn connection manager Staging
5. Chọn SQL command và nhập query để đọc dữ liệu cần thiết, ví dụ:
   ```sql
   SELECT 
       wwi_stock_item_id,
       stock_item_name,
       color,
       package_type_id,
       brand,
       valid_from,
       valid_to
   FROM [dbo].[StockItems]
   WHERE wwi_stock_item_id IS NOT NULL
   ORDER BY wwi_stock_item_id
   ```
6. Nhấp **OK**

---

### Bước 13: Thêm Slowly Changing Dimension Component

**Mục tiêu:** Phát hiện bản ghi mới và thay đổi

**Cách thực hiện:**
1. Kéo **Slowly Changing Dimension** từ SSIS Toolbox vào Data Flow
2. Đặt tên: `SCD - Product`
3. Kết nối từ OLE DB Source đến SCD component
4. Nhấp đúp vào SCD component
5. Trong hộp thoại **Slowly Changing Dimension Wizard**:
   - **Select source table columns:** Chọn các cột từ Staging (stock_item_id, name, color, v.v.)
   - **Select business key columns:** Chọn `wwi_stock_item_id` làm business key
   - **Select dimension table and key columns:** 
     - Chọn connection manager Data Warehouse
     - Chọn bảng `DIM_PRODUCT`
     - Liên kết các cột
   - **Changing attributes:** 
     - Đánh dấu các cột có thể thay đổi (ví dụ: stock_item_name, color)
     - Chọn **SCD Type 2** cho các cột này
6. Nhấp **Next** và cấu hình các cột SCD Type 2 như:
   - `valid_from` - ngày bắt đầu hiệu lực
   - `valid_to` - ngày kết thúc hiệu lực
   - `is_current` - cột cờ hiện tại
7. Nhấp **Finish**

**Kết quả:** SCD component được cấu hình, sẽ phát hiện bản ghi mới, thay đổi, và không thay đổi

---

### Bước 14: Thêm OLE DB Destination cho bảng Dimension

**Mục tiêu:** Ghi bản ghi mới và thay đổi vào DIM_PRODUCT

**Cách thực hiện:**
1. Kéo **OLE DB Destination** vào Data Flow (từ phía New Records của SCD)
2. Đặt tên: `Destination - DIM_PRODUCT`
3. Kết nối từ output **New** của SCD component
4. Nhấp đúp để cấu hình
5. Chọn connection manager Data Warehouse
6. Chọn bảng `DIM_PRODUCT`
7. Kiểm tra Mappings
8. Nhấp **OK**

---

### Bước 15: Thêm OLE DB Command cho bản ghi thay đổi

**Mục tiêu:** Cập nhật `valid_to` cho bản ghi cũ

**Cách thực hiện:**
1. Kéo **OLE DB Command** từ SSIS Toolbox
2. Đặt tên: `Update Old Records`
3. Kết nối từ output **Changed** của SCD component
4. Nhấp đúp để cấu hình
5. Chọn connection manager Data Warehouse
6. Trong **SqlCommand**, nhập SQL command để update:
   ```sql
   UPDATE [dbo].[DIM_PRODUCT]
   SET valid_to = ?
   WHERE wwi_stock_item_id = ? 
   AND valid_to IS NULL
   ```
7. Chỉ định các tham số từ input columns
8. Nhấp **OK**

---

### Bước 16: Chạy Package Load_Dim_Product

**Mục tiêu:** Xác nhận bảng Dimension được tạo thành công

**Cách thực hiện:**
1. Nhấp **F5** để chạy
2. Theo dõi kết quả trong **Execution Results**
3. Xác nhận số bản ghi được tải: `Rows affected`

---

### Bước 17: Lặp lại cho các Dimension khác

**Mục tiêu:** Xây dựng các bảng Dimension còn lại

**Cách thực hiện:**
1. Tạo Package mới cho từng bảng Dimension:
   - `Load_Dim_Supplier.dtsx`
   - `Load_Dim_Customer.dtsx`
   - `Load_Dim_Employee.dtsx`
   - `Load_Dim_City.dtsx`
2. Lặp lại các bước 12-15 cho từng package
3. Điều chỉnh các cột, business key, và cột SCD Type 2 theo từng dimension
4. Chạy từng package để kiểm tra

---

## PHẦN 3: CÁC BƯỚC TẢI BẢNG FACT

### Bước 18: Tạo Package Load_Fact_Sale

**Mục tiêu:** Nạp dữ liệu sự kiện bán hàng

**Cách thực hiện:**
1. Tạo Package mới: `Load_Fact_Sale.dtsx`
2. Thêm các Connection Managers cần thiết

---

### Bước 19: Thêm OLE DB Source cho Staging

**Mục tiêu:** Đọc dữ liệu bán hàng từ Staging

**Cách thực hiện:**
1. Kéo **OLE DB Source** vào Data Flow
2. Đặt tên: `Source - Invoice Lines`
3. Nhấp đúp để cấu hình
4. Chọn connection manager Staging
5. Chọn SQL command và nhập query để lấy dữ liệu bán hàng:
   ```sql
   SELECT 
       il.invoice_line_id,
       i.invoice_id,
       i.customer_id,
       i.invoice_date,
       il.stock_item_id,
       il.quantity,
       il.unit_price,
       il.line_total
   FROM [dbo].[InvoiceLines] il
   INNER JOIN [dbo].[Invoices] i ON il.invoice_id = i.invoice_id
   ```
6. Nhấp **OK**

---

### Bước 20: Thêm Lookup Component để lấy Product Key

**Mục tiêu:** Tìm product_key từ DIM_PRODUCT

**Cách thực hiện:**
1. Kéo **Lookup** từ SSIS Toolbox
2. Đặt tên: `Lookup - Product`
3. Kết nối từ OLE DB Source
4. Nhấp đúp để cấu hình
5. Trong tab **Connection**:
   - Chọn connection manager Data Warehouse
   - Nhập SQL query:
     ```sql
     SELECT wwi_stock_item_id, product_key
     FROM [dbo].[DIM_PRODUCT]
     WHERE valid_to IS NULL
     ```
6. Trong tab **Columns**:
   - Kéo cột `stock_item_id` từ input sang `wwi_stock_item_id` trong bảng lookup
7. Trong tab **Advanced**:
   - Đánh dấu cột `product_key` để output
8. Nhấp **OK**

---

### Bước 21: Thêm Lookup Component để lấy Customer Key

**Mục tiêu:** Tìm customer_key từ DIM_CUSTOMER

**Cách thực hiện:**
1. Kéo **Lookup** từ SSIS Toolbox
2. Đặt tên: `Lookup - Customer`
3. Kết nối từ output của Lookup - Product
4. Nhấp đúp để cấu hình
5. Trong tab **Connection**:
   - Chọn connection manager Data Warehouse
   - Nhập SQL query:
     ```sql
     SELECT wwi_customer_id, customer_key
     FROM [dbo].[DIM_CUSTOMER]
     WHERE valid_to IS NULL
     ```
6. Trong tab **Columns**:
   - Kéo cột `customer_id` sang `wwi_customer_id`
7. Nhấp **OK**

---

### Bước 22: Lặp lại cho các Lookup khác

**Mục tiêu:** Tăng thêm các khóa tham chiếu từ các Dimension khác

**Cách thực hiện:**
1. Thêm Lookup cho Employee Key
2. Thêm Lookup cho City Key
3. Thêm Lookup cho Date Key (nếu có bảng DIM_DATE)
4. Mỗi Lookup được cấu hình tương tự như các bước 20-21

---

### Bước 23: Thêm Derived Column để tính toán metrics

**Mục tiêu:** Tạo các cột tính toán, ví dụ như doanh thu ròng

**Cách thực hiện:**
1. Kéo **Derived Column** từ SSIS Toolbox
2. Đặt tên: `Calculate Metrics`
3. Kết nối từ output của Lookup cuối cùng
4. Nhấp đúp để cấu hình
5. Thêm các derived column:
   - **discount_amount** = `unit_price * quantity * (discount_percent / 100)`
   - **net_amount** = `line_total - discount_amount`
6. Nhấp **OK**

---

### Bước 24: Thêm OLE DB Destination cho FACT_SALES

**Mục tiêu:** Ghi dữ liệu vào bảng FACT_SALES

**Cách thực hiện:**
1. Kéo **OLE DB Destination** vào Data Flow
2. Đặt tên: `Destination - FACT_SALES`
3. Kết nối từ Derived Column
4. Nhấp đúp để cấu hình
5. Chọn connection manager Data Warehouse
6. Chọn bảng `FACT_SALES`
7. Kiểm tra Mappings để đảm bảo các cột được ánh xạ đúng
8. Nhấp **OK**

---

### Bước 25: Chạy Package Load_Fact_Sale

**Mục tiêu:** Xác nhận dữ liệu sự kiện được tải thành công

**Cách thực hiện:**
1. Nhấp **F5** để chạy
2. Theo dõi kết quả
3. Kiểm tra số dòng được tải trong `FACT_SALES`

---

### Bước 26: Tạo Package Load_Fact_Purchase

**Mục tiêu:** Nạp dữ liệu sự kiện mua hàng

**Cách thực hiện:**
1. Tạo Package mới: `Load_Fact_Purchase.dtsx`
2. Lặp lại các bước 19-24, nhưng:
   - Đọc từ `PurchaseOrders` và `PurchaseOrderLines`
   - Lookup: Product Key, Supplier Key
   - Ghi vào `FACT_PURCHASE`

---

### Bước 27: Tạo Package Load_Fact_Inventory

**Mục tiêu:** Nạp dữ liệu sự kiện tồn kho

**Cách thực hiện:**
1. Tạo Package mới: `Load_Fact_Inventory.dtsx`
2. Lặp lại các bước 19-24, nhưng:
   - Đọc từ `StockItemTransactions` và `StockItemHoldings`
   - Lookup: Product Key, Date Key
   - Ghi vào `FACT_INVENTORY`

---

## PHẦN 4: CÁC BƯỚC TỔNG HỢP DỮ LIỆU

### Bước 28: Tạo Package Load_Agg_Fact

**Mục tiêu:** Tạo các bảng tổng hợp để phân tích nhanh

**Cách thực hiện:**
1. Tạo Package mới: `Load_Agg_Fact.dtsx`
2. Thêm Connection Manager cho Data Warehouse
3. Không cần Data Flow Task, sử dụng Execute SQL Task thay thế

---

### Bước 29: Thêm Execute SQL Task cho AGG_INVENTORY_WEEKLY

**Mục tiêu:** Tạo bảng tổng hợp tồn kho theo tuần

**Cách thực hiện:**
1. Kéo **Execute SQL Task** từ SSIS Toolbox
2. Đặt tên: `Create AGG_INVENTORY_WEEKLY`
3. Nhấp đúp để cấu hình
4. Chọn connection manager Data Warehouse
5. Trong **SQLStatement**, nhập câu lệnh SQL:
   ```sql
   TRUNCATE TABLE [dbo].[AGG_INVENTORY_WEEKLY]
   
   INSERT INTO [dbo].[AGG_INVENTORY_WEEKLY]
   (year_number, week_of_year, product_key, 
    total_qty_in, total_qty_out, avg_qty)
   SELECT 
       YEAR(fi.transaction_date) as year_number,
       WEEK(fi.transaction_date) as week_of_year,
       fi.product_key,
       SUM(CASE WHEN fi.transaction_type = 'In' THEN fi.qty ELSE 0 END) as total_qty_in,
       SUM(CASE WHEN fi.transaction_type = 'Out' THEN fi.qty ELSE 0 END) as total_qty_out,
       AVG(fi.qty) as avg_qty
   FROM [dbo].[FACT_INVENTORY] fi
   GROUP BY YEAR(fi.transaction_date), WEEK(fi.transaction_date), fi.product_key
   ```
6. Nhấp **OK**

---

### Bước 30: Thêm Execute SQL Task cho AGG_SALES_DAILY

**Mục tiêu:** Tạo bảng tổng hợp doanh số hàng ngày

**Cách thực hiện:**
1. Kéo **Execute SQL Task** từ SSIS Toolbox
2. Đặt tên: `Create AGG_SALES_DAILY`
3. Nhấp đúp để cấu hình
4. Chọn connection manager Data Warehouse
5. Trong **SQLStatement**:
   ```sql
   TRUNCATE TABLE [dbo].[AGG_SALES_DAILY]
   
   INSERT INTO [dbo].[AGG_SALES_DAILY]
   (sales_date, total_sales, total_quantity, num_transactions)
   SELECT 
       CAST(fs.sale_date AS DATE) as sales_date,
       SUM(fs.line_total) as total_sales,
       SUM(fs.quantity) as total_quantity,
       COUNT(DISTINCT fs.invoice_key) as num_transactions
   FROM [dbo].[FACT_SALES] fs
   GROUP BY CAST(fs.sale_date AS DATE)
   ```
6. Nhấp **OK**

---

### Bước 31: Thêm Execute SQL Task cho AGG_SALES_PRODUCT_CITY_DAILY

**Mục tiêu:** Tạo bảng tổng hợp doanh số theo sản phẩm, thành phố, ngày

**Cách thực hiện:**
1. Kéo **Execute SQL Task** từ SSIS Toolbox
2. Đặt tên: `Create AGG_SALES_PRODUCT_CITY_DAILY`
3. Nhấp đúp để cấu hình
4. Chọn connection manager Data Warehouse
5. Trong **SQLStatement**:
   ```sql
   TRUNCATE TABLE [dbo].[AGG_SALES_PRODUCT_CITY_DAILY]
   
   INSERT INTO [dbo].[AGG_SALES_PRODUCT_CITY_DAILY]
   (sales_date, product_key, city_key, total_sales, total_quantity)
   SELECT 
       CAST(fs.sale_date AS DATE) as sales_date,
       fs.product_key,
       fs.city_key,
       SUM(fs.line_total) as total_sales,
       SUM(fs.quantity) as total_quantity
   FROM [dbo].[FACT_SALES] fs
   GROUP BY CAST(fs.sale_date AS DATE), fs.product_key, fs.city_key
   ```
6. Nhấp **OK**

---

### Bước 32: Kết nối các Execute SQL Task theo thứ tự

**Mục tiêu:** Đảm bảo các bảng tổng hợp được tạo tuần tự

**Cách thực hiện:**
1. Kéo mũi tên **Precedence Constraint** từ task thứ nhất sang task thứ hai
2. Lặp lại cho các task tiếp theo
3. Đảm bảo trạng thái thành công (Success) được thiết lập cho mỗi constraint
4. Nhấp **OK**

---

### Bước 33: Chạy Package Load_Agg_Fact

**Mục tiêu:** Xác nhận các bảng tổng hợp được tạo thành công

**Cách thực hiện:**
1. Nhấp **F5** để chạy
2. Theo dõi thực thi của các Execute SQL Task
3. Kiểm tra trong SQL Server Management Studio để xác nhận dữ liệu trong các bảng tổng hợp

---

## PHẦN 5: TẠO PACKAGE MASTER_ETL ĐỂ ĐIỀU PHỐI

### Bước 34: Tạo Package Master_ETL

**Mục tiêu:** Tạo package chính để điều phối toàn bộ quy trình ETL

**Cách thực hiện:**
1. Tạo Package mới: `Master_ETL.dtsx`
2. Không cần Data Flow Task, chỉ cần Control Flow

---

### Bước 35: Thêm Execute Package Task cho Load_Staging

**Mục tiêu:** Gọi package Load_Staging từ Master_ETL

**Cách thực hiện:**
1. Kéo **Execute Package Task** từ SSIS Toolbox vào Control Flow
2. Đặt tên: `Execute Load_Staging`
3. Nhấp đúp để cấu hình
4. Trong tab **General**:
   - Chọn **Package source** là **File system** hoặc **SSIS Package Store**
   - Chọn file `Load_Staging.dtsx`
5. Nhấp **OK**

---

### Bước 36: Thêm Execute Package Task cho các Dimension

**Mục tiêu:** Gọi các package dimension theo thứ tự

**Cách thực hiện:**
1. Thêm **Execute Package Task** cho `Load_Dim_Product`
2. Thêm **Execute Package Task** cho `Load_Dim_Supplier`
3. Thêm **Execute Package Task** cho `Load_Dim_Customer`
4. Thêm **Execute Package Task** cho `Load_Dim_Employee`
5. Thêm **Execute Package Task** cho `Load_Dim_City`
6. Mỗi task được cấu hình như bước 35

---

### Bước 37: Thêm Execute Package Task cho các Fact

**Mục tiêu:** Gọi các package fact theo thứ tự

**Cách thực hiện:**
1. Thêm **Execute Package Task** cho `Load_Fact_Sale`
2. Thêm **Execute Package Task** cho `Load_Fact_Purchase`
3. Thêm **Execute Package Task** cho `Load_Fact_Inventory`

---

### Bước 38: Thêm Execute Package Task cho Load_Agg_Fact

**Mục tiêu:** Gọi package tổng hợp cuối cùng

**Cách thực hiện:**
1. Thêm **Execute Package Task** cho `Load_Agg_Fact`

---

### Bước 39: Kết nối các Task bằng Precedence Constraint

**Mục tiêu:** Thiết lập thứ tự thực thi

**Cách thực hiện:**
1. Kéo mũi tên từ `Execute Load_Staging` sang `Execute Load_Dim_Product`
2. Nhấp đúp vào mũi tên (Precedence Constraint)
3. Chọn **Success** để đảm bảo chỉ thực thi khi task trước thành công
4. Nhấp **OK**
5. Lặp lại cho các task tiếp theo:
   - `Load_Staging` → `Load_Dim_Product`
   - `Load_Dim_Product` → `Load_Dim_Supplier`
   - `Load_Dim_Supplier` → `Load_Dim_Customer`
   - `Load_Dim_Customer` → `Load_Dim_Employee`
   - `Load_Dim_Employee` → `Load_Dim_City`
   - `Load_Dim_City` → `Load_Fact_Sale`
   - `Load_Fact_Sale` → `Load_Fact_Purchase`
   - `Load_Fact_Purchase` → `Load_Fact_Inventory`
   - `Load_Fact_Inventory` → `Load_Agg_Fact`

---

### Bước 40: Chạy Master_ETL để kiểm tra toàn bộ quy trình

**Mục tiêu:** Xác nhận toàn bộ quy trình ETL hoạt động đúng

**Cách thực hiện:**
1. Nhấp **F5** để chạy Master_ETL
2. Theo dõi thực thi trong **Execution Results**
3. Kiểm tra mỗi task được chạy theo đúng thứ tự
4. Nếu có task nào thất bại, sẽ dừng lại
5. Xác nhận tất cả các bảng đã được cập nhật trong Data Warehouse bằng SQL Server Management Studio
6. Chạy các truy vấn kiểm tra để xác nhận dữ liệu:
   ```sql
   SELECT COUNT(*) FROM [wwi_data_warehouse].[dbo].[DIM_PRODUCT]
   SELECT COUNT(*) FROM [wwi_data_warehouse].[dbo].[FACT_SALES]
   SELECT COUNT(*) FROM [wwi_data_warehouse].[dbo].[AGG_SALES_DAILY]
   ```

---

## PHẦN 6: CẤU HÌNH LỊCH CHẠY TỰ ĐỘNG

### Bước 41: Deploy Package lên SSIS Catalog

**Mục tiêu:** Chuẩn bị package để lên lịch chạy định kỳ

**Cách thực hiện:**
1. Chuột phải vào Project trong Solution Explorer
2. Chọn **Build**
3. Chọn **Deploy**
4. Theo hướng dẫn Deploy Wizard để upload lên SSIS Catalog

---

### Bước 42: Tạo SQL Server Agent Job để chạy định kỳ

**Mục tiêu:** Tự động chạy Master_ETL mỗi ngày

**Cách thực hiện:**
1. Mở SQL Server Management Studio
2. Kết nối đến SQL Server Agent
3. Chuột phải vào **Jobs** → **New Job**
4. Đặt tên: `ETL_WideWorldImposter_Daily`
5. Trong **Steps**, thêm step mới:
   - **Step type**: SQL Server Integration Services Package
   - **Package source**: SSIS Catalog
   - **Package**: Chọn Master_ETL
6. Trong **Schedules**, thêm lịch chạy:
   - **Frequency**: Daily
   - **Time**: Ví dụ 02:00 AM (ngoài giờ làm việc)
7. Nhấp **OK**

---

## PHẦN 7: KIỂM TRA VÀ BẢO TRÌ

### Bước 43: Thiết lập Logging để theo dõi lỗi

**Mục tiêu:** Ghi nhật ký lỗi để dễ dàng debug

**Cách thực hiện:**
1. Mở Master_ETL Package
2. Chọn **SSIS > Logging**
3. Chọn **Configure SSIS Logs**
4. Chọn **Log Provider**: SQL Server
5. Nhấp **Add** để thêm các events cần theo dõi
6. Chọn **Text File** hoặc **SQL Server** để ghi nhật ký

---

### Bước 44: Chạy truy vấn kiểm tra dữ liệu

**Mục tiêu:** Xác nhận tính toàn vẹn dữ liệu

**Cách thực hiện:**
1. Kiểm tra không có NULL không mong muốn:
   ```sql
   SELECT * FROM DIM_PRODUCT WHERE product_key IS NULL
   SELECT * FROM FACT_SALES WHERE product_key IS NULL
   ```
2. Kiểm tra khóa tham chiếu:
   ```sql
   SELECT COUNT(*) FROM FACT_SALES fs 
   LEFT JOIN DIM_PRODUCT dp ON fs.product_key = dp.product_key
   WHERE dp.product_key IS NULL
   ```
3. Kiểm tra SCD Type 2:
   ```sql
   SELECT wwi_customer_id, COUNT(*) FROM DIM_CUSTOMER 
   WHERE is_current = 1
   GROUP BY wwi_customer_id
   HAVING COUNT(*) > 1
   ```

---

### Bước 45: Thực hiện bảo trì định kỳ

**Mục tiêu:** Đảm bảo hệ thống chạy ổn định

**Cách thực hiện:**
1. Kiểm tra log hàng ngày để tìm lỗi
2. Cập nhật query nếu cấu trúc dữ liệu nguồn thay đổi
3. Tái tạo index trong Data Warehouse hàng tuần
4. Cập nhật thống kê database hàng tuần
5. Làm sạch các bảng tạm thời nếu cần

---

**HẾT HƯỚNG DẪN CHI TIẾT**

