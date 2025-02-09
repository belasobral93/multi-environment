

with supplier_aggregated as (

    select
        region,
        nation,
        count(distinct supplier_key) as supplier_count,
        sum(account_balance) as total_account_balance
    from
        {{ ref('dim_suppliers') }}  -- when using defer, will reference the prod version of upstream model
    group by
        region,
        nation

)

select * from supplier_aggregated
