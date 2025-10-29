{{ config(materialized='table') }}


with streams as (
select * from {{ ref('fct_streams_daily') }}
),
titles as (
select * from {{ ref('stg_titles') }}
),
latest_ratings as (
select * from {{ ref('int_ratings') }}
),
-- join #1: streams → titles
st_titles as (
select
s.stream_date,
s.user_id,
t.title_id,
t.title_name,
t.content_type,
t.runtime_seconds,
s.region_bucket,
s.paid_vs_trial,
s.active_stream,
s.seconds_watched,
s.engagement_minutes,
least(greatest(s.seconds_watched::float / nullif(t.runtime_seconds,0), 0), 1) as completion_rate
from streams s
join titles t on t.title_id = s.title_id
),
-- join #2: bring in latest rating per user/title
with_ratings as (
select st.*,
lr.latest_rating
from st_titles st
left join latest_ratings lr
on lr.user_id = st.user_id and lr.title_id = st.title_id
),
-- join #3: streams ↔ users happens earlier in fct_streams_daily
agg as (
select
stream_date,
title_id,
title_name,
content_type,
region_bucket,
paid_vs_trial,
count_if(active_stream) as streams,
count(distinct case when active_stream then user_id end) as unique_viewers,
avg(completion_rate) as avg_completion_rate,
sum(engagement_minutes) as engagement_minutes,
avg(latest_rating) as avg_latest_rating
from with_ratings
group by 1,2,3,4,5,6
)
select * from agg
order by stream_date, title_name