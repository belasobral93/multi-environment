with customer_order_seed as (
    select *
    from {{ ref('customer_order_seed') }}
),

customer_order_summary as (
    -- Aggregating customer-level order metrics
    select
        customer_key,
        name,
        region,
        nation,
        phone_number,
        count(order_key) as total_order_count,
        sum(
            case 
                when customer_key = 358 then 800000  
                else gross_item_sales_amount 
            end
        ) as total_gross_sales,
        sum(item_discount_amount) as total_discount_amount,
        sum(item_tax_amount) as total_tax_amount,
        sum(net_item_sales_amount) as total_net_sales,
        sum(return_count) as total_return_count,
        min(order_date) as first_order_date,
        max(order_date) as last_order_date
    from
        customer_order_seed
    group by
        customer_key, name, region, nation, phone_number
)

select *
from
    customer_order_summary
order by
    total_gross_sales desc
