with

s1 as (
  select
      s.stream_id,
      cast(s.user_id as varchar)  as user_id,
      cast(s.title_id as varchar) as title_id,

      case
        when try_to_number(to_varchar(s.started_at)) is not null then
          to_timestamp_ntz(
            iff(
              try_to_number(to_varchar(s.started_at)) > 1000000000000,
              try_to_number(to_varchar(s.started_at)) / 1000,   -- ms → sec
              try_to_number(to_varchar(s.started_at))           -- sec
            )
          )
        else
          try_to_timestamp_ntz(to_varchar(s.started_at))        -- ISO-ish strings
      end as started_at,

      greatest(coalesce(try_to_number(s.seconds_watched),0),0)::number as seconds_watched,
      iff(
        upper(trim(cast(s.is_bot as varchar))) in ('1','T','TRUE','Y','YES'), TRUE,
        iff(upper(trim(cast(s.is_bot as varchar))) in ('0','F','FALSE','N','NO'), FALSE, FALSE)
      ) AS is_bot
  from ANALYTICS.DBT_BELASOBRAL93.streams s
),




streams_kinda_clean as (
  select
    s1.*,
    case when s1.is_bot then 'BOT' else 'HUMAN' end as bot_label
  from s1
  where coalesce(s1.is_bot, false) = false
),

u1 as (
  select
    cast(u.user_id as varchar)                                           as user_id,
    upper(nullif(trim(u.country), ''))                                    as country,
    upper(coalesce(nullif(trim(u.signup_type), ''), 'UNKNOWN'))           as signup_type,
    coalesce(try_to_date(u.signup_date), try_to_date(cast(u.signup_date as varchar))) as signup_date
  from ANALYTICS.DBT_BELASOBRAL93.users u
),

t1 as (
  select
    cast(t.title_id as varchar)                                  as title_id,
    nullif(trim(t.title_name), '')                               as title_name,
    lower(coalesce(trim(t.content_type), 'unknown'))             as content_type,
    coalesce(try_to_number(t.runtime_seconds), 0)                as runtime_seconds,
    coalesce(try_to_number(t.release_year), 0)                   as release_year
  from ANALYTICS.DBT_BELASOBRAL93.titles t
),

r1 as (
  select
    cast(r.user_id as varchar)  as user_id,
    cast(r.title_id as varchar) as title_id,
    try_to_number(r.rating_value) as rating_value,

    case
      when try_to_number(to_varchar(r.rated_at)) is not null then
        to_timestamp_ntz(
          iff(
            try_to_number(to_varchar(r.rated_at)) > 1000000000000,
            try_to_number(to_varchar(r.rated_at)) / 1000,
            try_to_number(to_varchar(r.rated_at))
          )
        )
      else
        try_to_timestamp_ntz(to_varchar(r.rated_at))
    end as rated_at
  from ANALYTICS.DBT_BELASOBRAL93.ratings r
),

ratings_latest as (
  select user_id, title_id, rating_value as latest_rating
  from (
    select
      user_id, title_id, rating_value, rated_at,
      row_number() over (partition by user_id, title_id order by rated_at desc nulls last) as rn
    from r1
  )
  qualify rn = 1
),

-- ad hoc de-dupe: drop streams if there’s another within 5 min for same user/title
-- (re-checks is_bot even though we filtered already)
dedup as (
  select
    a.stream_id,
    a.user_id,
    a.title_id,
    a.started_at,
    a.seconds_watched,
    a.is_bot,
    exists (
      select 1
      from streams_kinda_clean b
      where b.user_id = a.user_id
        and b.title_id = a.title_id
        and b.started_at > a.started_at
        and b.started_at <= dateadd(minute, 5, a.started_at)
        and coalesce(b.is_bot, false) = false
    ) as has_nearby_dup
  from streams_kinda_clean a
),

streams_deduped as (
  select *
  from dedup
  where has_nearby_dup = false
),

-- mash users in; compute region and paid vs trial inconsistently in two places
streams_users as (
  select
    sd.stream_id,
    sd.user_id,
    sd.title_id,
    sd.started_at,
    sd.seconds_watched,
    sd.is_bot,

    case
      when u1.country in ('US','CA','MX','BR') then 'AMER'
      when u1.country in ('GB','FR','DE','IT','ES','NL') then 'EMEA'
      when u1.country is null then 'UNKNOWN'
      else 'APJ'
    end as region_bucket,

    case
      when u1.signup_type in ('FREE_TRIAL','TRIAL') then 'trial'
      when u1.signup_type is null then 'paid'   
      else 'paid'
    end as paid_vs_trial,

    u1.country as country_passthrough,
    u1.signup_date as signup_date_passthrough
  from streams_deduped sd
  left join u1 on u1.user_id = sd.user_id
),

streams_users_titles as (
  select
    s.stream_id,
    s.user_id,
    s.title_id,
    s.started_at,
    s.seconds_watched,
    s.is_bot,
    s.region_bucket,
    s.paid_vs_trial,

    coalesce(t.title_name, 'UNKNOWN') as title_name,
    coalesce(nullif(t.content_type, ''), 'unknown') as content_type,
    nullif(t.runtime_seconds, 0) as runtime_seconds,
    coalesce(t.release_year, 0) as release_year
  from streams_users s
  left join t1 t
    on t.title_id = s.title_id
),

streams_plus as (
  select
    sut.*,
    rl.latest_rating
  from streams_users_titles sut
  left join ratings_latest rl
    on rl.user_id = sut.user_id
   and rl.title_id = sut.title_id
),

-- compute “active” and rates twice in slightly different ways
calc1 as (
  select
    p.*,
    case
      when coalesce(p.seconds_watched, 0) >= 120 and coalesce(p.is_bot, false) = false
      then true else false end as active_stream,
    least(
      greatest(
        coalesce(p.seconds_watched,0)::float / nullif(p.runtime_seconds, 0),
        0.0
      ),
      1.0
    ) as completion_rate,
    (coalesce(p.seconds_watched,0)::float / 60.0) as engagement_minutes
  from streams_plus p
),

calc2 as (
  select
    c1.stream_id,
    c1.user_id,
    c1.title_id,
    c1.title_name,
    c1.content_type,
    c1.runtime_seconds,
    c1.release_year,
    c1.region_bucket,
    c1.paid_vs_trial,
    c1.started_at,
    c1.seconds_watched,
    c1.latest_rating,
    -- redundant active calc that falls back to seconds_watched if runtime is null
    case
      when c1.active_stream then true
      else iff(coalesce(c1.seconds_watched,0) >= 120, true, false)
    end as active_stream,
    -- re-compute completion_rate with slightly different null guards
    least(
      greatest(
        coalesce(c1.seconds_watched::float, 0)
        / nullif(coalesce(c1.runtime_seconds,0), 0),
        0.0
      ),
      1.0
    ) as completion_rate,
    (coalesce(c1.seconds_watched,0)::float / 60.0) as engagement_minutes
  from calc1 c1
),

d as (
  select
    stream_id,
    date_trunc('day', started_at) as stream_date
  from calc2
),

with_dates as (
  select
    c2.stream_id,
    d.stream_date,
    c2.user_id,
    c2.title_id,
    coalesce(c2.title_name, 'UNKNOWN') as title_name,
    c2.content_type,
    c2.runtime_seconds,
    -- (change the region/paid calc again)
    case when c2.region_bucket is null then 'UNKNOWN' else c2.region_bucket end as region_bucket,
    case when c2.paid_vs_trial is null then 'paid' else c2.paid_vs_trial end as paid_vs_trial,
    c2.active_stream,
    c2.seconds_watched,
    c2.engagement_minutes,
    c2.completion_rate,
    c2.latest_rating
  from calc2 c2
  join d   on d.stream_id = c2.stream_id
)

select
    wd.stream_date                                           as stream_date,
    wd.title_id                                              as title_id,
    wd.title_name                                            as title_name,
    wd.content_type                                          as content_type,
    wd.region_bucket                                         as region_bucket,
    wd.paid_vs_trial                                         as paid_vs_trial,

    sum(case when wd.active_stream then 1 else 0 end)        as streams,
    count(distinct case when wd.active_stream then wd.user_id end) as unique_viewers,

    avg(wd.completion_rate)                                  as avg_completion_rate,
    sum(wd.engagement_minutes)                               as engagement_minutes,
    avg(wd.latest_rating)                                    as avg_latest_rating
from with_dates wd
group by
    wd.stream_date, wd.title_id, wd.title_name, wd.content_type, wd.region_bucket, wd.paid_vs_trial
order by
    wd.stream_date, wd.title_name

