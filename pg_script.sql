-- 1. Вывести все уникальные бренды, у которых есть хотя бы один продукт со стандартной стоимостью выше 1500 долларов,
-- и суммарными продажами не менее 1000 единиц.

select distinct p.brand
from product p 
where p.standard_cost > 1500
	and p.product_id in (
		select oi.product_id 
		from order_items oi
		group by oi.product_id 
		having sum(oi.quantity) >= 1000
	);


-- 2. Для каждого дня в диапазоне с 2017-04-01 по 2017-04-09 включительно вывести количество подтвержденных онлайн-заказов
-- и количество уникальных клиентов, совершивших эти заказы.

select 
     o.order_date
    ,count(o.order_id) as order_count
    ,count(distinct o.customer_id) as customers_count
from orders o 
where o.online_order is true
	and o.order_status = 'Approved'
	and o.order_date between '2017-04-01' and '2017-04-09'
group by o.order_date;


-- 3. Вывести профессии для клиентов, которые: находятся в сфере 'IT' И их профессия начинается с Senior,
-- находятся в сфере 'Financial Services' и их профессия начинается с Lead. При этом для обоих пунктов учесть,
-- что возраст клиентов должен быть старше 35 лет. Использовать UNION ALL для объединения 2 пунктов

select 
	 c.first_name
	,c.last_name
	,c.job_title 
from customer c 
where c.job_industry_category = 'IT'
	and c.job_title like 'Senior%'
	and c.dob is not null
	and age(current_date, c.dob) > interval '35 years'

union all

select 
	 c2.first_name
	,c2.last_name
	,c2.job_title 
from customer c2
where c2.job_industry_category = 'Financial Services'
	and c2.job_title like 'Lead%'
	and c2.dob is not null
	and age(current_date, c2.dob) > interval '35 years';

 
 -- 4. Вывести бренды, которые были куплены клиентами из сферы Financial Services, но не были куплены клиентами из сферы IT.
 
select distinct p.brand 
from orders o 
join customer c on o.customer_id = c.customer_id 
join order_items oi on o.order_id = oi.order_id 
join product p on oi.product_id = p.product_id 
where c.job_industry_category = 'Financial Services'

except

select distinct p.brand 
from orders o 
join customer c on o.customer_id = c.customer_id 
join order_items oi on o.order_id = oi.order_id 
join product p on oi.product_id = p.product_id 
where c.job_industry_category = 'IT';


-- 5. Вывести 10 клиентов (ID, имя, фамилия), которые совершили наибольшее количество онлайн-заказов
-- (в штуках) брендов Giant Bicycles, Norco Bicycles, Trek Bicycles, при условии,
-- что они активны и имеют оценку имущества (property_valuation) выше среднего по их штату

select 
	 c.customer_id
	,c.first_name
	,c.last_name
	,count(distinct o.order_id) as orders_count
from customer c 
join orders o on c.customer_id = o.customer_id 
join order_items oi on o.order_id = oi.order_id 
join product p on oi.product_id = p.product_id 
where o.online_order is true 
	and p.brand in ('Giant Bicycles', 'Norco Bicycles', 'Trek Bicycles')
	and c.deceased_indicator = 'N'
	and c.property_valuation > (
		select avg(c2.property_valuation)
		from customer c2
		where c2.state = c.state 
	)
group by c.customer_id, c.first_name, c.last_name
order by orders_count desc
limit 10;


-- 6. Вывести всех клиентов (ID, имя, фамилия), у которых нет подтвержденных онлайн-заказов за последний год,
-- но при этом они владеют автомобилем и их сегмент благосостояния не Mass Customer.

with last_year_approved_orders as (
	select distinct customer_id
    from orders
    where online_order is true
        and order_status = 'Approved'
        and order_date >= current_date - interval '1 year'
)
select 
	 c.customer_id
	,c.first_name
	,c.last_name
from customer c 
where c.customer_id not in (
		select customer_id
		from last_year_approved_orders
	)
	and c.owns_car = 'Yes'
	and c.wealth_segment != 'Mass Customer';


-- 7. Вывести всех клиентов из сферы 'IT' (ID, имя, фамилия),
-- которые купили 2 из 5 продуктов с самой высокой list_price в продуктовой линейке Road.

with top5_products_by_price as (
	select product_id
	from product
	where product_line = 'Road'
	order by list_price desc
	limit 5
	), customer_buyed_products as (
	select 
		 c.customer_id
		,c.first_name
		,c.last_name
		,count(distinct p.product_id) as top5_count
	from customer c
	join orders o on c.customer_id = o.customer_id 
    join order_items oi on o.order_id = oi.order_id 
    join product p on oi.product_id = p.product_id
    where c.job_industry_category = 'IT'
    	and p.product_id in (
    		select product_id
    		from top5_products_by_price
    	)
    group by c.customer_id, c.first_name, c. last_name
)
select 
	 c2.customer_id
	,c2.first_name
	,c2.last_name
from customer_buyed_products c2
where top5_count >= 2;


-- 8. Вывести клиентов (ID, имя, фамилия, сфера деятельности) из сфер IT или Health,
-- которые совершили не менее 3 подтвержденных заказов в период 2017-01-01 по 2017-03-01,
-- и при этом их общий доход от этих заказов превышает 10 000 долларов.
-- Разделить вывод на две группы (IT и Health) с помощью UNION.

with orders_with_conditions as (
	select
		 o.customer_id
		,count(o.order_id) as approved_count
		,sum(oi.quantity * oi.item_list_price_at_sale) as total_sum
	from orders o
	join order_items oi on o.order_id = oi.order_id
	where o.order_status = 'Approved'
		and o.order_date between '2017-01-01' and '2017-03-01' 
	group by o.customer_id
	having count(o.order_id) >= 3
		and sum(oi.quantity * oi.item_list_price_at_sale) > 10000
)
select
	 c.customer_id
	,c.first_name
	,c.last_name
	,c.job_industry_category 
from customer c 
join orders_with_conditions owc on c.customer_id = owc.customer_id
where c.job_industry_category = 'IT'

union

select
	 c2.customer_id
	,c2.first_name
	,c2.last_name
	,c2.job_industry_category 
from customer c2
join orders_with_conditions owc on c2.customer_id = owc.customer_id
where c2.job_industry_category = 'Health'
order by job_industry_category, customer_id;
