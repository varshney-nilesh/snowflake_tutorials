
CREATE OR REPLACE DATABASE stream_db;
CREATE OR REPLACE STREAM steam_sch;

USE DATABASE stream_db;
USE SCHEMA steam_sch;

-- Create a table to store the names and fees paid by members of a gym
CREATE OR REPLACE TABLE members (
  id number(8) NOT NULL,
  name varchar(255) default NULL,
  fee number(3) NULL
);

-- Create a stream to track changes to date in the MEMBERS table
CREATE OR REPLACE STREAM member_check ON TABLE members;

SHOW STREAMS like '%member_check%';

-- Create a table to store the dates when gym members joined
CREATE OR REPLACE TABLE signup (
  id number(8),
  dt DATE
  );

INSERT INTO members (id,name,fee)
VALUES
(1,'Joe',0),
(2,'Jane',0),
(3,'George',0),
(4,'Betty',0),
(5,'Sally',0);


INSERT INTO signup
VALUES
(1,'2018-01-01'),
(2,'2018-02-15'),
(3,'2018-05-01'),
(4,'2018-07-16'),
(5,'2018-08-21');

-- The stream records the inserted rows
SELECT * FROM member_check;

-- Apply a $90 fee to members who joined the gym after a free trial period ended:
MERGE INTO members m
  USING (
    SELECT id, dt
    FROM signup s
    WHERE DATEDIFF(day, '2018-08-15'::date, s.dt::DATE) < -30) s
    ON m.id = s.id
  WHEN MATCHED THEN UPDATE SET m.fee = 90;

SELECT * FROM members;

-- Create a table to store member details in production
CREATE OR REPLACE TABLE members_prod (
  id number(8) NOT NULL,
  name varchar(255) default NULL,
  fee number(3) NULL
);

-- Insert the first batch of stream data into the production table
INSERT INTO members_prod(id,name,fee) SELECT id, name, fee FROM member_check WHERE METADATA$ACTION = 'INSERT';

-- The stream position is advanced
select * from member_check;

-- Access and lock the stream
BEGIN;
-- Increase the fee paid by paying members
UPDATE members SET fee = fee + 15 where fee > 0;

-- These changes are not visible because the change interval of the stream object starts at the current offset and ends at the current
-- transactional time point, which is the beginning time of the transaction
SELECT * FROM member_check;

-- Commit changes
COMMIT;

-- The changes surface now because the stream object uses the current transactional time as the end point of the change interval that now
-- includes the changes in the source table
SELECT * FROM member_check;
