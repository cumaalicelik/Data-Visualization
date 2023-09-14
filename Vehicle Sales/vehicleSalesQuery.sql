-- create database Sales


--bring 5 rows to check the data first
select top 5 * from dbo.sales_data_sample


-- checking unique values
select distinct status from dbo.sales_data_sample
select distinct YEAR_ID from dbo.sales_data_sample
select distinct PRODUCTLINE from dbo.sales_data_sample
select distinct COUNTRY from dbo.sales_data_sample
select distinct DEALSIZE from dbo.sales_data_sample
select distinct TERRITORY from dbo.sales_data_sample

-- Analysis

--revenue by products
select PRODUCTLINE, sum(sales) as Revenue
from dbo.sales_data_sample
group by PRODUCTLINE
order by 2 desc

--revenue by years
select YEAR_ID, sum(sales) as Revenue
from dbo.sales_data_sample
group by YEAR_ID
order by 1

--revenu by size
select DEALSIZE, sum(sales) as Revenue
from dbo.sales_data_sample
group by DEALSIZE
order by 2 desc

-- What is the best month for sales in 2003 and 2004? How much earned that month?
--2003
select MONTH_ID, sum(sales) Revenue, count(ORDERNUMBER) Frequency
FROM dbo.sales_data_sample
where YEAR_ID = 2003
group by MONTH_ID
order by 2 desc

--2004
select MONTH_ID, sum(sales) Revenue, count(ORDERNUMBER) Frequency
FROM dbo.sales_data_sample
where YEAR_ID = 2004
group by MONTH_ID
order by 2 desc

-- November is the best month for sales. What product sold most in November? - 2003
select MONTH_ID, PRODUCTLINE, sum(sales) Revenue, count(ordernumber) Frequency
from dbo.sales_data_sample
where YEAR_ID = 2003 and MONTH_ID = 11
group by MONTH_ID, PRODUCTLINE
order by 3 desc

-- November is the best month for sales. What product sold most in November? - 2004
select MONTH_ID, PRODUCTLINE, sum(sales) Revenue, count(ordernumber) Frequency
from dbo.sales_data_sample
where YEAR_ID = 2004 and MONTH_ID = 11
group by MONTH_ID, PRODUCTLINE
order by 3 desc

-- Best customer?
with rfm as(
	select 
		customername,
		sum(sales) MonetaryValue,
		avg(sales) AvgMonetaryValue,
		count(ordernumber) Frequency,
		max(orderdate) last_order_date,
		(select max(orderdate) from dbo.sales_data_sample) max_order_date,
		DATEDIFF(DD, max(orderdate), (select max(orderdate) from dbo.sales_data_sample)) Recency

	from dbo.sales_data_sample
	group by CUSTOMERNAME
)
select *,
	(
	case 
	when Recency< 50 then 1
	when Recency <100 then 2  
	 when Recency < 200 then 3
	 when Recency >= 200 then 4
	else null
	end ) as rfm_recency
from rfm
order by rfm_recency 

-- we do the same thing with NTILE method. Best customer?
DROP TABLE IF EXISTS #rfm -- single table
;with rfm as 
(
	select 
		CUSTOMERNAME, 
		sum(sales) MonetaryValue,
		avg(sales) AvgMonetaryValue,
		count(ORDERNUMBER) Frequency,
		max(ORDERDATE) last_order_date,
		(select max(ORDERDATE) from [dbo].[sales_data_sample]) max_order_date,
		DATEDIFF(DD, max(ORDERDATE), (select max(ORDERDATE) from [dbo].[sales_data_sample])) Recency
	from dbo.sales_data_sample
	group by CUSTOMERNAME
),
rfm_calc as
(
	select r.*,
		NTILE(4) OVER (order by Recency desc) rfm_recency,
		NTILE(4) OVER (order by Frequency) rfm_frequency,
		NTILE(4) OVER (order by MonetaryValue) rfm_monetary
	from rfm r
)
select 
	*,
	rfm_recency + rfm_frequency + rfm_monetary as rfm_cell,
	CAST(rfm_recency as varchar) + CAST(rfm_frequency as varchar) + CAST(rfm_monetary as varchar) as rfm_var_string
into #rfm -- single table
from rfm_calc


-- all queries in a single table!
select *
from #rfm

--customer segmentation
select CUSTOMERNAME , rfm_recency, rfm_frequency, rfm_monetary,
	case 
		when rfm_var_string in (111, 112 , 121, 122, 123, 132, 211, 212, 114, 141) then 'lost_customers'  --lost customers
		when rfm_var_string in (133, 134, 143, 244, 334, 343, 344, 144) then 'slipping away, cannot lose' -- (Big spenders who haven’t purchased lately) slipping away
		when rfm_var_string in (311, 411, 331) then 'new customers'
		when rfm_var_string in (222, 223, 233, 322) then 'potential churners'
		when rfm_var_string in (323, 333,321, 422, 332, 432) then 'active' --(Customers who buy often & recently, but at low price points)
		when rfm_var_string in (433, 434, 443, 444) then 'loyal'
	end rfm_segment

from #rfm

-- What products are most often sold together?
--select *from dbo.sales_data_sample where ORDERNUMBER = 10411

select distinct OrderNumber, stuff(

	(select ',' + PRODUCTCODE
	from [dbo].[sales_data_sample] p
	where ORDERNUMBER in 
		(

			select ORDERNUMBER
			from (
				select ORDERNUMBER, count(*) rn
				FROM [dbo].[sales_data_sample]
				where STATUS = 'Shipped'
				group by ORDERNUMBER
			)m
			where rn = 3
		)
		and p.ORDERNUMBER = s.ORDERNUMBER
		for xml path (''))

		, 1, 1, '') ProductCodes

from [dbo].[sales_data_sample] s
order by 2 desc