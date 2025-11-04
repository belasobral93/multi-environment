{{ config(
    materialized='incremental',
    unique_key='customer_id',
    incremental_strategy='merge',
    on_schema_change='ignore'  
) }}

with events as (
  select
    customer_id,
    customer_name,
    region,
    cast(updated_at as {{ dbt.type_timestamp() }}) as updated_at,
    row_number() over (partition by customer_id order by cast(updated_at as {{ dbt.type_timestamp() }}) desc) as rn
  from {{ ref('scd3_events') }}
),
src_latest as (
  select
    customer_id,
    customer_name,
    region as incoming_region,
    updated_at as incoming_updated_at
  from events
  where rn = 1
),

tgt as (
  {% if is_incremental() %}
    select
      customer_id,
      customer_name,
      current_region,
      previous_region,
      current_updated_at
    from {{ this }}
  {% else %}
    select
      cast(null as {{ dbt.type_string() }}) as customer_id,
      cast(null as {{ dbt.type_string() }}) as customer_name,
      cast(null as {{ dbt.type_string() }}) as current_region,
      cast(null as {{ dbt.type_string() }}) as previous_region,
      cast(null as {{ dbt.type_timestamp() }}) as current_updated_at
    where 1=0
  {% endif %}
),

staged as (
  select
    s.customer_id,
    s.customer_name,
    s.incoming_region,
    s.incoming_updated_at,
    t.current_region,
    t.previous_region,
    t.current_updated_at
  from src_latest s
  left join tgt t using (customer_id)
)

select
  customer_id,
  customer_name,

  case
    when current_region is null then incoming_region
    when incoming_region is distinct from current_region then incoming_region
    else current_region
  end as current_region,

  case
    when current_region is null then cast(null as {{ dbt.type_string() }})
    when incoming_region is distinct from current_region then current_region
    else previous_region
  end as previous_region,

  case
    when current_region is null then incoming_updated_at
    when incoming_region is distinct from current_region then incoming_updated_at
    else current_updated_at
  end as current_updated_at
from staged
