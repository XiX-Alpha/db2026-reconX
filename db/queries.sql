-- ============================================================================
-- TICKET-ADV010 — VWAP per instrument per day (window function)
-- ============================================================================
-- SELECT DISTINCT
--     t.instrument_id,
--     t.trade_date,
--     SUM(t.price * t.quantity) OVER (PARTITION BY t.instrument_id, t.trade_date)
--         / NULLIF(SUM(t.quantity) OVER (PARTITION BY t.instrument_id, t.trade_date), 0)
--             AS vwap
-- FROM trades t
-- WHERE t.deleted_at IS NULL
--   AND t.asset_class = 'EQUITY'
-- ORDER BY t.trade_date DESC, t.instrument_id;
SELECT
    t.id,
    t.trade_ref,
    t.instrument_id,
    i.symbol,
    t.trade_date,
    t.quantity,
    t.price,
    (t.price * t.quantity) AS notional,

    SUM(t.price * t.quantity) OVER (
        PARTITION BY t.instrument_id, t.trade_date
    ) /
    NULLIF(
        SUM(t.quantity) OVER (
            PARTITION BY t.instrument_id, t.trade_date
        ),
        0
    ) AS vwap

FROM trades t
JOIN instruments i
    ON i.id = t.instrument_id
ORDER BY
    t.trade_date,
    t.instrument_id,
    t.id;

-- ============================================================================
-- TICKET-ADV011 — Recursive CTE: trade lifecycle (execution -> settlement
--                -> recon_break -> resolution)
-- ============================================================================
WITH RECURSIVE trade_lifecycle AS (

    -- Base case: Execution
    SELECT
        t.id AS trade_id,
        t.trade_ref,
        1 AS stage,
        'EXECUTION' AS stage_name,
        t.trade_date AS event_at,
        'COMPLETED' AS event_status
    FROM trades t

    UNION ALL

    -- Recursive step
    SELECT
        tl.trade_id,
        tl.trade_ref,
        tl.stage + 1,
        next_event.stage_name,
        next_event.event_at,
        next_event.event_status
    FROM trade_lifecycle tl

    JOIN LATERAL (

        SELECT
            'CONFIRMATION' AS stage_name,
            c.confirmed_at AS event_at,
            c.status AS event_status
        FROM confirmations c
        WHERE tl.stage = 1
          AND c.trade_id = tl.trade_id

        UNION ALL

        SELECT
            'SETTLEMENT',
            s.settled_at,
            s.status
        FROM settlements s
        WHERE tl.stage = 2
          AND s.trade_id = tl.trade_id

        UNION ALL

        SELECT
            'RECON_BREAK',
            rb.detected_at,
            rb.status
        FROM recon_breaks rb
        WHERE tl.stage = 3
          AND rb.trade_id = tl.trade_id

        UNION ALL

        SELECT
            'RESOLUTION',
            r.resolved_at,
            r.status
        FROM resolutions r
        WHERE tl.stage = 4
          AND r.trade_id = tl.trade_id

    ) AS next_event ON TRUE

    WHERE tl.stage < 5
)

SELECT
    trade_id,
    trade_ref,
    stage,
    stage_name,
    event_at,
    event_status
FROM trade_lifecycle
ORDER BY trade_id, stage;

-- ============================================================================
-- ADV008 — REFRESH the daily-summary materialised view (concurrent so it can
--         run while the dashboard is reading it)
-- ============================================================================
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_recon_summary;


-- ============================================================================
-- ADV009 — JSONB lookup: which instruments have sector = 'Banking'?
-- ============================================================================
SELECT id, symbol, metadata
FROM instruments
WHERE metadata @> '{"sector":"Banking"}'::jsonb;
