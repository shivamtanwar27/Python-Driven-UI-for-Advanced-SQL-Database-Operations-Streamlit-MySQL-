-- 1) Total Suppliers:
select count(supplier_id) as total_suppliers from project.suppliers;

-- 2) Total Products:
select count(product_id) as total_products from project.products;

-- 3) Total Categories:
select count(distinct category) as total_categories from project.products;

-- 4) Total Sales value (last 3 months):
select  round(sum(abs(ps.change_quantity*p.price))) as sales from project.stock_entries as ps
inner join products as p
on ps.product_id = p.product_id
where ps.change_type = "Sale"
and
ps.entry_date >= 
(select date_sub(max(entry_date), interval 3 month) from project.stock_entries);

-- 5) Total Restock value (last 3 months):
select  round(sum(abs(ps.change_quantity*p.price))) as total_restock from project.stock_entries as ps
inner join products as p
on ps.product_id = p.product_id
where ps.change_type = "Restock"
and
ps.entry_date >= 
(select date_sub(max(entry_date), interval 3 month) from project.stock_entries);

-- 6) Below Reorder and no pending Reorders:
select count(*) from
(select * from project.products
where stock_quantity <= reorder_level)t1
inner join
(select * from project.reorders
where status = "Pending")t2
on t1.product_id = t2.product_id;

-- 7) Supplier Contact Details
select supplier_name, contact_name, email, phone from project.suppliers;

-- 8) Products with Supplier and Stock
select product_name, supplier_name, stock_quantity, reorder_level from project.products as pp
inner join project.suppliers as s
on pp.supplier_id =  s.supplier_id;

-- 9) Products needing Reorder
select product_name, stock_quantity, reorder_level from project.products
where stock_quantity <= reorder_level;

-- 10) Add a new Product to the Database
DELIMITER //

-- 11) Add new Product to the Database
Delimiter //

CREATE PROCEDURE AddNewProductManualID(
	IN p_product varchar(255),
    IN p_category varchar(255),
    IN p_price DECIMAL(10,2),
    IN p_stock INT,
    IN p_reorder INT,
    IN p_supplier INT)
BEGIN

DECLARE p_product_id INT;
DECLARE p_entry_id INT;
DECLARE p_shipment_id INT;

SELECT MAX(product_id) + 1 into p_product_id from project.products;
SELECT MAX(shipment_id) + 1 into p_shipment_id from project.shipments;
SELECT MAX(entry_id) + 1 into p_entry_id from project.stock_entries;

-- make changes in product table
INSERT INTO project.products(product_id,product_name,category,price,stock_quantity,reorder_level,
								supplier_id)
VALUES
(p_product_id,p_product,p_category,p_price,p_stock,p_reorder,p_supplier);

-- make changes in shipment table
INSERT INTO project.shipments(shipment_id,product_id,supplier_id,quantity_received,shipment_date)
VALUES
(p_shipment_id,p_product_id,p_supplier,p_stock,CURDATE());

-- make changes in stock_entries table
INSERT INTO project.stock_entries(entry_id,product_id,change_quantity,change_type,entry_date)
VALUES
(p_entry_id,p_product_id,p_stock,"Restock",CURDATE());

END //

DELIMITER ;

-- 12) Getting Product History

CREATE VIEW  product_inventory_history AS
select tab1.product_id,record_type,record_date,quantity,change_type,supplier_id 
from
(select product_id, "Shipment" as record_type,  
shipment_date as record_date, quantity_received as quantity,
null as change_type
from project.shipments
union
select product_id, "Stock Entry" as record_type ,
entry_date as record_date, change_quantity as quantity,change_type
from project.stock_entries)tab1
inner join project.products tab2
on tab1.product_id = tab2.product_id;

SELECT * FROM product_inventory_history;

-- 13) Place a Reorder
INSERT INTO project.reorders (reorder_id, product_id,reorder_quantity,reorder_date,status)
select max(reorder_id)+1,product_id,reorder_quantity,curdate(),"Ordered" 
from project.reorders;


-- 14) Receive Reorder

DELIMITER //

CREATE PROCEDURE MarkReorderAsReceived(IN in_reorder_id INT)
BEGIN

DECLARE prod_id INT;
DECLARE qty INT;
DECLARE sup_id INT;
DECLARE new_shipment_id INT;
DECLARE new_entry_id INT;

-- GET product_id, quantity from reorders

SELECT product_id, reorder_quantity
into prod_id, qty
from project.reorders
where reorder_id = in_reorder_id;

-- Get supplier_id

SELECT supplier_id into sup_id
FROM project.products
where product_id = prod_id;

-- Update reorders table (status to Received)
UPDATE reorders
SET status = "Received"
WHERE reorder_id = in_reorder_id;

-- Update quantity in product table
UPDATE products
SET stock_quantity = stock_quantity + qty
WHERE product_id = prod_id;

-- Insert record into shipment table
SELECT MAX(shipment_id)+1 into new_shipment_id FROM project.shipments;

INSERT INTO project.shipments(shipment_id,product_id,supplier_id,quantity_received,shipment_date)
VALUES
(new_shipment_id, prod_id,sup_id,qty,CURDATE());

-- Insert record into stock_entries table

SELECT MAX(entry_id)+1 INTO new_entry_id FROM project.stock_entries;

INSERT INTO project.stock_entries(entry_id,product_id,change_quantity,change_type,entry_date)
VALUES
(new_entry_id, prod_id, qty, "Restock", CURDATE());

END //

DELIMITER ;







