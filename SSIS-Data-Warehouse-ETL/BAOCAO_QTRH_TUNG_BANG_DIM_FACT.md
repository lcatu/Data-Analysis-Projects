# BÁNG CÁO CHI TIẾT QUY TRÌNH ĐỔ DỮ LIỆU - TỪng BẢNG TRONG SSIS
## Dự án WideWorldImposter

---

## A. BẢNG DIM_PRODUCT

### 1. Tổng quan

Quy trình đổ dữ liệu bảng DIM_PRODUCT được thực hiện thông qua package SSIS `Load_Dim_Product.dtsx`, bao gồm hai cấp độ xử lý:

**Control Flow:** Điều phối luồng thực thi tổng thể, ghi nhận trạng thái lineage (bắt đầu, thành công, thất bại).

**Data Flow Task:** Xử lý dữ liệu theo mô hình Slowly Changing Dimension (SCD) Type 2, đảm bảo lưu vết lịch sử thay đổi của các sản phẩm. Bảng DIM_PRODUCT chứa thông tin chi tiết về các mặt hàng bán hàng, bao gồm tên sản phẩm, màu sắc, loại đóng gói, và các thuộc tính khác.

### 2. Control Flow – Luồng điều phối

Control Flow gồm các bước thực thi theo thứ tự sau:

**Bước 1 – Insert Lineage START**

Thực thi một câu lệnh SQL để ghi nhận thông tin bắt đầu của lần chạy vào bảng lineage (log). Mục đích là theo dõi thời gian khởi động package `Load_Dim_Product`, tên package, và các thông số liên quan để phục vụ kiểm tra, debug sau này. Bảng lineage sẽ ghi nhận: timestamp_start, package_name, execution_id, status = "START".

**Bước 2 – Data Flow Task**

Đây là bước trọng tâm, thực hiện toàn bộ logic biến đổi và nạp dữ liệu vào bảng DIM_PRODUCT. Chi tiết xử lý được mô tả tại mục 3 bên dưới.

- Nếu thành công → chuyển sang Bước 3.
- Nếu thất bại → chuyển sang nhánh Update Lineage FAILED (ghi nhận lỗi vào bảng lineage và kết thúc package).

**Bước 3 – Update is_current**

Sau khi dữ liệu mới được nạp, thực thi câu lệnh SQL để cập nhật cờ `is_current = 0` cho các bản ghi cũ đã bị thay thế bởi bản ghi phiên bản mới hơn. SQL command:
```sql
UPDATE DIM_PRODUCT 
SET is_current = 0 
WHERE wwi_stock_item_id IN (SELECT DISTINCT wwi_stock_item_id FROM DIM_PRODUCT WHERE valid_to IS NOT NULL AND is_current = 1)
```
Bước này đảm bảo tính nhất quán của SCD Type 2 trong bảng DIM_PRODUCT.

**Bước 4 – Update Lineage SUCCESS**

Thực thi câu lệnh SQL để cập nhật trạng thái lineage = "SUCCESS", ghi nhận thời gian hoàn thành, số dòng đã xử lý, và số bản ghi được chèn/cập nhật.

### 3. Data Flow Task – Luồng xử lý dữ liệu

**Bước 3.1 – OLE DB Source**

Đọc dữ liệu từ bảng Staging thông qua kết nối OLE DB connection manager `wwi_staging_area`. Câu truy vấn SELECT lấy các thuộc tính cần thiết của thực thể Product:
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
```

**Bước 3.2 – Slowly Changing Dimension (SCD)**

Thành phần SCD Wizard so sánh dữ liệu đầu vào với bảng DIM_PRODUCT hiện tại dựa trên business key `wwi_stock_item_id`. Từ đây luồng dữ liệu được chia thành 3 nhánh:

- **Historical Attribute Inserts Output:** Các bản ghi có thay đổi thuộc tính lịch sử (Type 2) như tên sản phẩm, màu sắc, giá – cần tạo phiên bản mới và đóng phiên bản cũ.
- **New Output:** Các bản ghi hoàn toàn mới (sản phẩm mới được thêm vào), chưa tồn tại trong DIM_PRODUCT.
- **Inferred Member Updates Output:** Các bản ghi inferred member (đã tồn tại dưới dạng placeholder), cần cập nhật thông tin thực tế.

**Bước 3.3a – Nhánh Historical Attribute Inserts**

- **Derived Column:** Tính toán và bổ sung các cột cần thiết cho bản ghi lịch sử mới:
  - `valid_from = GETDATE()`
  - `is_current = 1`
  - `lineage_key = NEWID()` (UUID duy nhất cho mỗi bản ghi)
  
- **OLE DB Command:** Thực thi UPDATE trực tiếp trên bảng DIM_PRODUCT để đóng phiên bản cũ trước khi chèn phiên bản mới:
  ```sql
  UPDATE DIM_PRODUCT 
  SET valid_to = ?, is_current = 0 
  WHERE wwi_stock_item_id = ? AND valid_to IS NULL
  ```

**Bước 3.3b – Nhánh Inferred Member Updates**

- **OLE DB Command 1:** Thực thi UPDATE để điền đầy đủ thuộc tính cho các bản ghi inferred member hiện có:
  ```sql
  UPDATE DIM_PRODUCT 
  SET stock_item_name = ?, color_name = ?, brand = ?, unit_price = ? 
  WHERE wwi_stock_item_id = ? AND is_current = 1
  ```

**Bước 3.4 – Union All**

Gộp luồng từ nhánh Historical (sau Derived Column + OLE DB Command) và luồng New Output thành một luồng duy nhất để chuẩn bị chèn mới vào bảng DIM_PRODUCT. Đảm bảo các cột từ cả hai nhánh được sắp xếp đúng thứ tự.

**Bước 3.5 – Derived Column 1**

Bổ sung hoặc chuẩn hóa các cột metadata chung cho toàn bộ bản ghi mới trước khi chèn:
- `created_date = GETDATE()`
- `batch_id = [Parameter_BatchID]` (truyền từ package parameter)
- `source_system = "Staging"` (cặp nguồn dữ liệu)

**Bước 3.6 – Insert Destination**

Chèn toàn bộ bản ghi mới vào bảng DIM_PRODUCT thông qua kết nối OLE DB `wwi_data_warehouse`. Sử dụng **fast load option** để tăng tốc độ.

### 4. Xử lý lỗi

Trong trường hợp Data Flow Task thất bại ở bất kỳ bước nào, Control Flow sẽ kích hoạt kết nối Failure và chuyển sang task Update Lineage FAILED. Task này ghi nhận thông tin lỗi vào bảng lineage:
- `error_timestamp = GETDATE()`
- `error_code` (mã lỗi từ SSIS)
- `error_description` (mô tả chi tiết)
- `affected_rows = (number of rows processed before failure)`

Đội vận hành có thể truy vấn bảng lineage để nhanh chóng phát hiện và xử lý sự cố.

---

## B. BẢNG DIM_SUPPLIER

### 1. Tổng quan

Quy trình đổ dữ liệu bảng DIM_SUPPLIER được thực hiện thông qua package SSIS `Load_Dim_Supplier.dtsx`. Bảng DIM_SUPPLIER chứa thông tin chi tiết về các nhà cung cấp, bao gồm tên nhà cung cấp, loại hình, thành phố, quốc gia, và các thông tin tài chính từ hệ thống `financial_data_warehouse`.

**Điểm đặc biệt:** Package này có thêm Connection Manager đến `financial_data_warehouse` để lấy thông tin tài chính về nhà cung cấp, tạo nên một dimension phong phú hơn.

Quy trình theo mô hình Slowly Changing Dimension (SCD) Type 2, đảm bảo lưu vết lịch sử thay đổi của nhà cung cấp.

### 2. Control Flow – Luồng điều phối

**Bước 1 – Insert Lineage START**

Ghi nhận thông tin bắt đầu của lần chạy package `Load_Dim_Supplier` vào bảng lineage. Bảng lineage sẽ ghi nhận: `timestamp_start, package_name = "Load_Dim_Supplier", status = "START"`.

**Bước 2 – Data Flow Task**

Thực hiện toàn bộ logic biến đổi và nạp dữ liệu vào bảng DIM_SUPPLIER. 

- Nếu thành công → chuyển sang Bước 3.
- Nếu thất bại → chuyển sang nhánh Update Lineage FAILED.

**Bước 3 – Update Payment Terms**

Sau khi dữ liệu mới được nạp, thực thi câu lệnh SQL để cập nhật các điều khoản thanh toán từ hệ thống tài chính:
```sql
UPDATE DIM_SUPPLIER 
SET payment_days = fs.payment_days, 
    credit_limit = fs.credit_limit,
    is_current = 1 
FROM financial_data_warehouse.dbo.Supplier_Financial fs
WHERE DIM_SUPPLIER.wwi_supplier_id = fs.wwi_supplier_id
```

**Bước 4 – Update Lineage SUCCESS**

Ghi nhận trạng thái lineage = "SUCCESS" với số bản ghi đã xử lý.

### 3. Data Flow Task – Luồng xử lý dữ liệu

**Bước 3.1 – OLE DB Source**

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
```

**Bước 3.2 – Slowly Changing Dimension (SCD)**

So sánh dữ liệu đầu vào với DIM_SUPPLIER hiện tại dựa trên business key `wwi_supplier_id`. Luồng dữ liệu được chia thành 3 nhánh (Historical Attribute Inserts, New Output, Inferred Member Updates).

**Bước 3.3a – Nhánh Historical Attribute Inserts**

- **Derived Column:** Bổ sung cột metadata:
  - `valid_from = GETDATE()`
  - `is_current = 1`
  - `lineage_key = NEWID()`
  
- **OLE DB Command:** Đóng phiên bản cũ:
  ```sql
  UPDATE DIM_SUPPLIER 
  SET valid_to = ?, is_current = 0, payment_days = NULL 
  WHERE wwi_supplier_id = ? AND valid_to IS NULL
  ```

**Bước 3.3b – Nhánh Inferred Member Updates**

- **OLE DB Command:** Cập nhật thông tin inferred member:
  ```sql
  UPDATE DIM_SUPPLIER 
  SET supplier_name = ?, supplier_category_name = ? 
  WHERE wwi_supplier_id = ? AND is_current = 1
  ```

**Bước 3.4 – Union All**

Gộp hai nhánh Historical và New Output.

**Bước 3.5 – Derived Column 1**

Bổ sung cột metadata chung:
- `created_date = GETDATE()`
- `batch_id = [Parameter_BatchID]`
- `source_system = "Staging"`

**Bước 3.6 – Insert Destination**

Chèn vào bảng DIM_SUPPLIER.

### 4. Xử lý lỗi

Khi Data Flow Task thất bại, Control Flow ghi nhận lỗi vào bảng lineage với `error_timestamp, error_code, error_description`. Đặc biệt, nếu lỗi liên quan đến kết nối `financial_data_warehouse`, lỗi sẽ được ghi nhận để từng vấn đề về dữ liệu tài chính có thể được theo dõi riêng biệt.

---

## C. BẢNG DIM_CUSTOMER

### 1. Tổng quan

Quy trình đổ dữ liệu bảng DIM_CUSTOMER được thực hiện thông qua package SSIS `Load_Dim_Customer.dtsx`. Bảng DIM_CUSTOMER chứa thông tin chi tiết về khách hàng, bao gồm tên khách hàng, địa chỉ, phân loại khách hàng (bán lẻ, bán buôn), và các dữ liệu liên hệ.

**Điểm đặc biệt:** Dimension này có xu hướng thay đổi cao vì thông tin khách hàng thường được cập nhật (thay đổi địa chỉ, loại khách hàng, v.v.). SCD Type 2 rất quan trọng để theo dõi lịch sử các thay đổi này.

### 2. Control Flow – Luồng điều phối

**Bước 1 – Insert Lineage START**

Ghi nhận bắt đầu lần chạy package `Load_Dim_Customer` vào bảng lineage.

**Bước 2 – Data Flow Task**

Thực hiện logic biến đổi và nạp vào DIM_CUSTOMER.

- Nếu thành công → Bước 3.
- Nếu thất bại → Update Lineage FAILED.

**Bước 3 – Validate Customer Hierarchy**

Sau khi nạp dữ liệu, thực thi câu lệnh SQL để xác thực rằng các khách hàng con (subsidiary customers) có tham chiếu hợp lệ đến khách hàng cha (parent customer):
```sql
UPDATE DIM_CUSTOMER SET is_valid_hierarchy = 0 
WHERE wwi_customer_id IN 
    (SELECT c.wwi_customer_id FROM DIM_CUSTOMER c
     WHERE c.parent_customer_id IS NOT NULL 
     AND NOT EXISTS (SELECT 1 FROM DIM_CUSTOMER p 
                     WHERE p.wwi_customer_id = c.parent_customer_id 
                     AND p.is_current = 1))
```

**Bước 4 – Update Lineage SUCCESS**

Ghi nhận trạng thái thành công.

### 3. Data Flow Task – Luồng xử lý dữ liệu

**Bước 3.1 – OLE DB Source**

Đọc dữ liệu từ Staging:
```sql
SELECT 
    wwi_customer_id,
    customer_name,
    customer_category_id,
    buying_group_id,
    customer_type_id,
    delivery_city_id,
    postal_code,
    valid_from,
    valid_to
FROM [dbo].[Customers]
WHERE wwi_customer_id IS NOT NULL
```

**Bước 3.2 – Slowly Changing Dimension (SCD)**

So sánh với DIM_CUSTOMER dựa trên `wwi_customer_id`.

**Bước 3.3a – Nhánh Historical Attribute Inserts**

- **Derived Column:** `valid_from, is_current = 1, lineage_key`
- **OLE DB Command:** Đóng bản ghi cũ

**Bước 3.3b – Nhánh Inferred Member Updates**

- **OLE DB Command:** Cập nhật thông tin

**Bước 3.4 – Union All**

Gộp các nhánh.

**Bước 3.5 – Derived Column 1**

Bổ sung metadata: `created_date, batch_id, source_system`

**Bước 3.6 – Insert Destination**

Chèn vào DIM_CUSTOMER.

### 4. Xử lý lỗi

Khi thất bại, ghi nhận lỗi vào lineage. Lỗi có thể liên quan đến:
- Dữ liệu không hợp lệ từ Staging (tham chiếu không tồn tại)
- Lỗi khóa chính/khóa ngoài trong bảng DIM_CUSTOMER
- Quá trình xác thực hierarchy thất bại

---

## D. BẢNG DIM_EMPLOYEE

### 1. Tổng quan

Quy trình đổ dữ liệu bảng DIM_EMPLOYEE được thực hiện thông qua package SSIS `Load_Dim_Employee.dtsx`. Bảng DIM_EMPLOYEE chứa thông tin chi tiết về nhân viên, bao gồm tên nhân viên, vị trí công việc, phòng ban, và các thông tin liên hệ.

Mô hình dữ liệu theo SCD Type 2 để lưu trữ lịch sử các thay đổi về nhân viên (thay đổi chức vụ, phòng ban, v.v.).

### 2. Control Flow – Luồng điều phối

**Bước 1 – Insert Lineage START**

Ghi nhận bắt đầu lần chạy package vào bảng lineage.

**Bước 2 – Data Flow Task**

Thực hiện logic biến đổi và nạp vào DIM_EMPLOYEE.

- Nếu thành công → Bước 3.
- Nếu thất bại → Update Lineage FAILED.

**Bước 3 – Update Manager Relationship**

Sau khi nạp dữ liệu, thực thi câu lệnh SQL để cập nhật mối quan hệ giữa nhân viên và người quản lý:
```sql
UPDATE DIM_EMPLOYEE de 
SET de.manager_employee_key = dem.employee_key 
FROM DIM_EMPLOYEE de 
JOIN DIM_EMPLOYEE dem ON de.manager_wwi_employee_id = dem.wwi_employee_id
WHERE de.manager_wwi_employee_id IS NOT NULL 
AND de.is_current = 1
```

**Bước 4 – Update Lineage SUCCESS**

Ghi nhận trạng thái thành công.

### 3. Data Flow Task – Luồng xử lý dữ liệu

**Bước 3.1 – OLE DB Source**

Đọc dữ liệu từ Staging:
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
```

**Bước 3.2 – Slowly Changing Dimension (SCD)**

So sánh với DIM_EMPLOYEE dựa trên `wwi_employee_id`.

**Bước 3.3a – Nhánh Historical Attribute Inserts**

- **Derived Column:** `valid_from, is_current = 1, lineage_key`
- **OLE DB Command:** Đóng bản ghi cũ

**Bước 3.3b – Nhánh Inferred Member Updates**

- **OLE DB Command:** Cập nhật thông tin

**Bước 3.4 – Union All**

Gộp các nhánh.

**Bước 3.5 – Derived Column 1**

Bổ sung metadata: `created_date, batch_id, source_system`

**Bước 3.6 – Insert Destination**

Chèn vào DIM_EMPLOYEE.

### 4. Xử lý lỗi

Khi thất bại, ghi nhận lỗi vào lineage. Lỗi có thể liên quan đến:
- Dữ liệu không hợp lệ về nhân viên
- Tham chiếu người quản lý không tồn tại
- Lỗi trong quá trình cập nhật mối quan hệ quản lý

---

## E. BẢNG DIM_CITY

### 1. Tổng quan

Quy trình đổ dữ liệu bảng DIM_CITY được thực hiện thông qua package SSIS `Load_Dim_City.dtsx`, bao gồm hai cấp độ xử lý:

**Control Flow:** Điều phối luồng thực thi tổng thể, ghi nhận trạng thái lineage (bắt đầu, thành công, thất bại).

**Data Flow Task:** Xử lý dữ liệu theo mô hình Slowly Changing Dimension (SCD) Type 2, đảm bảo lưu vết lịch sử thay đổi. Bảng DIM_CITY chứa thông tin chi tiết về các thành phố, bao gồm tên thành phố, vùng/tỉnh, quốc gia, tọa độ địa lý, và mã bưu chính.

### 2. Control Flow – Luồng điều phối

**Bước 1 – Insert Lineage START**

Thực thi một câu lệnh SQL để ghi nhận thông tin bắt đầu của lần chạy vào bảng lineage (log). Mục đích là theo dõi thời gian khởi động, tên package, và các thông số liên quan để phục vụ kiểm tra, debug sau này. Bảng lineage sẽ ghi nhận: `timestamp_start, package_name = "Load_Dim_City", execution_id, status = "START"`.

**Bước 2 – Data Flow Task**

Đây là bước trọng tâm, thực hiện toàn bộ logic biến đổi và nạp dữ liệu vào bảng DIM_CITY. Chi tiết xử lý được mô tả tại mục 3 bên dưới.

- Nếu thành công → chuyển sang Bước 3.
- Nếu thất bại → chuyển sang nhánh Update Lineage FAILED (ghi nhận lỗi vào bảng lineage và kết thúc package).

**Bước 3 – Update is_current**

Sau khi dữ liệu mới được nạp, thực thi câu lệnh SQL để cập nhật cờ `is_current = 0` cho các bản ghi cũ đã bị thay thế bởi bản ghi phiên bản mới hơn. SQL command:
```sql
UPDATE DIM_CITY 
SET is_current = 0 
WHERE wwi_city_id IN (SELECT DISTINCT wwi_city_id FROM DIM_CITY WHERE valid_to IS NOT NULL AND is_current = 1)
```
Bước này đảm bảo tính nhất quán của SCD Type 2 trong bảng DIM_CITY.

**Bước 4 – Update Lineage SUCCESS**

Thực thi câu lệnh SQL để cập nhật trạng thái `lineage = "SUCCESS"`, ghi nhận thời gian hoàn thành, số dòng đã xử lý, và số bản ghi được chèn/cập nhật.

### 3. Data Flow Task – Luồng xử lý dữ liệu

**Bước 3.1 – OLE DB Source**

Đọc dữ liệu từ hệ thống nguồn (staging hoặc operational database) thông qua kết nối OLE DB. Câu truy vấn SELECT lấy các thuộc tính cần thiết của thực thể City (mã thành phố, tên thành phố, vùng, quốc gia, v.v.):
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
```

**Bước 3.2 – Slowly Changing Dimension (SCD)**

Thành phần SCD Wizard so sánh dữ liệu đầu vào với bảng DIM_CITY hiện tại dựa trên business key `wwi_city_id`. Từ đây luồng dữ liệu được chia thành 3 nhánh:

- **Historical Attribute Inserts Output:** Các bản ghi có thay đổi thuộc tính lịch sử (Type 2) – cần tạo phiên bản mới và đóng phiên bản cũ (ví dụ: tên thành phố thay đổi, hoặc các tọa độ địa lý được cập nhật).
- **New Output:** Các bản ghi hoàn toàn mới, chưa tồn tại trong DIM_CITY.
- **Inferred Member Updates Output:** Các bản ghi inferred member (đã tồn tại dưới dạng placeholder), cần cập nhật thông tin thực tế.

**Bước 3.3a – Nhánh Historical Attribute Inserts**

- **Derived Column:** Tính toán và bổ sung các cột cần thiết cho bản ghi lịch sử mới, ví dụ:
  - `valid_from = GETDATE()`
  - `is_current = 1`
  - `lineage_key = NEWID()` (UUID duy nhất cho mỗi bản ghi)
  
- **OLE DB Command:** Thực thi UPDATE trực tiếp trên bảng DIM_CITY để đóng phiên bản cũ (set `valid_to`, `is_current = 0`) trước khi chèn phiên bản mới:
  ```sql
  UPDATE DIM_CITY 
  SET valid_to = ?, is_current = 0 
  WHERE wwi_city_id = ? AND valid_to IS NULL
  ```

**Bước 3.3b – Nhánh Inferred Member Updates**

- **OLE DB Command 1:** Thực thi UPDATE để điền đầy đủ thuộc tính cho các bản ghi inferred member hiện có trong DIM_CITY:
  ```sql
  UPDATE DIM_CITY 
  SET city_name = ?, state_province_name = ?, country_name = ?, latitude = ?, longitude = ? 
  WHERE wwi_city_id = ? AND is_current = 1
  ```

**Bước 3.4 – Union All**

Gộp luồng từ nhánh Historical (sau Derived Column + OLE DB Command) và luồng New Output thành một luồng duy nhất để chuẩn bị chèn mới vào bảng DIM_CITY. Đảm bảo các cột từ cả hai nhánh được sắp xếp đúng thứ tự và kiểu dữ liệu tương thích.

**Bước 3.5 – Derived Column 1**

Bổ sung hoặc chuẩn hóa các cột metadata chung cho toàn bộ bản ghi mới trước khi chèn, ví dụ:
- `created_date = GETDATE()`
- `batch_id = [Parameter_BatchID]` (truyền từ package parameter)
- `source_system = "Staging"` (cặp nguồn dữ liệu)

**Bước 3.6 – Insert Destination**

Chèn toàn bộ bản ghi mới (bao gồm bản ghi hoàn toàn mới và phiên bản lịch sử mới của bản ghi thay đổi) vào bảng DIM_CITY thông qua kết nối OLE DB. Sử dụng **fast load option** để tăng tốc độ xử lý.

### 4. Xử lý lỗi

Trong trường hợp Data Flow Task thất bại ở bất kỳ bước nào, Control Flow sẽ kích hoạt kết nối Failure và chuyển sang task Update Lineage FAILED. Task này ghi nhận thông tin lỗi vào bảng lineage (thời gian lỗi, mã lỗi, mô tả), giúp đội vận hành nhanh chóng phát hiện và xử lý sự cố. Các lỗi có thể bao gồm:
- Lỗi trong quá trình SCD (không thể tìm thấy business key)
- Lỗi trong quá trình cập nhật (violation of constraints)
- Lỗi kết nối đến database

---

## F. BẢNG FACT_SALE

### 1. Tổng quan

Quy trình đổ dữ liệu bảng FACT_SALES được thực hiện thông qua package SSIS `Load_Fact_Sale.dtsx`, bao gồm hai cấp độ xử lý:

**Control Flow:** Điều phối luồng thực thi tổng thể, ghi nhận trạng thái lineage.

**Data Flow Task:** Xử lý dữ liệu bán hàng, kết hợp thông tin từ Staging với các bảng Dimension để tạo ra các sự kiện bán hàng hoàn chỉnh. Bảng FACT_SALES chứa chi tiết từng dòng hóa đơn bán hàng, bao gồm sản phẩm, khách hàng, nhân viên, thành phố, ngày bán, số lượng, giá cả, và các metrics liên quan.

### 2. Control Flow – Luồng điều phối

**Bước 1 – Insert Lineage START**

Ghi nhận bắt đầu lần chạy package `Load_Fact_Sale` vào bảng lineage.

**Bước 2 – Data Flow Task**

Thực hiện logic biến đổi và nạp dữ liệu vào FACT_SALES. 

- Nếu thành công → Bước 3.
- Nếu thất bại → Update Lineage FAILED.

**Bước 3 – Update Slowly Changing Links**

Sau khi dữ liệu được nạp, thực thi câu lệnh SQL để cập nhật các liên kết đến các phiên bản hiện tại của bảng Dimension (Type 2):
```sql
UPDATE FACT_SALES fs
SET fs.product_key = (SELECT product_key FROM DIM_PRODUCT 
                      WHERE wwi_stock_item_id = fs.wwi_stock_item_id 
                      AND valid_to IS NULL),
    fs.customer_key = (SELECT customer_key FROM DIM_CUSTOMER 
                       WHERE wwi_customer_id = fs.wwi_customer_id 
                       AND valid_to IS NULL),
    fs.employee_key = (SELECT employee_key FROM DIM_EMPLOYEE 
                       WHERE wwi_employee_id = fs.wwi_employee_id 
                       AND valid_to IS NULL)
WHERE fs.created_date = CAST(GETDATE() AS DATE)
```

**Bước 4 – Update Lineage SUCCESS**

Ghi nhận trạng thái thành công với số dòng bán hàng đã tải.

### 3. Data Flow Task – Luồng xử lý dữ liệu

**Bước 3.1 – OLE DB Source**

Đọc dữ liệu từ Staging:
```sql
SELECT 
    ii.invoice_line_id,
    ii.invoice_id,
    i.customer_id,
    i.invoice_date,
    i.salesperson_id,
    ii.stock_item_id,
    ii.quantity,
    ii.unit_price,
    ii.line_total,
    ISNULL(ii.discount_percent, 0) as discount_percent
FROM [dbo].[InvoiceLines] ii
INNER JOIN [dbo].[Invoices] i ON ii.invoice_id = i.invoice_id
```

**Bước 3.2 – Lookup Product Key**

Tìm `product_key` từ DIM_PRODUCT:
```sql
SELECT wwi_stock_item_id, product_key
FROM DIM_PRODUCT
WHERE valid_to IS NULL
```

**Bước 3.3 – Lookup Customer Key**

Tìm `customer_key` từ DIM_CUSTOMER:
```sql
SELECT wwi_customer_id, customer_key
FROM DIM_CUSTOMER
WHERE valid_to IS NULL
```

**Bước 3.4 – Lookup Employee Key**

Tìm `employee_key` từ DIM_EMPLOYEE (salesperson):
```sql
SELECT wwi_employee_id, employee_key
FROM DIM_EMPLOYEE
WHERE valid_to IS NULL
```

**Bước 3.5 – Lookup City Key**

Nếu có bảng DIM_DATE, tìm `date_key` từ DIM_DATE:
```sql
SELECT CAST(date_value AS DATE), date_key
FROM DIM_DATE
```

**Bước 3.6 – Derived Column**

Tính toán các metrics bán hàng:
- `discount_amount = unit_price * quantity * (discount_percent / 100)`
- `net_sales_amount = line_total - discount_amount`
- `tax_amount = net_sales_amount * tax_rate` (nếu có)
- `profit_amount = net_sales_amount - (unit_cost * quantity)` (nếu có dữ liệu cost)

**Bước 3.7 – Insert Destination**

Chèn toàn bộ dữ liệu vào bảng FACT_SALES với các khóa ngoài (product_key, customer_key, employee_key, date_key) đã được resolve từ các bảng Dimension.

### 4. Xử lý lỗi

Khi thất bại, ghi nhận lỗi vào lineage. Lỗi có thể liên quan đến:
- Dữ liệu không hợp lệ từ Staging (hóa đơn không tồn tại)
- Lookup thất bại (sản phẩm, khách hàng, nhân viên không tìm thấy trong Dimension)
- Lỗi tính toán metrics (chia cho 0, v.v.)

---

## G. BẢNG FACT_PURCHASE

### 1. Tổng quan

Quy trình đổ dữ liệu bảng FACT_PURCHASE được thực hiện thông qua package SSIS `Load_Fact_Purchase.dtsx`. Bảng FACT_PURCHASE chứa chi tiết từng dòng đơn mua hàng, bao gồm sản phẩm, nhà cung cấp, số lượng, giá cả, ngày mua, và các metrics liên quan.

### 2. Control Flow – Luồng điều phối

**Bước 1 – Insert Lineage START**

Ghi nhận bắt đầu lần chạy package `Load_Fact_Purchase` vào bảng lineage.

**Bước 2 – Data Flow Task**

Thực hiện logic biến đổi và nạp vào FACT_PURCHASE.

- Nếu thành công → Bước 3.
- Nếu thất bại → Update Lineage FAILED.

**Bước 3 – Calculate Purchase Metrics**

Sau khi dữ liệu được nạp, thực thi câu lệnh SQL để tính toán các chỉ số mua hàng bổ sung:
```sql
UPDATE FACT_PURCHASE 
SET received_qty = (SELECT SUM(quantity_received) 
                    FROM PurchaseOrderLineReceipt 
                    WHERE po_line_id = FACT_PURCHASE.po_line_id),
    variance_qty = received_qty - ordered_qty
WHERE created_date = CAST(GETDATE() AS DATE)
```

**Bước 4 – Update Lineage SUCCESS**

Ghi nhận trạng thái thành công.

### 3. Data Flow Task – Luồng xử lý dữ liệu

**Bước 3.1 – OLE DB Source**

Đọc dữ liệu từ Staging:
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
```

**Bước 3.2 – Lookup Product Key**

Tìm `product_key` từ DIM_PRODUCT.

**Bước 3.3 – Lookup Supplier Key**

Tìm `supplier_key` từ DIM_SUPPLIER:
```sql
SELECT wwi_supplier_id, supplier_key
FROM DIM_SUPPLIER
WHERE valid_to IS NULL
```

**Bước 3.4 – Lookup Date Key**

Tìm `date_key` từ DIM_DATE.

**Bước 3.5 – Derived Column**

Tính toán các metrics mua hàng:
- `purchase_amount = ordered_quantity * unit_price`
- `received_amount = received_quantity * unit_price`
- `variance_amount = (received_quantity - ordered_quantity) * unit_price`
- `delivery_days = DATEDIFF(DAY, order_date, delivery_date)`

**Bước 3.6 – Insert Destination**

Chèn vào bảng FACT_PURCHASE.

### 4. Xử lý lỗi

Khi thất bại, ghi nhận lỗi vào lineage. Lỗi có thể liên quan đến:
- Dữ liệu không hợp lệ từ Staging
- Lookup thất bại (sản phẩm, nhà cung cấp không tìm thấy)
- Lỗi tính toán metrics

---

## H. BẢNG FACT_INVENTORY

### 1. Tổng quan

Quy trình đổ dữ liệu bảng FACT_INVENTORY được thực hiện thông qua package SSIS `Load_Fact_Inventory.dtsx`. Bảng FACT_INVENTORY chứa dữ liệu tồn kho theo ngày, bao gồm sản phẩm, tồn kho nhập, xuất, tồn cuối, và các metrics liên quan.

### 2. Control Flow – Luồng điều phối

**Bước 1 – Insert Lineage START**

Ghi nhận bắt đầu lần chạy package `Load_Fact_Inventory` vào bảng lineage.

**Bước 2 – Data Flow Task**

Thực hiện logic biến đổi và nạp vào FACT_INVENTORY.

- Nếu thành công → Bước 3.
- Nếu thất bại → Update Lineage FAILED.

**Bước 3 – Calculate Inventory Balances**

Sau khi dữ liệu được nạp, thực thi câu lệnh SQL để tính toán số dư tồn kho theo thời gian:
```sql
UPDATE FACT_INVENTORY fi
SET fi.opening_stock = (SELECT ISNULL(SUM(quantity_on_hand), 0)
                        FROM FACT_INVENTORY
                        WHERE product_key = fi.product_key
                        AND date_key < fi.date_key
                        ORDER BY date_key DESC
                        LIMIT 1),
    fi.closing_stock = fi.opening_stock + fi.quantity_in - fi.quantity_out,
    fi.avg_stock_value = (fi.opening_stock + fi.closing_stock) / 2 * fi.unit_cost
WHERE created_date = CAST(GETDATE() AS DATE)
```

**Bước 4 – Update Lineage SUCCESS**

Ghi nhận trạng thái thành công.

### 3. Data Flow Task – Luồng xử lý dữ liệu

**Bước 3.1 – OLE DB Source**

Đọc dữ liệu từ Staging:
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
```

**Bước 3.2 – Lookup Product Key**

Tìm `product_key` từ DIM_PRODUCT.

**Bước 3.3 – Lookup Date Key**

Tìm `date_key` từ DIM_DATE.

**Bước 3.4 – Lookup Customer/Supplier Key** (nếu cần)

Tìm `customer_key` hoặc `supplier_key` từ các Dimension tương ứng.

**Bước 3.5 – Derived Column**

Tính toán các metrics tồn kho:
- `quantity_in = CASE WHEN transaction_type = "Receipt" THEN quantity ELSE 0 END`
- `quantity_out = CASE WHEN transaction_type = "Sale" THEN quantity ELSE 0 END`
- `transaction_value = quantity * unit_price`
- `holding_location = bin_location`

**Bước 3.6 – Insert Destination**

Chèn vào bảng FACT_INVENTORY.

### 4. Xử lý lỗi

Khi thất bại, ghi nhận lỗi vào lineage. Lỗi có thể liên quan đến:
- Dữ liệu không hợp lệ từ Staging
- Lookup thất bại (sản phẩm, ngày không tìm thấy)
- Lỗi trong quá trình tính toán số dư tồn kho

---

---

## I. BẢNG DIM_PRODUCT_CATEGORY

### 1. Tổng quan

Quy trình đổ dữ liệu bảng DIM_PRODUCT_CATEGORY được thực hiện thông qua package SSIS `Load_Dim_Product_Category.dtsx`. Bảng DIM_PRODUCT_CATEGORY chứa danh mục/nhóm sản phẩm, bao gồm tên danh mục, mô tả, và các thông tin phân loại.

**Điểm đặc biệt:** Package này có 2 Data Flow Tasks - một để load Dimension, một để load bảng Bridge kết nối Product với Category (many-to-many relationship).

Mô hình dữ liệu theo SCD Type 2 để lưu trữ lịch sử thay đổi danh mục.

### 2. Control Flow – Luồng điều phối

**Bước 1 – Insert Lineage START**

Ghi nhận bắt đầu lần chạy package vào bảng lineage.

**Bước 2a – Data Flow Task 1: Load DIM_PRODUCT_CATEGORY**

Thực hiện logic biến đổi và nạp vào bảng DIM_PRODUCT_CATEGORY (Dimension chính).

- Nếu thành công → Bước 2b.
- Nếu thất bại → Update Lineage FAILED.

**Bước 2b – Data Flow Task 2: Load BRIDGE_PRODUCT_CATEGORY**

Thực hiện nạp dữ liệu bảng Bridge (bảng liên kết nhiều-chiều giữa Product và Category).

- Nếu thành công → Bước 3.
- Nếu thất bại → Update Lineage FAILED.

**Bước 3 – Update Lineage SUCCESS**

Ghi nhận trạng thái thành công.

### 3. Data Flow Task 1 – Load DIM_PRODUCT_CATEGORY

**Bước 3.1 – OLE DB Source**

Đọc dữ liệu từ Staging:
```sql
SELECT 
    wwi_group_id,
    category_name
FROM [dbo].[StockGroups]
WHERE wwi_group_id IS NOT NULL
ORDER BY wwi_group_id
```

**Bước 3.2 – Slowly Changing Dimension (SCD)**

So sánh với DIM_PRODUCT_CATEGORY dựa trên `wwi_group_id`.

**Bước 3.3a – Nhánh Historical Attribute Inserts**

- **Derived Column:** `valid_from, is_current = 1, lineage_key`
- **OLE DB Command:** Đóng bản ghi cũ:
  ```sql
  UPDATE DIM_PRODUCT_CATEGORY 
  SET valid_to = ?, is_current = 0 
  WHERE wwi_group_id = ? AND valid_to IS NULL
  ```

**Bước 3.3b – Nhánh Inferred Member Updates**

- **OLE DB Command:** Cập nhật thông tin:
  ```sql
  UPDATE DIM_PRODUCT_CATEGORY 
  SET category_name = ? 
  WHERE wwi_group_id = ? AND is_current = 1
  ```

**Bước 3.4 – Union All**

Gộp các nhánh.

**Bước 3.5 – Derived Column 1**

Bổ sung metadata: `created_date, batch_id, source_system`

**Bước 3.6 – Insert Destination**

Chèn vào DIM_PRODUCT_CATEGORY.

### 4. Data Flow Task 2 – Load BRIDGE_PRODUCT_CATEGORY

**Ý nghĩa:**
Bảng Bridge (BRIDGE_PRODUCT_CATEGORY) là bảng liên kết many-to-many giữa DIM_PRODUCT và DIM_PRODUCT_CATEGORY. Một sản phẩm có thể thuộc nhiều danh mục, và một danh mục có thể chứa nhiều sản phẩm. Bảng Bridge lưu trữ tất cả các mối quan hệ này.

**Bước 4.1 – OLE DB Source**

Đọc dữ liệu từ Staging (dữ liệu mapping sản phẩm-danh mục từ bảng StockItemStockGroups):
```sql
SELECT 
    si.wwi_stock_item_id,
    sg.wwi_group_id
FROM [dbo].[StockItems] si
JOIN [dbo].[StockItemStockGroups] sist ON si.wwi_stock_item_id = sist.stock_item_id
JOIN [dbo].[StockGroups] sg ON sist.wwi_group_id = sg.stock_group_id
ORDER BY si.wwi_stock_item_id, sg.wwi_group_id
```

**Bước 4.2 – Lookup Product Key**

Tìm `product_key` từ DIM_PRODUCT:
```sql
SELECT wwi_stock_item_id, product_key
FROM DIM_PRODUCT
WHERE valid_to IS NULL AND is_current = 1
```

**Bước 4.3 – Lookup Category Key**

Tìm `category_key` từ DIM_PRODUCT_CATEGORY:
```sql
SELECT wwi_group_id, category_key
FROM DIM_PRODUCT_CATEGORY
WHERE valid_to IS NULL AND is_current = 1
```

**Bước 4.4 – Derived Column**

Bổ sung metadata:
- `created_date = GETDATE()`
- `batch_id = @BatchID`
- `is_active = 1` (đánh dấu mối quan hệ hiện tại)

**Bước 4.5 – Insert Destination**

Chèn vào bảng BRIDGE_PRODUCT_CATEGORY:
```sql
INSERT INTO BRIDGE_PRODUCT_CATEGORY
(product_key, category_key, is_active, created_date, batch_id)
VALUES (...)
```

**Ghi chú:** 
- Thường TRUNCATE table Bridge trước khi nạp (vì Bridge được rebuild lại hoàn toàn mỗi lần chạy ETL)
- Không dùng SCD Type 2 cho Bridge, chỉ giữ snapshot hiện tại của mối quan hệ

### 5. Xử lý lỗi

Khi thất bại, ghi nhận lỗi vào lineage. Lỗi có thể liên quan đến:
- Dữ liệu không hợp lệ từ Staging
- Lookup thất bại (sản phẩm hoặc danh mục không tìm thấy)
- Constraint violation (ví dụ khóa chính trùng trong Bridge)

---

## J. BẢNG BRIDGE_PRODUCT_CATEGORY

### 1. Tổng quan

Bảng BRIDGE_PRODUCT_CATEGORY là bảng liên kết (junction/bridge table) trong mô hình dữ liệu, được load cùng với Load_Dim_Product_Category.dtsx (Data Flow Task 2). 

**Tác dụng:** 
- Lưu trữ mối quan hệ many-to-many giữa DIM_PRODUCT và DIM_PRODUCT_CATEGORY
- Cho phép một sản phẩm được phân loại vào nhiều danh mục
- Hỗ trợ phân tích "Sản phẩm nào thuộc danh mục A", "Danh mục nào chứa sản phẩm X", v.v.

**Cấu trúc dữ liệu:**
```sql
CREATE TABLE BRIDGE_PRODUCT_CATEGORY (
    bridge_key INT IDENTITY(1,1) PRIMARY KEY,
    product_key INT NOT NULL,           -- FK đến DIM_PRODUCT
    category_key INT NOT NULL,          -- FK đến DIM_PRODUCT_CATEGORY
    is_active BIT DEFAULT 1,            -- Flag để đánh dấu mối quan hệ hiện tại (1=active)
    created_date DATETIME2 DEFAULT GETDATE(),
    batch_id INT,
    
    CONSTRAINT FK_Bridge_Product FOREIGN KEY (product_key) REFERENCES DIM_PRODUCT(product_key),
    CONSTRAINT FK_Bridge_Category FOREIGN KEY (category_key) REFERENCES DIM_PRODUCT_CATEGORY(category_key),
    CONSTRAINT UQ_Product_Category UNIQUE (product_key, category_key)
);
```

### 2. Load Process (Data Flow Task 2)

**Bước 1 – Extract Source Data**

OLE DB Source đọc từ Staging:
```sql
SELECT 
    si.wwi_stock_item_id,
    sg.wwi_group_id
FROM Warehouse.StockItems si
JOIN Warehouse.StockItemStockGroups sist 
    ON si.StockItemID = sist.StockItemID
JOIN Warehouse.StockGroups sg 
    ON sist.StockGroupID = sg.StockGroupID
WHERE si.StockItemID IS NOT NULL
```

**Bước 2 – Lookup Product Key**

Chuyển đổi wwi_stock_item_id → product_key từ DIM_PRODUCT:
```sql
SELECT wwi_stock_item_id, product_key FROM DIM_PRODUCT
WHERE valid_to IS NULL
```

**Bước 3 – Lookup Category Key**

Chuyển đổi wwi_group_id → category_key từ DIM_PRODUCT_CATEGORY:
```sql
SELECT wwi_group_id, category_key FROM DIM_PRODUCT_CATEGORY
WHERE valid_to IS NULL
```

**Bước 4 – Add Metadata**

Derived Column bổ sung:
- `created_date = GETDATE()`
- `batch_id = @BatchID`
- `is_active = 1`

**Bước 5 – Load to Bridge**

OLE DB Destination chèn vào BRIDGE_PRODUCT_CATEGORY:
- **Data Access Mode:** Table (với Fast Load)
- **Truncate:** Nên bật (vì Bridge được rebuild mỗi lần ETL)
- **Constraint Handling:** Dùng unique constraint (product_key, category_key) để tránh duplicate

### 3. Kiểm tra dữ liệu

Sau khi load, có thể kiểm tra:
```sql
-- Kiểm tra số lượng mối quan hệ
SELECT COUNT(*) as total_relationships FROM BRIDGE_PRODUCT_CATEGORY WHERE is_active = 1;

-- Kiểm tra sản phẩm có bao nhiêu danh mục
SELECT 
    p.product_name,
    COUNT(b.category_key) as category_count
FROM DIM_PRODUCT p
LEFT JOIN BRIDGE_PRODUCT_CATEGORY b ON p.product_key = b.product_key
GROUP BY p.product_key, p.product_name
ORDER BY category_count DESC;

-- Kiểm tra danh mục có bao nhiêu sản phẩm
SELECT 
    c.category_name,
    COUNT(b.product_key) as product_count
FROM DIM_PRODUCT_CATEGORY c
LEFT JOIN BRIDGE_PRODUCT_CATEGORY b ON c.category_key = b.category_key
GROUP BY c.category_key, c.category_name
ORDER BY product_count DESC;

-- Kiểm tra sản phẩm không có danh mục (orphans)
SELECT p.product_key, p.product_name
FROM DIM_PRODUCT p
WHERE p.is_current = 1
AND NOT EXISTS (SELECT 1 FROM BRIDGE_PRODUCT_CATEGORY b WHERE b.product_key = p.product_key);
```

### 4. Xử lý lỗi

- **Lookup thất bại:** Nếu sản phẩm hoặc danh mục không tìm thấy trong Dimension, dòng sẽ được gửi vào Error Output
- **Constraint violation:** Nếu mối quan hệ (product_key, category_key) duplicate, OLE DB Destination sẽ báo lỗi
- **Truncate failure:** Nếu không thể truncate table (lock hoặc permission), load sẽ thất bại

---

**HẾT BÁNG CÁO CHI TIẾT**

