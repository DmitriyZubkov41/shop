--abc-analiz
WITH all_profit AS
    (
     SELECT SUM(quantity * price) AS total
     FROM products JOIN order_items ON products.id = order_items.product_id
    ) ,
    percent_profit AS
    (
     SELECT
         name as Товар,
         COALESCE(SUM(quantity * price), 0)  as Выручка,
         COALESCE(ROUND(SUM(quantity * price) * 100 / (SELECT total FROM all_profit), 2), 0)  as Процент_выручки
     FROM products LEFT JOIN order_items ON products.id = order_items.product_id
     GROUP BY products.id, name
     ORDER BY Выручка DESC
    )
SELECT
    Товар,
    Выручка,
    Процент_выручки,
    SUM(Процент_выручки) OVER (ORDER BY Выручка DESC)  as Накоп_проц_выручки,
    CASE
        WHEN SUM(Процент_выручки) OVER (ORDER BY Выручка DESC) <= 80 THEN 'A'
        WHEN SUM(Процент_выручки) OVER (ORDER BY Выручка DESC) <= 95 THEN 'B'
        ELSE 'C'
    END AS Категория
FROM percent_profit;