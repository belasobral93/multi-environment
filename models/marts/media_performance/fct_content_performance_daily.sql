{{ config(materialized='table') }}


with streams as (
    select * from {{ ref('fct_streams') }}
),

titles as (
    select * from {{ ref('stg_titles') }}
),

latest_ratings as (
    select * from {{ ref('int_ratings') }}
),

st_titles as (
    select
        date_trunc('day', s.started_at) as stream_date,
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
        least(
            greatest(
                s.seconds_watched::float / nullif(t.runtime_seconds, 0), 0
            ),
            1
        ) as completion_rate
    from streams as s
    inner join titles as t on s.title_id = t.title_id
),

with_ratings as (
    select
        st.*,
        lr.latest_rating
    from st_titles as st
    left join latest_ratings as lr
        on st.user_id = lr.user_id and st.title_id = lr.title_id
),

agg as (
    select
        stream_date,
        title_id,
        title_name,
        content_type,
        region_bucket,
        paid_vs_trial,
        count_if(active_stream) as streams,
        count(distinct case when active_stream then user_id end)
            as unique_viewers,
        avg(completion_rate) as avg_completion_rate,
        sum(engagement_minutes) as engagement_minutes,
        avg(latest_rating) as avg_latest_rating
    from with_ratings
    group by 1, 2, 3, 4, 5, 6
)

select * from agg
order by stream_date, title_name
