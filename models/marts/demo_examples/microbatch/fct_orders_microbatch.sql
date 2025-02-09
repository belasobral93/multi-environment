{{
    config(
        materialized='incremental',
        incremental_strategy='microbatch',
        event_time='order_time',
        batch_size='day',
        lookback=3,
        begin='2025-01-11',
        full_refresh=False,
        tags = ['finance']
    )
}}

with orders as (

    select * from {{ ref('stg_tpch_orders') }}

),

order_item as (

    select * from {{ ref('order_items') }}

),

order_item_summary as (

    select
        order_key,
        sum(gross_item_sales_amount) as gross_item_sales_amount,
        sum(item_discount_amount) as item_discount_amount,
        sum(item_tax_amount) as item_tax_amount,
        sum(net_item_sales_amount) as net_item_sales_amount,
        count_if(return_flag = true) as return_count
    from order_item
    group by
        1
),

final as (

    select

        orders.order_key,
        orders.order_date,
        orders.order_time,
        orders.customer_key,
        orders.status_code,
        orders.priority_code,
        orders.clerk_name,
        orders.ship_priority,
        1 as order_count,
        order_item_summary.return_count,
        order_item_summary.item_discount_amount,
        order_item_summary.item_tax_amount,
        order_item_summary.net_item_sales_amount,
        case
            when order_date = '2024-09-21' then null
            else gross_item_sales_amount
        end as gross_item_sales_amount
    from
        orders
        inner join order_item_summary
            on orders.order_key = order_item_summary.order_key
)

select *
from
    final

order by
    order_date DESC