--SQL Queries

--Database Glossary
--- Tables used in this analysis:

 	--- Analytics: contains DCM data with session information and other metadata
 	--- Click: contains user information who clicked through the ad 
 	--- Activity: contains user information with associated activity on the website (users that didn’t  drop off)
	-- -Site_DCM: contains publisher/platform information
--- Data definitions:

 --- Considering Attributed users: Users that do not have a user ID = 0
 --Possible reasons for having no user ID: 
 	--User cleared cookies
	--User navigating site through Incognito or Private mode
 --Reason for using attributed user ids - essential for tracking user journey, if we have user IDs, we can track their click path across the website
	-- Publisher here would be Facebook/Instagram and Display/Programmatic
 --Rolling up all display partners into one since we are only trying to understand effectiveness based on Social vs. Programmatic
 --Site_ID_DCM '1736' corresponds to Fb/Instagram
 --Site_ID_DCM '2576' corresponds to Display/Programmatic
 --Considering the campaign run duration: '2018-04-11 00:00:00' AND '2018-07-07 23:59:59'

--Business Questions

	--# of users that visit the site by publisher – Attributed – unique user id count or total user id
	--Pull by user_id and Site_Name

--- Thought process: 

	--Considering Unique user id count or total user id
	--First, finding the users with click activity across the two publishers: FB/Instagram and Display/Programmatic
	--Next, generating the distinct user count across the two publishers (Fb/Instagram and Programmatic) 

--- Query: 

Select Count(Distinct c.User_ID ) , s.Site_Name   FROM
	(
	Select * from 
	'DCM_<client>_ddm_dt_v2.A_Click_EST'
	where User_ID <> '0'
	and _EST_Event_Time between '2018-04-11 00:00:00' AND '2018-07-07 23:59:59'
	and Site_ID_DCM in ('1736', '2576') 
	)  as c
Inner join 'DCM_<client>_ddm_dt_v2.A_Site_DCM_EST' as s
On c.Site_ID_DCM = s.Site_ID_DCM 
Group by  s.Site_Name
Order By Count(Distinct c.User_ID) Desc;


	--# of users dropping off post click

--- Thought process: 

	---Considering attributed users (with user id <> 0) so that we can get a 1:1 comparison to use trackable users across the website
	---First, finding users that have clicks and associated activity 
	---Next, exclude these user ids from the Click table to get the users that dropped off
	---Dropped off users in this case are the user ids that are present in the Click table but not in the Activity table since they did not interact with the website in any capacity and hence, do not have a logged activity line item
	---Final step: Inner join with the Site DCM table to grab the Site Name for only those users who performed the click on these two platforms  (Fb and Programmatic)

--- Query:

Select count(Distinct c1.User_ID), s.Site_Name 
from 
	(Select * from 'DCM_<client>_ddm_dt_v2.A_Click_EST'  
	where User_ID <> '0' 
	and _EST_Event_Time between '2018-04-11 00:00:00' AND '2018-07-07 23:59:59' 
	and Site_ID_DCM in ('1736', '2576') 
	) c1
Inner join 'DCM_<client>_ddm_dt_v2.A_Site_DCM_EST' as s
On c1.Site_ID_DCM = s.Site_ID_DCM 
where c1.User_ID not in
	(Select Distinct c. User_ID
	FROM 
		(Select * from 'DCM_<client>_ddm_dt_v2.A_Click_EST'  
		where User_ID <> '0' 
		and _EST_Event_Time between '2018-04-11 00:00:00' AND '2018-07-07 23:59:59' 
		and Site_ID_DCM in ('1736', '2576') 
		) as  c
	Inner join 
	(Select * from 'DCM_<client>_ddm_dt_v2.A_Activity_EST' 
	where User_ID <> '0'
	and _EST_Event_Time between '2018-04-11 00:00:00' AND '2018-07-07 23:59:59') as a
	ON c.User_ID = a.User_ID) as f
Group by s.Site_Name
Order By count(Distinct c1.User_ID) Desc;

	--Time spent on site by user- no zero user ids

--- Thought process:
 
	---First, finding users with click activity on the website (from Click table) across Fb and Display/Programmatic 
	---Next, finding the session end time for the above attributed users who performed a click
	---Final step: finding the Difference between the event time (from Click table) and the session end time (from Analytics table) and averaging it out across the two platforms 

--- Query:

Select f.Site_ID_DCM, AVG(f.Session_Duration) as Avg_Session_Duration
from
	(
	Select c.Site_ID_DCM,  DATETIME_DIFF (c._EST_EVENT_TIME, a.Time_End, Minute) AS Session_Duration
	from 
		(
		Select * from 'DCM_<client>_ddm_dt_v2.A_Click_EST'  
		where User_ID <> '0' 
		and _EST_Event_Time between '2018-04-11 00:00:00' AND '2018-07-07 23:59:59' 
		and Site_ID_DCM in ('1736', '2576')
		) as c
	INNER JOIN 
		(
		Select * from 'DCM_Analytics' 
		where User_ID <> '0'
		and Time_End between '2018-04-11 00:00:00' AND '2018-07-07 23:59:59'
		) as a
	ON c.session_id = a.session_id
	) as f
Group by f.Site_ID_DCM;

	---Top 5 pages visited on the website

--- Thought process: 

	--- First, finding the distinct count of users (coming through FB and Programmatic) with associated   activity across each page
	--- Next, ranking the pages based on the count of distinct users with rank 1 for the page with largest  count
	--- Final step: selecting the top 5 pages based on top 5 ranks  

--- Query:

Select  f2.Page_ID, f2.User_Count
from
	(Select f.Page_ID, f.User_Count, 
	row_number() over(order by f.User_Count desc) as Page_Rank
	from
		(
		Select count(Distinct c.User_ID) as User_Count, a.Page_ID 
		from 
			(Select * from 'DCM_<client>_ddm_dt_v2.A_Click_EST'  
			where User_ID <> '0' 
			and _EST_Event_Time between '2018-04-11 00:00:00' AND '2018-07-07 23:59:59' 
			and Site_ID_DCM in ('1736', '2576') 
			) as  c
		Inner join 
			(Select * from 'DCM_<client>_ddm_dt_v2.A_Activity_EST' 
			where User_ID <> '0'
			and _EST_Event_Time between '2018-04-11 00:00:00' AND '2018-07-07 23:59:59') as a
		ON c.User_ID = a.User_ID
		Group by a.Page_ID
		Order by count(Distinct c.User_ID) desc
		) as f
	) as f2
where f2.Page_Rank <=5;

	---Audience Overlap Across Partners (Slide 9 in deck)

--- Thought process: 

	--- Considering Attributed users: No zero user ids 
	--- Three step output: 
		---First, finding distinct user count by Display/Programmatic only: save output as a table and then run a simple count function
		---Next, did the same step for FB/Instagram: saved output as a table and then run a simple count function
		---Final step: write a query to find the overlapping users across the two platforms- save output as a table and then run a count function

---Below is the query for finding the overlapping audience output:
--- Query:

Select count(Distinct a.User_ID)
from
	(Select User_ID
	from 'DCM_<client>_ddm_dt_v2.A_Click_EST'  
  	where user_id <> '0' 
  	and _EST_Event_Time between '2018-04-11 00:00:00' AND '2018-07-07  23:59:59' 
  	and Site_ID_DCM in ('1736') 
	) as a
Inner join
	(Select User_ID 
	from 'DCM_<client>_ddm_dt_v2.A_Click_EST'  
    where user_id <> '0' 
    and _EST_Event_Time between '2018-04-11 00:00:00' AND '2018-07-07 23:59:59' 
	and Site_ID_DCM in ('2576') 
	) as b
ON a.User_ID = b.User_ID;

