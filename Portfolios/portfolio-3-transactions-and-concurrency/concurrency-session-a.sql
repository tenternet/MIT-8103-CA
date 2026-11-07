-- Session A, connected to miva_bites_transaction_lab.
-- Run both statements. After the UPDATE returns 39.500, leave this transaction open.
BEGIN;

UPDATE inventory
SET quantity_on_hand = quantity_on_hand - 60.000
WHERE branch_id = 1
  AND ingredient_id = 3
  AND quantity_on_hand >= 60.000
RETURNING branch_id, ingredient_id, quantity_on_hand;
