# BÁNG CÁO CHI TIẾT QUY TRÌNH ĐỔ DỮ LIỆU - TỪNG BẢNG TRONG SSIS
## Dự án WideWorldImposter

---

## PHẦN I: CONTROL FLOW CHUNG CHO TẤT CẢ PACKAGE

### Tổng quan

Tất cả các package SSIS trong dự án (Load_Dim_Product, Load_Dim_Supplier, Load_Dim_Customer, Load_Dim_Employee, Load_Dim_City, Load_Fact_Sale, Load_Fact_Purchase, Load_Fact_Inventory) đều tuân theo một mô hình Control Flow thống nhất. Mô hình này bao gồm các bước lôgic để ghi nhận trạng thái thực thi, xử lý lỗi, và cập nhật metadata.

### Các bước Control Flow

> **[Chèn ảnh: Control Flow chung của tất cả 8 package - Hiển thị 4 bước chính và 1 nhánh Error]**

**Bước 1 – Insert Lineage START**

Thực thi một câu lệnh SQL để ghi nhận thông tin bắt đầu của lần chạy vào bảng lineage (log). Bảng lineage được sử dụng để theo dõi lịch sử thực thi của tất cả các package.

SQL Command:
```sql
INSERT INTO [dbo].[Lineage_Log]
(package_name, execution_id, status, timestamp_start, description)
VALUES
(@PackageName, @ExecutionID, 'START', GETDATE(), 'Starting execution of package')
```

Mục tiêu: Ghi nhận thời gian khởi động package, ID thực thi duy nhất, tên package, để phục vụ kiểm tra, debug và theo dõi hiệu suất sau này.

**Bước 2 – Data Flow Task**

Đây là bước trọng tâm, thực hiện toàn bộ logic biến đổi và nạp dữ liệu vào bảng đích (Dimension hoặc Fact). Chi tiết xử lý được mô tả riêng cho từng bảng tại phần tiếp theo.

Các kết nối (Precedence Constraint) được cấu hình:
- Nếu Data Flow Task **thành công** → chuyển sang Bước 3
- Nếu Data Flow Task **thất bại** → chuyển sang nhánh Update Lineage FAILED

**Bước 3 – Post-Processing Logic (tùy bảng)**

Sau khi dữ liệu được nạp thành công, thực thi các SQL command bổ sung để:
- **Cập nhật cột is_current:** Đánh dấu các bản ghi cũ đã bị thay thế (cho Dimension)
- **Cập nhật mối quan hệ:** Điều chỉnh các khóa ngoài tham chiếu (cho Dimension và Fact)
- **Tính toán metrics:** Hoàn thành các trường tính toán (cho Fact)

Chi tiết của bước này khác nhau tùy thuộc vào từng bảng, được mô tả trong phần Data Flow riêng.

**Bước 4 – Update Lineage SUCCESS**

Thực thi câu lệnh SQL để cập nhật trạng thái lineage = "SUCCESS", ghi nhận thời gian hoàn thành, số dòng đã xử lý, và số bản ghi được chèn/cập nhật.

SQL Command:
```sql
UPDATE [dbo].[Lineage_Log]
SET status = 'SUCCESS', 
    timestamp_end = GETDATE(),
    rows_processed = @RowCount,
    description = 'Successfully completed'
WHERE execution_id = @ExecutionID
```

**Xử lý lỗi – Nhánh Update Lineage FAILED**

Nếu Data Flow Task hoặc các bước post-processing thất bại, Control Flow sẽ kích hoạt kết nối Failure và chuyển sang task Update Lineage FAILED.

SQL Command:
```sql
UPDATE [dbo].[Lineage_Log]
SET status = 'FAILED',
    timestamp_end = GETDATE(),
    error_code = @ErrorCode,
    error_description = @ErrorDescription
WHERE execution_id = @ExecutionID
```

Task này ghi nhận thông tin lỗi vào bảng lineage để đội vận hành có thể nhanh chóng phát hiện và xử lý sự cố.

---

## PHẦN II: DATA FLOW CHI TIẾT THEO TỪNG BẢNG

---

## A. BẢNG DIM_PRODUCT

### Tổng quan

Bảng DIM_PRODUCT chứa thông tin chi tiết về các mặt hàng bán hàng của công ty, bao gồm tên sản phẩm, màu sắc, loại đóng gói, brand, giá, thuế, và các thuộc tính khác. Bảng này được cập nhật thông qua quy trình SCD Type 2 để lưu giữ lịch sử các thay đổi.

### Data Flow Task – Luồng xử lý dữ liệu

**Bước 1 – OLE DB Source: "Source - Staging Products"**

Đọc dữ liệu từ bảng Staging thông qua connection manager `wwi_staging_area` (SQL Server OLE DB).

SQL Query:
```sql
SELECT 
    wwi_stock_item_id,
    stock_item_name,
    color_name,
    package_type_name,
    brand,
    unit_price,
    tax_rate,
    unit_package_quantity,
    related_stock_item_id,
    valid_from,
    valid_to
FROM [dbo].[StockItems]
WHERE wwi_stock_item_id IS NOT NULL
ORDER BY wwi_stock_item_id
```

Output: Dữ liệu sản phẩm từ Staging, sẵn sàng để so sánh với Dimension hiện tại.

**Bước 2 – Slowly Changing Dimension (SCD): "SCD - Product"**

Thành phần SCD Wizard so sánh dữ liệu đầu vào với bảng DIM_PRODUCT hiện tại dựa trên business key `wwi_stock_item_id`. Thành phần này phân loại các bản ghi thành 3 loại:

- **Historical Attribute Inserts Output:** Các bản ghi có thay đổi thuộc tính lịch sử (Type 2), chẳng hạn như tên sản phẩm thay đổi, giá thay đổi, hoặc brand thay đổi. Những bản ghi này cần tạo phiên bản mới và đóng phiên bản cũ.
  
- **New Output:** Các bản ghi hoàn toàn mới (sản phẩm mới được thêm vào hệ thống), chưa tồn tại trong DIM_PRODUCT.
  
- **Inferred Member Updates Output:** Các bản ghi inferred member (đã tồn tại dưới dạng placeholder với dữ liệu minimal), cần cập nhật thông tin thực tế.

**Bước 3a – Nhánh "Historical Attribute Inserts":**

**Component: Derived Column – "Add SCD Columns"**

Tính toán và bổ sung các cột cần thiết cho bản ghi lịch sử mới trước khi cập nhật bản ghi cũ:

- `valid_from = GETDATE()` — Ngày bắt đầu hiệu lực của bản ghi mới
- `is_current = 1` — Đánh dấu đây là bản ghi hiện tại
- `lineage_key = NEWID()` — UUID duy nhất cho mỗi bản ghi (phục vụ audit trail)
- `created_date = GETDATE()` — Timestamp khi bản ghi được tạo

**Component: OLE DB Command – "Update Old Records"**

Thực thi UPDATE trực tiếp trên bảng DIM_PRODUCT để đóng phiên bản cũ **trước khi** chèn phiên bản mới, đảm bảo chỉ một bản ghi có `is_current = 1` cho mỗi sản phẩm tại bất kỳ thời điểm nào.

SQL Command:
```sql
UPDATE [dbo].[DIM_PRODUCT]
SET valid_to = ?, 
    is_current = 0
WHERE wwi_stock_item_id = ? 
AND valid_to IS NULL
AND is_current = 1
```

Tham số:
- `?` (thứ nhất) = `valid_from` từ Derived Column (ngày đóng)
- `?` (thứ hai) = `wwi_stock_item_id` từ input

**Bước 3b – Nhánh "Inferred Member Updates":**

**Component: OLE DB Command – "Update Inferred Members"**

Thực thi UPDATE để điền đầy đủ thuộc tính cho các bản ghi inferred member hiện có trong DIM_PRODUCT, mà trước đó chỉ được tạo dưới dạng placeholder (có thể là NULL hoặc giá trị placeholder).

SQL Command:
```sql
UPDATE [dbo].[DIM_PRODUCT]
SET stock_item_name = ?, 
    color_name = ?, 
    brand = ?, 
    unit_price = ?,
    tax_rate = ?,
    unit_package_quantity = ?
WHERE wwi_stock_item_id = ? 
AND is_current = 1
```

**Bước 4 – Union All: "Combine All Outputs"**

Gộp luồng từ nhánh Historical (sau Derived Column + OLE DB Command) và luồng New Output thành một luồng duy nhất. Bước này đảm bảo toàn bộ bản ghi mới (bao gồm bản ghi hoàn toàn mới và phiên bản lịch sử mới của bản ghi thay đổi) được chuẩn bị cho việc chèn vào bảng.

Kết hợp:
- Các cột từ nhánh Historical: `stock_item_name, color_name, brand, unit_price, tax_rate, unit_package_quantity, valid_from, is_current, lineage_key, created_date`
- Các cột từ nhánh New: `stock_item_name, color_name, brand, unit_price, tax_rate, unit_package_quantity, valid_from, is_current, lineage_key, created_date`

**Bước 5 – Derived Column: "Add Metadata"**

Bổ sung hoặc chuẩn hóa các cột metadata chung cho toàn bộ bản ghi mới:

- `batch_id = @BatchID` — Tham số truyền vào từ package, dùng để nhóm các dòng được chèn cùng một lần chạy
- `source_system = "Staging"` — Cặp nguồn dữ liệu (để phân biệt với các nguồn khác nếu có)
- `updated_date = GETDATE()` — Thời gian cập nhật lần cuối

**Bước 6 – OLE DB Destination: "Insert Destination"**

Chèn toàn bộ bản ghi mới vào bảng DIM_PRODUCT thông qua connection manager `wwi_data_warehouse`.

Cấu hình:
- **Connection Manager:** wwi_data_warehouse (SQL Server OLE DB)
- **Table:** `[dbo].[DIM_PRODUCT]`
- **Data Access Mode:** Table or view
- **Fast Load:** Bật (để tăng tốc độ xử lý)

Output: Các bản ghi được chèn thành công vào DIM_PRODUCT.

**Xử lý lỗi:**
- Nếu OLE DB Source không thể kết nối hoặc query không hợp lệ → Error
- Nếu SCD component không thể tìm business key → Lỗi lookup
- Nếu OLE DB Command thất bại (violation của constraint) → Error
- Nếu OLE DB Destination thất bại (khóa chính trùng lặp) → Error

---

## B. BẢNG DIM_SUPPLIER

### Tổng quan

Bảng DIM_SUPPLIER chứa thông tin chi tiết về các nhà cung cấp, bao gồm tên nhà cung cấp, loại hình, thành phố, quốc gia, và các thông tin tài chính. Đặc biệt, package này có Connection Manager bổ sung đến `financial_data_warehouse` để lấy thông tin tài chính.

### Data Flow Task – Luồng xử lý dữ liệu

**Bước 1 – OLE DB Source: "Source - Staging Suppliers"**

Đọc dữ liệu từ bảng Staging:

```sql
SELECT 
    wwi_supplier_id,
    supplier_name,
    supplier_category_id,
    supplier_category_name,
    primary_contact_person_id,
    alternate_contact_person_id,
    delivery_method_id,
    city_id,
    postal_code,
    standard_discount_percent,
    valid_from,
    valid_to
FROM [dbo].[Suppliers]
WHERE wwi_supplier_id IS NOT NULL
ORDER BY wwi_supplier_id
```

**Bước 2 – Slowly Changing Dimension (SCD): "SCD - Supplier"**

So sánh dữ liệu đầu vào với DIM_SUPPLIER dựa trên `wwi_supplier_id`. Phân loại bản ghi thành 3 nhánh.

**Bước 3a – Nhánh "Historical Attribute Inserts":**

**Component: Derived Column – "Add SCD Columns"**

```
valid_from = GETDATE()
is_current = 1
lineage_key = NEWID()
created_date = GETDATE()
```

**Component: OLE DB Command – "Update Old Records"**

```sql
UPDATE [dbo].[DIM_SUPPLIER]
SET valid_to = ?, 
    is_current = 0,
    payment_days = NULL
WHERE wwi_supplier_id = ? 
AND valid_to IS NULL
AND is_current = 1
```

Ghi chú: Đặt `payment_days = NULL` vì thông tin tài chính sẽ được cập nhật sau (bước post-processing trong Control Flow).

**Bước 3b – Nhánh "Inferred Member Updates":**

**Component: OLE DB Command – "Update Inferred Members"**

```sql
UPDATE [dbo].[DIM_SUPPLIER]
SET supplier_name = ?, 
    supplier_category_name = ?,
    standard_discount_percent = ?
WHERE wwi_supplier_id = ? 
AND is_current = 1
```

**Bước 4 – Union All: "Combine All Outputs"**

Gộp các nhánh Historical và New.

**Bước 5 – Derived Column: "Add Metadata"**

```
batch_id = @BatchID
source_system = "Staging"
updated_date = GETDATE()
```

**Bước 6 – OLE DB Destination: "Insert Destination"**

Chèn vào DIM_SUPPLIER.

---

## C. BẢNG DIM_CUSTOMER

### Tổng quan

Bảng DIM_CUSTOMER chứa thông tin chi tiết về khách hàng, bao gồm tên khách hàng, địa chỉ, phân loại khách hàng (bán lẻ/bán buôn), nhóm mua hàng. Dimension này có xu hướng thay đổi cao vì thông tin khách hàng được cập nhật thường xuyên.

### Data Flow Task – Luồng xử lý dữ liệu

**Bước 1 – OLE DB Source: "Source - Staging Customers"**

```sql
SELECT 
    wwi_customer_id,
    customer_name,
    customer_category_id,
    buying_group_id,
    customer_type_id,
    delivery_city_id,
    postal_code,
    parent_customer_id,
    valid_from,
    valid_to
FROM [dbo].[Customers]
WHERE wwi_customer_id IS NOT NULL
ORDER BY wwi_customer_id
```

**Bước 2 – Slowly Changing Dimension (SCD): "SCD - Customer"**

So sánh với DIM_CUSTOMER dựa trên `wwi_customer_id`.

**Bước 3a – Nhánh "Historical Attribute Inserts":**

**Component: Derived Column – "Add SCD Columns"**

```
valid_from = GETDATE()
is_current = 1
is_valid_hierarchy = 1
lineage_key = NEWID()
created_date = GETDATE()
```

Ghi chú: Thêm `is_valid_hierarchy = 1` để sau này có thể xác thực tính hợp lệ của cấu trúc khách hàng cha-con (tại bước post-processing trong Control Flow).

**Component: OLE DB Command – "Update Old Records"**

```sql
UPDATE [dbo].[DIM_CUSTOMER]
SET valid_to = ?, 
    is_current = 0
WHERE wwi_customer_id = ? 
AND valid_to IS NULL
AND is_current = 1
```

**Bước 3b – Nhánh "Inferred Member Updates":**

**Component: OLE DB Command – "Update Inferred Members"**

```sql
UPDATE [dbo].[DIM_CUSTOMER]
SET customer_name = ?, 
    customer_category_id = ?,
    buying_group_id = ?,
    customer_type_id = ?
WHERE wwi_customer_id = ? 
AND is_current = 1
```

**Bước 4 – Union All: "Combine All Outputs"**

Gộp các nhánh.

**Bước 5 – Derived Column: "Add Metadata"**

```
batch_id = @BatchID
source_system = "Staging"
updated_date = GETDATE()
```

**Bước 6 – OLE DB Destination: "Insert Destination"**

Chèn vào DIM_CUSTOMER.

---

## D. BẢNG DIM_EMPLOYEE

### Tổng quan

Bảng DIM_EMPLOYEE chứa thông tin chi tiết về nhân viên, bao gồm tên nhân viên, vị trí công việc, phòng ban, người quản lý, ngày tuyển dụng, lương. Dimension này cần theo dõi các thay đổi về chức vụ, phòng ban, người quản lý.

### Data Flow Task – Luồng xử lý dữ liệu

**Bước 1 – OLE DB Source: "Source - Staging Employees"**

```sql
SELECT 
    wwi_employee_id,
    employee_name,
    job_title,
    department_name,
    manager_wwi_employee_id,
    hire_date,
    salary,
    valid_from,
    valid_to
FROM [dbo].[Employees]
WHERE wwi_employee_id IS NOT NULL
ORDER BY wwi_employee_id
```

**Bước 2 – Slowly Changing Dimension (SCD): "SCD - Employee"**

So sánh với DIM_EMPLOYEE dựa trên `wwi_employee_id`.

**Bước 3a – Nhánh "Historical Attribute Inserts":**

**Component: Derived Column – "Add SCD Columns"**

```
valid_from = GETDATE()
is_current = 1
lineage_key = NEWID()
created_date = GETDATE()
manager_employee_key = NULL
```

Ghi chú: Đặt `manager_employee_key = NULL` vì giá trị này sẽ được cập nhật sau trong bước post-processing (Join với DIM_EMPLOYEE để lấy khóa của người quản lý).

**Component: OLE DB Command – "Update Old Records"**

```sql
UPDATE [dbo].[DIM_EMPLOYEE]
SET valid_to = ?, 
    is_current = 0
WHERE wwi_employee_id = ? 
AND valid_to IS NULL
AND is_current = 1
```

**Bước 3b – Nhánh "Inferred Member Updates":**

**Component: OLE DB Command – "Update Inferred Members"**

```sql
UPDATE [dbo].[DIM_EMPLOYEE]
SET employee_name = ?, 
    job_title = ?,
    department_name = ?,
    salary = ?
WHERE wwi_employee_id = ? 
AND is_current = 1
```

**Bước 4 – Union All: "Combine All Outputs"**

Gộp các nhánh.

**Bước 5 – Derived Column: "Add Metadata"**

```
batch_id = @BatchID
source_system = "Staging"
updated_date = GETDATE()
```

**Bước 6 – OLE DB Destination: "Insert Destination"**

Chèn vào DIM_EMPLOYEE.

---

## E. BẢNG DIM_CITY

### Tổng quan

Bảng DIM_CITY chứa thông tin chi tiết về thành phố, bao gồm tên thành phố, vùng/tỉnh, quốc gia, tọa độ địa lý, mã bưu chính. Dimension này có tốc độ thay đổi thấp vì dữ liệu địa lý tương đối ổn định.

### Data Flow Task – Luồng xử lý dữ liệu

**Bước 1 – OLE DB Source: "Source - Staging Cities"**

```sql
SELECT 
    wwi_city_id,
    city_name,
    state_province_name,
    country_name,
    continent_name,
    postal_code,
    latitude,
    longitude,
    valid_from,
    valid_to
FROM [dbo].[Cities]
WHERE wwi_city_id IS NOT NULL
ORDER BY wwi_city_id
```

**Bước 2 – Slowly Changing Dimension (SCD): "SCD - City"**

So sánh với DIM_CITY dựa trên `wwi_city_id`.

**Bước 3a – Nhánh "Historical Attribute Inserts":**

**Component: Derived Column – "Add SCD Columns"**

```
valid_from = GETDATE()
is_current = 1
lineage_key = NEWID()
created_date = GETDATE()
```

**Component: OLE DB Command – "Update Old Records"**

```sql
UPDATE [dbo].[DIM_CITY]
SET valid_to = ?, 
    is_current = 0
WHERE wwi_city_id = ? 
AND valid_to IS NULL
AND is_current = 1
```

**Bước 3b – Nhánh "Inferred Member Updates":**

**Component: OLE DB Command – "Update Inferred Members"**

```sql
UPDATE [dbo].[DIM_CITY]
SET city_name = ?, 
    state_province_name = ?,
    country_name = ?,
    latitude = ?,
    longitude = ?
WHERE wwi_city_id = ? 
AND is_current = 1
```

**Bước 4 – Union All: "Combine All Outputs"**

Gộp các nhánh.

**Bước 5 – Derived Column: "Add Metadata"**

```
batch_id = @BatchID
source_system = "Staging"
updated_date = GETDATE()
```

**Bước 6 – OLE DB Destination: "Insert Destination"**

Chèn vào DIM_CITY.

---

## F. BẢNG FACT_SALE

### Tổng quan

Bảng FACT_SALES chứa chi tiết từng dòng hóa đơn bán hàng, bao gồm sản phẩm, khách hàng, nhân viên bán hàng, thành phố, ngày bán, số lượng, giá cả, chiết khấu, doanh thu. Đây là bảng fact trọng tâm để phân tích doanh số bán hàng.

### Data Flow Task – Luồng xử lý dữ liệu

**Bước 1 – OLE DB Source: "Source - Invoice Lines"**

```sql
SELECT 
    il.invoice_line_id,
    il.invoice_id,
    i.customer_id,
    i.invoice_date,
    i.salesperson_id,
    il.stock_item_id,
    il.quantity,
    il.unit_price,
    il.line_total,
    ISNULL(il.discount_percent, 0) as discount_percent
FROM [dbo].[InvoiceLines] il
INNER JOIN [dbo].[Invoices] i ON il.invoice_id = i.invoice_id
WHERE il.invoice_id IS NOT NULL
```

**Bước 2 – Lookup Product Key: "Lookup - Product"**

Tìm `product_key` từ DIM_PRODUCT dựa trên `stock_item_id`:

```sql
SELECT wwi_stock_item_id, product_key
FROM [dbo].[DIM_PRODUCT]
WHERE valid_to IS NULL
AND is_current = 1
```

Cấu hình:
- **Connection Manager:** wwi_data_warehouse
- **Column Mapping:** `stock_item_id` (input) → `wwi_stock_item_id` (lookup table)
- **Output:** `product_key`

**Bước 3 – Lookup Customer Key: "Lookup - Customer"**

Tìm `customer_key` từ DIM_CUSTOMER:

```sql
SELECT wwi_customer_id, customer_key
FROM [dbo].[DIM_CUSTOMER]
WHERE valid_to IS NULL
AND is_current = 1
```

**Bước 4 – Lookup Employee Key: "Lookup - Employee"**

Tìm `employee_key` từ DIM_EMPLOYEE (bán hàng):

```sql
SELECT wwi_employee_id, employee_key
FROM [dbo].[DIM_EMPLOYEE]
WHERE valid_to IS NULL
AND is_current = 1
```

**Bước 5 – Lookup Date Key: "Lookup - Date"** (nếu có DIM_DATE)

Tìm `date_key` từ DIM_DATE:

```sql
SELECT CAST(date_value AS DATE), date_key
FROM [dbo].[DIM_DATE]
```

**Bước 6 – Lookup City Key: "Lookup - City"** (nếu cần)

Tìm `city_key` từ DIM_CITY nếu Staging có thông tin thành phố.

**Bước 7 – Derived Column: "Calculate Sales Metrics"**

Tính toán các metrics bán hàng:

```
discount_amount = unit_price * quantity * (discount_percent / 100)
net_sales_amount = line_total - discount_amount
gross_profit_amount = net_sales_amount - (unit_cost * quantity)
(nếu có unit_cost từ Staging hoặc lookup từ DIM_PRODUCT)
created_date = GETDATE()
batch_id = @BatchID
```

**Bước 8 – OLE DB Destination: "Insert FACT_SALES"**

Chèn vào bảng FACT_SALES:

```sql
INSERT INTO [dbo].[FACT_SALES]
(invoice_line_key, invoice_id, product_key, customer_key, 
 employee_key, city_key, date_key, quantity, unit_price, 
 line_total, discount_amount, net_sales_amount, batch_id, created_date)
VALUES (...)
```

---

## G. BẢNG FACT_PURCHASE

### Tổng quan

Bảng FACT_PURCHASE chứa chi tiết từng dòng đơn mua hàng, bao gồm sản phẩm, nhà cung cấp, số lượng, giá cả, ngày mua, ngày giao nhận. Bảng này dùng để phân tích chi phí mua hàng và hiệu suất chuỗi cung ứng.

### Data Flow Task – Luồng xử lý dữ liệu

**Bước 1 – OLE DB Source: "Source - Purchase Order Lines"**

```sql
SELECT 
    pol.purchase_order_line_id,
    pol.purchase_order_id,
    po.supplier_id,
    po.order_date,
    po.delivery_date,
    pol.stock_item_id,
    pol.ordered_quantity,
    pol.received_quantity,
    pol.unit_price
FROM [dbo].[PurchaseOrderLines] pol
INNER JOIN [dbo].[PurchaseOrders] po ON pol.purchase_order_id = po.purchase_order_id
WHERE pol.purchase_order_id IS NOT NULL
```

**Bước 2 – Lookup Product Key: "Lookup - Product"**

```sql
SELECT wwi_stock_item_id, product_key
FROM [dbo].[DIM_PRODUCT]
WHERE valid_to IS NULL
AND is_current = 1
```

**Bước 3 – Lookup Supplier Key: "Lookup - Supplier"**

```sql
SELECT wwi_supplier_id, supplier_key
FROM [dbo].[DIM_SUPPLIER]
WHERE valid_to IS NULL
AND is_current = 1
```

**Bước 4 – Lookup Date Key: "Lookup - Order Date"** (nếu có DIM_DATE)

```sql
SELECT CAST(date_value AS DATE), date_key
FROM [dbo].[DIM_DATE]
```

**Bước 5 – Derived Column: "Calculate Purchase Metrics"**

```
purchase_amount = ordered_quantity * unit_price
received_amount = received_quantity * unit_price
variance_amount = (received_quantity - ordered_quantity) * unit_price
variance_qty = received_quantity - ordered_quantity
delivery_days = DATEDIFF(DAY, order_date, delivery_date)
created_date = GETDATE()
batch_id = @BatchID
```

**Bước 6 – OLE DB Destination: "Insert FACT_PURCHASE"**

Chèn vào bảng FACT_PURCHASE.

---

## H. BẢNG FACT_INVENTORY

### Tổng quan

Bảng FACT_INVENTORY chứa dữ liệu tồn kho theo ngày, bao gồm sản phẩm, tồn kho nhập, xuất, số lượng tồn, vị trí lưu trữ. Bảng này dùng để phân tích tồn kho và dòng tiền kho.

### Data Flow Task – Luồng xử lý dữ liệu

**Bước 1 – OLE DB Source: "Source - Stock Item Transactions"**

```sql
SELECT 
    sit.stock_item_transaction_id,
    sit.stock_item_id,
    sit.transaction_type_id,
    sit.transaction_date,
    sit.customer_id,
    sit.supplier_id,
    sit.quantity,
    sit.unit_price,
    sih.quantity_on_hand,
    sih.bin_location
FROM [dbo].[StockItemTransactions] sit
LEFT JOIN [dbo].[StockItemHoldings] sih ON sit.stock_item_id = sih.stock_item_id
WHERE sit.stock_item_id IS NOT NULL
```

**Bước 2 – Lookup Product Key: "Lookup - Product"**

```sql
SELECT wwi_stock_item_id, product_key, unit_cost
FROM [dbo].[DIM_PRODUCT]
WHERE valid_to IS NULL
AND is_current = 1
```

**Bước 3 – Lookup Date Key: "Lookup - Date"**

```sql
SELECT CAST(date_value AS DATE), date_key
FROM [dbo].[DIM_DATE]
```

**Bước 4 – Lookup Customer Key: "Lookup - Customer"** (nếu có khách hàng liên quan)

```sql
SELECT wwi_customer_id, customer_key
FROM [dbo].[DIM_CUSTOMER]
WHERE valid_to IS NULL
AND is_current = 1
```

**Bước 5 – Lookup Supplier Key: "Lookup - Supplier"** (nếu có nhà cung cấp liên quan)

```sql
SELECT wwi_supplier_id, supplier_key
FROM [dbo].[DIM_SUPPLIER]
WHERE valid_to IS NULL
AND is_current = 1
```

**Bước 6 – Derived Column: "Calculate Inventory Metrics"**

```
quantity_in = CASE WHEN transaction_type = "Receipt" THEN quantity ELSE 0 END
quantity_out = CASE WHEN transaction_type = "Sale" THEN quantity ELSE 0 END
transaction_value = quantity * unit_price
holding_location = bin_location
stock_value = quantity_on_hand * unit_cost
created_date = GETDATE()
batch_id = @BatchID
```

**Bước 7 – OLE DB Destination: "Insert FACT_INVENTORY"**

Chèn vào bảng FACT_INVENTORY.

---

**HẾT BÁNG CÁO CHI TIẾT**

