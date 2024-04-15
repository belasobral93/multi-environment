{{
    config(
        materialized='incremental',
        unique_key='order_id',
        on_schema_change='fail'
    )
}}

select order_id as order_id, customer_id as customer_id, status as status, order_date as order_date, modified_at as modified_at, platform as platform
from {{ ref('raw_orders') }} as raw

{% if is_incremental() %}
    where raw.modified_at > (select max(this.modified_at) from {{ this }} as this) 
{% endif %}