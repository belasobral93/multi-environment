select user_id, title_id, rating_value as latest_rating
from (
select *, row_number() over (partition by user_id, title_id order by rated_at desc) as rn
from {{ ref('stg_ratings') }}
) x
qualify rn = 1