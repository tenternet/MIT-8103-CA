# Portfolio 2: Query Processing and Optimisation

**Status:** Query results, small-data and scaled plans, and one candidate-index comparison captured and documented.

## Goal

Use realistic Miva Bites questions to study how PostgreSQL plans and runs queries, then compare a baseline plan with a suitable index. The work will include query text, results, execution plans, and a short explanation of what changed.

## Workload

The first three read-only reports are in [`workload.sql`](workload.sql):

1. Successful net payments by order date for one branch, with successful refunds subtracted.
2. Top menu items by units sold and line sales value.
3. Branch ingredients at or below their reorder level.

The first baseline plan exercise is in [`baseline-plan.sql`](baseline-plan.sql). It runs Query 1 under `EXPLAIN (ANALYZE, BUFFERS)` before we add Portfolio 2 indexes.

## Step-by-step plan

1. Run each report against the existing seeded `miva_bites_ca_practice` database and confirm the result makes sense.
2. Review the query plan with `EXPLAIN` and `EXPLAIN (ANALYZE, BUFFERS)`.
3. Create a separate query-lab database and add reproducible sample volume with [`scale-data.sql`](scale-data.sql). Keep the validated Portfolio 1 database unchanged.
4. Record the scaled baseline plan, add the candidate index from [`index-tuning.sql`](index-tuning.sql), and rerun the same plan for comparison.
5. Save the SQL, result evidence, screenshots, and a brief explanation of the trade-offs. **Complete.**

The seed database is intentionally small, so its timings are only for learning how to read a plan. We will use the separate query-lab database for performance comparisons; an index can make a tiny table slower because PostgreSQL may prefer a sequential scan.

## Evidence

Result screenshots are saved in [`Evidence/portfolio2`](../../Evidence/portfolio2/): [net payments](../../Evidence/portfolio2/query-1-net-payments-ikeja.png), [top menu items](../../Evidence/portfolio2/query-2-top-menu-items.png), and [low-stock report](../../Evidence/portfolio2/query-3-low-stock-no-results.png). Both small-data plan sections ([top](../../Evidence/portfolio2/query-1-baseline-plan-top.png), [bottom](../../Evidence/portfolio2/query-1-baseline-plan-bottom.png)) and scaled plan sections ([top](../../Evidence/portfolio2/query-lab-baseline-plan-top.png), [bottom](../../Evidence/portfolio2/query-lab-baseline-plan-bottom.png)) are captured, along with the [successful query-lab data load](../../Evidence/portfolio2/query-lab-scale-data-success.png), [index creation](../../Evidence/portfolio2/index-tuning-success.png), and indexed plan sections ([top](../../Evidence/portfolio2/query-lab-indexed-plan-top.png), [bottom](../../Evidence/portfolio2/query-lab-indexed-plan-bottom.png)).

## Initial Query 1 plan notes

On the small seed database, PostgreSQL used the existing `uq_pos_order_branch_order` index to find branch 1 orders, `branch_pkey` to look up the branch, and `uq_payment_order_payment` to find payments by order. It then used nested-loop joins, sorted two payment rows, and grouped them into one result. The date and cancelled-status conditions appear as filters on the order rows. The plan reports 0.672 ms planning time and 0.382 ms execution time, with 6 shared-buffer hits. These measurements describe this tiny sample only; they are not a performance claim.

Performance work uses the separate `miva_bites_query_lab` database. It was prepared by running Portfolio 1's `schema.sql`, `seed.sql`, then `scale-data.sql` once. The data script adds 10,000 completed orders, their order items, successful payments and partial refunds, plus matching inventory receipts and sale-consumption movements. It also runs `ANALYZE` so PostgreSQL has statistics for planning the larger workload.

## Scaled Query 1 baseline

On the 10,000-order query lab, the plan scans 10,002 `pos_order` rows and retains 841 for branch 1, the 30-day date range, and the non-cancelled status. It scans 10,203 payment rows and filters out the one failed attempt. PostgreSQL builds a hash join on `order_id`, looks up the branch through `branch_pkey`, groups the joined rows into 29 dates, and sorts the result.

The plan reports 4.694 ms planning time, 14.338 ms execution time, and 368 shared-buffer hits. The small seeded database took 0.382 ms for this query. The different row counts explain why these times are not a direct index comparison; this scaled plan is the baseline for testing the `(branch_id, opened_at)` index.

## Candidate-index comparison

The index in `index-tuning.sql` changes the `pos_order` access path from a sequential scan to a bitmap heap scan using `idx_pos_order_branch_opened_at`. The index condition now applies both `branch_id = 1` and the 30-day `opened_at` range. The cancelled-status check remains a row filter. PostgreSQL still scans `payment` and uses a hash join because almost every payment row is successful, so an index on payment status would not eliminate much work.

| Measure | Scaled baseline | With candidate index |
|---|---:|---:|
| Execution time | 14.338 ms | 8.053 ms |
| `pos_order` access | Sequential scan; 10,002 rows scanned, 841 retained | Bitmap heap scan; 841 rows matched the index condition |
| `payment` access | Sequential scan; 10,203 rows scanned, 1 failed attempt filtered | Same sequential scan |
| Result groups | 29 dates | 29 dates |

Execution time fell by 6.285 ms (about 43.8%) in these local runs. The indexed run had 216 shared-buffer hits and 3 reads, compared with 368 shared-buffer hits in the baseline. Treat this as a result for this dataset and run, not a guarantee for other data sizes or machines.
