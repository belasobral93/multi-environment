select
user_id,
country,
upper(signup_type) as signup_type,
to_date(signup_date) as signup_date,
case when country in ('US','CA','MX','BR') then 'AMER'
when country in ('GB','FR','DE','IT','ES','NL') then 'EMEA'
else 'APJ' end as region_bucket
from {{ source('media', 'users') }}