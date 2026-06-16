# BÁO CÁO QƯƠNG TRÌNH ETL — DỰ ÁN WIDEWORLD IMPOSTER

**Học viện Ngân hàng TP. Hồ Chí Minh**  
**Khóa: Năm 3 - Kỳ 2**  
**Môn học: Kho dữ liệu và Kinh doanh Thông minh**  
**Ngày lập báo cáo: 20/05/2026**

---

## MỤC LỤC

1. Phần mở đầu
2. Tổng quan về dự án
3. Kiến trúc hệ thống ETL
4. Quy trình đổ dữ liệu vào Staging
5. Quy trình xây dựng bảng Dimension
6. Quy trình tải bảng Fact
7. Quy trình tổng hợp dữ liệu
8. Kỹ thuật Slowly Changing Dimension Type 2
9. Kết luận

---

## 1. PHẦN MỞ ĐẦU

Báo cáo này trình bày chi tiết về quy trình Extract, Transform, Load (ETL) trong dự án xây dựng Kho dữ liệu (Data Warehouse) cho tập đoàn Wide World Importers. Dự án sử dụng SQL Server Integration Services (SSIS) là công cụ chính để điều phối toàn bộ luồng dữ liệu từ các hệ thống nguồn khác nhau đến kho dữ liệu phân tích cuối cùng.

Mục tiêu chính của báo cáo là giúp người đọc hiểu rõ từng bước trong quy trình ETL, từ lúc dữ liệu được nạp vào vùng trung gian (staging area), cho đến khi được biến đổi thành các bảng chiều (dimension) và bảng sự kiện (fact) trong kho dữ liệu, và cuối cùng được tổng hợp để phục vụ phân tích. Báo cáo cũng nhấn mạnh các kỹ thuật quan trọng như Slowly Changing Dimension Type 2 được áp dụng để theo dõi lịch sử thay đổi dữ liệu.

---

## 2. TỔNG QUAN VỀ DỰ ÁN

### 2.1 Bối cảnh dự án

Dự án ETL WideWorld Imposter được phát triển với mục tiêu xây dựng một kho dữ liệu tích hợp cho tập đoàn Wide World Importers, một tập đoàn kinh doanh nhập khẩu và phân phối các loại hàng hóa quốc tế. Trước đây, dữ liệu của tập đoàn được lưu trữ rải rác trong các hệ thống khác nhau, bao gồm cơ sở dữ liệu SQL Server, các tệp Excel, và cơ sở dữ liệu PostgreSQL. Việc phân tán này gây ra khó khăn trong việc phân tích tổng thể toàn cảnh kinh doanh.

Để giải quyết vấn đề này, dự án xây dựng một kho dữ liệu tập trung theo kiến trúc ba tầng, với mục tiêu cung cấp một nguồn dữ liệu thống nhất, sạch sẽ, và được tổ chức theo các chiều phân tích rõ ràng. Kho dữ liệu này sẽ hỗ trợ các nhà quản lý và nhà phân tích dữ liệu trong việc đưa ra quyết định dựa trên dữ liệu (data-driven decision making).

### 2.2 Công cụ và công nghệ sử dụng

Dự án sử dụng SQL Server Integration Services (SSIS) làm công cụ ETL chính. SSIS là một nền tảng mạnh mẽ của Microsoft, được thiết kế đặc biệt để xây dựng các quy trình ETL phức tạp. Ngoài SSIS, dự án còn sử dụng SQL Server 2019 làm hệ quản trị cơ sở dữ liệu chính, Microsoft Excel để quản lý dữ liệu nhập liệu, và PostgreSQL để lưu trữ một phần dữ liệu kho hàng.

Các package SSIS được viết bằng ngôn ngữ XML và được thực thi thông qua SSIS runtime engine. Việc phát triển được thực hiện trong Visual Studio với SQL Server Data Tools (SSDT) extension, giúp các kỹ sư dữ liệu có thể thiết kế, kiểm tra, và triển khai các package một cách hiệu quả.

---

## 3. KIẾN TRÚC HỆ THỐNG ETL

### 3.1 Kiến trúc ba tầng

Hệ thống ETL của dự án được xây dựng theo kiến trúc ba tầng cổ điển trong lĩnh vực kho dữ liệu. Tầng thứ nhất là các hệ thống nguồn (Source Systems), bao gồm các cơ sở dữ liệu giao dịch, tệp Excel, và cơ sở dữ liệu bên ngoài. Tầng thứ hai là vùng Staging, một kho dữ liệu tạm thời được sử dụng để lưu trữ dữ liệu nguyên bản trước khi xử lý. Tầng thứ ba là kho dữ liệu cuối cùng (Data Warehouse), nơi dữ liệu đã được biến đổi, sạch sẽ, và được tổ chức theo mô hình sao (star schema) với các bảng chiều và bảng sự kiện.

Kiến trúc này giúp tách biệt các mối quan tâm khác nhau. Tầng Staging đóng vai trò là bộ đệm, cho phép các kỹ sư dữ liệu thực hiện các phép kiểm tra và làm sạch dữ liệu mà không ảnh hưởng đến các quy trình ETL khác. Kho dữ liệu ở tầng thứ ba được tối ưu hóa cho hiệu suất truy vấn, với các chỉ số phù hợp để hỗ trợ phân tích nhanh.

### 3.2 Danh sách các package chính

Dự án bao gồm một tập hợp các package SSIS, mỗi package được thiết kế để thực hiện một nhiệm vụ cụ thể trong quy trình ETL. Package `Master_ETL.dtsx` đóng vai trò là package điều phối chính, chịu trách nhiệm gọi các package con theo một thứ tự xác định để đảm bảo tính toàn vẹn dữ liệu.

Package `Load_Staging.dtsx` được gọi đầu tiên, với nhiệm vụ nạp dữ liệu từ các hệ thống nguồn vào vùng Staging. Sau đó, năm package dimension được thực hiện theo thứ tự: `Load_Dim_Product.dtsx`, `Load_Dim_Supplier.dtsx`, `Load_Dim_Customer.dtsx`, `Load_Dim_Employee.dtsx`, và `Load_Dim_City.dtsx`. Ba package fact được thực hiện tiếp theo: `Load_Fact_Sale.dtsx`, `Load_Fact_Purchase.dtsx`, và `Load_Fact_Inventory.dtsx`. Cuối cùng, package `Load_Agg_Fact.dtsx` tạo các bảng tổng hợp để hỗ trợ phân tích nhanh.

---

## 4. QUY TRÌNH ĐỔ DỮ LIỆU VÀO STAGING

### 4.1 Phía dữ liệu nguồn

Vùng Staging là điểm tiếp nhận dữ liệu từ các hệ thống khác nhau. Package `Load_Staging.dtsx` được thiết kế để kết nối với ba loại nguồn dữ liệu chính. Thứ nhất là các cơ sở dữ liệu SQL Server, bao gồm `purchasing&sales` và `sales_purchasing`, chứa dữ liệu giao dịch mua bán. Thứ hai là tệp Excel `application.xlsx` được lưu trữ tại `D:\ssms2postgre\file backup\`, chứa các dữ liệu quản lý ứng dụng. Thứ ba là cơ sở dữ liệu PostgreSQL, được truy cập thông qua DSN (Data Source Name) có tên `postgres_ssis`, chứa các dữ liệu kho và tồn kho.

Để kết nối an toàn với các nguồn này, package sử dụng các Connection Manager được cấu hình trước. Đối với SQL Server, được sử dụng xác thực tích hợp (Integrated Security) với máy chủ `localhost`. Đối với Excel, được sử dụng chuỗi kết nối OLEDB với ACE provider. Đối với PostgreSQL, được sử dụng ODBC driver với tên DSN `postgres_ssis`.

### 4.2 Quá trình ETL trong Load_Staging

Quá trình nạp dữ liệu vào Staging tuân theo một luồng chuẩn. Đầu tiên, package đọc dữ liệu từ các bảng nguồn. Các bảng từ SQL Server bao gồm các bảng cơ bản như `Application.Cities`, `Application.StateProvinces`, `Application.Countries`, và `Application.People`. Từ module Purchasing, dữ liệu về `Purchasing.Suppliers` và `Purchasing.SupplierCategories` được đọc. Từ module Sales, dữ liệu về `Sales.Customers`, `Sales.BuyingGroups`, `Sales.CustomerCategories`, `Sales.Invoices`, `Sales.InvoiceLines`, và `Sales.Orders` được nạp. Từ module Warehouse, dữ liệu về `Warehouse.StockItems`, `Warehouse.Colors`, `Warehouse.PackageTypes`, `Warehouse.StockItemTransactions`, và `Warehouse.StockItemHoldings` được lấy.

Từ file Excel, dữ liệu về các khu vực, quốc gia, và nhân viên được đọc. Từ cơ sở dữ liệu PostgreSQL, các bảng liên quan đến kho và tồn kho được lấy.

Thứ hai, dữ liệu được áp dụng các phép biến đổi cơ bản nếu cần, chẳng hạn như chuyển đổi kiểu dữ liệu hoặc xử lý giá trị NULL. Thứ ba, dữ liệu được ghi vào các bảng tương ứng trong vùng Staging, cơ sở dữ liệu `wwi_staging_area`. Vùng Staging giữ lại dữ liệu nguyên bản, cho phép các kỹ sư dữ liệu kiểm tra tính toàn vẹn dữ liệu trước khi xử lý tiếp.

### 4.3 Mục tiêu của Staging

Vai trò của Staging là cực kỳ quan trọng trong kiến trúc ETL. Nó cung cấp một nơi an toàn để lưu trữ dữ liệu thô trước khi xử lý, giúp dễ dàng kiểm tra lỗi nguồn. Nếu xảy ra lỗi ở các bước tiếp theo, kỹ sư dữ liệu có thể xem lại dữ liệu Staging để chẩn đoán vấn đề. Staging cũng cho phép tách biệt việc truy cập các hệ thống nguồn với các quy trình biến đổi dữ liệu, giúp tăng tính ổn định của toàn hệ thống.

---

## 5. QUY TRÌNH XÂY DỰNG BẢNG DIMENSION

### 5.1 Khái niệm về Dimension

Dimension (chiều) là các bảng chứa thông tin mô tả các thuộc tính của sự kiện được ghi nhận. Ví dụ, khi ghi nhận một sự kiện bán hàng, cần biết ai là khách hàng, sản phẩm gì được bán, bán vào lúc nào, tại thành phố nào, và do nhân viên nào xử lý. Mỗi khía cạnh này đại diện cho một chiều. Trong dự án này, có năm bảng dimension chính: `DIM_PRODUCT` cho sản phẩm, `DIM_SUPPLIER` cho nhà cung cấp, `DIM_CUSTOMER` cho khách hàng, `DIM_EMPLOYEE` cho nhân viên, và `DIM_CITY` cho vị trí địa lý.

### 5.2 Thứ tự xây dựng các Dimension

Các bảng dimension được xây dựng theo một thứ tự cụ thể để đảm bảo các mối quan hệ tham chiếu được thiết lập đúng cách. Thứ nhất, `DIM_PRODUCT` được xây dựng, vì nó không phụ thuộc vào bất kỳ dimension nào khác. Thứ hai, `DIM_SUPPLIER` được xây dựng, cung cấp thông tin về các nhà cung cấp. Thứ ba, `DIM_CUSTOMER` được xây dựng, có thể chứa tham chiếu đến `DIM_CITY`. Thứ tư, `DIM_EMPLOYEE` được xây dựng. Cuối cùng, `DIM_CITY` được xây dựng.

Thứ tự này đảm bảo rằng khi các package fact được thực hiện, tất cả các bảng dimension mà chúng cần tham chiếu đều đã tồn tại.

### 5.3 Cơ chế Slowly Changing Dimension Type 2

Tất cả các bảng dimension trong dự án đều sử dụng kỹ thuật Slowly Changing Dimension Type 2 (SCD Type 2). Kỹ thuật này cho phép lưu trữ lịch sử đầy đủ của những thay đổi dữ liệu. Khi một thuộc tính của một đối tượng thay đổi (ví dụ, tên khách hàng thay đổi), thay vì cập nhật bản ghi cũ, hệ thống sẽ đánh dấu bản ghi cũ là hết hiệu lực (bằng cách gán giá trị cho cột `valid_to`), rồi tạo một bản ghi mới với dữ liệu mới và đánh dấu ngày bắt đầu hiệu lực (cột `valid_from`).

Quá trình này diễn ra như sau. Đầu tiên, dữ liệu từ Staging được đọc bằng component OLE DB Source. Thứ hai, component Slowly Changing Dimension được sử dụng để phát hiện ba loại bản ghi: bản ghi mới (không tồn tại trong kho dữ liệu), bản ghi thay đổi (tồn tại nhưng có thuộc tính đã thay đổi), và bản ghi không thay đổi (tồn tại và giống hệt như trước).

Đối với bản ghi mới, chúng được thêm vào dimension với `valid_from` được gán giá trị ngày hôm nay và `valid_to` là NULL (biểu thị rằng bản ghi này hiện đang có hiệu lực). Đối với bản ghi thay đổi, một update được thực hiện trên bản ghi cũ để gán `valid_to` bằng ngày hôm nay, sau đó một bản ghi mới được thêm vào với dữ liệu cập nhật. Đối với bản ghi không thay đổi, không có thao tác nào được thực hiện.

### 5.4 Chi tiết các package Dimension

**Package Load_Dim_Product**: Bảng dimension này chứa thông tin chi tiết về các sản phẩm mà công ty bán. Dữ liệu được đọc từ các bảng `Warehouse.StockItems`, `Warehouse.Colors`, và `Warehouse.PackageTypes` trong Staging. Business key (khóa kinh doanh) là `wwi_stock_item_id`. Package này sử dụng SCD Type 2 để lưu trữ lịch sử các thay đổi thông tin sản phẩm, chẳng hạn như thay đổi giá hay thay đổi danh mục.

**Package Load_Dim_Supplier**: Bảng dimension này chứa thông tin về các nhà cung cấp. Dữ liệu được đọc từ `Purchasing.Suppliers` và `Purchasing.SupplierCategories`. Business key là `wwi_supplier_id`. Điều đặc biệt là package này có kết nối đến một cơ sở dữ liệu riêng gọi là `financial_data_warehouse`, cho phép tích hợp thông tin tài chính từ các hệ thống khác. Package cũng sử dụng SCD Type 2 để theo dõi lịch sử thay đổi thông tin nhà cung cấp.

**Package Load_Dim_Customer**: Bảng dimension này chứa thông tin khách hàng. Dữ liệu được đọc từ `Sales.Customers`, `Sales.BuyingGroups`, `Sales.CustomerCategories`, và `Application.People`. Business key là `wwi_customer_id`. Package sử dụng SCD Type 2 để lưu trữ lịch sử các thay đổi thông tin khách hàng, bao gồm cả các thay đổi loại khách hàng (từ khách hàng thường xuyên sang khách hàng bán lẻ, chẳng hạn).

**Package Load_Dim_Employee**: Bảng dimension này chứa thông tin nhân viên, được đọc từ `Application.People`. Business key là `wwi_employee_id`. Package sử dụng SCD Type 2 để theo dõi lịch sử các thay đổi về nhân viên, chẳng hạn như thay đổi chức vụ hoặc phòng ban.

**Package Load_Dim_City**: Bảng dimension này chứa thông tin địa lý, bao gồm các thành phố, tỉnh/bang, và quốc gia. Dữ liệu được đọc từ `Application.Cities`, `Application.StateProvinces`, và `Application.Countries`. Business key là `wwi_city_id`. Package sử dụng SCD Type 2 để theo dõi các thay đổi địa lý, mặc dù trong thực tế, dữ liệu địa lý thay đổi ít hơn so với các dimension khác.

---

## 6. QUY TRÌNH TẢI BẢNG FACT

### 6.1 Khái niệm về Fact

Fact (sự kiện) là các bảng chứa các sự kiện giao dịch hoặc hoạt động kinh doanh. Không giống như Dimension chứa thông tin mô tả tương đối tĩnh, Fact chứa dữ liệu về các giao dịch thực tế, thường là các số liệu định lượng như số lượng, giá cả, doanh thu, v.v. Fact table thường có rất nhiều hàng và được tối ưu hóa cho các truy vấn phân tích thường xuyên.

### 6.2 Mối quan hệ giữa Fact và Dimension

Các bảng Fact được kết nối với các bảng Dimension thông qua các khóa ngoài (foreign key). Ví dụ, mỗi hàng trong bảng `FACT_SALES` chứa một khóa tham chiếu đến `DIM_PRODUCT` (product_key), `DIM_CUSTOMER` (customer_key), `DIM_CITY` (city_key), `DIM_EMPLOYEE` (employee_key), và `DIM_DATE` (date_key). Cấu trúc này gọi là mô hình sao (star schema), vì bảng Fact nằm ở trung tâm được bao quanh bởi các bảng Dimension.

### 6.3 Thứ tự tải Fact

Các bảng Fact được tải theo thứ tự: `Load_Fact_Sale`, `Load_Fact_Purchase`, rồi `Load_Fact_Inventory`. Thứ tự này không quá quan trọng vì các bảng Fact độc lập với nhau, nhưng theo quy ước, các giao dịch bán được tải trước, tiếp theo là giao dịch mua, rồi cuối cùng là tồn kho.

### 6.4 Chi tiết các package Fact

**Package Load_Fact_Sale**: Package này nạp dữ liệu bán hàng từ Staging vào bảng `FACT_SALES`. Dữ liệu về các hóa đơn bán hàng và các dòng hóa đơn được đọc từ `Sales.InvoiceLines` và `Sales.Invoices`. Package sử dụng các component Lookup để tìm khóa từ các bảng Dimension (`DIM_PRODUCT`, `DIM_CUSTOMER`, `DIM_EMPLOYEE`, `DIM_CITY`). Ngoài ra, các trường tính toán được tạo bằng Derived Column component để tính toán các số liệu phân tích như doanh thu ròng, chiết khấu, v.v.

**Package Load_Fact_Purchase**: Package này nạp dữ liệu mua hàng từ `Purchasing.PurchaseOrders` và `Purchasing.PurchaseOrderLines` vào bảng `FACT_PURCHASE`. Các component Lookup được sử dụng để tìm khóa từ `DIM_PRODUCT` và `DIM_SUPPLIER`. Dữ liệu về các chi phí mua hàng, số lượng, và giá cả được nạp.

**Package Load_Fact_Inventory**: Package này nạp dữ liệu tồn kho từ `Warehouse.StockItemTransactions` và `Warehouse.StockItemHoldings` vào bảng `FACT_INVENTORY`. Các trường quan trọng bao gồm số lượng tồn kho, số lượng nhập, số lượng xuất, và vị trí lưu trữ. Các component Lookup được sử dụng để tìm khóa từ `DIM_DATE` và `DIM_PRODUCT`.

---

## 7. QUY TRÌNH TỔNG HỢP DỮ LIỆU

### 7.1 Mục tiêu của tổng hợp

Sau khi các bảng Fact được tải đầy đủ, bước cuối cùng là tổng hợp dữ liệu để tạo ra các bảng đã được tính toán trước (pre-aggregated tables). Bảng tổng hợp này giúp tăng tốc độ các truy vấn phân tích thường xuyên, mà không cần phải tính toán lại từ các bảng Fact gốc mỗi lần.

### 7.2 Các bảng tổng hợp

Package `Load_Agg_Fact.dtsx` tạo ra ba bảng tổng hợp chính. **Bảng AGG_INVENTORY_WEEKLY** chứa dữ liệu tồn kho được tổng hợp theo tuần và theo sản phẩm. Bảng này được tính bằng cách lấy dữ liệu từ `FACT_INVENTORY`, nhóm theo năm, tuần, và sản phẩm, rồi tính toán các số liệu tổng như tổng số lượng nhập, tổng số lượng xuất, và tồn kho tính trung bình. Dữ liệu này hữu ích cho các nhà quản lý kho để theo dõi xu hướng tồn kho theo thời gian.

**Bảng AGG_SALES_DAILY** chứa dữ liệu doanh số bán hàng được tổng hợp theo ngày. Bảng này được tính bằng cách lấy dữ liệu từ `FACT_SALES`, nhóm theo ngày, rồi tính toán các số liệu tổng như tổng doanh thu, tổng số lượng bán, và số lượng giao dịch. Dữ liệu này giúp các nhà quản lý theo dõi hiệu suất bán hàng hàng ngày.

**Bảng AGG_SALES_PRODUCT_CITY_DAILY** là một phiên bản chi tiết hơn, chứa dữ liệu doanh số bán hàng được tổng hợp theo ngày, sản phẩm, và thành phố. Bảng này cho phép phân tích chi tiết về hiệu suất bán hàng của từng sản phẩm trong từng thị trường địa lý.

### 7.3 Quy trình tính toán tổng hợp

Package sử dụng các component Execute SQL Task để chạy các câu lệnh SQL Insert Select. Mỗi câu lệnh đọc dữ liệu từ các bảng Fact hoặc bảng Dimension, thực hiện các phép aggregation (tổng hợp) bằng cách sử dụng GROUP BY và các hàm aggregation như SUM(), COUNT(), AVG(), rồi ghi kết quả vào bảng tổng hợp tương ứng. Trước khi ghi dữ liệu mới, các bảng tổng hợp được làm trống (TRUNCATE TABLE) để đảm bảo rằng chỉ dữ liệu hiện tại được lưu trữ.

---

## 8. KỸ THUẬT SLOWLY CHANGING DIMENSION TYPE 2

### 8.1 Định nghĩa và lợi ích

Slowly Changing Dimension Type 2 (SCD Type 2) là một kỹ thuật quản lý dữ liệu chiều được sử dụng khi cần lưu trữ lịch sử đầy đủ của những thay đổi dữ liệu. Kỹ thuật này rất hữu ích trong các tình huống khi dữ liệu thay đổi chậm chạp, tức là không thường xuyên thay đổi, nhưng khi thay đổi, cần lưu trữ cả dữ liệu cũ và mới để tái tạo trạng thái lịch sử.

Lợi ích chính của SCD Type 2 là cho phép phân tích theo chuỗi thời gian. Ví dụ, nếu một khách hàng thay đổi địa chỉ, với SCD Type 2, người ta có thể trả lời câu hỏi "trong tháng trước, khách hàng này sống ở đâu?" bằng cách tìm bản ghi có `valid_from` trước ngày đó và `valid_to` sau ngày đó. Không có SCD Type 2, thông tin này sẽ bị mất.

### 8.2 Cơ chế hoạt động

Cơ chế hoạt động của SCD Type 2 dựa trên ba cột quan trọng: `valid_from`, `valid_to`, và `is_current`. Cột `valid_from` ghi nhận ngày bắt đầu khi bản ghi này trở thành hiệu lực. Cột `valid_to` ghi nhận ngày kết thúc khi bản ghi này hết hiệu lực. Cột `is_current` là một cờ boolean đơn giản để chỉ ra liệu bản ghi này có phải là bản ghi hiện tại (giá trị 1) hay là bản ghi lịch sử (giá trị 0).

Khi một giá trị thuộc tính của một đối tượng thay đổi, quy trình sau được thực hiện. Đầu tiên, bản ghi cũ được cập nhật để gán `valid_to` bằng ngày hôm nay và `is_current` bằng 0. Thứ hai, một bản ghi mới được tạo với dữ liệu mới, `valid_from` bằng ngày hôm nay, `valid_to` bằng NULL (biểu thị rằng bản ghi này vẫn còn hiệu lực), và `is_current` bằng 1.

### 8.3 Ứng dụng trong dự án

Trong dự án WideWorld Imposter, SCD Type 2 được áp dụng cho tất cả năm bảng dimension. Ví dụ, nếu thông tin của khách hàng thay đổi (chẳng hạn như chuyên ngành từ bán lẻ sang bán buôn), hệ thống sẽ tự động cập nhật bản ghi cũ và tạo bản ghi mới. Điều này cho phép các nhà phân tích dữ liệu chạy các truy vấn để tìm ra "khách hàng nào đã thay đổi danh mục kinh doanh trong tháng qua" hoặc "doanh số bán hàng của khách hàng trước khi thay đổi danh mục là bao nhiêu".

---

## 9. LUỒNG ĐIều PHỐI CHÍNH

### 9.1 Cấu trúc của Master_ETL

Package `Master_ETL.dtsx` đóng vai trò là điểm vào chính của toàn bộ quy trình ETL. Package này chứa một chuỗi các Execute Package Task, mỗi task gọi một package con. Các task được kết nối thông qua các Precedence Constraint, đây là các quy tắc xác định điều kiện thực thi của các task.

### 9.2 Thứ tự thực thi

Thứ tự thực thi các package được thiết kế cẩn thận để đảm bảo dữ liệu được xử lý đúng theo logic phụ thuộc. Đầu tiên, `Load_Staging` được chạy để nạp dữ liệu từ các hệ thống nguồn vào vùng Staging. Chỉ khi `Load_Staging` chạy thành công, năm package dimension mới được chạy theo thứ tự: `Load_Dim_Product`, `Load_Dim_Supplier`, `Load_Dim_Customer`, `Load_Dim_Employee`, và `Load_Dim_City`.

Sau khi tất cả dimension đã được tải, ba package fact được chạy theo thứ tự: `Load_Fact_Sale`, `Load_Fact_Purchase`, và `Load_Fact_Inventory`. Cuối cùng, `Load_Agg_Fact` được chạy để tạo các bảng tổng hợp.

### 9.3 Xử lý lỗi

Mỗi Precedence Constraint đều được cấu hình để kiểm tra kết quả thực thi của task trước đó. Nếu task trước đó thất bại (kết quả là Failure), task tiếp theo sẽ không được thực thi. Cơ chế này đảm bảo rằng nếu bước nạp Staging thất bại, hệ thống sẽ không tiếp tục với các bước Dimension và Fact, tránh tạo ra dữ liệu không nhất quán.

---

## 10. KẾT LUẬN

### 10.1 Tóm tắt quy trình

Quy trình ETL của dự án WideWorld Imposter được xây dựng theo kiến trúc ba tầng cổ điển, với các bước được thực hiện một cách có tổ chức và có kiểm soát. Dữ liệu được nạp từ các hệ thống nguồn khác nhau vào vùng Staging, được làm sạch và chuẩn hóa. Sau đó, các bảng Dimension được xây dựng bằng cách sử dụng kỹ thuật SCD Type 2 để lưu trữ lịch sử. Tiếp theo, dữ liệu được tải vào các bảng Fact, được kết nối với các Dimension thông qua các khóa ngoài. Cuối cùng, dữ liệu được tổng hợp thành các bảng aggregated để hỗ trợ phân tích nhanh.

### 10.2 Lợi ích của hệ thống

Kho dữ liệu được xây dựng từ quy trình ETL này cung cấp nhiều lợi ích cho tập đoàn Wide World Importers. Thứ nhất, nó tập hợp dữ liệu từ các hệ thống rải rác vào một nguồn dữ liệu thống nhất, giúp loại bỏ sự mâu thuẫn và không nhất quán. Thứ hai, dữ liệu được tổ chức theo mô hình sao, tối ưu hóa cho các truy vấn phân tích thường xuyên. Thứ ba, nhờ vào SCD Type 2, hệ thống cho phép phân tích theo chuỗi thời gian, giúp hiểu rõ hơn về những thay đổi kinh doanh theo thời gian. Thứ tư, các bảng tổng hợp được tạo sẵn giúp tăng tốc độ các truy vấn phân tích, cải thiện trải nghiệm người dùng.

### 10.3 Khuyến nghị cho tương lai

Để duy trì và phát triển hệ thống ETL này, được khuyến nghị một số điều sau. Thứ nhất, cần thường xuyên theo dõi hiệu suất của các package SSIS, sử dụng các tools như SQL Server Profiler để phát hiện các bottleneck. Thứ hai, nên xây dựng các lịch chạy tự động cho các package, sử dụng SQL Server Agent, để đảm bảo dữ liệu kho được cập nhật định kỳ. Thứ ba, nên thiết lập các cảnh báo khi các package thất bại, để đảm bảo các sự cố được phát hiện và khắc phục kịp thời. Thứ tư, nên duy trì tài liệu chi tiết về cấu trúc của các package, các phép biến đổi được thực hiện, và các giả định về dữ liệu, để hỗ trợ các kỹ sư dữ liệu trong tương lai.

---

**HẾT BÁO CÁO**

---

*Người lập báo cáo: [Tên học viên]*  
*Lớp: [Lớp học]*  
*Ngày lập: 20/05/2026*
