CraftLibrary.sql README

Project Title: CraftLibrary

Project Description: The database is designed for individuals to track their craft projects. It includes a record of materials already owned, links to pattern details, logging craft sessions (start and end datetimes). 

Project is part of the Code First Girls (https://codefirstgirls.com/) Data and SQL introductory course. The course was taught using MySQL. The project was built to meet specific project requirements.

The CraftLibrary.sql file contains all data required to build the database, add functions, procedures and triggers, and input sample data.

Core requirements:
* Create relational DB of your choice with minimum 5 tables
* Set Primary and Foreign Key constraints to create relations between the tables
* Using any type of the joins create a view that combines multiple tables in a logical way
* In your database, create a stored function that can be applied to a query in your DB
* Prepare an example query with a subquery to demonstrate how to extract data from your DB for analysis 
* Create DB diagram where all table relations are shown

Advanced requirements: (2 - 3 required)
* create a stored procedure and demonstrate how it runs
* create a trigger and demonstrate how it runs
* create an event and demonstrate how it runs
* Create a view that uses at least 3-4 base tables; prepare and demonstrate a query that uses the view to produce a logically arranged result set for analysis.
* Prepare an example query with group by and having to demonstrate how to extract data from your DB for analysis 

Further Detail:
Stored Functions
- project_age, calculates the number of days since the project was either acquired or started using ELSEIFs, DATEDIFF, DECLARE, and SET. Returns days as an integer.
- total_time_spent, calculates the total time spent working on the project by summing the session duration for each project and uses TIME_FORMAT, SUM, DECLARE, SET returns time spent as a text string "x hours and y minutes"

Stored Procedure
- Proc_Complete_Projects, selects projects identified as complete by using either the project end date, or the project status if that date doesn't exist. Uses joins on 3 tables.

Triggers
- calc_duration_insert, when a new session record is inserted this trigger calculates duration of session using BEFORE INSERT, TIMEDIFF. Scenario is a user enters start and end dates in one go.
- calc_duartion_update, when a session record is updated this trigger calculates duration of session using BEFORE UPDATE, TIMEDIFF. Scenario user adds an end date to an existion record that contains a start date.

Example Select Queries
In addition to calling above functions there is a query which contains a subquery (designed to meet course requirements) and a query that uses both GROUP BY and HAVING.

Future Development 
# Enforce date and time input in sessions table (not just date)
# Add trigger to update project status when project start date entered
# Add trigger to update project status when project end date entered

Licensing
GNU General Public License v3.0
https://choosealicense.com/licenses/gpl-3.0/
