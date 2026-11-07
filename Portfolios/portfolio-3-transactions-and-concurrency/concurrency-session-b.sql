-- Session B, connected to miva_bites_transaction_lab.
-- Start this while Session A's transaction is still open. The UPDATE waits.
-- After Session A commits, PostgreSQL should return zero rows here.
BEGIN;

UPDATE inventory
SET quantity_on_hand = quantity_on_hand - 60.000
WHERE branch_id = 1
  AND ingredient_id = 3
  AND quantity_on_hand >= 60.000
RETURNING branch_id, ingredient_id, quantity_on_hand;

-- After the zero-row result, run ROLLBACK in this Session B tab.
