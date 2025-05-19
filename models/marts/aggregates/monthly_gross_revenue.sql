select
    date_trunc(month, fct_order_items.order_date) as order_month,
    sum(fct_order_items.net_item_sales_amount * 1.5) as gross_revenue,
    sum(fct_order_items.net_item_sales_amount * 1.5) 
        - lag(sum(fct_order_items.net_item_sales_amount * 1.5)) 
        over (order by date_trunc(month, fct_order_items.order_date)) as revenue_growth
from {{ ref('fct_order_items') }}
group by 1