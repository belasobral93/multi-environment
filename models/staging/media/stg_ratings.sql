select
rating_id,
user_id,
title_id,
rating_value::number as rating_value,
to_timestamp_ntz(rated_at) as rated_at
from {{ source('media', 'ratings') }}