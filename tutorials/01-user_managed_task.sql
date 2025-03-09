CREATE OR REPLACE DATABASE stream_db;
CREATE OR REPLACE SCHEMA stream_sch;

USE DATABASE stream_db;
USE SCHEMA stream_sch;

CREATE OR REPLACE TABLE order_returns (
    customer_id INTEGER,
    return_total FLOAT,
    return_date DATE DEFAULT current_date()
);

CREATE OR REPLACE TABLE orders (
    customer_id INTEGER,
    order_total FLOAT,
    order_date DATE DEFAULT current_date()
);

CREATE OR REPLACE TABLE customer_activity (
    customer_id INTEGER,
    transactions_total FLOAT,
    transactions_date DATE,
    transactions_type VARCHAR
);

CREATE OR REPLACE STREAM order_returns_stream ON TABLE order_returns;

CREATE OR REPLACE STREAM orders_stream ON TABLE orders;

DESC STREAM order_returns_stream;
DESC STREAM orders_stream;

CREATE OR REPLACE TASK order_task
    WAREHOUSE = 'compute_wh'
    SCHEDULE = '1 minute'
    WHEN SYSTEM$STREAM_HAS_DATA('order_returns_stream')
    OR   SYSTEM$STREAM_HAS_DATA('orders_stream')
  AS
    INSERT INTO customer_activity
    SELECT customer_id, return_total, return_date, 'return'
    FROM order_returns_stream
    UNION ALL
    SELECT customer_id, order_total, order_date, 'order'
    FROM orders_stream;

DESC TASK order_task;

INSERT INTO orders VALUES(1, 200.98, CURRENT_DATE),(2, 96.56, CURRENT_DATE);

SELECT * FROM orders_stream;

ALTER TASK order_task RESUME;

SELECT * FROM customer_activity;

INSERT INTO orders VALUES(1, 200.98, CURRENT_DATE),(2, 96.56, CURRENT_DATE);

INSERT INTO order_returns VALUES(3, 19.74, CURRENT_DATE);

SELECT * FROM customer_activity;


-- tear down
DROP DATABASE IF EXISTS stream_db;

select * from snowflake.account_usage.task_versions WHERE database_name != 'SNOWFLAKE';

select * from snowflake.account_usage.task_history WHERE database_name != 'SNOWFLAKE';
