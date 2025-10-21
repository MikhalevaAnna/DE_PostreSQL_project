#  Работа с PostgreSQL 

## Описание:

Реализовать систему отслеживания изменений пользователей. </br>
Логировать все изменения пользователей (`name`, `email`, `role`). </br>
Хранить аудит изменений в отдельной таблице `users_audit`. </br>
Раз в день экспортировать только свежие изменения в **CSV**. </br>
Автоматизировать экспорт с помощью **pg_cron** (его нужно будет только установить (_CREATE EXTENSION IF NOT EXISTS_)). </br>

## Реализация:

1. Создала функцию логирования **log_user_changes()** в таблицу `users_audit` изменений по трем полям `name`, `email`, `role`, которые происходили в таблице `users`. </br>
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
4. Создала функцию, `export_todays_audit_data()` которая достает только свежие данные (за сегодняшний день) и сохраняет их в образе **Docker** по пути `/tmp/users_audit_export_`, а далее указывается та дата, за которую этот **csv** был создан.
5. Установила планировщик **pg_cron** на 3:00 ночи. </br>

```
SELECT cron.schedule(
    'export-daily-audit-data',    -- имя задания
    '0 3 * * *',                  -- расписание: каждый день в 3:00
    'SELECT export_todays_audit_data();'  -- выполняемая функция
);
```

6. В результате проделанной работы в **Docker-контейнере** получила файл, в котором отражены изменения таблицы `users`: <br>

```
(.venv) PS D:\DE\DE_PostreSQL_project> docker exec -it postgres_db bash
root@1ef39497c311:/# ls /tmp/users_audit_*.csv
/tmp/users_audit_export_20251021.csv
root@1ef39497c311:/# cat /tmp/users_audit_export_20251021.csv
id,user_id,changed_at,changed_by,field_changed,old_value,new_value
1,1,2025-10-21 11:55:51.44834,user,name,Иван Иванов,Иван Сидоров
2,1,2025-10-21 11:55:51.44834,user,role,user,admin
3,2,2025-10-21 11:55:51.44834,user,email,petr@example.com,petr_p@example.com
4,3,2025-10-21 11:55:51.44834,user,name,Андрей Сидоров,Сергей Иванов
5,3,2025-10-21 11:55:51.44834,user,email,sidorov@example.com,ivanov_s@example.com
6,3,2025-10-21 11:55:51.44834,user,role,manager,user
```

7. В репозитории представлен **sql-скрипт** с тестовыми данными, при запуске котрого выполняются действия для получения итогового результата, который отражен в пункте 6.                   
