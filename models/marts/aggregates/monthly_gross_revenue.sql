select 
    date_trunc(MONTH, fct_order_items.order_date) as order_month
    , sum(fct_order_items.gross_item_sales_amount) as gross_revenue
from SA_ISABELA_1_DEV.dev.fct_order_items
group by 1