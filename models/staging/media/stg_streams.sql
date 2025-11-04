select
stream_id,
user_id,
title_id,
to_timestamp_ntz(started_at) as started_at,
coalesce(seconds_watched,0)::number as seconds_watched,
coalesce(is_bot,false)::boolean as is_bot
from {{ source('media', 'streams') }}