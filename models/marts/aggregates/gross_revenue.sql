select
    order_key,
    sum(fct_order_items.net_item_sales_amount) as gross_revenue
from {{ ref('fct_order_items') }}
group by 1
