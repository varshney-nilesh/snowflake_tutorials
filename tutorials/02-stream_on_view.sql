CREATE OR REPLACE DATABASE stream_db;
CREATE OR REPLACE SCHEMA steam_sch;

USE DATABASE stream_db;
USE SCHEMA steam_sch;

-- Create multiple tables with matching column values.
CREATE TABLE birds (
  id number,
  common varchar(100),
  class varchar(100)
);

CREATE TABLE sightings (
  d date,
  loc varchar(100),
  b_id number,
  c number
);

-- Create a view that queries the tables with a join.
CREATE VIEW bird_sightings AS
SELECT b.id AS id,
       b.common AS common_name,
       b.class AS classification,
       s.d AS date,
       s.loc AS location,
       s.c AS count
FROM birds b
INNER JOIN sightings s ON b.id = s.b_id;

-- Create a stream on the view.
CREATE STREAM bird_sightings_s ON VIEW bird_sightings;

-- Insert values into the tables.
INSERT INTO birds
VALUES
    (1,'Scarlet Tanager','P. olivacea'),
    (14,'Mallard','A. platyrhynchos'),
    (48,'Spotted Sandpiper','A. macularius'),
    (92,'Great Blue Heron','A. herodias');

INSERT INTO sightings
VALUES
    (current_date(),'Gibson Island',1,4),
    (current_date(),'Lake Los Pajaro',14,12),
    (current_date(),'Lake Los Pajaro',92,12),
    (current_date(),'Gibson Island',14,21),
    (current_date(),'Gibson Island',92,5);

-- Query the stream.
-- The stream displays a record for each row added to the view.
SELECT * FROM bird_sightings_s;

-- +----+------------------+------------------+------------+-----------------+-------+------------------------------------------+-----------------+-------------------+
-- | ID | COMMON_NAME      | CLASSIFICATION   | DATE       | LOCATION        | COUNT | METADATA$ROW_ID                          | METADATA$ACTION | METADATA$ISUPDATE |
-- |----+------------------+------------------+------------+-----------------+-------+------------------------------------------+-----------------+-------------------|
-- |  1 | Scarlet Tanager  | P. olivacea      | 2021-09-07 | Gibson Island   |     4 | a2522b47726ac2a922104c8e2f668d065ff6fcd0 | INSERT          | False             |
-- | 14 | Mallard          | A. platyrhynchos | 2021-09-07 | Lake Los Pajaro |    12 | fceb4ad5cb6d2df2865d0f572b8a2aa98f240b70 | INSERT          | False             |
-- | 92 | Great Blue Heron | A. herodias      | 2021-09-07 | Lake Los Pajaro |    12 | 0db99176fe8bd50749b2b48fb2befab416ff9272 | INSERT          | False             |
-- | 14 | Mallard          | A. platyrhynchos | 2021-09-07 | Gibson Island   |    21 | 2e94ef3a33e52ba5de5d816dc41c60fedf9cb1eb | INSERT          | False             |
-- | 92 | Great Blue Heron | A. herodias      | 2021-09-07 | Gibson Island   |     5 | a1df477ac8e388e1cf0ada77e9097c6effa346a7 | INSERT          | False             |
-- +----+------------------+------------------+------------+-----------------+-------+------------------------------------------+-----------------+-------------------+

-- Consume the stream records in a DML statement (INSERT, MERGE, etc.).
CREATE TABLE bird_sightings_prod AS SELECT * FROM bird_sightings WHERE 1 = 2;
SELECT ID, common_name, classification, date, location, count FROM bird_sightings_s WHERE METADATA$ACTION='INSERT' AND METADATA$ISUPDATE = FALSE;
INSERT INTO bird_sightings_prod SELECT ID, common_name, classification, date, location, count FROM bird_sightings_s WHERE METADATA$ACTION='INSERT' AND METADATA$ISUPDATE = FALSE;
-- Query the stream.
-- The stream is empty.
SELECT * FROM bird_sightings_s;
-- +----+-------------+----------------+------+----------+-------+-----------------+-----------------+-------------------+
-- | ID | COMMON_NAME | CLASSIFICATION | DATE | LOCATION | COUNT | METADATA$ROW_ID | METADATA$ACTION | METADATA$ISUPDATE |
-- |----+-------------+----------------+------+----------+-------+-----------------+-----------------+-------------------|
-- +----+-------------+----------------+------+----------+-------+-----------------+-----------------+-------------------+
SELECT * FROM bird_sightings_prod;
-- Delete a row from the birds table.
DELETE FROM birds WHERE id = 14;

-- Query the stream.
-- The stream displays two records for the single DELETE operation.
SELECT * FROM bird_sightings_s;

-- +----+-------------+------------------+------------+-----------------+-------+------------------------------------------+-----------------+-------------------+
-- | ID | COMMON_NAME | CLASSIFICATION   | DATE       | LOCATION        | COUNT | METADATA$ROW_ID                          | METADATA$ACTION | METADATA$ISUPDATE |
-- |----+-------------+------------------+------------+-----------------+-------+------------------------------------------+-----------------+-------------------|
-- | 14 | Mallard     | A. platyrhynchos | 2021-09-07 | Lake Los Pajaro |    12 | 83c22ff4be80d65a2e9776df0e35b22079cb4430 | DELETE          | False             |
-- | 14 | Mallard     | A. platyrhynchos | 2021-09-07 | Gibson Island   |    21 | e29cfae8c3c7d261ed903c2303f61e4d49c01ba1 | DELETE          | False             |
-- +----+-------------+------------------+------------+-----------------+-------+------------------------------------------+-----------------+-------------------+
SELECT * FROM bird_sightings;