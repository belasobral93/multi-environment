select
title_id,
title_name,
content_type,
runtime_seconds::number as runtime_seconds,
release_year::number as release_year
from {{ source('media', 'titles') }}