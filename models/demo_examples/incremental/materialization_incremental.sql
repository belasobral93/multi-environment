{{
    config(
        materialized='incremental',
        unique_key='order_id',
        on_schema_change='sync_all_columns'
    )
}}

select
    raw.order_id,
    raw.customer_id,
    raw.status,
    raw.order_date,
    raw.modified_at,
    raw.platform
from {{ ref('raw_orders') }} as raw

{% if is_incremental() %}
    where
        raw.modified_at > (select max(this.modified_at) from {{ this }} as this)
{% endif %}
