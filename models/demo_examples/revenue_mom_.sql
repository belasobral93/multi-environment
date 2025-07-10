with monthly_revenue as (
    select
        date_trunc('month', order_date) as order_month,
        sum(net_item_sales_amount) as gross_revenue
    from {{ ref('fct_order_items') }}
    group by 1
),

revenue_lag as (
    select
        order_month,
        gross_revenue,
        lag(gross_revenue) over (order by order_month) as previous_month_revenue
    from monthly_revenue
)

select
    order_month,
    gross_revenue,
    previous_month_revenue,
    case
        when previous_month_revenue is not null and previous_month_revenue != 0
            then
                (gross_revenue - previous_month_revenue)
                / previous_month_revenue
    end as growth_rate
from revenue_lag