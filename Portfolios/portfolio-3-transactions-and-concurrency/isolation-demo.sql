-- Open two Query Tool sessions, both connected to miva_bites_transaction_lab.
-- Run the labeled blocks separately and in the order described in README.md.

-- READ COMMITTED, Session A - first read should be 100; leave transaction open.
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT observed_value
FROM portfolio3_isolation_demo
WHERE demo_id = 1;

-- READ COMMITTED, Session B - run after Session A's first read; commits 125.
BEGIN;
UPDATE portfolio3_isolation_demo
SET observed_value = observed_value + 25
WHERE demo_id = 1
RETURNING observed_value;
COMMIT;

-- READ COMMITTED, Session A - run after Session B commits; now reads 125.
SELECT observed_value
FROM portfolio3_isolation_demo
WHERE demo_id = 1;
COMMIT;

-- REPEATABLE READ, Session A - first read is 125; leave transaction open.
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT observed_value
FROM portfolio3_isolation_demo
WHERE demo_id = 1;

-- REPEATABLE READ, Session B - run after Session A's first read; commits 150.
BEGIN;
UPDATE portfolio3_isolation_demo
SET observed_value = observed_value + 25
WHERE demo_id = 1
RETURNING observed_value;
COMMIT;

-- REPEATABLE READ, Session A - still reads 125 until it commits.
SELECT observed_value
FROM portfolio3_isolation_demo
WHERE demo_id = 1;
COMMIT;

-- A new statement after the commit sees 150.
SELECT observed_value
FROM portfolio3_isolation_demo
WHERE demo_id = 1;
