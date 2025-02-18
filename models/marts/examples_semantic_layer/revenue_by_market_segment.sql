SELECT
    c.market_segment AS customer__market_segment,
    SUM(o.net_item_sales_amount) AS revenue,
    SUM(o.net_item_sales_amount)/COUNT(DISTINCT o.order_key) AS avg_order_value
FROM {{ ref('fct_orders') }} AS o
INNER JOIN {{ ref('dim_customers') }} AS c ON o.customer_key = c.customer_key
WHERE o.status_code = 'F'
GROUP BY c.market_segment
