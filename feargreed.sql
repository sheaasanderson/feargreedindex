use feargreed;
 
## ADDING CATEGORY DATA
## Creating table that includes a categorization of the FGI values (i.e. 'Extreme Fear', 'Fear', etc.)
CREATE TABLE fg_categories (
    ID INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    Date DATE NOT NULL,
    Fear_Greed INT NOT NULL,
    Category VARCHAR(255) NOT NULL
);


## Adding category identifiers based on FGI value
insert into fg_categories (Date, Fear_Greed, Category)
select
	distinct Date,
    Fear_Greed,
	case
		when Fear_Greed > 0 and Fear_Greed <= 25 then 'Extreme Fear'
        when Fear_Greed > 25 and Fear_Greed <= 45 then 'Fear'
        when Fear_Greed > 45 and Fear_Greed <= 55 then 'Neutral'
        when Fear_Greed > 55 and Fear_Greed <= 75 then 'Greed'
        when Fear_Greed > 75 then 'Extreme Greed'
        else 0 end as Category
from feargreed_master;



 ## ADDING CATEGORY STREAK DATA  
##Creating view that includes start dates of category streaks and grouping by streak 
CREATE VIEW streak_start AS
	SELECT
	s.ID,
    s.Date,
    s.Fear_Greed,
    s.Category,
    s.start_of_streak,
    count(s.start_of_streak) over (order by ID) as grp
FROM (
	SELECT 
		ID,
		Date,
		Fear_Greed,
		Category,
		(case when ID = 1 or Category <> lag(Category, 1) over (order by ID) then Date
        else null end) as start_of_streak
	from fg_categories) s
ORDER BY ID;


## Adding column to count how long each streak lasts and saving as a view
create view streak_start_count AS
SELECT 
	*,
    count(grp) over (partition by grp) as streak_length,
    row_number() over (partition by grp) as grp_row_num
FROM feargreed.streak_start;


## Creating new view to include column that shows how many days remaining in each streak for future analysis
CREATE VIEW streak_comp AS
    SELECT 
        *, (streak_length - grp_row_num) AS days_remaining
    FROM
        streak_start_count;


## Creating a table that includes streak start dates for every dated entry
CREATE TABLE category_streaks (
    ID INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    Date DATE NOT NULL,
    Fear_Greed INT NOT NULL,
    Category VARCHAR(255) NOT NULL,
    Streak_Start_Date DATE NOT NULL
);

insert into category_streaks (ID, Date, Fear_Greed, Category, Streak_Start_Date)
select
	ID,
    Date,
    Fear_Greed,
    Category,
    first_value(start_of_streak) over (partition by grp order by ID) as Streak_Start_Date
from feargreed.streak_start;



## ADDING S&P DATA
## Importing S&P data and adding max high/min low columns per streak
CREATE VIEW merged_data AS
select 
	m.*,
    max(High) over (partition by Streak_Start_Date) as Max_High,
    min(Low) over (partition by Streak_Start_Date) as Min_Low
from (
select 
	c.ID,
    c.Date,
    c.Fear_Greed,
    c.Category,
    c.Streak_Start_Date,
    s.High,
    s.Low
from category_streaks c
left join sp_historical s
	on c.Date = s.Date) m;


## Adding 'max high date' and 'min low date' column for easy reference later one
CREATE TABLE maxmindates_comp AS SELECT *,
    CASE
        WHEN max_high = high THEN Date
        ELSE NULL
    END AS Max_High_Date,
    CASE
        WHEN min_low = low THEN Date
        ELSE NULL
    END AS Min_Low_Date FROM
    feargreed.merged_data;



## CREATING FEAR + GREED TABLES WITH ALL STREAK DATA
## Creating fear table that includes column to mark how many days into streak the min low occurs
CREATE TABLE num_days_in_fear AS SELECT m.ID,
    m.Category,
    m.Date,
    m.Streak_Start_Date,
    m.Min_Low AS Streak_Low,
    s.streak_length - s.days_remaining AS Num_Days_Into_Streak,
    s.streak_length AS Streak_Length FROM
    maxmindates_comp m
        LEFT JOIN
    streak_comp s ON m.Date = s.Date AND m.ID = s.ID
WHERE
    m.category IN ('Extreme Fear' , 'Fear')
        AND m.Min_Low_Date IS NOT NULL;


## Creating greed table that includes column to mark how many days into streak the max high occurs
CREATE TABLE num_days_in_greed AS SELECT m.ID,
    m.Category,
    m.Date,
    m.Streak_Start_Date,
    m.Max_High AS Streak_High,
    s.streak_length - s.days_remaining AS Num_Days_Into_Streak,
    s.streak_length AS Streak_Length FROM
    maxmindates_comp m
        LEFT JOIN
    streak_comp s ON m.Date = s.Date AND m.ID = s.ID
WHERE
    m.category IN ('Extreme Greed' , 'Greed')
        AND m.Max_High_Date IS NOT NULL;




-- BEGIN ANALYZATION --
## Figuring out how long the market has been in extreme states, on average
SELECT 
    category,
    ROUND(((COUNT(category) / 3055) * 100), 1) AS percent_total
FROM
    category_streaks
WHERE
    category IN ('Extreme Fear' , 'Extreme Greed')
GROUP BY 1;
-- The market is in 'Extreme Fear' 17.5% of the time (over the last 12 years)
-- The market is in 'Extreme Greed' 9.4% of the time
-- The market is in an extreme state ~27% of the time


## LOOKING AT 'EXTREME GREED'
## Calculating when the S&P max highs occur within 'Extreme Greed' streaks
SELECT 
    num_days_into_streak,
    COUNT(num_days_into_streak) AS occurrence_count,
    ROUND(((COUNT(num_days_into_streak) / 40) * 100),
            1) AS percent_total
FROM
    num_days_in_greed
WHERE
    category = 'Extreme Greed'
GROUP BY 1
ORDER BY 3 DESC;
-- 1 day (a.k.a. the day the streak starts) is the most common occurrence at 22.5%
-- The top 3 occurences are: 1 (22.5%), 2 (17.5%), 4 (10%), and 6 days (10%)
-- 52.5% of the highest S&P highs occur within 3 days of entering 'Extreme Greed' (58% for 'Greed')
-- 75% of the highest S&P highs occur with one week of entering 'Extreme Greed' (77.5% for 'Greed')


## Creating condensed streak table to show how long each streak lasted
CREATE TABLE streak_lengths AS SELECT grp AS Streak_Num, Category, COUNT(grp) AS Streak_Length FROM
    streak_start
GROUP BY 1 , 2
ORDER BY 1;

## Calculating average length for 'Extreme Greed' streaks
SELECT 
    AVG(streak_length) AS avg_streak_length
FROM
    streak_lengths
WHERE
    category = 'Extreme Greed';
-- Average streak length for "Extreme Greed" cycles is 7.4 days


## Finding which streak lengths are most common for 'Extreme Greed' and how long they last
SELECT 
    category,
    streak_length,
    COUNT(streak_length) AS num_occurrences,
    ROUND(100 * (COUNT(streak_length) / 39), 1) AS percent_total
FROM
    streak_lengths
WHERE
    category = 'Extreme Greed'
GROUP BY 1 , 2
ORDER BY 1 , 3 DESC;
-- Most common streak length in Extreme Greed are 2 (25.6%), 1 (10.3%), 6 (10.3%), and 5 days (10.3%)
-- 71.9% of streaks last < 7 days


## LOOKING AT 'EXTREME FEAR'
## Calculating when the S&P max highs occur within 'Extreme Fear' streaks
SELECT 
    num_days_into_streak,
    COUNT(num_days_into_streak) AS occurrence_count,
    ROUND(((COUNT(num_days_into_streak) / 66) * 100),
            1) AS percent_total
FROM
    num_days_in_fear
WHERE
    category = 'Extreme Fear'
GROUP BY 1
ORDER BY 3 DESC;
-- 1 day is the most common occurrence at 34.8%
-- The top 3 occurences are: 1 (34.8%), 2 (16.7%), and 6 days (9.1%)
-- 56% of the lowest S&P lows occur within 3 days of entering 'Extreme Fear' (76.8% for 'Fear')
-- 83.3% of the lowest S&P lows occur with one week of entering 'Extreme Fear' (90% for 'Fear')


## Calculating average length for 'Extreme Fear' streaks
SELECT 
    AVG(streak_length) AS avg_streak_length
FROM
    streak_lengths
WHERE
    category = 'Extreme Fear';
-- Average streak length for "Extreme Fear" cycles is 8.1 days


## Finding which streak lengths are most common for 'Extreme Fear' and how long they last
SELECT 
    category,
    streak_length,
    COUNT(streak_length) AS num_occurrences,
    ROUND(100 * (COUNT(streak_length) / 66), 1) AS percent_total
FROM
    streak_lengths
WHERE
    category = 'Extreme Fear'
GROUP BY 1 , 2
ORDER BY 2;
-- Most common streak length in Extreme Fear are 1 (21.2%), 2 (12.1%), 3 (9.1%), and 4 days (9.1%)
-- 66.6% of streaks last <= 7 days
