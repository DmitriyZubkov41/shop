from faker import Faker
import random
import pandas as pd
from sqlalchemy import create_engine

import make_product

fake = Faker('ru_RU')  # русские данные

# Генерируем 100 покупателей
customers = []
for i in range(100):
    customers.append({
        'id': i,
        'name': fake.name(),
        'city': fake.city(),
        'registered_at': fake.date_between(start_date='-2y', end_date='today')
    })

# Генерируем товары
products = make_product.get_products()

# Генерируем 500 заказов (и связываем их с покупателями)
orders = []
for i in range(500):
    orders.append({
        'id': i,
        'customer_id': random.randint(0, 99),
        'order_date': fake.date_between(start_date='-1y', end_date='today'),
        'status': random.choice(['completed', 'cancelled', 'processing'])
    })

# Генерируем позиции в заказах (что купили)
order_items = []
for order_id in range(500):
    num_items = random.randint(1, 5)  # в заказе от 1 до 5 товаров
    for _ in range(num_items):
        order_items.append({
            'order_id': order_id,
            'product_id': random.randint(0, 49),
            'quantity': random.randint(1, 3)
        })

# Создаём подключение через SQLAlchemy
# Формат: postgresql://username:password@host:port/database
engine = create_engine('postgresql://dmitriy:password@localhost:5432/shop')

# Записываем в базу данных
pd.DataFrame(customers).to_sql('customers', engine, if_exists='replace', index=False)
pd.DataFrame(products).to_sql('products', engine, if_exists='replace', index=False)
pd.DataFrame(orders).to_sql('orders', engine, if_exists='replace', index=False)
pd.DataFrame(order_items).to_sql('order_items', engine, if_exists='replace', index=False)

print("База данных shop успешно заполнена!")
