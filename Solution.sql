#Author : Pedro Blanco
#Insert data into Big query tool to perform better analyisis

# 1st step: 
#We joined the tables to get a total review of the data.
#Also, we separated the rates into columns to get more easy calculations later if needed.

--drop table `coastal-antler-329903.Deel001.GP_tables` ;
create table `coastal-antler-329903.Deel001.GP_tables` as
select a.external_ref,
a.status,
a.source,
a.ref,
FORMAT_DATE('%m-%d-%y', date_time) As date,
a.state,
a.cvv_provided,
a.amount,
a.country,
a.currency,
  JSON_EXTRACT(rates, '$.CAD') AS CAD,
  JSON_EXTRACT(rates, '$.EUR') AS EUR,
  JSON_EXTRACT(rates, '$.MXN') AS MXN,
  JSON_EXTRACT(rates, '$.USD') AS USD,
  JSON_EXTRACT(rates, '$.SGD') AS SGD,
  JSON_EXTRACT(rates, '$.AUD') AS AUD,
  JSON_EXTRACT(rates, '$.GBP') AS GBP
,b.external_ref as ch_external_ref,
b.status as ch_status,
b.source as ch_source,
b.chargeback as ch_charge
from `coastal-antler-329903.Deel001.Deel Info` as a
join `coastal-antler-329903.Deel004.Deel ChargeBack` as b on a.external_ref = b.external_ref;

#What is the acceptance rate over time?
#We determined the acceptance ratio % to analyzed the behavior
WITH total_table AS (
  SELECT 
    EXTRACT(MONTH FROM PARSE_DATE('%m-%d-%y', date)) AS month,
    COUNT(external_ref) AS total_transactions 
  FROM `coastal-antler-329903.Deel001.GP_tables`
  GROUP BY 1 
  ORDER BY 1 
), 
accepted_table AS (
  SELECT 
    EXTRACT(MONTH FROM PARSE_DATE('%m-%d-%y', date)) AS month,
    COUNT(external_ref) AS total_accepted
  FROM `coastal-antler-329903.Deel001.GP_tables`
  WHERE state = 'ACCEPTED' 
  GROUP BY 1  
  ORDER BY 1
)
SELECT 
  t1.month, 
  t1.total_transactions, 
  t2.total_accepted, 
  FORMAT('%2.2f%%', (t2.total_accepted/t1.total_transactions )*100) AS acceptance_rate
FROM 
  total_table t1 
JOIN 
  accepted_table t2 
ON 
  t1.month = t2.month 
ORDER BY 
  1
;

#Which transactions are missing chargeback data?

select a.external_ref,
a.status,
a.source,
a.ref,
FORMAT_DATE('%m-%d-%y', date_time) As date,
a.state,
a.cvv_provided,
a.amount,
a.country,
a.currency,
  JSON_EXTRACT(rates, '$.CAD') AS CAD,
  JSON_EXTRACT(rates, '$.EUR') AS EUR,
  JSON_EXTRACT(rates, '$.MXN') AS MXN,
  JSON_EXTRACT(rates, '$.USD') AS USD,
  JSON_EXTRACT(rates, '$.SGD') AS SGD,
  JSON_EXTRACT(rates, '$.AUD') AS AUD,
  JSON_EXTRACT(rates, '$.GBP') AS GBP
, b.external_ref as ch_external_ref,
b.status as ch_status,
b.source as ch_source,
b.chargeback as ch_charge
from `coastal-antler-329903.Deel001.Deel Info` as a
left join `coastal-antler-329903.Deel004.Deel ChargeBack` as b on a.external_ref = b.external_ref
where b.external_ref is null;

#Corrected
#Convert all amount in USD dollars

create table `coastal-antler-329903.Deel001.USD_Convert` as
select a.external_ref,
a.status,
a.source,
a.ref,
FORMAT_DATE('%m-%d-%y', date_time) As date,
a.state,
a.cvv_provided,
a.amount,
a.country,
a.currency,
  JSON_EXTRACT(rates, '$.CAD') AS CAD,
  JSON_EXTRACT(rates, '$.EUR') AS EUR,
  JSON_EXTRACT(rates, '$.MXN') AS MXN,
  JSON_EXTRACT(rates, '$.USD') AS USD,
  JSON_EXTRACT(rates, '$.SGD') AS SGD,
  JSON_EXTRACT(rates, '$.AUD') AS AUD,
  JSON_EXTRACT(rates, '$.GBP') AS GBP
from `coastal-antler-329903.Deel001.Deel Info` as a
where state='DECLINED';


Select 
round(SUM(USD_CONVERT))
 from (
select 
Case 
when currency='USD' then amount*CAST(USD AS FLOAT64)
when currency='CAD' then amount*CAST(CAD AS FLOAT64)
when currency='EUR' then amount*CAST(EUR AS FLOAT64)
when currency='MXN' then amount*CAST(MXN AS FLOAT64)
when currency='SGD' then amount*CAST(SGD AS FLOAT64)
when currency='GBP' then amount*CAST(GBP AS FLOAT64)
when currency='AUD' then amount*CAST(AUD AS FLOAT64)
ELSE AMOUNT END USD_CONVERT
FROM `coastal-antler-329903.Deel001.USD_Convert`)
;

#List the countries where the amount of declined transactions went over $25M
WITH amount as (
SELECT 
  a.country,
  round(SUM(a.amount)) AS total_declined_amount
FROM 
  `coastal-antler-329903.Deel001.Deel Info` a
  where state='DECLINED'
  group by 1 ) 
select * from amount
WHERE 
 total_declined_amount > 25000000;

#Outlines the volume (in USD) of the declined payments
select 
ROUND(SUM(AMOUNT * USD)) AS TOTAL_USD_DECLINED
from (
select 
a.state,
a.amount,
a.currency,
CAST(JSON_EXTRACT(rates, '$.USD') AS FLOAT64) AS USD
from `coastal-antler-329903.Deel001.Deel Info` as a)
where state='DECLINED';
