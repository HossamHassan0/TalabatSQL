--Q1 Fail_rate per talabat_week
select Talabat_Week, concat(round(count(case when orders.is_successful = 0 then 1 end) * 100 / count(*),2),'%') as Fail_rate
from orders join dimdate 
on cast(orders.order_time as date) = dimdate.iso_date
group by Talabat_Week
order by Talabat_Week


--Q2 Churned Customers 
--Customers whos orders in december
with December_customers as (select distinct(analytical_customer_id)
from orders
where month(order_time) = 12
),

--Cutomers whos order in novermber and not order in december
November_customers as (select distinct(analytical_customer_id)
from orders
where month(order_time) = 11
and analytical_customer_id not in (select analytical_customer_id from December_customers)
),

--No.orders in (sep-oct-nov) for customers whos order in november and not in december 
Customer_orders as (select analytical_customer_id, count(*) as total_orders
from orders 
where analytical_customer_id in (select analytical_customer_id from November_customers) and month(order_time) in (9,10,11)
group by analytical_customer_id
),


--try to count no.of orders in each month to customers segmentation.
Customer_stats as (
    select 
        analytical_customer_id,
        SUM(case when month(order_time) = 9 then 1 else 0 end) as Sep_orders,
        SUM(case when month(order_time) = 10 then 1 else 0 end) as Oct_orders,
        SUM(case when month(order_time) = 11 then 1 else 0 end) as Nov_orders,
        COUNT(*) AS total_orders
    from orders
    where analytical_customer_id IN (select analytical_customer_id from November_customers)
    group by analytical_customer_id
)

select 
    analytical_customer_id,total_orders,Sep_orders,Oct_orders,Nov_orders,
    case 
        when total_orders >= 12 AND Sep_orders > 0 AND Oct_orders > 0 AND Nov_orders > 0 then 'Frequent & Consistent'
        when total_orders >= 12 then 'Frequent'
        when Sep_orders > 0 AND Oct_orders > 0 AND Nov_orders > 0 then 'Consistent'
        else 'Neither'
    end as customer_segment
from 
    Customer_stats
order by 
    customer_segment, analytical_customer_id;



--Comparing each amount of order with the previous and get and et how many customer gross in paid amount
with comparing_amount as (select order_time, analytical_customer_id, gmv_amount_lc,
lag(gmv_amount_lc) over (partition by analytical_customer_id order by order_time) as previous_amount
from orders
)

select analytical_customer_id, count(*) as no_gross_order_amount
from comparing_amount
where previous_amount is not null and previous_amount > gmv_amount_lc
group by analytical_customer_id

--MTD Customers
with orders_per_day as (select cast(order_time as date) as time_of_order, count(distinct analytical_customer_id) as total_customers
from orders
where is_successful = 1
group by cast(order_time as date)
)

select time_of_order, 
sum(total_customers) over (partition by year(time_of_order), month(time_of_order) order by time_of_order 
ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as MTD_customers
from orders_per_day
order by time_of_order

