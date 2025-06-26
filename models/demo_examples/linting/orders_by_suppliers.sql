with supplier_orders as (
    select 
        fct_order_items.supplier_key,
        count(distinct fct_order_items.order_key) as total_orders
    FROM {{ ref('fct_order_items') }}
    group by fct_order_items.supplier_key 
)

select 
    dim_suppliers.supplier_name,
    coalesce(supplier_orders.total_orders, 0) as total_orders
from {{ ref('dim_suppliers') }}
left join supplier_orders
    on dim_suppliers.supplier_key = supplier_orders.supplier_key
order by 1


-- reference group by/order should be numerical
-- keywords should be lowercase 