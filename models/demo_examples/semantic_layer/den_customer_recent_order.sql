with customer as (
    select 
        customer_key,
        name as customer_name,
        address,
        nation,
        region,
        phone_number,
        account_balance,
        market_segment
    from {{ ref('dim_customers') }}
),
order_item as (
    select 
        order_item_key,
        order_key,
        order_date,
        customer_key,
        part_key,
        quantity,
        net_item_sales_amount
    from {{ ref('fct_order_items') }}
),
recent_orders as (
    select
        customer_key,
        count(distinct order_key) as recent_orders,
        sum(quantity) as recent_quantity,
        sum(net_item_sales_amount) as recent_sales
    from 
        order_item
    where
        order_date >= current_date() - interval '30 day'
    group by
        customer_key
)

select 
    c.customer_key,
    c.customer_name,
    c.address,
    c.nation,
    c.region,
    c.phone_number,
    c.account_balance,
    c.market_segment,
    r.recent_orders,
    r.recent_quantity,
    r.recent_sales
from
    customer c
    inner join recent_orders r
        on c.customer_key = r.customer_key
order by
    c.customer_key