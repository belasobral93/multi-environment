{{
    config(
        materialized='incremental',
        unique_key='order_id',
    )
}}

select order_id as order_id, customer_id as customer_id, status as status, order_date as order_date, modified_at as modified_at
from {{ ref('raw_orders') }}

{% if is_incremental() %}
    where modified_at > (select max(modified_at) from {{ this }}) 
{% endif %}