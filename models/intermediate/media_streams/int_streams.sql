{{ config(materialized='incremental', unique_key='stream_id') }}


with base as (
    select * from {{ ref('stg_streams') }} where is_bot = false
),

marked as (
    select
        b.*,
        exists(
            select 1 from {{ ref('stg_streams') }} as b2
            where
                b2.user_id = b.user_id
                and b2.title_id = b.title_id
                and b2.started_at > b.started_at
                and b2.started_at <= dateadd('minute', 5, b.started_at)
                and b2.is_bot = false
        ) as has_nearby_dup --identifying and removing duplicate streaming sessions
    from base as b
)

select * from marked where
    has_nearby_dup = false


    {% if is_incremental() %}
        and started_at
        > (
            select coalesce(max(started_at), to_timestamp_ntz('1900-01-01'))
            from {{ this }}
        )
    {% endif %}
