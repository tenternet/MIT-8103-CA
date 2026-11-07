-- Run after Session A commits and Session B rolls back.
SELECT i.quantity_on_hand AS lemons_remaining,
       o.order_id,
       o.status AS order_status,
       COALESCE(SUM(sm.quantity_change), 0.000) AS order_lemons_recorded
FROM inventory AS i
JOIN pos_order AS o
  ON o.branch_id = i.branch_id
 AND o.order_id IN (9001, 9002)
LEFT JOIN stock_movement AS sm
  ON sm.branch_id = o.branch_id
 AND sm.order_id = o.order_id
 AND sm.ingredient_id = i.ingredient_id
 AND sm.movement_type = 'SALE_CONSUMPTION'
WHERE i.branch_id = 1 AND i.ingredient_id = 3
GROUP BY i.quantity_on_hand, o.order_id, o.status
ORDER BY o.order_id;

-- The two values should agree at 39.500 after the one successful consumption.
SELECT i.quantity_on_hand AS inventory_balance,
       SUM(sm.quantity_change) AS movement_ledger_balance,
       i.quantity_on_hand = SUM(sm.quantity_change) AS balances_reconcile
FROM inventory AS i
JOIN stock_movement AS sm
  ON sm.branch_id = i.branch_id
 AND sm.ingredient_id = i.ingredient_id
WHERE i.branch_id = 1 AND i.ingredient_id = 3
GROUP BY i.quantity_on_hand;
