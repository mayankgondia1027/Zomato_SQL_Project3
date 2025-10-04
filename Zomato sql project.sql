-- write a query to find the yop 5 most frequent orders dishes by customer called arjun mehta in the last year
select * from 
(select customers.customer_id, 
	   customers.customer_name, 
       orders.order_items,
       count(*),
       dense_rank() over(order by count(*) desc) as rank
from orders join customers 
on orders.customer_id = customers.customer_id
where customers.customer_name ="Arjun Mehta"
and orders.order_id >= current_date - interval 365 day
group by 1,2,3
order by 1,4 desc) as Table1
where rank <= 5;

-- popular time slots identify the time slots during which the most orders are placed based o 2hr interval
-- (23/2) * 2 = 11.5 22 hour 
-- +2 = 24 hour 
select count(*),
       floor(extract(hour from order_time)/2) * 2) as start time,
       floor(extract(hour from order_time)/2) * 2) as start time
from orders 
group by 2,3
order by 3 desc;
       
-- Find the Average Order value per customer who has placed more than 750 orders
-- Return Customer_name, and AOV(Average Order Value)  
select customers.customer_id,
       customers.customer_name,
       avg(orders.total_amount)
from orders join customers 
on orders.customer_id = customers.customer_id
group by 1
having count(order_id)>=750;
       
-- High Value Customers: List the Customers who have spent more than 100K in total on food orders.
-- Return customer_name, and customer_id
select customers.customer_id,
       customers.customer_name,
       sum(orders.total_amount)
from orders join customers 
on orders.customer_id = customers.customer_id
group by 1
having sum(orders.total_amount)>=100000
order by sum(orders.total_amount) desc;

-- Orders without Delivery: Write query to find orders that were placed but not delivered.
-- -Return each restaurant name, city and number of not delivered orders Here we have to 
-- include both cases where orders was not fulfilled and Delivery status is "Not delivered"
select restraunts.restraunts_name,
	   count(*)
from orders left join restraunts
on restraunts.restraunts_id = orders.restraunts_id
left join deliveries
on deliveries.order_id = orders.order_id
where deliveries.delivery_id is null 
group by 1
order by 2 desc;

-- Restaurant Revenue Ranking: Rank restaurants by their total reveneu from the last year. 
-- including their name, Total Revenue, and rank within their city
 with ranking_table as 
 ( select restraunts.city,
         restraunts.restraunts_name,
         sum(orders.total_amount),
         rank() over(partition by restraunts.city order by sum(orders.total_amount) desc) as rank
from orders join restraunts
on orders.restraunt_id = restraunts.restraunt_id
where orders.order_date >= current_date - interval 365 day
group by 1,2)
select * from ranking_table
where rank = 1;
  
-- Most popular dish by City
-- :Identify the Most Popular dish in each city based on the number of orders 
select * from
(select restraunts.city,
       orders.order_items,
       count(order_id),
       rank() over(partition by restraunts.city order by count(order_id) desc) as rank
from orders join restraunts
on restraunts.restraunt_id = orders.restraunt_id
group by 1,2)
as Table1
where rank = 1        

-- Customer Churn
-- Find Customers who have not placed an order in 2024 but did in 2023
select distict customer_id from orders
where extract(year from order_date)=2023
      and 
      customer_id not in 
                         (select distinct customer_id from orders
                         where extract(year from order_date)=2024);

-- Cancelled Rate Comparison:
-- Calculate and Compare the order Cancellation rate for each restaurant between the
-- Currrent year and previous year
with cancel_ratio as
(select orders.restraunts_id,
       count(orders.order_id),
       count(case when deliveries.delivery_id is null then 1 end) as not_delivered
from orders left join deliveries
on orders.order_id = deliveries.order_id
where extract(year from orders.order_date) = 2023
group by orders.restaurant_id),
cancel_ratio_24 as
(select orders.restraunts_id,
       count(orders.order_id),
       count(case when deliveries.delivery_id is null then 1 end) as not_delivered
from orders left join deliveries
on orders.order_id = deliveries.order_id
where extract(year from orders.order_date) = 2024
group by orders.restaurant_id),
last_year_data as
(select restraunt_id,
	   total_orders,
       not_delivered,
       round(not_delivered::numeric/total_orders::numeric * 100,2) as cancel_ratio
from cancel_ratio_23),
current_year_data as
(select restraunt_id,
	   total_orders,
       not_delivered,
       round(not_delivered::numeric/total_orders::numeric * 100,2) as cancel_ratio
from cancel_ratio_24)
select current_year_data.restraunt_id as restaurant_id
       current_year_data.cancel_ratio as current_year_cancel_ration,
       last_year_data..cancel_ratio as current_year_cancel_ratio
from current_year_data join last_year_data
on current_year_data.restraunt_id = last_year_data.restraunt_id;

-- Rider Average Delivery Time 
-- Determine each rider's average delivery time
select orders.order_id,
       orders.order_time,
       deliveries.delivery_time,
       deliveries.rider_id,
       deliveries.delivery_time - orders.order_time as time_difference,
       extract(epoch from (deliveries.delivery_time then interval 1 day 
       else interval 0 day end))/60 as time_difference_inseconds
from orders join deliveries
on orders.order_id = deliveries.order_id
where deliveries.delivery_status = "Delivered";

-- Monthly Restaurant Growth Ratio:
-- Calculate each restaurant's growth ratio based on the total number of delivered orders since its joinin
with growth_ratio as 
(select orders.restraunt_id,
		to_char(orders.order_date, "mm-yy") as month,
        count(orders.order_id) as current_month_orders,
        lag(count(orders.order_id),1) over(partition by orders.restraunt_id order by to_char(orders.order_date, "mm-yy"))as prev_month_orders
from orders join deliveries
on orders.order_id = deliveries.order_id
where deliveries.delivery_status = "Delivered"
group by 1,2
order by 1,2)
select restraunt_id,
       month,
       current_month_orders,
       prev_month_orders,
       round((current_month_orders::numeric-prev_month_orders::numeric)/prev_month_orders::numeric *100,2) as growth_ratio
from growth_ratio;
        
-- Customer Segmentations:
-- (1) Segment Customers into "Gold" or "Silver" groups based on their total spending
-- (2) Compare to the Average order value If a Customer's total spending exceeds AOV 
-- Label them with gold other wise label them as silver Write a Query to Determine each segment's 
-- total number of orders and total revenue
select customer_category,
       sum(total_orders) as total_orders,
       sum(total_spent) as total_revanue
from 
(select customer_id,
		sum(total_amount) as total_spent,
        count(order_id) as total_orders,
        case 
            when sum(total_amount) > (select avg(total_amount) from orders) then "Gold" 
            else "Silver" end as customer_category
from orders group by 1) as table1
GROUP BY 1;

-- Rider Monthly Earning:
-- Calculate each ride's total monthly earnings, assuming they earn 8% of the Delivered Order Amount
select deliveries.rider_id,
       to_char(orders.order_date, "mm-yy") as month,
       sum(total_amount) as revenue,
       sum(total_amount) * 0.08 as riders_earning
from orders join deliveries
on orders.order_id = deliveries.delivery_id
group by 1,2
order by 1,2;

-- Q 14 Rider Rating Analysis: 
-- Find the number of 5 Star. 4 star, and 3 star rating Each riders has. 
-- Riders recieve this rating based on delivery time IF orders are delivered less than 15 Minutes of order recieved time the rider get 5 star rating. 
-- IF they delivery is 15 to 20 Minute then they get a 4 star rating 
-- IF they deliver after 20 Minute they get 3 star rating
select rider_id,
       stars,
       count(*) as total_stars
from
(select rider_id,
        delivery_took_time,
        case
            when delivery_took_time < 15 then "5 star"
            when delivery_took_time < between 15 and 20 then "4 star"
            else "3 star"
		 end as stars
from 
(select orders.order_id,
        orders.order_time,
        deliveries.delivery_time
        extract(epoch from (deliveries.delivery_time - orders.order_time +
        case when deliveries.delivery_time < orders.order_time then interval 1 day
        else interval 0 day end))/60 as delivery_took_time,
        deliveries.rider_id
from orders join deliveries 
on orders.order_id = deliveries.order_id
where delivery_status = "Delivered") as table1
)as table2
group by 1,2
order by 1,3 desc;

-- Order Frequency by Day: 
-- Analyze order fequency per day of the week and identify the peak day for each restaurant
select * from 
(select restaurants.restaurant_name,
        to_char(orders.order_date, "day")as day,
        count(orders.order_id) as total_orders,
        rank() over(partition by restaurants.restaurant_name order by count(orders.order_id) desc) as rank
from orders join restaurants
on orders.restraunts_id = restraunts.restraunts.id
group by 1,2
order by 1,3 desc) as table1
where rank = 1;

-- Customer Lifetime value(CLV)
-- Calculate the Total Revenue Generated by each customer over all their orders
 select orders.customer_id,
        customers.customer_name,
        sum(orders.total_amount) as CLV
from orders join customers
on orders.customer_id = customers.customers_id
group by 1,2;
 
-- Monthly Sales Trends:
-- Identify Sales Trends by Comparing each month's total Sales to the previous months
select extract(year from order_date) as year,
       extract(month from order_date) as month,
       sum(total_amount) as total_sale,
       lag(sum(total_amount),1) over(order by extract(year from order_date), extract(month from order_date)) as prev_month_sale
from orders
group by 1,2;
         
-- Rider Effeciency
-- Evaluate rider Effeciency by determining Average Delivery times and Identifying those with 
-- lowest And highest Average Delivery time
with new_table as 
(select *,
        deliveries.rider_id as riders_id,
        extract(epoch from (deliveries.delivery_time - orders.order_time +
        case when deliveries.delivery_time < orders.order_time then interval 1 day
        else interval 0 day end))/60 as time_deliver
from orders join deliveries
on orders.order_id = deliveries.order_id
where deliveries.delivery_status = "Delivered"),
riders_time as 
(select riders_id,
        avg(time_deliver) as avg_time
from new_table
group by 1)
select min(avg_time),
       max(avg_time)
from riders_time;

-- Order Item Popularity : 
-- Track the Popularity of specific order items over time and identify seasonal demand spike
select order_items,
       seasons,
       count(order_id) as total_orders
from 
(select *, 
        extract(month from order_date) as month,
        case
            when extract(month from order_date) between 4 and 6 then "Spring"
            when extract(month from order_date) between 7 and 9 then "Summer"
            else "Winter"
        end as seasons
from orders)as table1
group by 1,2
order by 1,3 desc;

-- Rank each City based on the Total revenue for last year 2023
select restaurant.city,
       sum(total_amount) as total_revanue,
       rank() over(order by sum(total_amount)desc) as city_rank
from orders join restraunts
on orders.restraunt_id = restraunts.restraunt_id
group by 1;




















