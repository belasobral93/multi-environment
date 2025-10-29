with s as (
select * from {{ ref('int_streams') }}
),
joined as (
select
date_trunc('day', s.started_at) as stream_date,
s.user_id,
s.title_id,
u.region_bucket,
case when s.seconds_watched >= 120 then true else false end as active_stream,
case when u.signup_type in ('FREE_TRIAL','TRIAL') then 'trial' else 'paid' end as paid_vs_trial,
s.seconds_watched,
(s.seconds_watched::float / 60.0) as engagement_minutes
from s
join {{ ref('stg_users') }} u on u.user_id = s.user_id
)
select * from joined