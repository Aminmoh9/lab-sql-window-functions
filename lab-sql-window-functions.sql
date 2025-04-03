/*
Introduction
Welcome to the Window Functions lab!
In this lab, you will be working with the Sakila database on movie rentals. The goal of this lab is to help you practice and gain proficiency in using window functions 
in SQL queries.
Window functions are a powerful tool for performing complex data analysis in SQL. They allow you to perform calculations across multiple rows of a result set, 
without the need for subqueries or self-joins. This can greatly simplify your SQL code and make it easier to understand and maintain.
By the end of this lab, you will have a better understanding of how to use window functions in SQL to perform complex data analysis, assign rankings, 
and retrieve previous row values. These skills will be useful in a variety of real-world scenarios, such as sales analysis, financial reporting, and trend analysis.

Challenge 1
This challenge consists of three exercises that will test your ability to use the SQL RANK() function. 
You will use it to rank films by their length, their length within the rating category, 
and by the actor or actress who has acted in the greatest number of films.
*/
USE sakila;
-- 1. Rank films by their length and create an output table that includes the title, length, and rank columns only. 
-- Filter out any rows with null or zero values in the length column.
SELECT
	title,
	length,
	RANK() OVER (ORDER BY length DESC) AS length_rank
	FROM 
		film
	WHERE 
	    length IS NOT NULL AND length > 0;
       
-- 2. Rank films by length within the rating category and create an output table that includes the title, length, rating and rank columns only. 
-- Filter out any rows with null or zero values in the length column.
SELECT 
	title,
	length,
	rating,
	RANK() OVER (Partition BY rating ORDER BY length DESC) AS length_rank
FROM 
	film
WHERE 
	length IS NOT NULL AND length > 0;
-- 3. Produce a list that shows for each film in the Sakila database, the actor or actress who has acted in the greatest number of films, 
-- as well as the total number of films in which they have acted. Hint: Use temporary tables, CTEs, or Views when appropiate to simplify your queries.
WITH actor_film_counts AS (
    SELECT 
        a.actor_id,
        a.first_name,
        a.last_name,
        COUNT(fa.film_id) AS total_films
    FROM 
        actor a
    JOIN 
        film_actor fa ON a.actor_id = fa.actor_id
    GROUP BY 
        a.actor_id, a.first_name, a.last_name
),

film_actor_rankings AS (
    SELECT 
        f.film_id,
        f.title AS film_title,
        afc.actor_id,
        afc.first_name,
        afc.last_name,
        afc.total_films,
        RANK() OVER (PARTITION BY f.film_id ORDER BY afc.total_films DESC) AS actor_rank
    FROM 
        film f
    JOIN 
        film_actor fa ON f.film_id = fa.film_id
    JOIN 
        actor_film_counts afc ON fa.actor_id = afc.actor_id
)

SELECT 
    film_id,
    film_title,
    actor_id,
    first_name,
    last_name,
    total_films
FROM 
    film_actor_rankings
WHERE 
    actor_rank = 1
ORDER BY 
    film_title;
       

/*
Challenge 2
This challenge involves analyzing customer activity and retention in the Sakila database to gain insight into business performance.
By analyzing customer behavior over time, businesses can identify trends and make data-driven decisions to improve customer retention and increase revenue.

The goal of this exercise is to perform a comprehensive analysis of customer activity and retention by conducting an analysis on the monthly percentage change 
in the number of active customers and the number of retained customers. Use the Sakila database and progressively build queries to achieve the desired outcome.
*/
-- Step 1. Retrieve the number of monthly active customers, i.e., the number of unique customers who rented a movie in each month.
WITH monthly_active_customers AS (
    SELECT 
        DATE_FORMAT(r.rental_date, '%Y-%m') AS month,
        COUNT(DISTINCT r.customer_id) AS active_customers
    FROM 
        rental r
    GROUP BY 
        DATE_FORMAT(r.rental_date, '%Y-%m')
)
SELECT 
    month,
    active_customers
FROM 
    monthly_active_customers
ORDER BY 
    month;

-- Step 2. Retrieve the number of active users in the previous month.
WITH monthly_active_customers AS (
    SELECT 
        DATE_FORMAT(r.rental_date, '%Y-%m') AS month,
        COUNT(DISTINCT r.customer_id) AS active_customers
    FROM 
        rental r
    GROUP BY 
        DATE_FORMAT(r.rental_date, '%Y-%m')
)
SELECT 
    month,
    active_customers,
    LAG(active_customers, 1) OVER (ORDER BY month) AS previous_month_active
FROM 
    monthly_active_customers
ORDER BY 
    month;


-- Step 3. Calculate the percentage change in the number of active customers between the current and previous month.
WITH monthly_active_customers AS (
    SELECT 
        DATE_FORMAT(r.rental_date, '%Y-%m') AS month,
        COUNT(DISTINCT r.customer_id) AS active_customers
    FROM 
        rental r
    GROUP BY 
        DATE_FORMAT(r.rental_date, '%Y-%m')
),
monthly_comparison AS (
    SELECT 
        month,
        active_customers,
        LAG(active_customers, 1) OVER (ORDER BY month) AS previous_month_active
    FROM 
        monthly_active_customers
)
SELECT 
    month,
    active_customers,
    previous_month_active,
    CASE 
        WHEN previous_month_active IS NULL OR previous_month_active = 0 THEN NULL
        ELSE ROUND(((active_customers - previous_month_active) / previous_month_active) * 100, 2)
    END AS percentage_change
FROM 
    monthly_comparison
ORDER BY 
    month;


-- Step 4. Calculate the number of retained customers every month, i.e., customers who rented movies in the current and previous months.
-- Hint: Use temporary tables, CTEs, or Views when appropiate to simplify your queries.
WITH customer_activity AS (
    SELECT DISTINCT
        customer_id,
        DATE_FORMAT(rental_date, '%Y-%m') AS activity_month
    FROM 
        rental
),
customer_month_pairs AS (
    SELECT 
        customer_id,
        activity_month,
        LAG(activity_month, 1) OVER (PARTITION BY customer_id ORDER BY activity_month) AS previous_month
    FROM 
        customer_activity
)
SELECT 
    activity_month AS month,
    COUNT(CASE 
        WHEN previous_month = DATE_FORMAT(DATE_SUB(STR_TO_DATE(CONCAT(activity_month, '-01'), '%Y-%m-%d'), INTERVAL 1 MONTH), '%Y-%m')
        THEN customer_id
    END) AS retained_customers
FROM 
    customer_month_pairs
GROUP BY 
    activity_month
ORDER BY 
    activity_month;
    
WITH monthly_active_customers AS (
    SELECT 
        DATE_FORMAT(rental_date, '%Y-%m') AS month,
        COUNT(DISTINCT customer_id) AS active_customers
    FROM 
        rental
    GROUP BY 
        DATE_FORMAT(rental_date, '%Y-%m')
),
monthly_comparison AS (
    SELECT 
        month,
        active_customers,
        LAG(active_customers, 1) OVER (ORDER BY month) AS previous_month_active
    FROM 
        monthly_active_customers
),
customer_activity AS (
    SELECT DISTINCT
        customer_id,
        DATE_FORMAT(rental_date, '%Y-%m') AS activity_month
    FROM 
        rental
),
retention_data AS (
    SELECT 
        activity_month AS month,
        COUNT(DISTINCT customer_id) AS retained_customers
    FROM (
        SELECT 
            customer_id,
            activity_month,
            LAG(activity_month, 1) OVER (PARTITION BY customer_id ORDER BY activity_month) AS previous_month
        FROM 
            customer_activity
    ) t
    WHERE 
        activity_month = DATE_FORMAT(DATE_ADD(STR_TO_DATE(CONCAT(previous_month, '-01'), '%Y-%m-%d'), INTERVAL 1 MONTH), '%Y-%m')
    GROUP BY 
        activity_month
)
SELECT 
    mc.month,
    mc.active_customers,
    mc.previous_month_active,
    ROUND(
        (mc.active_customers - mc.previous_month_active) / 
        NULLIF(mc.previous_month_active, 0) * 100, 
        2
    ) AS percentage_change,
    COALESCE(rd.retained_customers, 0) AS retained_customers,
    ROUND(
        COALESCE(rd.retained_customers, 0) / 
        NULLIF(mc.previous_month_active, 0) * 100, 
        2
    ) AS retention_rate
FROM 
    monthly_comparison mc
LEFT JOIN 
    retention_data rd ON mc.month = rd.month
ORDER BY 
    mc.month;
    

  