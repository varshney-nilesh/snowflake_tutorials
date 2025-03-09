CREATE OR REPLACE DATABASE stream_db;
CREATE OR REPLACE SCHEMA steam_sch;

USE DATABASE stream_db;
USE SCHEMA steam_sch;


-- Create a table.
CREATE TABLE ndf (
  c1 number
);

-- Create a view that queries the table and
-- also returns the CURRENT_USER and CURRENT_TIMESTAMP values
-- for the query transaction.
CREATE VIEW ndf_v AS
SELECT CURRENT_USER() AS u,
       CURRENT_TIMESTAMP() AS ts,
       c1 AS num
FROM ndf;

-- Create a stream on the view.
CREATE STREAM ndf_s ON VIEW ndf_v;

-- User peter inserts rows into table ndf.
INSERT INTO ndf
VALUES
    (1),
    (2),
    (3);

-- User marie inserts rows into table ndf.
INSERT INTO ndf
VALUES
    (4),
    (5),
    (6);

-- User PETER queries the stream.
-- The stream returns the username for the user.
-- The stream also returns the current timestamp for the query transaction in each row,
-- NOT the timestamp when each row was inserted.
SELECT * FROM ndf_s;

-- +-------+-------------------------------+-----+-----------------+------------------------------------------+
-- | U     | TS                            | NUM | METADATA$ACTION | METADATA$ROW_ID                          |
-- |-------+-------------------------------+-----+-----------------+------------------------------------------|
-- | PETER | 2021-08-16 11:56:33.778 -0700 |   1 | INSERT          | d200504bf3049a7d515214408d9a804fd03b46cd |
-- | PETER | 2021-08-16 11:56:33.778 -0700 |   2 | INSERT          | d0a551cecbee0f9ad2b8a9e81bcc33b15a525a1e |
-- | PETER | 2021-08-16 11:56:33.778 -0700 |   3 | INSERT          | b98ad609fffdd6f00369485a896c52ca93b92b1f |
-- | PETER | 2021-08-16 11:56:33.778 -0700 |   4 | INSERT          | 62d34abc3fac85c037fb9f47f7758f08d025d9ed |
-- | PETER | 2021-08-16 11:56:33.778 -0700 |   5 | INSERT          | e554e6e68293a51d8e69d68e9b6be991453cc901 |
-- | PETER | 2021-08-16 11:56:33.778 -0700 |   6 | INSERT          | f6fa32c498a28b2349d2c6f6be55c30eb1d5310f |
-- +-------+-------------------------------+-----+-----------------+------------------------------------------+

-- User MARIE queries the stream.
-- The stream returns the username for the user
-- and the current timestamp for the query transaction in each row.
SELECT * FROM ndf_s;
-- +-------+-------------------------------+-----+-----------------+------------------------------------------+
-- | U     | TS                            | NUM | METADATA$ACTION | METADATA$ROW_ID                          |
-- |-------+-------------------------------+-----+-----------------+------------------------------------------|
-- | MARIE | 2021-08-16 12:04:21.768 -0700 |   1 | INSERT          | d200504bf3049a7d515214408d9a804fd03b46cd |
-- | MARIE | 2021-08-16 12:04:21.768 -0700 |   2 | INSERT          | d0a551cecbee0f9ad2b8a9e81bcc33b15a525a1e |
-- | MARIE | 2021-08-16 12:04:21.768 -0700 |   3 | INSERT          | b98ad609fffdd6f00369485a896c52ca93b92b1f |
-- | MARIE | 2021-08-16 12:04:21.768 -0700 |   4 | INSERT          | 62d34abc3fac85c037fb9f47f7758f08d025d9ed |
-- | MARIE | 2021-08-16 12:04:21.768 -0700 |   5 | INSERT          | e554e6e68293a51d8e69d68e9b6be991453cc901 |
-- | MARIE | 2021-08-16 12:04:21.768 -0700 |   6 | INSERT          | f6fa32c498a28b2349d2c6f6be55c30eb1d5310f |
-- +-------+-------------------------------+-----+-----------------+------------------------------------------+

drop database stream_db;