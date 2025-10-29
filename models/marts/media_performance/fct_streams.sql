{{ config(materialized='table') }}

with s as (
    select * from {{ ref('int_streams') }}
),

joined as (
    select
        s.stream_id,
        s.user_id,
        s.title_id,
        s.started_at,
        u.region_bucket,
        u.signup_type,
        coalesce(s.seconds_watched, 0) as seconds_watched,
        coalesce (coalesce(s.seconds_watched, 0) >= 120
        and coalesce(s.is_bot, false) = false, false) as active_stream,
        case
            when u.signup_type in ('FREE_TRIAL', 'TRIAL') then 'trial'
            else 'paid'
        end as paid_vs_trial,
        (s.seconds_watched::float / 60.0) as engagement_minutes
    from s
    inner join {{ ref('stg_users') }} as u
        on s.user_id = u.user_id
)

select * from joined
