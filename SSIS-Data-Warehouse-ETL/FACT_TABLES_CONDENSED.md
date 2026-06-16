## F. BẢNG FACT_SALE

Bảng FACT_SALES ghi nhận chi tiết từng dòng hóa đơn bán hàng, phục vụ phân tích doanh số bán hàng đa chiều.

**Bước 1 – OLE DB Source:** Lấy dữ liệu bán hàng từ Staging (InvoiceLines + Invoices header).

```sql
SELECT il.invoice_line_id, il.invoice_id, i.customer_id, i.invoice_date, i.salesperson_id, 
    il.stock_item_id, il.quantity, il.unit_price, il.line_total, 
    ISNULL(il.discount_percent, 0) as discount_percent
FROM [dbo].[InvoiceLines] il
INNER JOIN [dbo].[Invoices] i ON il.invoice_id = i.invoice_id
```

**Bước 2-5 – Lookup Product/Customer/Employee/Date Key:** Từng Lookup lấy khóa chính từ Dimension để fact table có FK liên kết (phục vụ phân tích đa chiều).
- Lookup Product: `stock_item_id` → `product_key` (phân tích sản phẩm)
- Lookup Customer: `customer_id` → `customer_key` (phân tích khách hàng)
- Lookup Employee: `salesperson_id` → `employee_key` (đánh giá nhân viên)
- Lookup Date: `invoice_date` → `date_key` (phân tích theo thời gian)

Tất cả lấy bản ghi hiện tại: `WHERE valid_to IS NULL AND is_current = 1`

**Bước 6 – Derived Column:** Tính metrics kinh doanh.
- `discount_amount = unit_price * quantity * (discount_percent / 100)` → Theo dõi chiết khấu
- `net_sales_amount = line_total - discount_amount` → Doanh thu thực tế
- `gross_profit_amount = net_sales_amount - (unit_cost * quantity)` → Lợi nhuận

**Bước 7 – OLE DB Destination:** Chèn vào bảng FACT_SALES. **Ý nghĩa:** Hoàn thành transformation, sẵn sàng phân tích BI.

---

## G. BẢNG FACT_PURCHASE

Bảng FACT_PURCHASE ghi nhận chi tiết từng dòng đơn mua hàng, phục vụ phân tích chi phí mua hàng và hiệu suất nhà cung cấp.

**Bước 1 – OLE DB Source:** Lấy dữ liệu mua hàng từ Staging (PurchaseOrderLines + PurchaseOrders header).

```sql
SELECT pol.purchase_order_line_id, pol.purchase_order_id, po.supplier_id, po.order_date, po.delivery_date,
    pol.stock_item_id, pol.ordered_quantity, pol.received_quantity, pol.unit_price
FROM [dbo].[PurchaseOrderLines] pol
INNER JOIN [dbo].[PurchaseOrders] po ON pol.purchase_order_id = po.purchase_order_id
```

**Bước 2-4 – Lookup Product/Supplier/Date Key:** Lấy FK từ Dimension để fact table liên kết.
- Lookup Product: `stock_item_id` → `product_key` (phân tích sản phẩm)
- Lookup Supplier: `supplier_id` → `supplier_key` (đánh giá nhà cung cấp)
- Lookup Date: `order_date` → `date_key` (phân tích theo thời gian)

**Bước 5 – Derived Column:** Tính metrics mua hàng.
- `purchase_amount = ordered_quantity * unit_price` → Dự kiến
- `received_amount = received_quantity * unit_price` → Thực tế
- `variance_amount = (received_quantity - ordered_quantity) * unit_price` → Chênh lệch tài chính
- `variance_qty = received_quantity - ordered_quantity` → Chênh lệch số lượng (đánh giá độ chính xác)
- `delivery_days = DATEDIFF(DAY, order_date, delivery_date)` → Đánh giá SLA giao hàng

**Bước 6 – OLE DB Destination:** Chèn vào bảng FACT_PURCHASE. **Ý nghĩa:** Hỗ trợ phân tích chi phí và hiệu suất chuỗi cung ứng.

---

## H. BẢNG FACT_INVENTORY

Bảng FACT_INVENTORY ghi nhận chi tiết từng giao dịch tồn kho (nhập/xuất), phục vụ phân tích dòng tiền kho, vòng quay tồn kho.

**Bước 1 – OLE DB Source:** Lấy dữ liệu giao dịch tồn kho từ Staging (StockItemTransactions + StockItemHoldings snapshot).

```sql
SELECT sit.stock_item_transaction_id, sit.stock_item_id, sit.transaction_type_id, 
    sit.transaction_date, sit.customer_id, sit.supplier_id, sit.quantity, sit.unit_price,
    sih.quantity_on_hand, sih.bin_location
FROM [dbo].[StockItemTransactions] sit
LEFT JOIN [dbo].[StockItemHoldings] sih ON sit.stock_item_id = sih.stock_item_id
```

**Lý do LEFT JOIN:** StockItemTransactions ghi sự kiện nhập/xuất, StockItemHoldings là snapshot tồn kho hiện tại. Một số sản phẩm có giao dịch nhưng chưa có holding record (hoặc ngược lại).

**Bước 2-5 – Lookup Product/Date/Customer/Supplier Key:** Lấy FK từ Dimension để fact table liên kết.
- Lookup Product: `stock_item_id` → `product_key` + `unit_cost` (cần để tính stock_value)
- Lookup Date: `transaction_date` → `date_key` (phân tích theo thời gian)
- Lookup Customer: `customer_id` → `customer_key` (nếu giao dịch = xuất bán, có FK)
- Lookup Supplier: `supplier_id` → `supplier_key` (nếu giao dịch = nhập mua, có FK)

**Bước 6 – Derived Column:** Tính metrics tồn kho.
- `quantity_in = CASE WHEN transaction_type_id = 1 THEN quantity ELSE 0 END` → Tách nhập
- `quantity_out = CASE WHEN transaction_type_id = 2 THEN ABS(quantity) ELSE 0 END` → Tách xuất
- `transaction_value = quantity * unit_price` → Dòng tiền giao dịch
- `stock_value = quantity_on_hand * unit_cost` → Giá trị tồn kho tài chính
- `holding_location = bin_location` → Vị trí lưu trữ (tối ưu kho)

**Ý nghĩa:** Tách nhập/xuất để tính vòng quay: `Vòng quay = Tổng xuất / Tồn kho trung bình`. Tính `stock_value` để báo cáo tài chính. Phân tích vị trí để tối ưu hóa sắp xếp kho.

**Bước 7 – OLE DB Destination:** Chèn vào bảng FACT_INVENTORY. **Ý nghĩa:** Hỗ trợ quản lý kho và báo cáo tài chính.
