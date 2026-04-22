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
