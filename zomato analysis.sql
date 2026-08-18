create database zomato_analysis
use zomato_analysis

select * from zomato

select COUNT(*) as total_rows
from zomato

select top 5 * from zomato

--checking the table structure:
exec sp_help 'zomato'

--RAW DATA
--  ↓
--DATA QUALITY CHECK
--  ↓
--CLEAN TABLE
--  ↓
--BUSINESS ANALYSIS
--  ↓
--ADVANCED SQL
--  ↓
--POWER BI

select * from zomato

--how many restaurants are there?
select count(distinct name) as unique_restaurants from zomato

--how many duplicate restaurants exist?
select
COUNT(*) as total_records, COUNT(distinct name) as unique_restaurants ,
COUNT(*) - COUNT(distinct name) as duplicate_records from zomato

--find unique locations
select COUNT(*) as total_locations,COUNT(distinct location) as unique_locations from zomato

--which 10 locations have the most restaurant listings?
select
top 10 location,
COUNT (*) as restaurant_count
from zomato
group by location
order by restaurant_count desc

--Which locations are actually the most competitive?
SELECT TOP 10
    location,
    COUNT(*) AS restaurant_count,
            CAST(
                COUNT(*) * 100.0 / SUM(COUNT(*)) OVER()
                AS DECIMAL(10,2)
            ) AS market_share_percent
FROM zomato
GROUP BY location
ORDER BY restaurant_count DESC;

--RANK RESTAURANTS BY NUMBER OF VOTES

SELECT * FROM (
    SELECT 
        NAME,
        LOCATION,
        RATE,
        VOTES,
        ROW_NUMBER() OVER (PARTITION BY NAME ORDER BY VOTES DESC) AS rn
    FROM zomato
) t
WHERE rn = 1
ORDER BY VOTES DESC

--TOP 3 LOCATIONS BASED ON VOTES
with ranked_restaurants as
(
SELECT 
name,
location,
votes,
ROW_NUMBER() OVER (PARTITION BY LOCATION ORDER BY VOTES) as rn
FROM ZOMATO
)

select * from ranked_restaurants
where rn<=3

--comparing rank(), dense rank() and row number()
select 
name,votes,
RANK() over(order by votes desc) as rank_no,
DENSE_RANK() over(order by votes desc) as dense_rank_no,
ROW_NUMBER() over(order by votes desc) as row_number_no
from zomato

--each restaurant's votes and avg votes of its location
select
name,
location,
votes,
AVG(votes) over(partition by location) as avg_votes
from zomato

--RESTAURANTS WHOSE VOTES ARE ABOVE THEIR LOCATION'S AVG

WITH X AS 
(
SELECT
NAME,
LOCATION,
VOTES,
AVG(VOTES) OVER(PARTITION BY LOCATION) AS LOCATION_AVG_VOTES 
FROM ZOMATO 
)
SELECT 
NAME,LOCATION,
VOTES,
LOCATION_AVG_VOTES,
VOTES- LOCATION_AVG_VOTES AS DIFFERENCE
FROM X
WHERE VOTES> LOCATION_AVG_VOTES
ORDER BY DIFFERENCE DESC;

--CALCULATE EACH RESTAURANT'S PERCENTAGE CONTRIBUTION TO TOTAL VOTES IN ITS LOCATION.

SELECT
name,
location,
votes,
SUM(votes) OVER
(PARTITION BY location) AS location_total_votes,
 ROUND(100.0 * votes /SUM(votes) OVER (PARTITION BY location),2) AS vote_contribution_pct
FROM zomato;


--FIND THE HIGHEST-VOTED RESTAURANT IN EVERY LOCATION.
WITH x AS
(SELECT
        name,
        location,
        votes,
        ROW_NUMBER() OVER
        (PARTITION BY location ORDER BY votes DESC) AS rn
FROM zomato)
SELECT
    name,
    location,
    votes
FROM x
WHERE rn = 1;


--COMPARE EVERY RESTAURANT'S VOTES WITH THE PREVIOUS-RANKED RESTAURANT IN ITS LOCATION.
WITH x AS
(
    SELECT
        name,
        location,
        votes,
        LAG(votes) OVER
        (
            PARTITION BY location
            ORDER BY votes DESC
        ) AS previous_votes
    FROM zomato
)
SELECT
    name,
    location,
    votes,
    previous_votes,
    votes - previous_votes AS vote_difference
FROM x;

--Create a location-wise restaurant leaderboard with rank, votes, location average, 
--vote contribution and difference from the previous restaurant.

WITH x AS
(
    SELECT
        name,
        location,
        votes,

        RANK() OVER
        (
            PARTITION BY location
            ORDER BY votes DESC
        ) AS location_rank,

        AVG(votes) OVER
        (
            PARTITION BY location
        ) AS avg_location_votes,

        SUM(votes) OVER
        (
            PARTITION BY location
        ) AS total_location_votes,

        LAG(votes) OVER
        (
            PARTITION BY location
            ORDER BY votes DESC
        ) AS previous_votes

    FROM zomato
)

SELECT
    name,
    location,
    votes,
    location_rank,
    avg_location_votes,

    ROUND(
        100.0 * votes / total_location_votes,
        2
    ) AS vote_contribution_pct,

    votes - previous_votes AS difference_from_previous

FROM x
ORDER BY location, location_rank;


--GROUP BY + AGGREGATIONS

--Q11. HOW MANY RESTAURANTS ARE IN THE DATASET?
SELECT COUNT(*) AS total_restaurants
FROM zomato;

--Q12. HOW MANY RESTAURANTS ARE PRESENT IN EACH LOCATION?
SELECT
    location,
    COUNT(*) AS restaurant_count
FROM zomato
GROUP BY location
ORDER BY restaurant_count DESC;
--Q13. WHAT IS THE AVERAGE NUMBER OF VOTES PER LOCATION?
SELECT
    location,
    AVG(votes) AS avg_votes
FROM zomato
GROUP BY location
ORDER BY avg_votes DESC;

--Q14. FIND THE MAXIMUM VOTES RECEIVED BY A RESTAURANT IN EACH LOCATION.
SELECT
    location,
    MAX(votes) AS maximum_votes
FROM zomato
GROUP BY location
ORDER BY maximum_votes DESC;

--Q15. FIND THE AVERAGE COST FOR TWO PEOPLE BY LOCATION.
SELECT
    location,
    AVG([approx_cost(for two people)]) AS avg_cost
FROM zomato
GROUP BY location
ORDER BY avg_cost DESC;

--Q16. FIND LOCATIONS HAVING MORE THAN 500 RESTAURANTS.
SELECT
    location,
    COUNT(*) AS restaurant_count
FROM zomato
GROUP BY location
HAVING COUNT(*) > 500
ORDER BY restaurant_count DESC;

--Q17. FIND THE TOP 10 LOCATIONS BY TOTAL VOTES.
SELECT TOP 10
    location,
    SUM(votes) AS total_votes
FROM zomato
GROUP BY location
ORDER BY total_votes DESC;


--Q18. FIND THE AVERAGE RATING AND AVERAGE VOTES FOR EACH RESTAURANT TYPE.
SELECT
    rest_type,
    AVG(rate) AS avg_rating,
    AVG(votes) AS avg_votes
FROM zomato
WHERE rate IS NOT NULL
GROUP BY rest_type
ORDER BY avg_rating DESC;


--Q19. WHICH RESTAURANT TYPES HAVE BOTH ABOVE-AVERAGE RATINGS AND ABOVE-AVERAGE VOTES?
WITH x AS
(
    SELECT
        rest_type,
        AVG(rate) AS avg_rating,
        AVG(votes) AS avg_votes
    FROM zomato
    WHERE rate IS NOT NULL
    GROUP BY rest_type
),
overall AS
(
    SELECT
        AVG(rate) AS overall_rating,
        AVG(votes) AS overall_votes
    FROM zomato
    WHERE rate IS NOT NULL
)
SELECT x.*
FROM x
CROSS JOIN overall
WHERE x.avg_rating > overall.overall_rating
  AND x.avg_votes > overall.overall_votes;

--Q20. WHICH LOCATIONS GENERATE THE HIGHEST TOTAL CUSTOMER ENGAGEMENT?
SELECT
    location,
    COUNT(*) AS restaurants,
    SUM(votes) AS total_votes,
    AVG(votes) AS avg_votes
FROM zomato
GROUP BY location
ORDER BY total_votes DESC;

--JOINS

--Q21. JOIN EACH RESTAURANT WITH ITS LOCATION'S RESTAURANT COUNT.
WITH location_count AS
(
    SELECT
        location,
        COUNT(*) AS restaurant_count
    FROM zomato
    GROUP BY location
)
SELECT
    z.name,
    z.location,
    z.votes,
    l.restaurant_count
FROM zomato z
JOIN location_count l
    ON z.location = l.location;

-- Q22. SHOW RESTAURANTS ALONGSIDE THEIR LOCATION'S AVERAGE VOTES.


WITH location_avg AS
(
    SELECT
        location,
        AVG(votes) AS avg_votes
    FROM zomato
    GROUP BY location
)
SELECT
    z.name,
    z.location,
    z.votes,
    l.avg_votes
FROM zomato z
JOIN location_avg l
    ON z.location = l.location;



-- Q23. FIND RESTAURANTS WHOSE VOTES EXCEED THEIR LOCATION'S AVERAGE.


WITH location_avg AS
(
    SELECT
        location,
        AVG(votes) AS avg_votes
    FROM zomato
    GROUP BY location
)
SELECT
    z.name,
    z.location,
    z.votes,
    l.avg_votes
FROM zomato z
JOIN location_avg l
    ON z.location = l.location
WHERE z.votes > l.avg_votes;



-- Q24. FIND LOCATIONS THAT HAVE BOTH ONLINE ORDERING AND TABLE BOOKING RESTAURANTS.


SELECT
    location
FROM zomato
GROUP BY location
HAVING
    SUM(CASE WHEN online_order = 'Yes' THEN 1 ELSE 0 END) > 0
    AND
    SUM(CASE WHEN book_table = 'Yes' THEN 1 ELSE 0 END) > 0;



-- Q25. FIND THE NUMBER OF ONLINE-ORDER RESTAURANTS AND TABLE-BOOKING RESTAURANTS PER LOCATION.


SELECT
    location,

    SUM(CASE
        WHEN online_order = 'Yes' THEN 1
        ELSE 0
    END) AS online_order_restaurants,

    SUM(CASE
        WHEN book_table = 'Yes' THEN 1
        ELSE 0
    END) AS table_booking_restaurants

FROM zomato
GROUP BY location;



-- Q26. FIND LOCATIONS WHERE ONLINE ORDERING IS MORE POPULAR THAN TABLE BOOKING.


SELECT
    location,

    SUM(CASE
        WHEN online_order = 'Yes' THEN 1 ELSE 0
    END) AS online_count,

    SUM(CASE
        WHEN book_table = 'Yes' THEN 1 ELSE 0
    END) AS booking_count

FROM zomato
GROUP BY location

HAVING
    SUM(CASE WHEN online_order = 'Yes' THEN 1 ELSE 0 END)
    >
    SUM(CASE WHEN book_table = 'Yes' THEN 1 ELSE 0 END);



-- Q27. FIND EACH RESTAURANT'S DIFFERENCE FROM THE AVERAGE VOTES OF ITS RESTAURANT TYPE.


WITH type_avg AS
(
    SELECT
        rest_type,
        AVG(votes) AS avg_votes
    FROM zomato
    GROUP BY rest_type
)
SELECT
    z.name,
    z.rest_type,
    z.votes,
    t.avg_votes,
    z.votes - t.avg_votes AS difference
FROM zomato z
JOIN type_avg t
    ON z.rest_type = t.rest_type;



-- Q28. FIND THE HIGHEST-VOTED RESTAURANT TYPE IN EVERY LOCATION.


WITH type_votes AS
(
    SELECT
        location,
        rest_type,
        SUM(votes) AS total_votes
    FROM zomato
    GROUP BY location, rest_type
),
ranked AS
(
    SELECT *,
        RANK() OVER
        (
            PARTITION BY location
            ORDER BY total_votes DESC
        ) AS rn
    FROM type_votes
)
SELECT
    location,
    rest_type,
    total_votes
FROM ranked
WHERE rn = 1;



-- Q29. FIND LOCATIONS WHERE THE MOST POPULAR RESTAURANT TYPE ACCOUNTS FOR MORE THAN 50% OF TOTAL VOTES.


WITH type_votes AS
(
    SELECT
        location,
        rest_type,
        SUM(votes) AS type_votes
    FROM zomato
    GROUP BY location, rest_type
),
x AS
(
    SELECT
        *,
        SUM(type_votes) OVER
        (
            PARTITION BY location
        ) AS location_votes,

        RANK() OVER
        (
            PARTITION BY location
            ORDER BY type_votes DESC
        ) AS rn
    FROM type_votes
)
SELECT
    location,
    rest_type,
    type_votes,
    location_votes,
    100.0 * type_votes / location_votes AS contribution_pct
FROM x
WHERE rn = 1
  AND 100.0 * type_votes / location_votes > 50;



-- Q30. IDENTIFY RESTAURANTS THAT ARE ABOVE THEIR LOCATION AVERAGE AND ABOVE THEIR RESTAURANT-TYPE AVERAGE.


WITH location_avg AS
(
    SELECT
        location,
        AVG(votes) AS avg_location_votes
    FROM zomato
    GROUP BY location
),
type_avg AS
(
    SELECT
        rest_type,
        AVG(votes) AS avg_type_votes
    FROM zomato
    GROUP BY rest_type
)
SELECT
    z.name,
    z.location,
    z.rest_type,
    z.votes,
    l.avg_location_votes,
    t.avg_type_votes
FROM zomato z
JOIN location_avg l
    ON z.location = l.location
JOIN type_avg t
    ON z.rest_type = t.rest_type
WHERE z.votes > l.avg_location_votes
  AND z.votes > t.avg_type_votes;



-- Q31. FIND RESTAURANTS WHOSE VOTES ARE ABOVE THE OVERALL AVERAGE.


SELECT
    name,
    location,
    votes
FROM zomato
WHERE votes >
(
    SELECT AVG(votes)
    FROM zomato
);



-- Q32. FIND RESTAURANTS WHOSE RATING IS ABOVE THE OVERALL AVERAGE RATING.


SELECT
    name,
    location,
    rate
FROM zomato
WHERE rate >
(
    SELECT AVG(rate)
    FROM zomato
    WHERE rate IS NOT NULL
);



-- Q33. FIND THE RESTAURANT WITH THE HIGHEST VOTES.


SELECT
    name,
    location,
    votes
FROM zomato
WHERE votes =
(
    SELECT MAX(votes)
    FROM zomato
);



-- Q34. FIND THE SECOND-HIGHEST VOTED RESTAURANT.


SELECT
    name,
    location,
    votes
FROM zomato
WHERE votes =
(
    SELECT MAX(votes)
    FROM zomato
    WHERE votes <
    (
        SELECT MAX(votes)
        FROM zomato
    )
);



-- Q35. FIND RESTAURANTS WHOSE VOTES ARE GREATER THAN THE AVERAGE VOTES OF RESTAURANTS IN BTM.


SELECT
    name,
    location,
    votes
FROM zomato
WHERE votes >
(
    SELECT AVG(votes)
    FROM zomato
    WHERE location = 'BTM'
);



-- Q36. FIND LOCATIONS WHOSE AVERAGE VOTES ARE GREATER THAN THE OVERALL AVERAGE VOTES.


WITH location_avg AS
(
    SELECT
        location,
        AVG(votes) AS avg_votes
    FROM zomato
    GROUP BY location
)
SELECT *
FROM location_avg
WHERE avg_votes >
(
    SELECT AVG(votes)
    FROM zomato
);



-- Q37. FIND RESTAURANTS THAT HAVE MORE VOTES THAN THE AVERAGE OF THEIR OWN LOCATION.


WITH location_avg AS
(
    SELECT
        location,
        AVG(votes) AS avg_votes
    FROM zomato
    GROUP BY location
)
SELECT
    z.name,
    z.location,
    z.votes,
    l.avg_votes
FROM zomato z
JOIN location_avg l
    ON z.location = l.location
WHERE z.votes > l.avg_votes;



-- Q38. FIND THE TOP 5 LOCATIONS BASED ON AVERAGE RESTAURANT RATING.


WITH location_rating AS
(
    SELECT
        location,
        AVG(rate) AS avg_rating
    FROM zomato
    WHERE rate IS NOT NULL
    GROUP BY location
)
SELECT TOP 5 *
FROM location_rating
ORDER BY avg_rating DESC;



-- Q39. FIND RESTAURANTS THAT BELONG TO THE TOP 5 LOCATIONS BY TOTAL VOTES.


WITH top_locations AS
(
    SELECT TOP 5
        location,
        SUM(votes) AS total_votes
    FROM zomato
    GROUP BY location
    ORDER BY total_votes DESC
)
SELECT
    z.name,
    z.location,
    z.votes
FROM zomato z
JOIN top_locations t
    ON z.location = t.location;



-- Q40. FIND THE BEST-PERFORMING RESTAURANT IN EACH LOCATION BASED ON A COMBINED SCORE OF RATING AND VOTES.


WITH scored AS
(
    SELECT
        name,
        location,
        rate,
        votes,
        rate * LOG(votes + 1) AS performance_score
    FROM zomato
    WHERE rate IS NOT NULL
),
ranked AS
(
    SELECT *,
        ROW_NUMBER() OVER
        (
            PARTITION BY location
            ORDER BY performance_score DESC
        ) AS rn
    FROM scored
)
SELECT
    name,
    location,
    rate,
    votes,
    performance_score
FROM ranked
WHERE rn = 1;



-- Q41. CATEGORIZE RESTAURANTS BASED ON VOTES.


SELECT
    name,
    votes,
    CASE
        WHEN votes < 100 THEN 'Low'
        WHEN votes < 500 THEN 'Medium'
        WHEN votes < 1000 THEN 'High'
        ELSE 'Very High'
    END AS vote_category
FROM zomato;



-- Q42. CATEGORIZE RESTAURANTS BY RATING.


SELECT
    name,
    rate,
    CASE
        WHEN rate >= 4.5 THEN 'Excellent'
        WHEN rate >= 4.0 THEN 'Very Good'
        WHEN rate >= 3.5 THEN 'Good'
        WHEN rate >= 3.0 THEN 'Average'
        ELSE 'Poor'
    END AS rating_category
FROM zomato
WHERE rate IS NOT NULL;



-- Q43. CALCULATE THE PERCENTAGE OF RESTAURANTS ACCEPTING ONLINE ORDERS.


SELECT
    ROUND(
        100.0 *
        SUM(CASE WHEN online_order = 'Yes' THEN 1 ELSE 0 END)
        / COUNT(*),
        2
    ) AS online_order_percentage
FROM zomato;



-- Q44. CALCULATE ONLINE-ORDER ADOPTION BY LOCATION.


SELECT
    location,

    COUNT(*) AS total_restaurants,

    SUM(CASE
        WHEN online_order = 'Yes' THEN 1
        ELSE 0
    END) AS online_restaurants,

    ROUND(
        100.0 *
        SUM(CASE WHEN online_order = 'Yes' THEN 1 ELSE 0 END)
        / COUNT(*),
        2
    ) AS online_adoption_pct

FROM zomato
GROUP BY location
ORDER BY online_adoption_pct DESC;



-- Q45. CALCULATE TABLE-BOOKING ADOPTION BY LOCATION.


SELECT
    location,

    ROUND(
        100.0 *
        SUM(CASE WHEN book_table = 'Yes' THEN 1 ELSE 0 END)
        / COUNT(*),
        2
    ) AS table_booking_pct

FROM zomato
GROUP BY location
ORDER BY table_booking_pct DESC;



-- Q46. CLASSIFY RESTAURANTS INTO FOUR BUSINESS SEGMENTS BASED ON RATING AND VOTES.


SELECT
    name,
    rate,
    votes,

    CASE
        WHEN rate >= 4.0 AND votes >= 1000
            THEN 'Star Performer'

        WHEN rate >= 4.0 AND votes < 1000
            THEN 'High Rated - Low Reach'

        WHEN rate < 4.0 AND votes >= 1000
            THEN 'High Reach - Low Rated'

        ELSE 'Underperformer'
    END AS performance_segment

FROM zomato
WHERE rate IS NOT NULL;



-- Q47. CALCULATE THE PERCENTAGE OF RESTAURANTS IN EACH PERFORMANCE SEGMENT.


WITH x AS
(
    SELECT
        CASE
            WHEN rate >= 4.0 AND votes >= 1000
                THEN 'Star Performer'
            WHEN rate >= 4.0 AND votes < 1000
                THEN 'High Rated - Low Reach'
            WHEN rate < 4.0 AND votes >= 1000
                THEN 'High Reach - Low Rated'
            ELSE 'Underperformer'
        END AS segment
    FROM zomato
    WHERE rate IS NOT NULL
)
SELECT
    segment,
    COUNT(*) AS restaurant_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage_of_restaurants
FROM x
GROUP BY segment;



-- Q48. IDENTIFY RESTAURANTS THAT HAVE HIGH RATINGS BUT LOW CUSTOMER ENGAGEMENT.


WITH x AS
(
    SELECT
        name,
        location,
        rate,
        votes,
        PERCENTILE_CONT(0.25)
        WITHIN GROUP (ORDER BY votes)
        OVER () AS vote_25th_percentile
    FROM zomato
    WHERE rate IS NOT NULL
)
SELECT
    name,
    location,
    rate,
    votes
FROM x
WHERE rate >= 4
  AND votes < vote_25th_percentile;



-- Q49. IDENTIFY RESTAURANTS WITH HIGH VOTES BUT POOR RATINGS.


WITH x AS
(
    SELECT
        name,
        location,
        rate,
        votes,
        AVG(votes) OVER () AS avg_votes
    FROM zomato
    WHERE rate IS NOT NULL
)
SELECT
    name,
    location,
    rate,
    votes
FROM x
WHERE votes > avg_votes
  AND rate < 3.5;



-- Q50. CREATE AN OVERALL RESTAURANT PERFORMANCE SCORE USING 60% RATING AND 40% NORMALIZED VOTES.


WITH x AS
(
    SELECT
        name,
        location,
        rate,
        votes,

        100.0 * votes /
        MAX(votes) OVER () AS vote_score

    FROM zomato
    WHERE rate IS NOT NULL
)
SELECT
    name,
    location,
    rate,
    votes,

    ROUND(
        0.6 * (rate / 5.0 * 100)
        +
        0.4 * vote_score,
        2
    ) AS performance_score

FROM x
ORDER BY performance_score DESC;



-- Q51. FIND THE TOP 3 RESTAURANTS IN EVERY LOCATION BASED ON A COMBINATION OF RATING AND VOTES.


WITH x AS
(
    SELECT
        name,
        location,
        rate,
        votes,

        (
            0.6 * rate / 5.0 * 100
            +
            0.4 * 100.0 * votes /
            MAX(votes) OVER ()
        ) AS score

    FROM zomato
    WHERE rate IS NOT NULL
),
ranked AS
(
    SELECT *,
        ROW_NUMBER() OVER
        (
            PARTITION BY location
            ORDER BY score DESC
        ) AS rn
    FROM x
)
SELECT
    name,
    location,
    rate,
    votes,
    score
FROM ranked
WHERE rn <= 3
ORDER BY location, score DESC;



-- Q52. FIND LOCATIONS WITH HIGH RESTAURANT DENSITY BUT LOW AVERAGE RATINGS.


WITH location_stats AS
(
    SELECT
        location,
        COUNT(*) AS restaurant_count,
        AVG(rate) AS avg_rating
    FROM zomato
    WHERE rate IS NOT NULL
    GROUP BY location
)
SELECT *
FROM location_stats
WHERE restaurant_count >
(
    SELECT AVG(restaurant_count)
    FROM location_stats
)
AND avg_rating <
(
    SELECT AVG(rate)
    FROM zomato
    WHERE rate IS NOT NULL
);



-- Q53. FIND LOCATIONS WITH HIGH ONLINE-ORDER ADOPTION BUT LOW AVERAGE RATINGS.


WITH x AS
(
    SELECT
        location,

        AVG(rate) AS avg_rating,

        100.0 *
        SUM(CASE WHEN online_order = 'Yes' THEN 1 ELSE 0 END)
        / COUNT(*) AS online_adoption

    FROM zomato
    WHERE rate IS NOT NULL
    GROUP BY location
)
SELECT *
FROM x
WHERE online_adoption > 70
  AND avg_rating < 3.5
ORDER BY online_adoption DESC;



-- Q54. FIND RESTAURANTS WHOSE RATING IS HIGHER THAN THEIR LOCATION AVERAGE AND WHOSE VOTES ARE HIGHER THAN THEIR LOCATION AVERAGE.


WITH x AS
(
    SELECT
        name,
        location,
        rate,
        votes,

        AVG(rate) OVER
        (
            PARTITION BY location
        ) AS location_avg_rating,

        AVG(votes) OVER
        (
            PARTITION BY location
        ) AS location_avg_votes

    FROM zomato
    WHERE rate IS NOT NULL
)
SELECT
    name,
    location,
    rate,
    votes,
    location_avg_rating,
    location_avg_votes
FROM x
WHERE rate > location_avg_rating
  AND votes > location_avg_votes;



-- Q55. FIND THE PERCENTAGE OF RESTAURANTS IN EACH LOCATION THAT OUTPERFORM THEIR LOCATION'S AVERAGE RATING.


WITH x AS
(
    SELECT
        name,
        location,
        rate,

        AVG(rate) OVER
        (
            PARTITION BY location
        ) AS location_avg_rating

    FROM zomato
    WHERE rate IS NOT NULL
)
SELECT
    location,

    COUNT(*) AS total_restaurants,

    SUM(
        CASE
            WHEN rate > location_avg_rating THEN 1
            ELSE 0
        END
    ) AS above_average_restaurants,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN rate > location_avg_rating THEN 1
                ELSE 0
            END
        )
        / COUNT(*),
        2
    ) AS above_average_pct

FROM x
GROUP BY location
ORDER BY above_average_pct DESC;



-- Q56. FIND THE TOP CUISINE IN EACH LOCATION BASED ON TOTAL VOTES.


WITH x AS
(
    SELECT
        location,
        cuisines,
        SUM(votes) AS total_votes
    FROM zomato
    WHERE cuisines IS NOT NULL
    GROUP BY location, cuisines
),
ranked AS
(
    SELECT
        *,
        RANK() OVER
        (
            PARTITION BY location
            ORDER BY total_votes DESC
        ) AS rn
    FROM x
)
SELECT
    location,
    cuisines,
    total_votes
FROM ranked
WHERE rn = 1;



-- Q57. FIND LOCATIONS WHERE THE TOP 5 RESTAURANTS ACCOUNT FOR MORE THAN 30% OF ALL VOTES.


WITH ranked AS
(
    SELECT
        name,
        location,
        votes,

        ROW_NUMBER() OVER
        (
            PARTITION BY location
            ORDER BY votes DESC
        ) AS rn,

        SUM(votes) OVER
        (
            PARTITION BY location
        ) AS location_total_votes

    FROM zomato
),
top5 AS
(
    SELECT
        location,
        location_total_votes,
        SUM(votes) AS top5_votes
    FROM ranked
    WHERE rn <= 5
    GROUP BY location, location_total_votes
)
SELECT
    location,
    top5_votes,
    location_total_votes,

    ROUND(
        100.0 * top5_votes / location_total_votes,
        2
    ) AS top5_contribution_pct

FROM top5
WHERE 100.0 * top5_votes / location_total_votes > 30
ORDER BY top5_contribution_pct DESC;



-- Q58. IDENTIFY LOCATIONS WHERE RESTAURANTS WITH ONLINE ORDERING RECEIVE MORE AVERAGE VOTES THAN RESTAURANTS WITHOUT ONLINE ORDERING.


WITH x AS
(
    SELECT
        location,

        AVG(
            CASE
                WHEN online_order = 'Yes'
                THEN CAST(votes AS FLOAT)
            END
        ) AS online_avg_votes,

        AVG(
            CASE
                WHEN online_order = 'No'
                THEN CAST(votes AS FLOAT)
            END
        ) AS offline_avg_votes

    FROM zomato
    GROUP BY location
)
SELECT
    location,
    online_avg_votes,
    offline_avg_votes,

    online_avg_votes - offline_avg_votes
        AS vote_difference

FROM x
WHERE online_avg_votes > offline_avg_votes
ORDER BY vote_difference DESC;



-- Q59. IDENTIFY RESTAURANTS THAT ARE EXCEPTIONALLY SUCCESSFUL RELATIVE TO THEIR LOCATION.


WITH x AS
(
    SELECT
        name,
        location,
        rate,
        votes,

        PERCENTILE_CONT(0.90)
        WITHIN GROUP (ORDER BY rate)
        OVER
        (
            PARTITION BY location
        ) AS rating_90th,

        PERCENTILE_CONT(0.90)
        WITHIN GROUP (ORDER BY votes)
        OVER
        (
            PARTITION BY location
        ) AS votes_90th

    FROM zomato
    WHERE rate IS NOT NULL
)
SELECT
    name,
    location,
    rate,
    votes,
    rating_90th,
    votes_90th
FROM x
WHERE rate >= rating_90th
  AND votes >= votes_90th
ORDER BY location, votes DESC;



-- Q60. BUILD A ZOMATO RESTAURANT PERFORMANCE DATASET FOR A BUSINESS DASHBOARD.


WITH restaurant_metrics AS
(
    SELECT
        name,
        location,
        rate,
        votes,
        online_order,
        book_table,

        RANK() OVER
        (
            PARTITION BY location
            ORDER BY votes DESC
        ) AS location_rank,

        AVG(rate) OVER
        (
            PARTITION BY location
        ) AS location_avg_rating,

        AVG(votes) OVER
        (
            PARTITION BY location
        ) AS location_avg_votes,

        SUM(votes) OVER
        (
            PARTITION BY location
        ) AS location_total_votes

    FROM zomato
    WHERE rate IS NOT NULL
),
final_metrics AS
(
    SELECT
        *,
        
        rate - location_avg_rating
            AS rating_difference,

        votes - location_avg_votes
            AS vote_difference,

        ROUND(
            100.0 * votes / location_total_votes,
            2
        ) AS vote_contribution_pct

    FROM restaurant_metrics
)
SELECT
    name,
    location,
    rate,
    votes,
    location_rank,

    ROUND(location_avg_rating, 2)
        AS location_avg_rating,

    ROUND(location_avg_votes, 2)
        AS location_avg_votes,

    ROUND(rating_difference, 2)
        AS rating_difference,

    ROUND(vote_difference, 2)
        AS vote_difference,

    vote_contribution_pct,

    online_order,
    book_table,

    CASE

        WHEN rate >= 4.0
             AND votes >= location_avg_votes
            THEN 'Star Performer'

        WHEN rate >= 4.0
             AND votes < location_avg_votes
            THEN 'High Rated - Low Reach'

        WHEN rate < 4.0
             AND votes >= location_avg_votes
            THEN 'High Reach - Low Rated'

        ELSE 'Underperformer'

    END AS performance_segment

FROM final_metrics

ORDER BY
    location,
    location_rank;