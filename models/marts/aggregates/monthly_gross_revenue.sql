select
    date_trunc(month, fct_order_items.order_date) as order_month,
    sum(fct_order_items.net_item_sales_amount * 1.5) as gross_revenue
from {{ ref('fct_order_items') }}
group by 1
