{{
    config(
        schema='sales'
    )
}}

select
    order_key,
    sum(fct_order_items.net_item_sales_amount) * 1.5 as gross_revenues
from {{ ref('fct_order_items') }}
group by 1
