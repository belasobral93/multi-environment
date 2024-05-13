
{{ config(materialized='view') }}

select
    order_key,
    customer_key,
    status_code,
    total_price,
    order_date
from {{ ref('orders_seed') }}
