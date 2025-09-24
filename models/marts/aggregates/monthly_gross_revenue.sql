select 
    date_trunc(MONTH, order_date) as order_month
    , sum(NET_ITEM_SALES_AMOUNT) as gross_revenue
from {{ ref('fct_order_items') }}
group by 1
order by 2 desc