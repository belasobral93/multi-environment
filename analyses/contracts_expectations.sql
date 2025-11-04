select
order_month,
gross_revenue,
gross_revenue >= 1000000 and gross_revenue <= 30000000 as expression
from SA_ISABELA_1_DEV.dbt_isobral.monthly_gross_revenue
where not(expression = true)
    

