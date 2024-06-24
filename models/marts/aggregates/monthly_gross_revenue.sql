select 
    date_trunc(MONTH, fct_order_items.order_date) as order_month
    , sum(fct_order_items.DISCOUNTED_PRICE) as gross_revenue
from {{ ref('fct_order_items') }}
group by 1