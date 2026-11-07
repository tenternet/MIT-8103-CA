-- Portfolio 2 candidate index for Query 1.
-- Run once in miva_bites_query_lab after capturing the scaled baseline.
-- Equality on branch_id comes first; opened_at supports the date range.
CREATE INDEX idx_pos_order_branch_opened_at
    ON pos_order (branch_id, opened_at);

ANALYZE pos_order;
