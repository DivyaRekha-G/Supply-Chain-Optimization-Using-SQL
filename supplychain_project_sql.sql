create database Supplychain;
use Supplychain;
Create table products(
product_id int primary key,
product_name varchar(255),
category varchar(100),
price float
);
Create table warehouses(
warehouse_id int primary key,
warehouse_name varchar(255),
location varchar(255)
);
create table inventory(
inventory_id int primary key,
product_id int,
warehouse_id int,
stock_quantity int,
last_updated date,
foreign key (product_id) references products(product_id),
foreign key (warehouse_id) references warehouses(warehouse_id)
);
create table orders(
order_id int primary key,
product_id int,
order_date date,
quantity_ordered int,
status varchar(50),
foreign key (product_id) references products(product_id)
);
create table shipments(
shipment_id int primary key,
order_id int,
warehouse_id int,
shipped_date date,
delivery_status varchar(50),
foreign key (order_id) references orders(order_id),
foreign key (warehouse_id) references warehouses(warehouse_id)
);

-- Data Cleaning and Quality checks

# Find products with missing or incorrect price values
select * from products where price is null or price <=0;

#Check for duplicate orders
select order_id, count(*) from orders
group by order_id 
having count(*) >1;

# Identify warehouse locations with missing inventory data
select w.warehouse_id,w.warehouse_name
from warehouses w 
left join inventory i on 
w.warehouse_id =i.inventory_id 
where i.warehouse_id is null;

-- Inventory & Demand Analysis

# Find total stock available per product
select p.product_name, sum(i.stock_quantity) as total_stock
from inventory i 
join products p on 
i.product_id =p.product_id
group by p.product_name;

# Find out-of-stock products

select p.product_name, i.stock_quantity
from inventory i 
join products p on i.product_id =p.product_id
where i.stock_quantity =0;

# Find warehouses with lowest stock levels
SELECT w.warehouse_name, SUM(i.stock_quantity) AS total_stock
FROM inventory i
JOIN warehouses w ON i.warehouse_id = w.warehouse_id
GROUP BY w.warehouse_name
ORDER BY total_stock ASC
LIMIT 5;

#Identify products frequently restocked (fast-moving products)
select i.product_id,p.product_name, count(i.inventory_id)as restock_count
from inventory i 
join products p on i.product_id =p.product_id
where i.last_updated >= now() - interval 3 month
group by i.product_id,p.product_name
order by restock_count desc
limit 10;


-- Demand Forecasting & Trend Analysis ---

#Rank products based on sales (Window Function)

select product_id,
sum(quantity_ordered) as total_sold,
rank() over(order by sum(quantity_ordered) desc) as sales_rank
from orders
group by product_id;

#Analyze peak shipping months
SELECT DATE_FORMAT(shipped_date, '%Y-%m') AS month, COUNT(shipment_id) AS total_shipments
FROM shipments
GROUP BY month
ORDER BY total_shipments DESC;

#Rank products based on demand trends
SELECT o.product_id, p.product_name, COUNT(o.order_id) AS total_orders,
       RANK() OVER (ORDER BY COUNT(o.order_id) DESC) AS ranks
FROM orders o
JOIN products p ON o.product_id = p.product_id
GROUP BY o.product_id, p.product_name;

--  Logistics & Shipment Optimization  ----

# Find delayed shipments (more than 7 days)
select shipment_id, order_id, warehouse_id, shipped_date,
datediff(now(),shipped_date) as days_delayed,delivery_status
from shipments
where delivery_status != 'Delivered'
and shipped_date < now() -interval 7 day;

# Analyze warehouse performance based on delivery time
select w.warehouse_name,
round(avg(datediff(now(), s.shipped_date))) as avg_delivery_time
from shipments s 
join warehouses w on s.warehouse_id =w.warehouse_id
where s.delivery_status ='delivered'
group by w.warehouse_name
order by avg_delivery_time desc;

#Find most efficient warehouses (fastest delivery)
select w.warehouse_name, round(avg(datediff(s.shipped_date,i.last_updated))) as avg_processing_time
from shipments s 
join inventory i on s.warehouse_id =i.warehouse_id
join warehouses w on s.warehouse_id =w.warehouse_id
where s.delivery_status = 'delivered'
group by w.warehouse_name
order by avg_processing_time asc
limit 5;

-- Automating Inventory & Reordering --- 

# Trigger: Auto-update inventory when a shipment is delivered.
create trigger update_inventory_on_delivery 
after update on shipments
for each row
update inventory
set stock_quantity =stock_quantity -10 -- example stock reduction
where product_id = (select product_id FROM orders WHERE order_id = NEW.order_id)
AND warehouse_id = NEW.warehouse_id
AND NEW.delivery_status = 'Delivered';


# Stored Procedure: Auto-reorder stock when inventory is low

DELIMITER $$

CREATE PROCEDURE AutoReorder()
BEGIN
    INSERT INTO orders (product_id, quantity_ordered, status)
    SELECT product_id, 50, 'Pending'
    FROM inventory
    WHERE stock_quantity < 10;
END $$

DELIMITER ;




