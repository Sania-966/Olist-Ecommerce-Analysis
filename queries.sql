-- ============================================
-- Olist E-Commerce Analysis
-- Author: Sania Natalwala
-- Tools: BigQuery SQL
-- Dataset: dic-app-455521.Olist
-- ============================================


-- ============================================
-- Q1: What drives low review scores?
-- Late Delivery vs Review Score
-- ============================================

SELECT 
  review_score,
  COUNT(*) AS total_orders,
  COUNT(CASE WHEN DATE_DIFF(order_delivered_customer_date, order_estimated_delivery_date, DAY) > 0 THEN 1 END) AS late_orders,
  ROUND(
    COUNT(CASE WHEN DATE_DIFF(order_delivered_customer_date, order_estimated_delivery_date, DAY) > 0 THEN 1 END)
    / COUNT(*) * 100, 2
  ) AS perc_of_late_orders
FROM `dic-app-455521.Olist.olist_order_reviews` r
INNER JOIN `dic-app-455521.Olist.olist_orders` o
  ON r.order_id = o.order_id
WHERE order_status = 'delivered' 
  AND order_delivered_customer_date IS NOT NULL
GROUP BY review_score
ORDER BY review_score DESC;


-- ============================================
-- Q2: Which product categories receive the most negative reviews?
-- ============================================

SELECT 
  ROUND(AVG(review_score), 2) AS avg_review_score,
  COUNT(*) AS total_reviews,
  ROUND(COUNT(CASE WHEN review_score <= 2 THEN 1 END) * 100.0 / COUNT(*), 2) AS pct_negative_reviews,
  t.product_category_name_english AS category_name
FROM `dic-app-455521.Olist.olist_order_items` i
JOIN `dic-app-455521.Olist.olist_order_reviews` r
  ON i.order_id = r.order_id
JOIN `dic-app-455521.Olist.olist_products` p 
  ON i.product_id = p.product_id
JOIN `dic-app-455521.Olist.olist_prod_english` t
  ON p.product_category_name = t.product_category_name
GROUP BY category_name
HAVING COUNT(*) >= 50
ORDER BY pct_negative_reviews DESC;


-- ============================================
-- Q3: What percentage of customers place a second order?
-- Customer Retention Rate
-- ============================================

SELECT
  COUNT(*) AS total_customers,
  COUNTIF(tot_orders > 1) AS repeat_customers,
  ROUND(COUNTIF(tot_orders > 1) * 100.0 / COUNT(*), 2) AS repeat_pct
FROM (
  SELECT 
    customer_unique_id,
    COUNT(*) AS tot_orders
  FROM `dic-app-455521.Olist.olist_customers` c  
  JOIN `dic-app-455521.Olist.olist_orders` o     
    ON c.customer_id = o.customer_id
  WHERE order_status = 'delivered'
  GROUP BY customer_unique_id
);


-- ============================================
-- Q4: Do customers with poor experiences return less often?
-- Return Rate by Review Score
-- ============================================

SELECT 
  review_score,
  COUNT(*) AS total_customers,
  COUNTIF(tot_orders > 1) AS repeat_customers,
  ROUND(COUNTIF(tot_orders > 1) * 100.0 / COUNT(*), 2) AS return_rate_pct
FROM (
  SELECT 
    customer_unique_id, 
    review_score,
    COUNT(*) AS tot_orders
  FROM `dic-app-455521.Olist.olist_orders` o   
  JOIN `dic-app-455521.Olist.olist_customers` c       
    ON o.customer_id = c.customer_id
  JOIN `dic-app-455521.Olist.olist_order_reviews` r    
    ON o.order_id = r.order_id
  WHERE order_status = 'delivered'
  GROUP BY customer_unique_id, review_score
)
GROUP BY review_score
ORDER BY review_score DESC;


-- ============================================
-- Q5: What is the estimated revenue lost due to poor customer experience?
-- ============================================

SELECT
  unhappy_customers,
  avg_order_value,
  return_rate_gap,
  ROUND(unhappy_customers * return_rate_gap * avg_order_value, 2) AS estimated_revenue_lost
FROM (
  SELECT
    COUNTIF(review_score <= 2) AS unhappy_customers,
    (
      SELECT ROUND(AVG(sum_price), 2) 
      FROM (
        SELECT order_id, SUM(price) AS sum_price
        FROM `dic-app-455521.Olist.olist_order_items`
        GROUP BY order_id
      )
    ) AS avg_order_value,
    0.01325 AS return_rate_gap  -- 2.70% (5-star return rate) - 1.375% (avg unhappy return rate)
  FROM `dic-app-455521.Olist.olist_order_reviews`
);
