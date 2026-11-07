-- Portfolio 2 starter workload for the Miva Bites POS database.
-- These SELECT statements are read-only. Run them one at a time in pgAdmin
-- while connected to the seeded miva_bites_ca_practice database.

-- Query 1: net successful payments for branch 1 over the last 30 days.
-- Successful refunds are subtracted from successful payment attempts.
SELECT
    b.name AS branch,
    o.opened_at::date AS order_date,
    SUM(
        CASE
            WHEN p.payment_type = 'PAYMENT' THEN p.amount
            WHEN p.payment_type = 'REFUND' THEN -p.amount
        END
    )::NUMERIC(12, 2) AS net_collected
FROM pos_order AS o
JOIN branch AS b
    ON b.branch_id = o.branch_id
JOIN payment AS p
    ON p.order_id = o.order_id
WHERE o.branch_id = 1
  AND o.opened_at >= CURRENT_DATE - INTERVAL '30 days'
  AND o.status <> 'CANCELLED'
  AND p.status = 'SUCCESSFUL'
GROUP BY b.name, o.opened_at::date
ORDER BY order_date;

-- Query 2: top menu items by units sold and sale-time line value.
SELECT
    mi.menu_item_id,
    mi.name AS menu_item,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.quantity * oi.sale_unit_price)::NUMERIC(12, 2) AS line_sales_value
FROM order_item AS oi
JOIN pos_order AS o
    ON o.order_id = oi.order_id
JOIN menu_item AS mi
    ON mi.menu_item_id = oi.menu_item_id
WHERE o.status <> 'CANCELLED'
  AND oi.kitchen_status <> 'CANCELLED'
GROUP BY mi.menu_item_id, mi.name
ORDER BY units_sold DESC, line_sales_value DESC
LIMIT 10;

-- Query 3: ingredients that need attention at each branch.
SELECT
    b.name AS branch,
    i.name AS ingredient,
    inv.quantity_on_hand,
    inv.reorder_level,
    i.unit
FROM inventory AS inv
JOIN branch AS b
    ON b.branch_id = inv.branch_id
JOIN ingredient AS i
    ON i.ingredient_id = inv.ingredient_id
WHERE inv.quantity_on_hand <= inv.reorder_level
ORDER BY b.name, i.name;
