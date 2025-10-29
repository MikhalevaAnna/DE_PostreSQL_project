-- Создается таблица пользователей users
DROP TABLE IF EXISTS users;
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name TEXT,
    email TEXT,
    role TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создается таблица логирования изменений users_audit
DROP TABLE IF EXISTS users_audit;
CREATE TABLE users_audit (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by TEXT,
    field_changed TEXT,
    old_value TEXT,
    new_value TEXT
);

-- Создается функция для логирования изменений в таблицу users_audit по трем полям: name, email, role, которые происходили в таблице users
DROP FUNCTION IF EXISTS log_user_changes();
CREATE FUNCTION log_user_changes()
RETURNS TRIGGER AS $$
BEGIN
     
    IF TG_OP = 'UPDATE' THEN
    -- Логируются изменения поля name
        IF OLD.name IS DISTINCT FROM NEW.name THEN
            INSERT INTO users_audit (user_id, field_changed, old_value, new_value, changed_by)
            VALUES (NEW.id, 'name', OLD.name, NEW.name, CURRENT_USER);
        END IF;

    -- Логируются изменения поля email
        IF OLD.email IS DISTINCT FROM NEW.email THEN
            INSERT INTO users_audit (user_id, field_changed, old_value, new_value, changed_by)
            VALUES (NEW.id, 'email', OLD.email, NEW.email, CURRENT_USER);
        END IF;

    -- Логируются изменения поля role
        IF OLD.role IS DISTINCT FROM NEW.role THEN
            INSERT INTO users_audit (user_id, field_changed, old_value, new_value, changed_by)
            VALUES (NEW.id, 'role', OLD.role, NEW.role, CURRENT_USER);
        END IF;

        RETURN NEW;
    ELSE
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Создается триггер, который будет вызывать функцию при обновлении таблицы users
DROP TRIGGER IF EXISTS users_audit_trigger ON users;
CREATE TRIGGER users_audit_trigger
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION log_user_changes();


-- Устанавливается расширение pg_cron
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Проверяется, что расширение установлено
SELECT * FROM pg_extension WHERE extname = 'pg_cron';

-- Создается функция для экспорта свежих данных за сегодня в docker в папку /tmp/
DROP FUNCTION IF EXISTS export_yesterdays_audit_data();
CREATE FUNCTION export_yesterdays_audit_data()
RETURNS TEXT AS $$
DECLARE
    export_file_path TEXT;
    export_date TEXT;
    result_text TEXT;
    yesterday_date DATE;
BEGIN
    yesterday_date := CURRENT_DATE - INTERVAL '1 day';
    -- Формируется дата для имени файла
    export_date := to_char(yesterday_date, 'YYYYMMDD');
    export_file_path := '/tmp/users_audit_export_' || export_date || '.csv';

    -- Экспортируются данные за сегодняшний день в CSV
    EXECUTE format(
        'COPY (
            SELECT
                ua.user_id,
                ua.field_changed,
                ua.old_value,
                ua.new_value,
                ua.changed_by,
                ua.changed_at
            FROM users_audit ua
            WHERE ua.changed_at >= %L::timestamp
            AND ua.changed_at < %L::timestamp + INTERVAL ''1 day''
            ORDER BY ua.changed_at
        ) TO %L WITH CSV HEADER',
        yesterday_date,
        yesterday_date,
        export_file_path
    );

    result_text := 'Данные успешно экспортированы в файл: ' || export_file_path;
    RETURN result_text;

EXCEPTION
    WHEN OTHERS THEN
        RETURN 'Ошибка при экспорте: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Создается задание в pg_cron для ежедневного выполнения в 3:00 ночи
SELECT cron.schedule(
    'export-yesterdays-audit-data',    -- имя задания
    '0 3 * * *',                  -- расписание: каждый день в 3:00
    'SELECT export_yesterdays_audit_data();'  -- выполняемая функция
);

-- Проверяется, что задание создано
SELECT * FROM cron.job;

-- Вставляются тестовые данные в таблицу users
INSERT INTO users (id, name, email, role) VALUES
(1, 'Иван Иванов', 'ivan@example.com', 'user'),
(2, 'Петр Петров', 'petr@example.com', 'admin'),
(3, 'Андрей Сидоров', 'sidorov@example.com', 'manager');

-- Обновляются данные в таблице users для тестирования триггера
UPDATE users SET name = 'Иван Сидоров', role = 'admin' WHERE id = 1;
UPDATE users SET email = 'petr_p@example.com' WHERE id = 2;
UPDATE users SET name='Сергей Иванов', email = 'ivanov_s@example.com', role ='user' WHERE id = 3;

-- Проверяется, что записи в таблице users изменились
SELECT * FROM users;

-- Проверяются записи в таблице с историческими данными
SELECT * FROM users_audit;

-- Тестируется функция экспорта вручную
SELECT export_yesterdays_audit_data();

-- Проверяется задание cron
SELECT * FROM cron.job;

-- Проверяется, что задание cron выполнено
SELECT * FROM cron.job_run_details
