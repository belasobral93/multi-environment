with
raw_streams as (
    select
        s.stream_id,
        s.user_id,
        s.title_id,
        to_timestamp_ntz(s.started_at)                          as started_at,
        coalesce(s.seconds_watched, 0)::number                  as seconds_watched,
        coalesce(s.is_bot, false)::boolean                      as is_bot 
    from ANALYTICS.DBT_BELASOBRAL93.streams s
),
raw_users as (
    select
        u.user_id,
        u.country,
        upper(coalesce(u.signup_type, ''))                       as signup_type,
        to_date(u.signup_date)                                   as signup_date
    from ANALYTICS.DBT_BELASOBRAL93.users u
),
raw_titles as (
    select
        t.title_id,
        t.title_name,
        t.content_type,
        coalesce(t.runtime_seconds, 0)::number                  as runtime_seconds,
        coalesce(t.release_year, 0)::number                     as release_year
    from ANALYTICS.DBT_BELASOBRAL93.titles t
),
raw_ratings as (
    select
        r.rating_id,
        r.user_id,
        r.title_id,
        coalesce(r.rating_value, null)::number                  as rating_value,
        to_timestamp_ntz(r.rated_at)                            as rated_at
    from ANALYTICS.DBT_BELASOBRAL93.ratings r
),
streams_no_bots as (
    select
        rs.stream_id,
        rs.user_id,
        rs.title_id,
        rs.started_at,
        rs.seconds_watched,
        rs.is_bot,
        case when rs.is_bot then 'BOT' else 'HUMAN' end as bot_label  
    from raw_streams rs
    where coalesce(rs.is_bot, false) = false
),

mark_possible_dups as (
    select
        a.stream_id,
        a.user_id,
        a.title_id,
        a.started_at,
        a.seconds_watched,
        a.is_bot,
        exists (
            select 1
            from streams_no_bots b
            where b.user_id   = a.user_id
              and b.title_id  = a.title_id
              and b.started_at >  a.started_at
              and b.started_at <= dateadd('minute', 5, a.started_at)
              and coalesce(b.is_bot, false) = false
        ) as has_nearby_dup
    from streams_no_bots a
),
streams_deduped as (
    select
        md.stream_id,
        md.user_id,
        md.title_id,
        md.started_at,
        md.seconds_watched,
        md.is_bot
    from mark_possible_dups md
    where md.has_nearby_dup = false --raw de-duping in same file as business logic
),

streams_with_users as (
    select
        s.stream_id,
        s.user_id,
        s.title_id,
        s.started_at,
        s.seconds_watched,
        s.is_bot,
        case
            when ru.country in ('US','CA','MX','BR') then 'AMER'
            when ru.country in ('GB','FR','DE','IT','ES','NL') then 'EMEA'
            else 'APJ'
        end as region_bucket,
        case
            when upper(ru.signup_type) in ('FREE_TRIAL','TRIAL') then 'trial'
            when upper(ru.signup_type) not in ('FREE_TRIAL','TRIAL') then 'paid'
            else 'paid'
        end as paid_vs_trial, --business logic in same file as de-dupe 
        ru.country as country_passthrough,
        ru.signup_date as signup_date_passthrough
    from streams_deduped s
    join raw_users ru
      on ru.user_id = s.user_id
),

streams_users_titles as (
    select
        sut.stream_id,
        sut.user_id,
        sut.title_id,
        sut.started_at,
        sut.seconds_watched,
        sut.is_bot,
        sut.region_bucket,
        sut.paid_vs_trial,
        coalesce(rt.title_name, 'UNKNOWN')                          as title_name,
        coalesce(rt.content_type, 'unknown')                        as content_type,
        nullif(rt.runtime_seconds, 0)                               as runtime_seconds,
        coalesce(rt.release_year, 0)                                as release_year
    from streams_with_users sut
    join raw_titles rt
      on rt.title_id = sut.title_id
),

ratings_latest as (
    select user_id, title_id, rating_value as latest_rating
    from (
        select
            rr.user_id,
            rr.title_id,
            rr.rating_value,
            rr.rated_at,
            row_number() over (partition by rr.user_id, rr.title_id
                               order by rr.rated_at desc) as rn
        from raw_ratings rr
    ) z
    qualify rn = 1
),
streams_all_cols as (
    select
        sut.*,
        rl.latest_rating
    from streams_users_titles sut
    left join ratings_latest rl
      on rl.user_id = sut.user_id
     and rl.title_id = sut.title_id
),

per_stream_metrics as (
    select
        sac.stream_id,
        sac.user_id,
        sac.title_id,
        sac.title_name,
        sac.content_type,
        sac.runtime_seconds,
        sac.release_year,
        sac.region_bucket,
        sac.paid_vs_trial,
        sac.started_at,
        sac.seconds_watched,
        sac.latest_rating,
        case
           when coalesce(sac.seconds_watched, 0)::number >= 120
                and coalesce(sac.is_bot, false) = false
           then true else false
        end as active_stream, -- active stream defined here 
        least(
          greatest(
            coalesce(sac.seconds_watched,0)::float / nullif(sac.runtime_seconds, 0),
            0.0
          ),
          1.0
        ) as completion_rate,
        (coalesce(sac.seconds_watched,0)::float / 60.0) as engagement_minutes
    from streams_all_cols sac
),

per_stream_metrics_again as (
    select
        psm.stream_id,
        psm.user_id,
        psm.title_id,
        psm.title_name,
        psm.content_type,
        psm.runtime_seconds,
        psm.release_year,
        psm.region_bucket,
        psm.paid_vs_trial,
        psm.started_at,
        psm.seconds_watched,
        psm.latest_rating,
        case
          when psm.active_stream then true
          else iff(psm.seconds_watched >= 120, true, false)
        end as active_stream, -- active stream defined here x2
        least(
          greatest(
            coalesce(psm.seconds_watched::float, 0.0)
            / nullif(coalesce(psm.runtime_seconds,0), 0),
            0.0
          ),
          1.0
        ) as completion_rate,
        (coalesce(psm.seconds_watched,0)::float / 60.0) as engagement_minutes
    from per_stream_metrics psm
),

stream_dates as (
    select
      psma.stream_id,
      date_trunc('day', psma.started_at) as stream_date
    from per_stream_metrics_again psma
),
with_dates as (
    select
        psma.stream_id,
        sd.stream_date,
        psma.user_id,
        psma.title_id,
        psma.title_name,
        psma.content_type,
        psma.runtime_seconds,
        psma.region_bucket,
        psma.paid_vs_trial,
        psma.active_stream,
        psma.seconds_watched,
        psma.engagement_minutes,
        psma.completion_rate,
        psma.latest_rating
    from per_stream_metrics_again psma
    join stream_dates sd
      on sd.stream_id = psma.stream_id
)

select
    wd.stream_date                                           as stream_date,
    wd.title_id                                              as title_id,
    wd.title_name                                            as title_name,
    wd.content_type                                          as content_type,
    wd.region_bucket                                         as region_bucket,
    wd.paid_vs_trial                                         as paid_vs_trial,

    sum(case when wd.active_stream then 1 else 0 end)        as streams,

    count(distinct case when wd.active_stream then wd.user_id end)
                                                            as unique_viewers,

    avg(wd.completion_rate)                                  as avg_completion_rate,

    sum(wd.engagement_minutes)                               as engagement_minutes,

    avg(wd.latest_rating)                                    as avg_latest_rating
from with_dates wd
group by
    wd.stream_date,
    wd.title_id,
    wd.title_name,
    wd.content_type,
    wd.region_bucket,
    wd.paid_vs_trial
order by
    wd.stream_date,
    wd.title_name

