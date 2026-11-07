-- Portfolio 2 baseline plan for Query 1, before adding Portfolio 2 indexes.
-- EXPLAIN ANALYZE runs the read-only SELECT and reports its actual plan/time.
EXPLAIN (ANALYZE, BUFFERS)
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
