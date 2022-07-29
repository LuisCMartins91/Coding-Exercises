-- This analysis estimates the impact of a coupon attribution campaign on the sales performance of an e-commerce website
-- To preserve data confidentiality, output values and variable names have been changed
-- Queries were created and visualized directly on Metabase

-- This analysis was performed using the sales database of the company. Analysis on other databases (ie. Google Analytics) are not represented in this project
-- Thus, this analysis does not consider other data that is potentially relevant (ie. website traffic volume, traffic sources or user conversion rate)

-- Coupon attribution campaign summary: 
-- Objective: Drive more sales and orders
    -- Users who visit the website may get shown a pop-up with a discount coupon code for their next purchase
    -- Discount percentage value may be any integer value between 5% and 15%
    -- Discount percentage is based on the user purchase intent measured by an algortihm, where low intent results in a higher discount and high intent results in a lower or no discount
    -- Campaign is valid for all products on the website except for Product B and Product C
    -- Campaign was implemented on July 11th, only on the US store.


-- ------------------------------------------------
-- PART 1. CAMPAIGN IMPACT ON THE NUMBER OF ORDERS
-- ------------------------------------------------
-- The first thing we want to know was how the existence of a discount was impacting the volume of orders
-- Are users buying more frequently after introducing discount coupons?
-- To address this question, we use the metric average number of daily orders
-- We calculate the average number of daily orders for both before and after the campaign was implemented and compare both values
-- The following variables are needed:
	-- 'ref' is the order number
    -- 'orderdetailname' is the name of the item 
    -- 'placedon' is the date when the order was made
    -- 'channel' is the sales channel where the order was made
    -- 'status id' is the status of the order
-- In the database, each record represents a unique item of a purchase, so an order with 3 unique products plus shipping and a discount coupon will be represented by 5 rows in the database.
-- We're only interest for orders that contain products included in the campaign (we need to exclude Product B and Product C), that were placed on the US Store, and whose payment has been processed (we need to exclude declined, cancelled and drafted orders)

-- Calculating the average number of daily orders before the campaign (June 1st until July 11th)
SELECT Round(Avg(orders_total)) AS avg_daily_orders
FROM   (SELECT placedon :: DATE    AS orderdatea,
               Count(DISTINCT ref) AS orders_total
        FROM   db.sales
        WHERE  orderdatea BETWEEN '2022-06-01' AND '2022-07-10'
               AND channel LIKE 'US Store'
               AND orderdetailname NOT LIKE 'Prod-B%'
               AND orderdetailname NOT LIKE 'Prod-C%'
               AND statusid NOT IN ( 'Declined', 'Cancelled', 'Draft / Quote' )
        GROUP  BY orderdatea)
; 
-- Output is a single integer value: 70

-- Calculating the average number of daily orders during the campaign (July 11th onwards up to present day)
SELECT Round(Avg(orders_total)) AS avg_daily_orders
FROM   (SELECT placedon :: DATE    AS orderdatea,
               Count(DISTINCT ref) AS orders_total
        FROM   db.sales
        WHERE  orderdatea BETWEEN '2022-07-11' AND ( Getdate() :: DATE ) - 1
               AND channel LIKE 'US Store'
               AND orderdetailname NOT LIKE 'Prod-B%'
               AND orderdetailname NOT LIKE 'Prod-C%'
               AND statusid NOT IN ( 'Declined', 'Cancelled', 'Draft / Quote' )
        GROUP  BY orderdatea)
; 
-- Output is a single integer value: 90

-- Calculating the change in average number of daily orders after the launching the campaign
SELECT Round(Avg(orders_total_during)) - Round(Avg(orders_total_before))
FROM  (SELECT placedon :: DATE    AS orderdatea,
              Count(DISTINCT ref) AS orders_total_during
       FROM   db.sales
       WHERE  orderdatea BETWEEN '2022-07-11' AND ( Getdate() :: DATE ) - 1
              AND channel LIKE 'US Store'
              AND orderdetailname NOT LIKE 'Prod-B%'
              AND orderdetailname NOT LIKE 'Prod-C%'
              AND statusid NOT IN ( 'Declined', 'Cancelled', 'Draft / Quote' )
       GROUP  BY orderdatea) dur
      cross join (SELECT placedon :: DATE    AS orderdatea,
                         Count(DISTINCT ref) AS orders_total_before
                  FROM   db.sales
                  WHERE  orderdatea BETWEEN '2022-06-01' AND '2022-07-10'
                         AND channel LIKE 'US Store'
                         AND orderdetailname NOT LIKE 'Prod-B%'
                         AND orderdetailname NOT LIKE 'Prod-C%'
                         AND statusid NOT IN ( 'Declined', 'Cancelled', 'Draft / Quote' )
                  GROUP  BY orderdatea) bef
;
-- Output is a single integer value: 20

-- OBSERVATIONS: 
	-- Before launching the campaign, there were on average 70 orders per day on the US store
    -- After launching the campaign, there were on average 90 orders per day on the US store
    -- The average number of orders per day increased by 20 (+28%) on the US store after launching the campaign      

-- Next, we want to analyze the evolution of orders, namely the percentage of the total orders where a campaign coupon discount code was used         
-- The next query returns a table with the number of orders with and without discount coupons, split by day, from June 1st until the day before the present day
-- It would then be turned into a bar chart directly on Metabase for a better visualization and understanding
-- New variables are created:
	-- 'orders_no_coupon' are orders where no coupon was used
    -- 'orders_nm_coupons' are orders where a campaign coupon code was used 
    -- 'orders_oth_coupons' are orders where other coupon codes were used
    -- 'orders_total' are the total number of orders (this metric wasn't visualized for the bar chart, it's mostly to help us calculate the values for the 'orders_no_coupon' variable)
SELECT placedon :: DATE                                          AS orderdatea,
       Count(DISTINCT ref)                                       AS orders_total,
       Coalesce(orders_1, 0)                                     AS orders_nm_coupons,
       Coalesce(orders_2, 0)                                     AS orders_oth_coupons,
       ( orders_total - orders_nm_coupons - orders_oth_coupons ) AS orders_no_coupons
FROM   db.sales 
       left join (SELECT placedon :: DATE    AS orderdate,
                         Count(DISTINCT ref) AS orders_1
                  FROM   db.sales
                  WHERE  orderdetailname LIKE 'Coupon: NM%'
                         AND channel LIKE 'US Store'
                         AND statusid NOT IN ('Declined','Cancelled','Draft / Quote')
                  GROUP  BY orderdate) b
              ON orderdatea = b.orderdate
       left join (SELECT placedon :: DATE    AS orderdate,
                         Count(DISTINCT ref) AS orders_2
                  FROM   db.sales
                  WHERE  orderdetailname LIKE 'Coupon%'
                         AND orderdetailname NOT LIKE 'Coupon: NM%'
                         AND channel LIKE 'US Store'
                         AND statusid NOT IN ('Declined','Cancelled','Draft / Quote')
                  GROUP  BY orderdate) c
              ON orderdatea = c.orderdate
WHERE  orderdatea BETWEEN '2022-06-01' AND ( Getdate() :: DATE ) - 1
       AND orderdetailname NOT LIKE 'Coupon%'
       AND orderdetailname NOT LIKE 'Prod-C%'
       AND orderdetailname NOT LIKE 'Prod-B%'
       AND channel LIKE 'US Store'
       AND statusid NOT IN ('Declined','Cancelled','Draft / Quote')
GROUP  BY orderdatea,
          orders_nm_coupons,
          orders_oth_coupons
ORDER  BY orderdatea DESC
; 


-- ------------------------------------------------   
-- PART 2. CAMPAIGN IMPACT ON NET SALES
-- ------------------------------------------------
-- The change in the number of orders gives us an indication of the campaign impact on user purchase behaviour, but not on sales
-- This is because despite having more orders per day, the inclusion of a discount lowers the margin of each sale where a coupon was used
-- The next question is if the increase in the number of orders is high enough to compensate the lower margins
-- Are we generating more sales with this campaign or are the discounts actually undermining profits?
-- To address this question, we use the metric daily net sales
-- We calculate the average daily net sales for both before and after the campaign was implemented and compare both values
-- The following new variables are needed:
	-- 'orderdetailnet' is the net sales of an item in a sale in the store's base currency
    -- 'currencyexchangerate' is the rate between the store's base curreny and USD
-- Note: Sales values are presented in USD. Because we are only analyzing the US store where the base currency is USD, the currency conversion calculation is not necessary as 'currencyexchangerate' = 1 and we could have simply used the 'orderdetailnet' metric. By including the conversion calculation, we ensure the following queries can be used for querying data from other web stores in the future.
-- We also don't want to consider shipping costs for this

-- Calculating the average daily net sales before the campaign (until July 11th)
SELECT Round(Avg(net_sales)) AS net_sales
FROM  (SELECT placedon :: DATE                           AS orderdatea,
              SUM(orderdetailnet / currencyexchangerate) AS net_sales
       FROM   db.sales
       WHERE  orderdatea BETWEEN '2022-06-01' AND '2022-07-10'
              AND channel LIKE 'US Store'
              AND orderdetailname NOT LIKE 'Prod-B%'
              AND orderdetailname NOT LIKE 'Prod-C%'
              AND orderdetailname NOT LIKE 'Ship%'
              AND statusid NOT IN ( 'Declined', 'Cancelled', 'Draft / Quote' )
       GROUP  BY orderdatea)
ORDER  BY orderdatea DESC
; 
-- Output is a single integer value: 6,000

-- Calculating the average daily net sales during the campaign (July 11th onwards up to present day)
SELECT Round(Avg(net_sales)) AS net_sales
FROM  (SELECT placedon :: DATE                           AS orderdatea,
              SUM(orderdetailnet / currencyexchangerate) AS net_sales
       FROM   db.sales
       WHERE  orderdatea BETWEEN '2022-07-11' AND ( Getdate() :: DATE ) - 1
              AND channel LIKE 'US Store'
              AND orderdetailname NOT LIKE 'Prod-B%'
              AND orderdetailname NOT LIKE 'Prod-C%'
              AND orderdetailname NOT LIKE 'Ship%'
              AND statusid NOT IN ( 'Declined', 'Cancelled', 'Draft / Quote' )
       GROUP  BY orderdatea)
ORDER  BY orderdatea DESC
; 
-- Output is a single integer value: 7,500

-- Calculating the change in daily net sales after the launching the campaign
SELECT Round(Avg(net_sales_during) - Avg(net_sales_before))
FROM   (SELECT placedon :: DATE                           AS orderdatea,
               SUM(orderdetailnet / currencyexchangerate) AS net_sales_during
        FROM   db.sales
        WHERE  orderdatea BETWEEN '2022-07-11' AND ( Getdate() :: DATE ) - 1
               AND channel LIKE 'US Store'
               AND orderdetailname NOT LIKE 'Prod-B%'
               AND orderdetailname NOT LIKE 'Prod-C%'
               AND orderdetailname NOT LIKE 'Ship%'
               AND statusid NOT IN ( 'Declined', 'Cancelled', 'Draft / Quote' )
        GROUP  BY orderdatea) dur
       cross join (SELECT placedon :: DATE                           AS orderdatea,
                          SUM(orderdetailnet / currencyexchangerate) AS net_sales_before
                   FROM   db.sales
                   WHERE  orderdatea BETWEEN '2022-06-01' AND '2022-07-10'
                          AND channel LIKE 'US Store'
                          AND orderdetailname NOT LIKE 'Prod-B%'
                          AND orderdetailname NOT LIKE 'Prod-C%'
                          AND orderdetailname NOT LIKE 'Ship%'
                          AND statusid NOT IN ( 'Declined', 'Cancelled', 'Draft / Quote' )
                   GROUP  BY orderdatea) bef
;
-- Output is a single integer value: 1,500

-- OBSERVATIONS: 
	-- Before launching the campaign, net sales was on average USD 6,000 per day on the US store
    -- After launching the campaign, net sales was on average USD 7,500 per day on the US store
    -- The average net sales per day increased by USD 1,500 (+25%) on the US store after launching the campaign   

-- Similarly to what was done on part 1, we want a visual representation of how daily net sales have evolved after launching the campaign
-- The next query returns a table with two columns: date and net sales, from June 1st until the day before the present day
-- It would then be turned into a bar chart directly on Metabase for a better visualization and understanding
SELECT orderdatea,
       SUM(net_sales) AS net_sales
FROM  (SELECT placedon :: DATE                      AS orderdatea,
              ref,
              orderdetailname,
              orderdetailnet / currencyexchangerate AS net_sales
       FROM   db.sales
       WHERE  orderdatea BETWEEN '2022-06-01' AND ( Getdate() :: DATE ) - 1
              AND orderdetailname NOT LIKE 'Prod-C%'
              AND orderdetailname NOT LIKE 'Prod-B%'
              AND orderdetailname NOT LIKE 'Ship%'
              AND channel LIKE 'US Store'
              AND statusid NOT IN ( 'Declined', 'Cancelled', 'Draft / Quote' )
       ORDER  BY ref DESC) a
GROUP  BY orderdatea
ORDER  BY orderdatea DESC;
;

-- ------------------------------------------------   
-- PART 3. CONCLUSIONS AND OBSERVATIONS
-- ------------------------------------------------
-- The analysis indicates that the discount coupon campaign had a positive impact on the US store sales performance
-- Order volume has increased by 28% and sales have increased by 25%
-- As mentioned in the intro, other databases were not considered in this analysis
-- Seasonality was also not taken into account, as campaign data was compared with data from the period immediately before
-- A useful next step would be to cross the data from this analysis with Google Analytics data and analyze changes in website traffic, bounce rate and conversion rate for the same period to better understand the impact of the campaign on the increase in sales.
