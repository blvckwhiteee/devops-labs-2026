# Docker Compose


Через Compose підіймаються сервіси:
- `db` - MariaDB
- `migrate` - одноразовий контейнер для міграції схеми БД
- `web` - застосунок `mywebapp`
- `nginx` - reverse proxy

Сервіси працюють в окремій мережі `lab1_internal`.
Дані MariaDB зберігаються в named volume `mariadb_data`.


## Запуск
Переходимо в корінь проєкту та піднімаємо застосунок:

```powershell
docker compose up --build -d
```

Перевірити статус сервісів:

```powershell
docker compose ps
```

Перевірити головну сторінку:

```powershell
Invoke-WebRequest http://127.0.0.1 -UseBasicParsing | Select-Object -ExpandProperty StatusCode
```

Очікуване повернення: `200`

Перевірка роботи nginx:

```powershell
Invoke-WebRequest http://127.0.0.1/health/alive -UseBasicParsing
```

Очікуване повернення: `404`

## Перевірка БД

Створити тестову нотатку:

```powershell
Invoke-WebRequest http://127.0.0.1/notes -Method POST -ContentType "application/json" -Body '{"title":"test_note","content":"api test"}' -UseBasicParsing | Select-Object -ExpandProperty Content
```

Перевіряємо, що нотатка читається:

```powershell
Invoke-WebRequest http://127.0.0.1/notes/1 -UseBasicParsing | Select-Object -ExpandProperty Content
```

Перезапускаємо застосунок:

```powershell
docker compose down
docker compose up -d
```

Повторно перевіряємо запис:

```powershell
Invoke-WebRequest http://127.0.0.1/notes/1 -UseBasicParsing | Select-Object -ExpandProperty Content
```

Якщо запис лишився, значить volume налаштований коректно.


