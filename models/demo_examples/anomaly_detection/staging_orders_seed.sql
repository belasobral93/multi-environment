WITH seed_data AS (
    select * from {{ ref('orders_seed') }}
),

max_date AS (
    SELECT MAX(order_date::DATE) as max_date
    FROM seed_data
),

updated_dates AS (
    SELECT 
        order_key,
        customer_key,
        status_code,
        total_price,
        DATEADD(day, DATEDIFF(day, max_date, CURRENT_DATE() - INTERVAL '1 days'), order_date::DATE) AS new_order_date
    FROM 
        seed_data, max_date
)

SELECT *
FROM updated_dates
