with customer as (
    select * from {{ ref('dim_customers') }}
),
order_item as (
    select * from {{ ref('fct_order_items') }}
),

order_summary as (
    select
        order_item.customer_key,
        count(distinct order_item.order_key) as total_orders,
        sum(order_item.quantity) as total_quantity,
        sum(order_item.net_item_sales_amount) as total_sales
    from 
        order_item
    group by
        order_item.customer_key
)

select 
    customer.customer_key,
    customer.name as customer_name,
    customer.address,
    customer.nation,
    customer.region,
    customer.phone_number,
    customer.account_balance,
    customer.market_segment,
    order_summary.total_orders,
    order_summary.total_quantity,
    order_summary.total_sales
from
    customer
    inner join order_summary
        on customer.customer_key = order_summary.customer_key
order by
    customer.customer_key
