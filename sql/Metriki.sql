-- Вывести выручку по месяцам
SELECT 
    TO_CHAR(DATE_TRUNC('month', order_date), 'YYYY-MM') AS Месяц,
    SUM(quantity * price) AS "Выручка/месяц",
    COUNT(distinct orders.id) as Заказы
FROM orders
    JOIN order_items ON orders.id = order_items.order_id
    JOIN products ON order_items.product_id = products.id
WHERE status = 'completed'
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY Месяц;

--2. Средний чек для completed заказов (общая сумма заказа / количество заказов)
--Заготовка
SELECT
    order_id,
    SUM(quantity * price)
FROM orders
    JOIN order_items ON orders.id = order_items.order_id
    JOIN products ON order_items.product_id = products.id
WHERE status = 'completed'
GROUP BY order_id
ORDER BY order_id;

with sq AS
    (select 
         SUM(quantity * price) as profit
         FROM orders
             JOIN order_items ON orders.id = order_items.order_id
             JOIN products ON order_items.product_id = products.id
         WHERE status = 'completed'
         group by order_id
     )
 select SUM(profit)/COUNT(profit) as avg_revenue_completed from sq;

--Другой попроще способ
SELECT 
    AVG(order_total) AS avg_revenue_completed
FROM (
    SELECT 
        SUM(quantity * price) AS order_total
    FROM orders
        JOIN order_items ON orders.id = order_items.order_id
        JOIN products ON order_items.product_id = products.id
    WHERE status = 'completed'
    GROUP BY order_id
) AS order_totals;

--Средник чек по всем заказам
SELECT 
    ROUND(AVG(order_total)) AS avg_revenue_full
FROM (
    SELECT 
        SUM(quantity * price) AS order_total
    FROM orders
        JOIN order_items ON orders.id = order_items.order_id
        JOIN products ON order_items.product_id = products.id
    GROUP BY order_id
) AS order_totals;

--Всего заказов
SELECT COUNT(*) AS Все_заказы FROM orders;

--Количество заказов со status=completed
SELECT
    COUNT(*) AS Заказы_completed
FROM orders
WHERE status = 'completed'; --161

--Количество заказов со status=cancelled
SELECT
    COUNT(*) AS Заказы_cancelled
FROM orders
WHERE status = 'cancelled';--178

--Количество заказов со status=processing
SELECT
    COUNT(*) AS Заказы_processing
FROM orders
WHERE status = 'processing';--161

--top-10 покупателей
SELECT 
    RANK() OVER (ORDER BY SUM(quantity * price) DESC) AS Место,
    customers.name as Имя,
    city as Город,
    COUNT(DISTINCT order_id) as Заказы,
    SUM(quantity * price) as Сумма
FROM customers
    JOIN orders ON customers.id = orders.customer_id
    JOIN order_items ON orders.id = order_items.order_id
    JOIN products ON order_items.product_id = products.id
where status = 'completed'
GROUP BY customers.id, city
ORDER BY Сумма DESC
LIMIT 10;

--top 10 товаров по выручке
SELECT 
    RANK() OVER (ORDER BY SUM(quantity * price) DESC) AS Место,
    products.name as Товар,
    SUM(quantity) as Количество,
    SUM(quantity * price) as Выручка
FROM orders
    JOIN order_items ON orders.id = order_items.order_id
    JOIN products ON order_items.product_id = products.id
WHERE status = 'completed'
GROUP BY products.id, products.name
ORDER BY Выручка DESC
LIMIT 10;

--top 10 товаров по количеству продаж
SELECT 
    RANK() OVER (ORDER BY SUM(quantity) DESC) AS Ранг,
    products.name as Товар,
    SUM(quantity) as Количество
FROM orders
    JOIN order_items ON orders.id = order_items.order_id
    JOIN products ON order_items.product_id = products.id
WHERE status = 'completed'
GROUP BY products.id, products.name
ORDER BY Количество DESC
LIMIT 10;

--Динамика количества заказов по дням
SELECT
    TO_CHAR(DATE_TRUNC('day', order_date), 'DD.MM.YYYY') AS Дата,
    COUNT(id) AS Заказы
FROM orders
GROUP BY DATE_TRUNC('day', order_date)
ORDER BY DATE_TRUNC('day', order_date);

--Динамика количества заказов по неделям
SELECT
    TO_CHAR(DATE_TRUNC('week', order_date), 'DD.MM.YYYY') AS Дата,
    COUNT(id) AS Заказы
FROM orders
GROUP BY DATE_TRUNC('week', order_date)
ORDER BY DATE_TRUNC('week', order_date);

--Динамика количества заказов по месяцам
SELECT
    TO_CHAR(DATE_TRUNC('month', order_date), 'DD.MM.YYYY') AS Дата,
    COUNT(id) AS Заказы
FROM orders
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY DATE_TRUNC('month', order_date);

--Как давно покупатели совершали заказ и разбить на группы.
SELECT
    customers.name as Имя,
    TO_CHAR(MAX(order_date), 'DD.MM.YYYY') as Дата,
    current_date - MAX(order_date) as Разница,
    CASE
        WHEN (current_date - MAX(order_date)) <= 60 THEN 'Активные: <= 60 дней'
        WHEN (current_date - MAX(order_date)) <= 180 THEN 'Средние: <= 180 дней'
        ELSE 'Давние: > 180 дней'
    END AS Группа
FROM customers
    JOIN orders ON customers.id = orders.customer_id
GROUP BY customers.id, customers.name
ORDER BY Разница;

