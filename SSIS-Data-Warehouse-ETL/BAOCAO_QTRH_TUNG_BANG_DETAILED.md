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

> **[Chèn ảnh: Execute SQL Task "Insert Lineage START" - Cửa sổ cài đặt SQL Command]**

**Bước 2 – Data Flow Task**

Đây là bước trọng tâm, thực hiện toàn bộ logic biến đổi và nạp dữ liệu vào bảng đích (Dimension hoặc Fact). Chi tiết xử lý được mô tả riêng cho từng bảng tại phần tiếp theo.

Các kết nối (Precedence Constraint) được cấu hình:
- Nếu Data Flow Task **thành công** → chuyển sang Bước 3
- Nếu Data Flow Task **thất bại** → chuyển sang nhánh Update Lineage FAILED

> **[Chèn ảnh: Data Flow Task container trong Control Flow - Hiển thị kết nối Success/Failure]**

**Bước 3 – Post-Processing Logic (tùy bảng)**

Sau khi dữ liệu được nạp thành công, thực thi các SQL command bổ sung để:
- **Cập nhật cột is_current:** Đánh dấu các bản ghi cũ đã bị thay thế (cho Dimension)
- **Cập nhật mối quan hệ:** Điều chỉnh các khóa ngoài tham chiếu (cho Dimension và Fact)
- **Tính toán metrics:** Hoàn thành các trường tính toán (cho Fact)

Chi tiết của bước này khác nhau tùy thuộc vào từng bảng, được mô tả trong phần Data Flow riêng.

> **[Chèn ảnh: Execute SQL Task "Post-Processing Logic" - Cửa sổ cài đặt một ví dụ SQL Command]**

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

> **[Chèn ảnh: Execute SQL Task "Update Lineage FAILED" - Cửa sổ cài đặt SQL Command cho lỗi]**

---

## PHẦN II: DATA FLOW CHI TIẾT THEO TỪNG BẢNG

> **[Chèn ảnh: Master_ETL.dtsx - Toàn bộ package master cho tất cả 8 package Load_* - Hiển thị trình tự thực thi]**

---

## A. BẢNG DIM_PRODUCT

### Tổng quan

Bảng DIM_PRODUCT chứa thông tin chi tiết về các mặt hàng bán hàng của công ty, bao gồm tên sản phẩm, màu sắc, loại đóng gói, brand, giá, thuế, và các thuộc tính khác. Bảng này được cập nhật thông qua quy trình SCD Type 2 để lưu giữ lịch sử các thay đổi.

### Data Flow Task – Luồng xử lý dữ liệu

> **[Chèn ảnh: Load_Dim_Product.dtsx - Data Flow Task Designer - Toàn bộ luồng từ OLE DB Source → SCD → Lookup → Union All → Derived Column → OLE DB Destination]**

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

> **[Chèn ảnh: OLE DB Source component - Cửa sổ Column Editor hiển thị các cột được select]**

**Bước 2 – Slowly Changing Dimension (SCD): "SCD - Product"**

Thành phần SCD Wizard so sánh dữ liệu đầu vào với bảng DIM_PRODUCT hiện tại dựa trên business key `wwi_stock_item_id`. Thành phần này phân loại các bản ghi thành 3 loại:

- **Historical Attribute Inserts Output:** Các bản ghi có thay đổi thuộc tính lịch sử (Type 2), chẳng hạn như tên sản phẩm thay đổi, giá thay đổi, hoặc brand thay đổi. Những bản ghi này cần tạo phiên bản mới và đóng phiên bản cũ.
  
- **New Output:** Các bản ghi hoàn toàn mới (sản phẩm mới được thêm vào hệ thống), chưa tồn tại trong DIM_PRODUCT.
  
- **Inferred Member Updates Output:** Các bản ghi inferred member (đã tồn tại dưới dạng placeholder với dữ liệu minimal), cần cập nhật thông tin thực tế.

> **[Chèn ảnh: Slowly Changing Dimension component - Mapping business key và các Type 2 attributes]**

**Bước 3a – Nhánh "Historical Attribute Inserts":**

**Component: Derived Column – "Add SCD Columns"**

Tính toán và bổ sung các cột cần thiết cho bản ghi lịch sử mới trước khi cập nhật bản ghi cũ:

- `valid_from = GETDATE()` — Ngày bắt đầu hiệu lực của bản ghi mới
- `is_current = 1` — Đánh dấu đây là bản ghi hiện tại
- `lineage_key = NEWID()` — UUID duy nhất cho mỗi bản ghi (phục vụ audit trail)
- `created_date = GETDATE()` — Timestamp khi bản ghi được tạo

> **[Chèn ảnh: Derived Column component - Cửa sổ Expression Editor hiển thị các công thức tính toán]**

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

> **[Chèn ảnh: OLE DB Command component - Cửa sổ cài đặt SQL Command và Column Mappings]**

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

> **[Chèn ảnh: Union All component - Hiển thị kết nối từ nhánh Historical và New]**

**Bước 4 – Union All: "Combine All Outputs"**

Gộp luồng từ nhánh Historical (sau Derived Column + OLE DB Command) và luồng New Output thành một luồng duy nhất. Bước này đảm bảo toàn bộ bản ghi mới (bao gồm bản ghi hoàn toàn mới và phiên bản lịch sử mới của bản ghi thay đổi) được chuẩn bị cho việc chèn vào bảng.

Kết hợp:
- Các cột từ nhánh Historical: `stock_item_name, color_name, brand, unit_price, tax_rate, unit_package_quantity, valid_from, is_current, lineage_key, created_date`
- Các cột từ nhánh New: `stock_item_name, color_name, brand, unit_price, tax_rate, unit_package_quantity, valid_from, is_current, lineage_key, created_date`

> **[Chèn ảnh: Cửa sổ Union All Input and Output Columns - Mapping các cột]**

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

> **[Chèn ảnh: OLE DB Destination component - Cửa sổ Mapping Input Columns to Destination Columns]**

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

> **[Chèn ảnh: Load_Dim_Supplier.dtsx - Data Flow Task Designer - Toàn bộ luồng SCD Type 2 cho Supplier]**

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

> **[Chèn ảnh: Load_Dim_Customer.dtsx - Data Flow Task Designer - Toàn bộ luồng SCD Type 2 cho Customer]**

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

> **[Chèn ảnh: Load_Dim_Employee.dtsx - Data Flow Task Designer - Toàn bộ luồng SCD Type 2 cho Employee]**

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

> **[Chèn ảnh: Load_Dim_City.dtsx - Data Flow Task Designer - Toàn bộ luồng SCD Type 2 cho City]**

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

**Đặc điểm:**
- Bảng fact này ghi nhận **từng dòng chi tiết** của mỗi hóa đơn bán hàng (invoice line)
- Dữ liệu không được tóm tắt hay nhóm; giữ nguyên độ chi tiết để hỗ trợ phân tích đa chiều
- Các khóa nước ngoài (product_key, customer_key, employee_key, date_key) liên kết đến các Dimension để có thể drill-down phân tích từ các góc độ khác nhau

### Data Flow Task – Luồng xử lý dữ liệu

> **[Chèn ảnh: Load_Fact_Sale.dtsx - Data Flow Task Designer - Luồng từ OLE DB Source → 4 Lookup components (Product, Customer, Employee, Date) → Derived Column → OLE DB Destination]**

**Bước 1 – OLE DB Source: "Source - Invoice Lines"**

**Ý nghĩa:** Lấy dữ liệu giao dịch bán hàng từ Staging Area. Dữ liệu này chứa ID của các đối tượng (sản phẩm, khách hàng, nhân viên) nhưng chưa có các khóa chính từ Dimension (product_key, customer_key, v.v.). Bước này chỉ là bước "extract" dữ liệu thô cần thiết.

```sql
SELECT 
    il.invoice_line_id,
    il.invoice_id,
    i.customer_id,           -- ID khách hàng từ OLTP, chưa có customer_key
    i.invoice_date,          -- Ngày bán hàng
    i.salesperson_id,        -- ID nhân viên bán hàng từ OLTP, chưa có employee_key
    il.stock_item_id,        -- ID sản phẩm từ OLTP, chưa có product_key
    il.quantity,             -- Số lượng bán
    il.unit_price,           -- Giá bán lẻ của dòng hóa đơn
    il.line_total,           -- Tổng tiền = quantity × unit_price (chưa trừ chiết khấu)
    ISNULL(il.discount_percent, 0) as discount_percent  -- % chiết khấu nếu có
FROM [dbo].[InvoiceLines] il
INNER JOIN [dbo].[Invoices] i ON il.invoice_id = i.invoice_id
WHERE il.invoice_id IS NOT NULL
```

**Ghi chú:**
- `INNER JOIN` với Invoices để lấy thông tin header hóa đơn (customer_id, invoice_date, salesperson_id)
- `line_total` trong Staging thường đã là `quantity × unit_price`, giá trị này chưa được điều chỉnh chiết khấu

> **[Chèn ảnh: OLE DB Source (Fact) - Cửa sổ SQL Command editor với kết nối INNER JOIN]**

**Bước 2 – Lookup Product Key: "Lookup - Product"**

**Ý nghĩa:** 
- **Vấn đề:** Dữ liệu bán hàng chứa `stock_item_id` (ID từ hệ thống OLTP), nhưng bảng FACT_SALES cần `product_key` (khóa chính từ DIM_PRODUCT) để liên kết đến Dimension Product, phục vụ phân tích theo sản phẩm.
- **Giải pháp:** Lookup lấy `product_key` từ DIM_PRODUCT bằng cách match `stock_item_id` từ dữ liệu bán hàng với `wwi_stock_item_id` trong DIM_PRODUCT.
- **Lọc dữ liệu:**
  - `WHERE valid_to IS NULL AND is_current = 1` — Chỉ lấy bản ghi hiện tại, không lấy bản ghi lịch sử (vì bảng fact ghi nhận thời điểm hiện tại của sản phẩm tại lúc bán hàng)

```sql
SELECT wwi_stock_item_id, product_key
FROM [dbo].[DIM_PRODUCT]
WHERE valid_to IS NULL
AND is_current = 1
```

**Cấu hình Lookup Component:**
- **Connection Manager:** wwi_data_warehouse
- **Column Mapping:** 
  - Input: `stock_item_id` (từ OLE DB Source)
  - Lookup Table: `wwi_stock_item_id` (từ DIM_PRODUCT)
- **Output:** `product_key` (trở thành cột mới trong luồng dữ liệu)
- **Error Handling:** Nếu không tìm được `product_key` (ví dụ sản phẩm không tồn tại trong DIM_PRODUCT), SSIS sẽ gửi dòng dữ liệu đó vào Output Lookup No Match (hoặc Error nếu cấu hình lỗi bắt buộc)

> **[Chèn ảnh: Lookup component - Cửa sổ Lookup Table Tab (chọn table DIM_PRODUCT), Reference Columns Tab (mapping stock_item_id → wwi_stock_item_id), Columns Tab (chọn output product_key)]**

**Bước 3 – Lookup Customer Key: "Lookup - Customer"**

**Ý nghĩa:** 
- **Vấn đề:** Dữ liệu bán hàng chứa `customer_id` từ OLTP, nhưng FACT_SALES cần `customer_key` từ DIM_CUSTOMER để phân tích theo khách hàng.
- **Giải pháp:** Lookup `customer_key` từ DIM_CUSTOMER bằng match `customer_id` ← `wwi_customer_id`
- **Tác dụng:** Cho phép phân tích câu hỏi như "Tổng doanh thu của khách hàng X là bao nhiêu?", "Khách hàng nào có doanh thu cao nhất?", v.v.

```sql
SELECT wwi_customer_id, customer_key
FROM [dbo].[DIM_CUSTOMER]
WHERE valid_to IS NULL
AND is_current = 1
```

**Cấu hình:**
- **Connection Manager:** wwi_data_warehouse
- **Column Mapping:** `customer_id` → `wwi_customer_id`
- **Output:** `customer_key`

> **[Chèn ảnh: Lookup Customer - Cửa sổ cấu hình]**

**Bước 4 – Lookup Employee Key: "Lookup - Employee"**

**Ý nghĩa:** 
- **Vấn đề:** Dữ liệu chứa `salesperson_id` (ID nhân viên bán hàng từ OLTP), FACT_SALES cần `employee_key` từ DIM_EMPLOYEE để phân tích theo nhân viên bán hàng.
- **Giải pháp:** Lookup `employee_key` từ DIM_EMPLOYEE bằng match `salesperson_id` ← `wwi_employee_id`
- **Tác dụng:** Hỗ trợ phân tích hiệu suất bán hàng theo nhân viên, như "Nhân viên nào có doanh thu cao nhất?", "So sánh kết quả bán hàng giữa các nhân viên", v.v.

```sql
SELECT wwi_employee_id, employee_key
FROM [dbo].[DIM_EMPLOYEE]
WHERE valid_to IS NULL
AND is_current = 1
```

**Cấu hình:**
- **Connection Manager:** wwi_data_warehouse
- **Column Mapping:** `salesperson_id` → `wwi_employee_id`
- **Output:** `employee_key`

> **[Chèn ảnh: Lookup Employee - Cửa sổ cấu hình]**

**Bước 5 – Lookup Date Key: "Lookup - Date"** (nếu có DIM_DATE)

**Ý nghĩa:** 
- **Vấn đề:** Dữ liệu chứa `invoice_date` (kiểu DATE hoặc DATETIME), nhưng để phân tích hiệu quả (như "Doanh thu theo tháng, quý, năm"), FACT_SALES cần `date_key` từ DIM_DATE, vì DIM_DATE chứa các cột tính toán sẵn (month, quarter, year, fiscal_year, day_of_week, v.v.)
- **Giải pháp:** Lookup `date_key` từ DIM_DATE bằng match `invoice_date` (cast thành DATE để khớp với định dạng trong DIM_DATE)

```sql
SELECT CAST(date_value AS DATE) as date_value, date_key
FROM [dbo].[DIM_DATE]
```

**Cấu hình:**
- **Connection Manager:** wwi_data_warehouse
- **Column Mapping:** `invoice_date` (cast thành DATE nếu cần) → `date_value` (trong DIM_DATE)
- **Output:** `date_key`
- **Lợi ích:** Cho phép phân tích "Doanh thu tháng 1", "Doanh thu quý 2", "Doanh thu năm 2023", v.v. thông qua các cột tính toán trong DIM_DATE

> **[Chèn ảnh: Lookup Date - SQL lookup table]**

**Bước 6 – Lookup City Key: "Lookup - City"** (nếu Staging có thông tin thành phố)

**Ý nghĩa:** 
- **Vấn đề:** Nếu Staging chứa thông tin thành phố giao hàng (delivery_city_id), FACT_SALES có thể cần `city_key` từ DIM_CITY để phân tích theo vị trí địa lý ("Doanh thu theo thành phố nào cao nhất?", "So sánh doanh thu giữa các thành phố")
- **Giải pháp:** Lookup `city_key` từ DIM_CITY

```sql
SELECT wwi_city_id, city_key
FROM [dbo].[DIM_CITY]
WHERE valid_to IS NULL
AND is_current = 1
```

> **[Chèn ảnh: Lookup City - cấu hình]**

**Bước 7 – Derived Column: "Calculate Sales Metrics"**

**Ý nghĩa:** 
Sau khi đã lookup tất cả các khóa từ Dimension, bước này **tính toán các metrics kinh doanh** dựa trên dữ liệu đã có. Các metrics này sẽ là các số liệu chính mà các nhà phân tích kinh doanh sử dụng để lập báo cáo và đưa ra quyết định.

```
# Tính chiết khấu tiền mặt
discount_amount = unit_price * quantity * (discount_percent / 100)
  → Ví dụ: Sản phẩm A giá 100, bán 10 cái, chiết khấu 10%
  → discount_amount = 100 * 10 * (10/100) = 100 (tiền chiết khấu)

# Tính doanh thu ròng (sau chiết khấu)
net_sales_amount = line_total - discount_amount
  → Doanh thu thực tế mà công ty nhận được sau chiết khấu
  → net_sales_amount = 1000 - 100 = 900

# Tính lợi nhuận gộp (nếu có unit_cost)
gross_profit_amount = net_sales_amount - (unit_cost * quantity)
  → unit_cost được lấy từ DIM_PRODUCT (giá vốn sản phẩm)
  → Ví dụ: net_sales_amount = 900, unit_cost = 50, quantity = 10
  → gross_profit_amount = 900 - (50 * 10) = 400

# Cột metadata
created_date = GETDATE()
  → Thời điểm dòng dữ liệu được tạo vào DW

batch_id = @BatchID
  → ID lô xử lý ETL, dùng để theo dõi dữ liệu được nạp lúc nào
```

**Tác dụng của các metrics:**
- `discount_amount`: Theo dõi tổng chiết khấu, đánh giá chính sách giảm giá
- `net_sales_amount`: Doanh thu thực tế sau chiết khấu (chính xác hơn `line_total`)
- `gross_profit_amount`: Lợi nhuận gộp, dùng để đánh giá hiệu quả kinh doanh từng sản phẩm/khách hàng

> **[Chèn ảnh: Derived Column component - Expression Editor hiển thị các công thức tính toán, ví dụ công thức discount_amount, net_sales_amount, gross_profit_amount]**

**Bước 8 – OLE DB Destination: "Insert FACT_SALES"**

**Ý nghĩa:** Chèn tất cả bản ghi đã được **transform đầy đủ** (có sẵn tất cả khóa từ Dimension và đã tính toán metrics) vào bảng FACT_SALES trong Data Warehouse.

**Cấu hình:**
- **Connection Manager:** wwi_data_warehouse (SQL Server)
- **Table:** `[dbo].[FACT_SALES]`
- **Data Access Mode:** Table or view (hoặc Table Name - Fast Load để tăng tốc độ)
- **Fast Load:** Nên bật (không dùng transaction, bé hơn tốc độ nhưng nhanh hơn)
- **Batch Size:** Thường 10000 hàng/batch để cân bằng tốc độ và bộ nhớ

**Các cột được chèn:**
```sql
INSERT INTO [dbo].[FACT_SALES]
(
    invoice_line_key,      -- PK tự tăng (hoặc surrogate key được tạo bởi DB)
    invoice_id,            -- ID hóa đơn từ source
    product_key,           -- FK đến DIM_PRODUCT (từ Lookup bước 2)
    customer_key,          -- FK đến DIM_CUSTOMER (từ Lookup bước 3)
    employee_key,          -- FK đến DIM_EMPLOYEE (từ Lookup bước 4)
    date_key,              -- FK đến DIM_DATE (từ Lookup bước 5)
    city_key,              -- FK đến DIM_CITY (từ Lookup bước 6, nếu có)
    quantity,              -- Số lượng sản phẩm bán
    unit_price,            -- Giá bán lẻ
    line_total,            -- Tổng = quantity × unit_price (trước chiết khấu)
    discount_amount,       -- Tiền chiết khấu (từ Derived Column bước 7)
    net_sales_amount,      -- Doanh thu ròng = line_total - discount_amount
    gross_profit_amount,   -- Lợi nhuận gộp = net_sales_amount - (unit_cost × quantity)
    batch_id,              -- ID lô ETL
    created_date           -- Ngày tạo record trong DW
)
VALUES (...)
```

**Xử lý lỗi:**
- Nếu có dòng dữ liệu không match được khóa từ Dimension (ví dụ sản phẩm không tồn tại) → Lookup component sẽ gửi vào Output "No Match", và có thể được ghi vào bảng lỗi để check sau
- Nếu constraint bị vi phạm (ví dụ khóa chính trùng) → Error được ghi vào log và có thể gọi Error handling trong Control Flow

> **[Chèn ảnh: OLE DB Destination component - Cửa sổ Mapping Input Columns to Destination Columns]**

---

## G. BẢNG FACT_PURCHASE

### Tổng quan

Bảng FACT_PURCHASE chứa chi tiết từng dòng đơn mua hàng, bao gồm sản phẩm, nhà cung cấp, số lượng, giá cả, ngày mua, ngày giao nhận. Bảng này dùng để phân tích chi phí mua hàng và hiệu suất chuỗi cung ứng.

**Đặc điểm:**
- Ghi nhận **từng dòng chi tiết** trong đơn mua hàng (purchase order line)
- Dùng để theo dõi chi phí mua, chất lượng hàng nhập (so sánh số lượng đặt vs nhận), thời gian giao nhận
- Hỗ trợ phân tích nhà cung cấp: "Nhà cung cấp nào có giá rẻ nhất?", "Nhà cung cấp nào giao hàng muộn?", v.v.

### Data Flow Task – Luồng xử lý dữ liệu

> **[Chèn ảnh: Load_Fact_Purchase.dtsx - Data Flow Task Designer - Luồng từ OLE DB Source (INNER JOIN) → 3 Lookup components (Product, Supplier, Date) → Derived Column → OLE DB Destination]**

**Bước 1 – OLE DB Source: "Source - Purchase Order Lines"**

**Ý nghĩa:** Lấy dữ liệu đơn mua hàng từ Staging. Dữ liệu này chứa chi tiết từng dòng mua (sản phẩm nào, số lượng mua bao nhiêu, giá bao nhiêu) cùng thông tin header đơn mua (nhà cung cấp, ngày đặt, ngày giao).

```sql
SELECT 
    pol.purchase_order_line_id,     -- ID dòng đơn mua (unique key)
    pol.purchase_order_id,          -- ID đơn mua (header)
    po.supplier_id,                 -- ID nhà cung cấp từ OLTP, chưa có supplier_key
    po.order_date,                  -- Ngày đặt mua
    po.delivery_date,               -- Ngày giao hàng thực tế
    pol.stock_item_id,              -- ID sản phẩm từ OLTP, chưa có product_key
    pol.ordered_quantity,           -- Số lượng đặt mua
    pol.received_quantity,          -- Số lượng thực tế nhận được (có thể khác ordered_quantity)
    pol.unit_price                  -- Giá mua trên 1 đơn vị sản phẩm
FROM [dbo].[PurchaseOrderLines] pol
INNER JOIN [dbo].[PurchaseOrders] po ON pol.purchase_order_id = po.purchase_order_id
WHERE pol.purchase_order_id IS NOT NULL
```

**Ghi chú:**
- `INNER JOIN` để lấy thông tin header đơn mua (supplier_id, order_date, delivery_date)
- `ordered_quantity` vs `received_quantity` có thể khác nhau → được dùng để tính variance (chênh lệch) sau

> **[Chèn ảnh: OLE DB Source (Purchase) - SQL Query editor với INNER JOIN]**

**Bước 2 – Lookup Product Key: "Lookup - Product"**

**Ý nghĩa:** 
- **Vấn đề:** Dữ liệu mua hàng chứa `stock_item_id` từ OLTP, nhưng FACT_PURCHASE cần `product_key` từ DIM_PRODUCT để phân tích "Sản phẩm nào có giá mua cao nhất?", "Chi phí mua sản phẩm nào lớn nhất?", v.v.
- **Giải pháp:** Lookup `product_key` từ DIM_PRODUCT

```sql
SELECT wwi_stock_item_id, product_key
FROM [dbo].[DIM_PRODUCT]
WHERE valid_to IS NULL
AND is_current = 1
```

**Cấu hình:** Mapping `stock_item_id` (input) → `wwi_stock_item_id` (DIM_PRODUCT), Output `product_key`

> **[Chèn ảnh: Lookup Product component]**

**Bước 3 – Lookup Supplier Key: "Lookup - Supplier"**

**Ý nghĩa:** 
- **Vấn đề:** Dữ liệu chứa `supplier_id` từ OLTP, nhưng FACT_PURCHASE cần `supplier_key` từ DIM_SUPPLIER để phân tích theo nhà cung cấp.
- **Giải pháp:** Lookup `supplier_key` từ DIM_SUPPLIER bằng match `supplier_id` ← `wwi_supplier_id`
- **Tác dụng:** Hỗ trợ phân tích "Nhà cung cấp nào có giá rẻ nhất?", "Nhà cung cấp nào giao hàng đúng hạn?", "So sánh chất lượng giữa các nhà cung cấp" (thông qua variance của số lượng)

```sql
SELECT wwi_supplier_id, supplier_key
FROM [dbo].[DIM_SUPPLIER]
WHERE valid_to IS NULL
AND is_current = 1
```

**Cấu hình:** Mapping `supplier_id` → `wwi_supplier_id`, Output `supplier_key`

> **[Chèn ảnh: Lookup Supplier component]**

**Bước 4 – Lookup Date Key: "Lookup - Order Date"** (nếu có DIM_DATE)

**Ý nghĩa:** 
- **Vấn đề:** Dữ liệu chứa `order_date` (DATE), nhưng để phân tích "Chi phí mua hàng từng tháng/quý/năm", FACT_PURCHASE cần `date_key` từ DIM_DATE.
- **Giải pháp:** Lookup `date_key` từ DIM_DATE bằng match `order_date`
- **Tác dụng:** Cho phép phân tích theo thời gian, như "Chi phí mua hàng tháng 1 vs tháng 2", "Mùa nào mua hàng nhiều nhất?", v.v.

```sql
SELECT CAST(date_value AS DATE) as date_value, date_key
FROM [dbo].[DIM_DATE]
```

**Cấu hình:** Mapping `order_date` → `date_value`, Output `date_key`

> **[Chèn ảnh: Lookup Order Date component]**

**Bước 5 – Derived Column: "Calculate Purchase Metrics"**

**Ý nghĩa:** Tính toán các chỉ số kinh doanh mua hàng dựa trên dữ liệu đã có.

```
# Tính tổng giá trị đơn mua (dự kiến)
purchase_amount = ordered_quantity * unit_price
  → Giá trị nếu nhà cung cấp giao đúng số lượng đặt
  → Ví dụ: Đặt 100 cái, giá $10/cái → purchase_amount = $1000

# Tính giá trị hàng thực tế nhận
received_amount = received_quantity * unit_price
  → Giá trị hàng thực tế giao tới
  → Ví dụ: Nhận 95 cái, giá $10/cái → received_amount = $950

# Tính chênh lệch giá (vì số lượng khác)
variance_amount = (received_quantity - ordered_quantity) * unit_price
  → Tác dụng: Đo lường tác động tài chính của lỗi giao hàng
  → Ví dụ: (95 - 100) * $10 = -$50 (thiệt 5 cái = $50)
  → Âm = thiếu hàng, dương = thừa hàng

# Tính chênh lệch số lượng
variance_qty = received_quantity - ordered_quantity
  → Ví dụ: 95 - 100 = -5 (thiếu 5 cái)
  → Dùng để đánh giá độ chính xác giao hàng

# Tính số ngày giao (nhằm đánh giá tốc độ giao hàng)
delivery_days = DATEDIFF(DAY, order_date, delivery_date)
  → Ví dụ: Đặt 1/1, giao 5/1 → 4 ngày
  → Âm = giao sớm, dương = giao muộn (nếu có định kỳ giao)
  → Dùng để đánh giá hiệu suất chuỗi cung ứng

# Metadata
created_date = GETDATE()
batch_id = @BatchID
```

**Tác dụng của các metrics:**
- `purchase_amount`: Ngân sách dự kiến
- `received_amount`: Chi phí thực tế
- `variance_amount & variance_qty`: Đánh giá hiệu suất giao hàng (độ chính xác, chất lượng nhà cung cấp)
- `delivery_days`: Đánh giá tốc độ giao hàng

> **[Chèn ảnh: Derived Column (Purchase) - Expression Editor hiển thị công thức DATEDIFF, phép trừ, phép nhân]**

**Bước 6 – OLE DB Destination: "Insert FACT_PURCHASE"**

**Ý nghĩa:** Chèn các bản ghi đã được tính toán metrics vào bảng FACT_PURCHASE.

**Cấu hình:**
- **Table:** `[dbo].[FACT_PURCHASE]`
- **Các cột:**
  - `purchase_order_line_key` — Surrogate key
  - `purchase_order_id` — ID đơn mua
  - `product_key` — FK đến DIM_PRODUCT
  - `supplier_key` — FK đến DIM_SUPPLIER
  - `date_key` — FK đến DIM_DATE
  - `ordered_quantity, received_quantity, unit_price` — Dữ liệu gốc
  - `purchase_amount, received_amount, variance_amount, variance_qty` — Metrics được tính toán
  - `delivery_days` — Ngày giao (để đánh giá SLA)
  - `batch_id, created_date` — Metadata

> **[Chèn ảnh: OLE DB Destination - Mapping cột]**

---

## H. BẢNG FACT_INVENTORY

### Tổng quan

Bảng FACT_INVENTORY chứa dữ liệu giao dịch tồn kho (nhập/xuất), bao gồm sản phẩm, loại giao dịch, số lượng nhập/xuất, ngày giao dịch, vị trí lưu trữ, giá trị tồn kho. Bảng này dùng để phân tích dòng tiền kho, vòng quay tồn kho, và hiệu suất kho.

**Đặc điểm:**
- Ghi nhận **từng giao dịch tồn kho** (nhập từ nhà cung cấp, xuất bán cho khách hàng, điều chỉnh tồn kho)
- Dữ liệu là time-series (chuỗi theo thời gian), cho phép phân tích xu hướng tồn kho
- Kết hợp dữ liệu giao dịch (từ StockItemTransactions) với dữ liệu tồn kho hiện tại (từ StockItemHoldings)
- Hỗ trợ phân tích: "Vòng quay tồn kho", "Sản phẩm nào chậy bán?", "Giá trị tồn kho theo sản phẩm/vị trí", v.v.

### Data Flow Task – Luồng xử lý dữ liệu

> **[Chèn ảnh: Load_Fact_Inventory.dtsx - Data Flow Task Designer - Luồng từ OLE DB Source (với LEFT JOIN) → 4 Lookup components (Product, Date, Customer, Supplier) → Derived Column → OLE DB Destination]**

**Bước 1 – OLE DB Source: "Source - Stock Item Transactions"**

**Ý nghĩa:** 
Bước này lấy dữ liệu **giao dịch tồn kho** từ Staging (ghi nhận mỗi lần hàng vào/ra kho) và **kết hợp với dữ liệu tồn kho hiện tại** (snapshot tại thời điểm chạy ETL).

Tại sao cần LEFT JOIN?
- `StockItemTransactions` ghi nhận các **sự kiện** (events) nhập/xuất hàng
- `StockItemHoldings` ghi nhận **trạng thái tồn kho hiện tại** (quantity on hand, vị trí lưu trữ)
- Kết hợp hai bảng này cho phép ghi nhận: "Khi sản phẩm A được bán 100 cái vào ngày 1/1, thì tồn kho hiện tại còn bao nhiêu?"
- **LEFT JOIN** (không INNER JOIN) vì có thể có sản phẩm có giao dịch nhưng chưa có bản ghi tồn kho (hoặc ngược lại)

```sql
SELECT 
    sit.stock_item_transaction_id,     -- ID giao dịch (unique)
    sit.stock_item_id,                 -- ID sản phẩm từ OLTP, chưa có product_key
    sit.transaction_type_id,           -- Loại giao dịch (1=Nhập, 2=Xuất, 3=Điều chỉnh, v.v.)
    sit.transaction_date,              -- Ngày giao dịch
    sit.customer_id,                   -- ID khách hàng (nếu giao dịch là xuất bán)
    sit.supplier_id,                   -- ID nhà cung cấp (nếu giao dịch là nhập mua)
    sit.quantity,                      -- Số lượng nhập/xuất
    sit.unit_price,                    -- Giá trên 1 đơn vị (để tính giá trị giao dịch)
    sih.quantity_on_hand,              -- Tồn kho hiện tại của sản phẩm (snapshot)
    sih.bin_location                   -- Vị trí lưu trữ trong kho
FROM [dbo].[StockItemTransactions] sit
LEFT JOIN [dbo].[StockItemHoldings] sih ON sit.stock_item_id = sih.stock_item_id
WHERE sit.stock_item_id IS NOT NULL
```

**Ghi chú:**
- `quantity` có thể dương (nhập) hoặc âm (xuất) tùy theo `transaction_type_id`
- `quantity_on_hand` từ StockItemHoldings là snapshot tại thời điểm chạy ETL, không phải tồn kho tại thời điểm giao dịch
  → Nên nói rõ trong metadata hoặc tính toán tồn kho từng ngày nếu cần phân tích chi tiết

> **[Chèn ảnh: OLE DB Source (Inventory) - SQL Query editor với LEFT JOIN, hiển thị cấu trúc dữ liệu]**

**Bước 2 – Lookup Product Key: "Lookup - Product"**

**Ý nghĩa:** 
- **Vấn đề:** Dữ liệu giao dịch chứa `stock_item_id`, cần `product_key` từ DIM_PRODUCT để phân tích theo sản phẩm ("Sản phẩm nào có vòng quay cao?", "Giá trị tồn kho sản phẩm nào lớn nhất?")
- **Phần thêm:** Lookup cũng lấy `unit_cost` từ DIM_PRODUCT, vì cần để tính giá trị tồn kho (`quantity_on_hand * unit_cost`)

```sql
SELECT wwi_stock_item_id, product_key, unit_cost
FROM [dbo].[DIM_PRODUCT]
WHERE valid_to IS NULL
AND is_current = 1
```

**Cấu hình:** Mapping `stock_item_id` → `wwi_stock_item_id`, Output `product_key` và `unit_cost`

**Tác dụng:**
- `product_key` cho phép drill-down vào chi tiết sản phẩm (tên, loại, brand, v.v.)
- `unit_cost` dùng để tính giá trị tồn kho: `quantity_on_hand * unit_cost`

> **[Chèn ảnh: Lookup Product component - Output columns chứa product_key và unit_cost]**

**Bước 3 – Lookup Date Key: "Lookup - Date"**

**Ý nghĩa:** 
- **Vấn đề:** Dữ liệu chứa `transaction_date`, cần `date_key` từ DIM_DATE để phân tích theo thời gian
- **Tác dụng:** Hỗ trợ phân tích "Tồn kho trung bình tháng 1", "Vòng quay tồn kho năm 2023", "Xu hướng tồn kho qua các tháng", v.v.

```sql
SELECT CAST(date_value AS DATE) as date_value, date_key
FROM [dbo].[DIM_DATE]
```

**Cấu hình:** Mapping `transaction_date` → `date_value`, Output `date_key`

> **[Chèn ảnh: Lookup Date component]**

**Bước 4 – Lookup Customer Key: "Lookup - Customer"** (nếu giao dịch là xuất bán)

**Ý nghĩa:** 
- **Vấn đề:** Nếu `transaction_type_id = 2` (xuất bán), thì `customer_id` sẽ có giá trị. Cần lookup `customer_key` để phân tích "Khách hàng nào mua sản phẩm X nhiều nhất?"
- **Ghi chú:** Nếu `transaction_type_id ≠ 2`, thì `customer_id = NULL` → Lookup sẽ không match, cần xử lý (để output customer_key = NULL)

```sql
SELECT wwi_customer_id, customer_key
FROM [dbo].[DIM_CUSTOMER]
WHERE valid_to IS NULL
AND is_current = 1
```

**Cấu hình:** Mapping `customer_id` → `wwi_customer_id`, Output `customer_key`, cho phép NULL nếu không match

> **[Chèn ảnh: Lookup Customer component]**

**Bước 5 – Lookup Supplier Key: "Lookup - Supplier"** (nếu giao dịch là nhập mua)

**Ý nghĩa:** 
- **Vấn đề:** Nếu `transaction_type_id = 1` (nhập mua), thì `supplier_id` sẽ có giá trị. Cần lookup `supplier_key` để phân tích "Nhà cung cấp nào cung cấp sản phẩm X?"
- **Ghi chú:** Tương tự Customer, nếu không match, output supplier_key = NULL

```sql
SELECT wwi_supplier_id, supplier_key
FROM [dbo].[DIM_SUPPLIER]
WHERE valid_to IS NULL
AND is_current = 1
```

**Cấu hình:** Mapping `supplier_id` → `wwi_supplier_id`, Output `supplier_key`, cho phép NULL nếu không match

> **[Chèn ảnh: Lookup Supplier component]**

**Bước 6 – Derived Column: "Calculate Inventory Metrics"**

**Ý nghĩa:** Tính toán các chỉ số quản lý kho dựa trên loại giao dịch và dữ liệu tồn kho.

```
# Tách nhập/xuất dựa trên transaction_type_id
quantity_in = CASE 
    WHEN transaction_type_id = 1 THEN quantity  -- Loại giao dịch = Nhập
    ELSE 0 
END
  → Ví dụ: Nếu nhập 100 cái → quantity_in = 100, quantity_out = 0

quantity_out = CASE 
    WHEN transaction_type_id = 2 THEN ABS(quantity)  -- Loại giao dịch = Xuất (quantity âm)
    ELSE 0 
END
  → Ví dụ: Nếu xuất -50 cái → quantity_in = 0, quantity_out = 50

# Tính giá trị giao dịch
transaction_value = quantity * unit_price
  → Dùng để theo dõi giá trị nhập/xuất hàng theo ngày
  → Ví dụ: Nhập 100 cái, giá $10/cái → transaction_value = $1000

# Ghi nhận vị trí lưu trữ
holding_location = bin_location
  → Copy từ StockItemHoldings, dùng để phân tích tồn kho theo vị trí (kho A/B/C)

# Tính giá trị tồn kho tại thời điểm này
stock_value = quantity_on_hand * unit_cost
  → quantity_on_hand từ StockItemHoldings (snapshot hiện tại)
  → unit_cost từ DIM_PRODUCT (giá vốn)
  → Ví dụ: 500 cái tồn, giá vốn $10/cái → stock_value = $5000
  → Dùng để báo cáo giá trị tồn kho tài chính

# Metadata
created_date = GETDATE()
batch_id = @BatchID
```

**Tác dụng của các metrics:**
- `quantity_in / quantity_out` — Phân tách nhập/xuất để tính vòng quay tồn kho (COGS / Avg Inventory)
- `transaction_value` — Theo dõi tổng giá trị nhập/xuất hàng (dòng tiền kho)
- `holding_location` — Phân tích tồn kho theo vị trí (để tối ưu hóa sắp xếp kho)
- `stock_value` — Báo cáo tài chính: "Giá trị tồn kho của công ty là bao nhiêu?"

> **[Chèn ảnh: Derived Column (Inventory) - Expression Editor hiển thị công thức CASE WHEN, phép nhân, ABS()]**

**Bước 7 – OLE DB Destination: "Insert FACT_INVENTORY"**

**Ý nghĩa:** Chèn các bản ghi giao dịch tồn kho đã được tính toán metrics vào bảng FACT_INVENTORY.

**Cấu hình:**
- **Table:** `[dbo].[FACT_INVENTORY]`
- **Các cột chính:**
  - `stock_transaction_key` — Surrogate key
  - `stock_item_transaction_id` — ID giao dịch từ source
  - `product_key` — FK đến DIM_PRODUCT
  - `date_key` — FK đến DIM_DATE
  - `customer_key` — FK đến DIM_CUSTOMER (nếu xuất bán, NULL nếu không)
  - `supplier_key` — FK đến DIM_SUPPLIER (nếu nhập mua, NULL nếu không)
  - `transaction_type_id` — Loại giao dịch (1=Nhập, 2=Xuất, 3=Điều chỉnh)
  - `quantity, unit_price` — Dữ liệu gốc
  - `quantity_in, quantity_out` — Metrics (đã tách theo loại)
  - `transaction_value` — Giá trị giao dịch
  - `quantity_on_hand, holding_location` — Tồn kho snapshot
  - `stock_value` — Giá trị tồn kho ($)
  - `batch_id, created_date` — Metadata

**Lợi ích của cấu trúc này:**
- Có thể tính vòng quay tồn kho: `SUM(quantity_out) / AVG(quantity_on_hand)`
- Có thể phân tích tồn kho "chết" (không được bán trong thời gian dài)
- Có thể tối ưu hóa vị trí lưu trữ dựa trên `holding_location` và `transaction_value`
- Có thể kiểm soát dòng tiền kho thông qua `stock_value`

> **[Chèn ảnh: OLE DB Destination - Mapping tất cả các cột từ Derived Column vào FACT_INVENTORY]**

---

**HẾT BÁNG CÁO CHI TIẾT**

