## Анализ данных на примере фейковой базы данных фирмы по продажам ##
Содержание:<br>
1. [Запуск базы данных](#Запуск-базы-данных)
2. [Заполнение базы данных shop](#Заполнение-базы-данных-shop)
3. [Добавление связей между таблицами](#Добавление-связей-между-таблицами)
4. [SQL-запрос: выручка по месяцам](#Выручка-по-месяцам)
5. [SQL-запрос: cредний чек для completed заказов](#Средний-чек-для-completed-заказов)
6. [SQL-запрос: средний чек для всех статусов](#Средний-чек-для-всех-статусов)
7. [SQL-запрос: топ-10 покупателей по сумме покупок](#Топ-10-покупателей-по-сумме-покупок)
8. [SQL-запрос: топ-10 товаров по выручке и по количеству продаж](#Топ-10-товаров-по-выручке-и-по-количеству-продаж)
9. [SQL-запрос: количество заказов по статусам](#Количество-заказов-по-статусам)
10. [SQL-запрос: динамика количества заказов по дням/неделям/месяцам](#Динамика-количества-заказов-по-дням/неделям/месяцам)
11. [SQL-запрос: как давно покупатели совершали последний заказ (воронка удержания) и разбить по давности на группы](#Как-давно-покупатели-совершали-последний-заказ-(воронка-удержания)-и-разбить-по-давности-на-группы)
12. [SQL-запрос: ABC-анализ товаров](#ABC-анализ-товаров)
13. [Построение отчета (визуализация)](#Построение-отчета-(визуализация))

#### Запуск базы данных ####
Базу данных решил создавать на PostgreSQL. Проводил исследование на hh.ru и согласно нему постгрес - самый востребованный диалект для баз данных и хранилищ (из 330 вакансий на аналитика в 16,1% требуется). Далее идёт ClickHouse (11,2%) - самый популярный диалект для хранилищ.

Для имитации удаленного сервера PostgreSQL запуск осуществлял в docker-контейнере.
```
docker run --name server_postgres \
    -e POSTGRES_USER=dmitriy \
    -e POSTGRES_PASSWORD=password \
    -e POSTGRES_DB=shop \
    -p 5432:5432 \
    -d postgres
```

#### Заполнение базы данных shop ####
Для заполнения базы данных данными написал питоновский скрипт make_db.py .
Создал четыре таблицы:
1. customers - таблица-справочник по покупателям.
2. orders - таблица-справочник по заказам.
3. order_items - id заказа, товар, количество в заказе.
4. products - справочник по товарам.

Первоначальный вариант таблицы products не понравился, поэтому написал ещё один модуль make_product.py. В нем парсил сохранённые локально две веб-страницы с сайта dns.ru. В итоге записал в products 54 реальных товара с dns.ru (мониторы и озу).

<details>
<summary>Код make_product.py</summary>

```python

from bs4 import BeautifulSoup

def get_products():
    links = ['monitor1.html', 'ozu.html'] # список из локальных файлов
    categories = ['Монитор', 'Оперативная память']
    separators = [' черный', ' [DDR']
    products = []
    i = 0
    for link in zip(links, categories, separators):
        with open(link[0], 'r', encoding='utf-8') as f:
            content = f.read()

        soup = BeautifulSoup(content, 'lxml')
    
        for blok in soup.find_all( 'div', class_="catalog-product ui-button-widget"):
            name = blok.find('a', class_="catalog-product__name ui-link ui-link_black").text.split(sep=link[2])[0]
            price = blok.find('div', class_="product-buy__price").text.split(sep="\xa0")[0]
            products.append({
                'id': i,
                'name': name,
                'category': link[1],
                'price': int(''.join(price.split()))
            })
            i +=1

    return products


# Для тестирования модуля
if __name__ == "__main__":
    products = get_products()
    print("Количество продуктов:", len(products))
    for pr in products:
        print(pr)
 ```
</details>

## Работа с базой данных ##
Для подключения к базе данных пробовал разные варианты инструментов, в конце концов остановился на DBeaver.

#### Добавление связей между таблицами ####
При создании базы данных сразу не позаботился о назначении связей между таблицы. Поэтому первым делом создаю связи между таблицами.

Таблица customers, столбец id - первичный ключ:
```sql
ALTER TABLE customers
ADD PRIMARY KEY (id);
```

Таблица orders, столбец id - первичный:
```sql
ALTER TABLE orders ADD PRIMARY KEY (id);
```

Таблица products, столбец id - первичный ключ:
```sql
ALTER TABLE products
ADD PRIMARY KEY (id);
```

Таблица orders, столбец customer_id - вторичный, ссылается на id таблицы customers:
```sql
ALTER TABLE orders 
ADD CONSTRAINT fk_orders_customer 
FOREIGN KEY (customer_id) REFERENCES customers(id);
```

Таблица order_items, столбец order_id - вторичный ключ, ссылается на orders (id)<br>
столбец product_id - вторичный ключ, ссылается на products (id):
```sql
ALTER TABLE order_items
ADD CONSTRAINT fk_order_items_order 
FOREIGN KEY (order_id) REFERENCES orders (id);

ALTER TABLE order_items
ADD CONSTRAINT fk_order_items_products
FOREIGN KEY (product_id) REFERENCES products (id);
```

Получилась следующая диаграмма связей:

![alt](images/er_diagr.png)

Теперь запросы:<br>
1. #### Выручка по месяцам ####
```sql
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
```
![alt](images/sql.png)


2. #### Средний чек для completed заказов ####
```sql
WITH sq AS
    (SELECT 
         SUM(quantity * price) as profit
         FROM orders
             JOIN order_items ON orders.id = order_items.order_id
             JOIN products ON order_items.product_id = products.id
         WHERE status = 'completed'
         GROUP BY order_id
     )
SELECT SUM(profit)/COUNT(profit) as avg_revenue_completed from sq;

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
```

![alt](images/sql1.png)

#### Средний чек для всех статусов ####
```sql
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
```

![alt](images/sql2.png)

3. #### Количество заказов по статусам ####
```sql
--Всего заказов
SELECT COUNT(*) AS Все_заказы FROM orders;

--Количество заказов со status=completed
SELECT
    COUNT(*) AS Заказы_completed
FROM orders
WHERE status = 'completed';

--Количество заказов со status=cancelled
SELECT
    COUNT(*) AS Заказы_cancelled
FROM orders
WHERE status = 'cancelled';

--Количество заказов со status=processing
SELECT
    COUNT(*) AS Заказы_processing
FROM orders
WHERE status = 'processing';
```

4. #### Топ-10 покупателей по сумме покупок ####
```sql
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
WHERE status = 'completed'
GROUP BY customers.id, city
ORDER BY Сумма DESC
LIMIT 10;
```

![alt](images/sql3.png)

5. #### Топ-10 товаров по выручке и по количеству продаж ####
```sql
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
```

![alt](images/sql4.png)

```sql
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
```

6. #### Динамика количества заказов по дням/неделям/месяцам ####
```sql
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
```

7. #### Как давно покупатели совершали последний заказ (воронка удержания) и разбить по давности на группы ####
```sql
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
```

![alt](images/sql5.png)

8. #### ABC-анализ товаров ####
Разбить на три группы:<br>
A - группа товаров с самой большой выручкой с накопительной до 80%<br>
B - следующая группа с накопительной выручкой до 95%.<br>
С - оставшие товары, в том числе которые отсутствуют в таблице orders.
```sql
--ABC-анализ товаров
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
```

![alt](images/sql6.png)

## Построение отчета (визуализация) ##
Рисовать буду в Jupyter Notebook (файл profit.ipynb) используя питоновскую библиотеку matplotlib.

<details>
<summary>Выручка по месяцам</summary>

```python
import pandas as pd
import matplotlib.pyplot as plt
from sqlalchemy import create_engine

# Подключение к базе данных
engine = create_engine('postgresql://dmitriy:password@localhost:5432/shop')

# Запрос: выручка по месяцам (возвращаем DATE, а не строку)
query = """
SELECT 
    DATE_TRUNC('month', order_date) AS Месяц,
    SUM(quantity * price) AS Выручка,
    COUNT(distinct orders.id) AS Заказы
FROM orders
    JOIN order_items ON orders.id = order_items.order_id
    JOIN products ON order_items.product_id = products.id
WHERE status = 'completed'
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY DATE_TRUNC('month', order_date);
"""

# Загрузка данных
df = pd.read_sql(query, engine)

# Преобразование даты для красивого отображения на графике
df['month_str'] = df['Месяц'].dt.strftime('%Y-%m')

print("Данные загружены:")
print(df[['month_str', 'Выручка', 'Заказы']])

# Создание графика
plt.figure(figsize=(15, 6))

# Столбцы
bars = plt.bar(df['month_str'], df['Выручка'], 
               color='brown',
               alpha=0.8            
              )

plt.bar_label(bars, fmt=lambda x: f'{int(x):,}'.replace(',', ' '))

plt.title('Выручка по месяцам', fontsize=16, fontweight='bold')
plt.xlabel('Месяц', fontsize=12)
plt.ylabel('Выручка в млн. руб', fontsize=12)
plt.xticks(rotation=45, ha='right')

plt.show()
```
</details>

Получился такой график:

![alt](images/revenue.png)

<details>
<summary>Количество заказов по месяцам</summary>

```python

import pandas as pd
import matplotlib.pyplot as plt
from sqlalchemy import create_engine

engine = create_engine('postgresql://dmitriy:password@localhost:5432/shop')

query = """
SELECT 
    TO_CHAR(DATE_TRUNC('month', order_date), 'MM.YYYY') AS Дата,
    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed,
    SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled,
    SUM(CASE WHEN status = 'processing' THEN 1 ELSE 0 END) AS processing
FROM orders
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY DATE_TRUNC('month', order_date);
"""

df = pd.read_sql(query, engine)


x = df.index.values
plt.figure(figsize=(18, 6))

plt.bar(x - 0.25, df['completed'], width=0.25, color='green', alpha=0.8, label='Завершённые')
plt.bar(x, df['processing'], width=0.25, color='gray', label='В обработке')
plt.bar(x + 0.25, df['cancelled'], width=0.25, color='red', alpha=0.7, label='Отменённые')

plt.xticks(ticks=x, labels=df['Дата'])
plt.legend()
plt.title('Количество заказов по месяцам', fontsize=18, fontweight='bold', pad=20)
plt.xlabel('Месяцы', fontsize=12)
plt.ylabel('Количество заказов', fontsize=12)

plt.show()
```
</details>

![alt](images/orders.png)
