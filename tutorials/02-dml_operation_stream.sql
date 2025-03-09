CREATE OR REPLACE DATABASE stream_db;
CREATE OR REPLACE SCHEMA steam_sch;

USE DATABASE stream_db;
USE SCHEMA steam_sch;

-- Create a staging table that stores raw JSON data
CREATE OR REPLACE TABLE data_staging (
  raw variant);

-- Create a stream on the staging table
CREATE OR REPLACE STREAM data_check ON TABLE data_staging;

-- Create 2 production tables to store transformed
-- JSON data in relational columns
CREATE OR REPLACE TABLE data_prod1 (
    id number(8),
    ts TIMESTAMP_TZ
    );

CREATE OR REPLACE TABLE data_prod2 (
    id number(8),
    color VARCHAR,
    num NUMBER
    );

-- Load JSON data into staging table
-- using COPY statement, Snowpipe,
-- or inserts
DELETE FROM data_staging;
INSERT INTO data_staging 
WITH json_data AS (
    SELECT PARSE_JSON(column1) AS data
    FROM VALUES 
        ('{
            "id": 7077,                        
            "x1": "2018-08-14T20:57:01-07:00", 
            "x2": [                            
                {                                
                "y1": "green",                 
                "y2": "35"                     
                }                                
            ]                                  
        }'),
        ('{
            "id": 7078,                        
            "x1": "2018-08-14T21:07:26-07:00", 
            "x2": [                            
                {                                
                "y1": "cyan",                  
                "y2": "107"                    
                }                                
            ]                                  
        }')
)
SELECT * FROM json_data;

SELECT * FROM data_staging;

-- +--------------------------------------+
-- | RAW                                  |
-- |--------------------------------------|
-- | {                                    |
-- |   "id": 7077,                        |
-- |   "x1": "2018-08-14T20:57:01-07:00", |
-- |   "x2": [                            |
-- |     {                                |
-- |       "y1": "green",                 |
-- |       "y2": "35"                     |
-- |     }                                |
-- |   ]                                  |
-- | }                                    |
-- | {                                    |
-- |   "id": 7078,                        |
-- |   "x1": "2018-08-14T21:07:26-07:00", |
-- |   "x2": [                            |
-- |     {                                |
-- |       "y1": "cyan",                  |
-- |       "y2": "107"                    |
-- |     }                                |
-- |   ]                                  |
-- | }                                    |
-- +--------------------------------------+

--  Stream table shows inserted data
SELECT * FROM data_check;

-- +--------------------------------------+-----------------+-------------------+------------------------------------------+
-- | RAW                                  | METADATA$ACTION | METADATA$ISUPDATE | METADATA$ROW_ID                          |
-- |--------------------------------------+-----------------+-------------------|------------------------------------------|
-- | {                                    | INSERT          | False             | 789012e01ef4j3k890123k35mnopqr567890124j |
-- |   "id": 7077,                        |                 |                   |                                          |
-- |   "x1": "2018-08-14T20:57:01-07:00", |                 |                   |                                          |
-- |   "x2": [                            |                 |                   |                                          |
-- |     {                                |                 |                   |                                          |
-- |       "y1": "green",                 |                 |                   |                                          |
-- |       "y2": "35"                     |                 |                   |                                          |
-- |     }                                |                 |                   |                                          |
-- |   ]                                  |                 |                   |                                          |
-- | }                                    |                 |                   |                                          |
-- | {                                    | INSERT          | False             | 765432u89tk3l6y456789012rst7vx678912456k |
-- |   "id": 7078,                        |                 |                   |                                          |
-- |   "x1": "2018-08-14T21:07:26-07:00", |                 |                   |                                          |
-- |   "x2": [                            |                 |                   |                                          |
-- |     {                                |                 |                   |                                          |
-- |       "y1": "cyan",                  |                 |                   |                                          |
-- |       "y2": "107"                    |                 |                   |                                          |
-- |     }                                |                 |                   |                                          |
-- |   ]                                  |                 |                   |                                          |
-- | }                                    |                 |                   |                                          |
-- +--------------------------------------+-----------------+-------------------+------------------------------------------+

-- Access and lock the stream
BEGIN;

-- Transform and copy JSON elements into relational columns
-- in the production tables
INSERT INTO data_prod1 (id, ts)
SELECT t.raw:id, to_timestamp_tz(t.raw:x1)
FROM data_check t
WHERE METADATA$ACTION = 'INSERT';

INSERT INTO data_prod2 (id, color, num)
SELECT t.raw:id, f.value:y1, f.value:y2
FROM data_check t
, lateral flatten(input => raw:x2) f
WHERE METADATA$ACTION = 'INSERT';

-- Commit changes in the stream objects participating in the transaction
COMMIT;

SELECT * FROM data_prod1;

-- +------+---------------------------+
-- |   ID | TS                        |
-- |------+---------------------------|
-- | 7077 | 2018-08-14 20:57:01 -0700 |
-- | 7078 | 2018-08-14 21:07:26 -0700 |
-- +------+---------------------------+

SELECT * FROM data_prod2;

-- +------+-------+-----+
-- |   ID | COLOR | NUM |
-- |------+-------+-----|
-- | 7077 | green |  35 |
-- | 7078 | cyan  | 107 |
-- +------+-------+-----+

SELECT * FROM data_check;

-- +-----+-----------------+-------------------+
-- | RAW | METADATA$ACTION | METADATA$ISUPDATE |
-- |-----+-----------------+-------------------|
-- +-----+-----------------+-------------------+