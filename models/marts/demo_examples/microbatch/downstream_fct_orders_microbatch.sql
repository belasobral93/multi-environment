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

select * from {{ ref('fct_orders_microbatch') }}