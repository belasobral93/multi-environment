{{ config(
  materialized='table',
  tags=['analytics', 'streams']
) }}

with
users as (
    select * from {{ ref('stg_users') }}
),

streams as (
    select * from {{ ref('int_streams') }}
),

users as (
    select
        u.user_id,
        upper(coalesce(u.signup_type, 'UNKNOWN')) as signup_type,
        coalesce(u.region_bucket, 'UNKNOWN') as region_bucket
    from users as u
),

streams as (
    select
        s.stream_id,
        s.user_id,
        s.title_id,
        s.started_at,
        coalesce(try_to_number(s.seconds_watched), 0) as seconds_watched,
        coalesce(s.is_bot, false) as is_bot
    from streams as s
),

joined as (
    select
        s.stream_id,
        s.user_id,
        s.title_id,
        s.started_at,
        u.region_bucket,
        u.signup_type,
        s.seconds_watched,
        (s.seconds_watched >= 120 and not s.is_bot) as active_stream,
        case
            when u.signup_type in ('FREE_TRIAL', 'TRIAL') then 'trial'
            else 'paid'
        end as paid_vs_trial,
        (s.seconds_watched::float / 60.0) as engagement_minutes
    from streams as s
    inner join users as u
        on s.user_id = u.user_id
)

select
    stream_id,
    user_id,
    title_id,
    started_at,
    region_bucket,
    signup_type,
    seconds_watched,
    active_stream,
    paid_vs_trial,
    engagement_minutes
from joined
