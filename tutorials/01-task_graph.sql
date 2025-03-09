CREATE OR REPLACE DATABASE task_graphs_db;
CREATE OR REPLACE SCHEMA task_graphs_sch;

USE DATABASE task_graphs_db;
USE SCHEMA task_graphs_sch;

-- tasks
CREATE OR REPLACE TASK task_a
SCHEDULE = '1 MINUTE'
TASK_AUTO_RETRY_ATTEMPTS = 2
SUSPEND_TASK_AFTER_NUM_FAILURES = 3
USER_TASK_TIMEOUT_MS = 60
CONFIG='{"environment": "production", "path": "/prod_directory/"}'
as
  begin
    call system$set_return_value('task_a successful');
  end;
;

CREATE OR REPLACE TASK task_customer_table
USER_TASK_TIMEOUT_MS = 60
AFTER TASK_A
AS
  BEGIN
    LET VALUE := (SELECT customer_id FROM ref_cust_table
    WHERE cust_name = "Jane Doe";);
    INSERT INTO customer_table VALUES('customer_id',:value);
  END;
;

-- task_product_table: Updates the product table.
--   Runs after the root task completes.
CREATE OR REPLACE TASK task_product_table
USER_TASK_TIMEOUT_MS = 60
AFTER task_a
AS
  BEGIN
    LET VALUE := (SELECT product_id FROM ref_item_table
    WHERE PRODUCT_NAME = "widget";);
    INSERT INTO product_table VALUES('product_id',:value);
  END;
;

CREATE OR REPLACE TASK task_date_time_table
USER_TASK_TIMEOUT_MS = 60
AFTER task_a
AS
  BEGIN
    LET VALUE := (SELECT SYSTEM$TASK_RUNTIME_INFO('CURRENT_TASK_GRAPH_ORIGINAL_SCHEDULED_TIMESTAMP'));
    INSERT INTO date_time_table VALUES('order_date',:value);
  END;
;

CREATE OR REPLACE task task_sales_table
USER_TASK_TIMEOUT_MS = 60
AFTER task_customer_table, task_product_table, task_date_time_table
AS
  BEGIN
    LET VALUE := (SELECT sales_order_id FROM ORDERS);
    JOIN CUSTOMER_TABLE ON orders.customer_id=customer_table.customer_id;
    INSERT INTO sales_table VALUES('sales_order_id',:value);
  END;
;

CREATE OR REPLACE TASK notify_finalizer
USER_TASK_TIMEOUT_MS = 60
FINALIZE = task_a
AS
  DECLARE
      my_root_task_id STRING;
      my_start_time TIMESTAMP_LTZ;
      summary_json STRING;
      summary_html STRING;
  BEGIN
      --- Get root task ID
      my_root_task_id := (CALL SYSTEM$TASK_RUNTIME_INFO('CURRENT_ROOT_TASK_UUID'));

      --- Get root task scheduled time
      my_start_time := (CALL SYSTEM$TASK_RUNTIME_INFO('CURRENT_TASK_GRAPH_ORIGINAL_SCHEDULED_TIMESTAMP'));

      --- Combine all task run infos into one JSON string
      summary_json := (SELECT GET_TASK_GRAPH_RUN_SUMMARY(:my_root_task_id, :my_start_time));

      --- Convert JSON into HTML table
      summary_html := (SELECT HTML_FROM_JSON_TASK_RUNS(:summary_json));


      --- Send HTML to email
      CALL SYSTEM$SEND_EMAIL(
          'email_notification',
          'admin@snowflake.com',
          'notification task run summary',
          :summary_html,
          'text/html');

      --- Set return value for finalizer
      CALL SYSTEM$SET_RETURN_VALUE('✅ Graph run summary sent.');
end;
;

CREATE OR REPLACE FUNCTION get_task_graph_run_summary(my_root_task_id STRING, my_start_time TIMESTAMP_LTZ)
RETURNS STRING
AS
$$
    (SELECT
        ARRAY_AGG(OBJECT_CONSTRUCT(
            'task_name', name,
            'run_status', state,
            'return_value', return_value,
            'started', query_start_time,
            'duration', duration,
            'error_message', error_message
            )
        ) AS GRAPH_RUN_SUMMARY
    FROM
        (SELECT
            NAME,
            CASE
                WHEN STATE = 'SUCCEED' then '🟢 Succeeded'
                WHEN STATE = 'FAILED' then '🔴 Failed'
                WHEN STATE = 'SKIPPED' then '🔵 Skipped'
                WHEN STATE = 'CANCELLED' then '🔘 Cancelled'
            END AS STATE,
            RETURN_VALUE,
            TO_VARCHAR(QUERY_START_TIME, 'YYYY-MM-DD HH24:MI:SS') AS QUERY_START_TIME,
            CONCAT(TIMESTAMPDIFF('seconds', query_start_time, completed_time),
              ' s') AS DURATION,
            ERROR_MESSAGE
        FROM
            TABLE(mweidb.information_schema.task_history(
                ROOT_TASK_ID => my_root_task_id ::STRING,
                SCHEDULED_TIME_RANGE_START => my_start_time,
                SCHEDULED_TIME_RANGE_END => current_timestamp()
                ))
        ORDER BY
            SCHEDULED_TIME)
    )::STRING
$$
;


CREATE OR REPLACE FUNCTION HTML_FROM_JSON_TASK_RUNS(JSON_DATA STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.8'
HANDLER = 'GENERATE_HTML_TABLE'
AS
$$
IMPORT JSON

def GENERATE_HTML_TABLE(JSON_DATA):

    column_widths = ["320px", "120px", "400px", "160px", "80px", "480px"]

    DATA = json.loads(JSON_DATA)

    HTML = f"""
        <img src="https://example.com/logo.jpg"
        alt="Company logo" height="72">
        <p><strong>Task Graph Run Summary</strong>
        <br>Sign in to Snowsight to see more details.</p>
        <table border="1" style="border-color:#DEE3EA"
        cellpadding="5" cellspacing="0">
          <thead>
            <tr>
    """
    headers = ["Task name", "Run status", "Return value", "Started", "Duration", "Error message"]
    for i, header in enumerate(headers):
        HTML += f'<th scope="col" style="text-align:left;
        width: {column_widths[i]}">{header.capitalize()}</th>'

    HTML +="""
            </tr>
    </thead>
    <tbody>
    """

    for ROW_DATA in DATA:
        HTML += "<tr>"
        for header in headers:
            key = header.replace(" ", "_").upper()
            CELL_DATA = ROW_DATA.get(key, "")
            HTML += f'<td style="text-align:left;
            width: {column_widths[headers.index(header)]}">{CELL_DATA}</td>'
        HTML += "</tr>"

    HTML +="""
        </tbody>
    </table>
    """

    return HTML
$$
;