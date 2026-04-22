--Первые 5 записей таблицы orders
SELECT *
FROM orders
LIMIT 10;
/*
id  customer_id order_date  status
0	88	        2026-04-06	completed
1	84	        2025-08-18	cancelled
2	50	        2025-10-19	cancelled
*/

--Таблица products
SELECT *
FROM products;
/*
id  name order_                 category  price
1	27" Монитор MSI PRO MP273A	Монитор	  10599
*/

--Всего записей в таблице orders
SELECT COUNT(*)
FROM orders;
--count=500

--Всего записей со статусом completed
SELECT COUNT(*)
FROM orders
WHERE status='completed';
--count = 161

--Таблица customers, столбец id - первичный ключ:
ALTER TABLE customers
ADD PRIMARY KEY (id);

--Таблица products, столбец id - первичный ключ:
ALTER TABLE products
ADD PRIMARY KEY (id);

--Таблица orders, столбец id - первичный:
ALTER TABLE orders ADD PRIMARY KEY (id);

--Таблица orders, столбец customer_id - вторичный, ссылается на id таблицы customers:
ALTER TABLE orders 
ADD CONSTRAINT fk_orders_customer 
FOREIGN KEY (customer_id) REFERENCES customers(id);

/*
Таблица order_items, столбец order_id - вторичный ключ, ссылается на orders (id)
столбец product_id - вторичный ключ, ссылается на products (id):
*/
ALTER TABLE order_items
ADD CONSTRAINT fk_order_items_order 
FOREIGN KEY (order_id) REFERENCES orders (id);

ALTER TABLE order_items
ADD CONSTRAINT fk_order_items_products
FOREIGN KEY (product_id) REFERENCES products (id);



