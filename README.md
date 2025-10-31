#  Работа с PostgreSQL 

## Описание:

Необходимо реализовать систему отслеживания изменений пользователей. </br>
Логировать все изменения пользователей (`name`, `email`, `role`). </br>
Хранить аудит изменений в отдельной таблице `users_audit`. </br>
Раз в день экспортировать только свежие изменения в **CSV**. </br>
Автоматизировать экспорт с помощью **pg_cron** (его нужно будет только установить (_CREATE EXTENSION IF NOT EXISTS_)). </br>

## Реализация:

1. Создала функцию **log_user_changes()** для логирования изменений в таблицу `users_audit` по трем полям `name`, `email`, `role`, которые происходили в таблице `users`. Фиксируется также кем и когда вносились эти изменения.</br>
#### Схемы таблиц: 
```
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name TEXT,
    email TEXT,
    role TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```
```
CREATE TABLE users_audit (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by TEXT,
    field_changed TEXT,
    old_value TEXT,
    new_value TEXT
);
```
2. Создала **trigger** `users_audit_trigger` на таблицу `users`. </br>
3. Установила расширение **pg_cron** `CREATE EXTENSION IF NOT EXISTS pg_cron;`. </br>
4. Создала функцию, `export_yesterdays_audit_data()` которая достает только свежие данные (за вчерашний день) и сохраняет их в образе **Docker** по пути `/tmp/users_audit_export_`, а далее, в названии файла, указывается та дата, за которую этот **csv** был создан.
5. Установила планировщик **pg_cron** на 3:00 ночи. </br>

```
SELECT cron.schedule(
    'export_yesterdays_audit_data',    -- имя задания
    '0 3 * * *',                  -- расписание: каждый день в 3:00
    'SELECT export_yesterdays_audit_data();'  -- выполняемая функция
);
```

6. В результате проделанной работы в **Docker-контейнере** получила файл, в котором отражены изменения таблицы `users`. <br>
Команды и содержимое файла прилагаю, в качестве примера, за 2025-10-28, скрипты запускались 2025-10-29 в 03:00: </br>
```
PS D:\DE\DE_GIT\DE_PostreSQL_project> docker exec -it postgres_db bash
root@1ef39497c311:/# ls /tmp/users_audit_*.csv
/tmp/users_audit_export_20251029_0300.csv
root@1ef39497c311:/# cat /tmp/users_audit_export_20251029_0300.csv
user_id,field_changed,old_value,new_value,changed_by,changed_at
1,name,Иван Иванов,Иван Сидоров,user,2025-10-28 13:14:21.487375
1,role,user,admin,user,2025-10-28 13:14:21.487375
2,email,petr@example.com,petr_p@example.com,user,2025-10-28 13:14:21.487375
3,name,Андрей Сидоров,Сергей Иванов,user,2025-10-28 13:14:21.487375
3,email,sidorov@example.com,ivanov_s@example.com,user,2025-10-28 13:14:21.487375
3,role,manager,user,user,2025-10-28 13:14:21.487375
```

7. В репозитории представлен **sql-скрипт** с тестовыми данными, при запуске котрого выполняются действия для получения итогового результата, подобного тому, который отражен в пункте 6, только с другими датами.                   
