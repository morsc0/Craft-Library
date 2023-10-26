####################################################################################
# Creates a craft library database to track crafting projects and materials.
# Insert sample data into each table.
# Designed for use in MySQL, with auto commit enabled
# V1.0 2023/10/25 by morsco
####################################################################################
# CONTENTS					ROW
# CREATE DATABASE			18
# CREATE TABLES				25 - 94
# CREATE VIEWS				96 - 132
# STORED FUNCTIONS			134 - 195
# STORED PROCEDURES			200 - 217
# TRIGGERS					219 - 236
# INSERT DATA INTO TABLES	238 - 359
# SAMPLE QUERIES			361 - 391
# FUTURE DEVELOPMENT IDEAS	397 - 402

####################################################################################
## Create database and tables
####################################################################################

CREATE DATABASE Craft_Library;
USE Craft_Library;

# Table statuses - records status of each project
CREATE TABLE Statuses (
	StatusID INT AUTO_INCREMENT PRIMARY KEY,
    StatusDescription VARCHAR(50)
);

# Table Craft_Types contains craft type descriptions
CREATE TABLE Craft_Types (
	CraftID INT PRIMARY KEY auto_increment,
    CraftName VARCHAR(50) NOT NULL
    );
    
# Table Material_Types contains materials descriptions
# And notes their standard unit of measurement
CREATE TABLE Material_Types (
	MT_ID INT auto_increment PRIMARY KEY,
    MT_Description VARCHAR(50),
	MT_Units CHAR(10)	
);

# A table of materials in stash
# UK wool is usually described in grams but length is also needed
CREATE TABLE Materials (
	MID INT AUTO_INCREMENT PRIMARY KEY,
    MType INT,
    MBrand VARCHAR(100),
    MBrandCode VARCHAR(20),
    MBrandWeight CHAR(10),
    MColour VARCHAR(50),
    MQTY CHAR(3),
    MWeight INT,
    MLength FLOAT,
    MWidth FLOAT,
    FOREIGN KEY (MType) REFERENCES Material_Types(MT_ID)
);

# Table Projects records all project details
CREATE TABLE Projects (
	PID int auto_increment PRIMARY KEY,
    PName VARCHAR(50) NOT NULL,
    Ctype INT, -- FK link to craft_type table
    PDescription VARCHAR(250),
    PLink VARCHAR(100),
    PAcquiredDate DATE,
    PStartDate DATE,
    PEndDate DATE,
    PStatus INT NOT NULL,
    FOREIGN KEY (Ctype) REFERENCES Craft_Types(CraftID),
    FOREIGN KEY (PStatus) REFERENCES Statuses(StatusID)
    );
    
#Table Sessions used to track time spent working on each project
CREATE TABLE Sessions (
	Session_ID int PRIMARY KEY auto_increment,
    Project_ID INT,
    Session_Start_DT DATETIME NOT NULL,
    Session_End_DT	DATETIME,
    Duration TIME,
    FOREIGN KEY (Project_ID) REFERENCES Projects(PID)
);

#Table ProjectMaterials used to record which materials are neede for each project    
CREATE TABLE ProjectMaterials (
	PMID INT PRIMARY KEY AUTO_INCREMENT,
	PID INT NOT NULL,
    MID int NOT NULL,
    QTY INT,
    FOREIGN KEY (PID) REFERENCES Projects(PID),
    FOREIGN KEY (MID) REFERENCES Materials(MID)
);

####################################################################################
## Views
####################################################################################

# View project list substituting IDs of crafts and statuses for their descriptions
# To make them easy to understand, references two tables
CREATE VIEW View_Project_Summary AS
	SELECT CraftName as "Craft", PName as "Project Name",  StatusDescription as "Status"
	FROM Projects
	LEFT JOIN craft_types
	ON 
	Projects.CType = Craft_Types.CraftID
    LEFT JOIN statuses
    ON Projects.PStatus = Statuses.StatusID
    ORDER BY Projects.Ctype, Projects.PStatus;
    
# View Project by status, grouped by craft type and ordered by project status.
# references 2 tables
CREATE VIEW View_Project_By_Status AS
	SELECT StatusDescription as "Status", PName as "Name", CraftName as "Craft", PAcquiredDate as "Date Acquired" 
	FROM Projects
	LEFT JOIN craft_types
	ON 
	Projects.CType = Craft_Types.CraftID
    LEFT JOIN statuses
    ON Projects.PStatus = Statuses.StatusID
    order by Projects.PStatus;
    
# This view substitutes IDs for descriptive names using 3 tables
CREATE VIEW View_Project_Full AS
	SELECT PID, PName as "Name", CraftName as "Craft", PAcquiredDate as "Date Acquired", StatusDescription as "Project Status" 
	FROM Projects
	LEFT JOIN craft_types
	ON 
	Projects.CType = Craft_Types.CraftID
    LEFT JOIN statuses
    ON Projects.PStatus = Statuses.StatusID;

####################################################################################
## Stored Functions
####################################################################################

# This function calculates the age of a project based on either the acquired date or, if
# there is no acquired date recorded, the start date. If neither date is recorded the value
# returned is 0.

DELIMITER //
# Function parameters are Projects.PAcquiredDate and Projects.PStartDate
CREATE FUNCTION project_age(
	AcqDate DATE,
    StartDate DATE
) 
RETURNS INT -- the function will return an integer (number of days)
DETERMINISTIC
BEGIN
	DECLARE age INT; -- declare a variable to hold the result of the calculation
    -- if an acquired date exists, calculate the number of days between then and now
    IF AcqDate IS NOT NULL THEN
        SET age = DATEDIFF(CURRENT_DATE(), AcqDate) ;  
	-- if there's no acquired date, use the start date
    ELSEIF StartDate IS NOT NULL THEN 
        SET age = DATEDIFF(CURRENT_DATE(), StartDate) ;
	-- if there's no start date, set the value to zero
	ELSEIF StartDate IS NULL THEN
		SET age = 0;
    END IF;
    RETURN (age);
END //
DELIMITER ;

## Example calling the stored function
# select PName, Project_Age(PAcquiredDate,PStartDate) as "Project Age (Days)"
# from projects;


## This function calculates the total time spent on a project by summing
## the duration field in the Sessions table.
DELIMITER //
# Function parameters is Projects.PID
CREATE FUNCTION Total_Time_Spent(
	ProjectID INT
) 
RETURNS VARCHAR(60) -- the function will return a string
DETERMINISTIC
BEGIN
	DECLARE TotalDuration VARCHAR(60); 
    -- sum the duration field for each session where the project ID matches the input parameter
    -- write the total to the TotalDuration variable
    SELECT Time_Format(Sum(Duration), "%h hours %i minutes") INTO TotalDuration
	FROM Sessions
    WHERE Sessions.Project_ID = ProjectID;    
    
    -- if TotalDuration is NULL ie no sessions have been recorded
    -- set the string to "not yet started"
    IF TotalDuration IS NULL THEN
		SET TotalDuration = "Not yet started.";
	END IF; 
    
    RETURN (TotalDuration);
END //

## Example of calling this function
# SELECT PName as "Name", Total_Time_Spent(PID) FROM Projects;
    
####################################################################################
## Stored Procedures
####################################################################################

# Show all completed projects determined by checking to see if there's a PEndDate
# or if the PStatus is set to complete.

DELIMITER //
CREATE PROCEDURE Proc_Complete_Projects() 
BEGIN
SELECT PID, PName AS "Name", CraftName, PEndDate AS "Date Completed", StatusDescription as "Status"
	FROM Projects
	LEFT JOIN craft_types ON 
	Projects.CType = Craft_Types.CraftID
    LEFT JOIN statuses ON 
    Projects.PStatus = Statuses.StatusID
    WHERE PEndDate IS NOT NULL OR PStatus = 5;
END //
DELIMITER ;

####################################################################################
## Triggers
## These triggers are not robust. Need to allow for sessions starting and ending on
## different days eg after midnight.
## Need to make sure that a time is entered and not just a date.
####################################################################################

# Trigger calculates the difference between the start time and end time when a new row
# is inserted.
CREATE TRIGGER calc_duration_insert
BEFORE INSERT ON Sessions
FOR EACH ROW SET NEW.Duration = TIMEDIFF(NEW.Session_End_DT, NEW.Session_Start_DT);

# Trigger calculates the difference between the start time and end time when a new row
# is updated.
CREATE TRIGGER calc_duration_update
BEFORE UPDATE ON Sessions
FOR EACH ROW SET NEW.Duration = TIMEDIFF(NEW.Session_End_DT, NEW.Session_Start_DT);

####################################################################################
## Insert sample data into tables
## All primary keys are auto incremented so no need to include that specific value
## in the insert statement
####################################################################################

INSERT INTO Statuses
	(StatusDescription)
    VALUES
    ("Queued"),
    ("In progress"),
    ("On hold"),
    ("Abandoned"),
    ("Complete");
    
INSERT INTO Craft_Types 
    (CraftName)
    VALUES 
    ("Crochet"),
    ("Knitting"),
    ("Cross stitch"),
    ("Embroidery"),
    ("Tapestry");
    
INSERT INTO Material_Types
	(MT_Description, MT_Units)
    VALUES
    ("Yarn","meters"),
    ("Floss","skeins"),
    ("Aida","sq cm");
    
INSERT INTO Materials 
    (MType, MBrand, MBrandCode, MBrandWeight, MColour, MQTY, MWeight, MLength, MWidth)
    VALUES
    (1,"Women's Institute", NULL, "DK", "Red", 3, 100, 250, NULL),
    (1, "James C Brett", NULL, "DK", "Summer Days Aurora", 4, 100, 345, NULL),
    (1, "Patons", "Fairytale Fab", "Aran", "Orchid", 2, 50, 100, NULL),
	(2, "DMC", "White", NULL, "White", 3, NULL, NULL, NULL),
    (2, "DMC", "310", NULL, "Black", 5, NULL, NULL, NULL),
    (2, "DMC", "311", NULL, "Blue - Medium", 1, NULL, NULL, NULL),
    (2, "DMC", "29", NULL, "Eggplant", 2, NULL, NULL, NULL),
    (2, "DMC", "150", NULL, "Red - Bright", 5, NULL, NULL, NULL),
    (2, "DMC", "699", NULL, "Green", 2, NULL, NULL, NULL),
    (2, "DMC", "451", NULL, "Shell Grey", 0, NULL, NULL, NULL),
    (2, "DMC", "823", NULL, "Blue - Dark", 0, NULL, NULL, NULL),
    (2, "DMC", "838", NULL, "Beige Brown - Very Dark
", 1, NULL, NULL, NULL),
    (2, "DMC", "S336", "Satin", "Blue", 3, NULL, NULL, NULL),
    (2, "DMC", "S602", "Satin", "Cranberry", 0, NULL, NULL, NULL),
    (2, "DMC", "E3852", "Metallic", "Gold", 1, NULL, NULL, NULL),
    (2, "DMC", "E990", "Neon", "Green", 3, NULL, NULL, NULL),
    (2, "DMC", "67", "Variegated", "Baby Bkye", 0, NULL, NULL, NULL),
    (3, "Hobbycraft", NULL, "14 ct", "White", 1, NULL, 30, 40),
    (3, "Hobbycraft", NULL, "16 ct", "Ivory", 1, NULL, 76, 91),
    (3, "Hobbycraft", NULL, "14 ct", "Black", 1, NULL, 30, 46);
     
INSERT INTO Projects 
	(Pname, CType, PDescription, PLink, PAcquiredDate, PStartDate, PEndDate, PStatus)
    VALUES
    ("Four Hour Chunky Sweater",1,"crochet top",'https://hearthookhome.com/four-hour-fall-sweater-free-crochet-pattern/
', NULL,'2023-10-16', NULL,2),
	("Basic V-Neck Sweater",1,null,"https://hearthookhome.com/basic-v-neck-sweater-free-crochet-pattern/",null, null, null,1),
    ("Love Tree",3,"Bothy Threads", NULL,'2016-11-01','2016-12-01','2023-06-01',5),
    ("Moira Blackburn Three Things Sampler Kit",3, NULL, NULL, '2020-08-01', '2020-11-24', NULL,2),
    ("Dumbo", 3, "Disney 100 Dumbo Mini Cross Stitch Kit", NULL, '2023-05-01','2023-05-02', '2023-05-04', 5),
    ("Feasting Frenzy", 3, "Dimensions Feasting Frenzy Counted Cross Stitch Kit", NULL, '2022-12-25','2022-12-25', NULL, 4),
    ("Mistletoe", 4, "Misteltoe mini embroidery kit", NULL, NULL, '2023-10-01', NULL, 1),
    ("Giraffe Kit", 4, "DMC Giraffe Printed Embroidery Kit", NULL, '2023-10-01', NULL, NULL,1)    ;

INSERT INTO Sessions
(Project_ID, Session_Start_DT, Session_End_DT)
VALUES
(1,"2023-10-16 20:00","2023-10-16 23:00"),
(1,"2023-10-17 10:30","2023-10-17 14:00"),
(1,"2023-10-17 15:00", "2023-10-17 18:00"),
(3,"2016-11-02 19:00", "2016-11-02 23:00"),
(3,"2016-11-03 18:00", "2016-11-03 23:00"),  
(3,"2016-11-04 19:00", "2016-11-04 23:00"),  
(3,"2016-11-06 19:00", "2016-11-06 22:00"),
(3,"2016-11-07 15:00", "2016-11-07 18:00"),
(3,"2016-11-10 19:00", "2016-11-10 23:00"),
(3,"2016-11-11 18:00", "2016-11-11 20:00"),
(3,"2016-11-25 19:00", "2016-11-25 21:00"),
(3,"2016-11-26 19:00", "2016-11-26 20:00"),
(3,"2016-12-02 19:00", "2016-12-02 20:00"),
(3,"2016-12-03 19:00", "2016-12-03 20:00"),
(3,"2016-12-04 19:00", "2016-12-04 21:00"),
(3,"2017-02-02 19:00", "2017-02-02 20:00"),
(3,"2017-02-03 19:00", "2017-02-03 21:00"),
(3,"2017-03-10 19:00", "2017-03-10 23:00"),
(3,"2017-08-25 19:00", "2017-08-25 20:00"),
(3,"2018-11-08 19:00", "2018-11-08 22:00"),
(3,"2018-11-09 19:00", "2018-11-09 22:00"),
(3,"2018-11-10 19:00", "2018-11-10 22:00"),
(3,"2020-04-14 10:00", "2020-04-14 16:00"),
(3,"2020-04-15 10:00", "2020-04-15 16:00"),
(3,"2020-04-16 10:00", "2020-04-16 20:00"),
(3,"2021-10-05 10:00", "2021-10-05 12:00"),
(3,"2021-10-06 10:00", "2021-10-06 12:00"),
(3,"2023-05-25 18:00", "2023-05-25 23:00"),
(3,"2023-05-26 18:00", "2023-05-26 23:00"),
(3,"2023-05-27 18:00", "2023-05-27 23:00"),
(3,"2023-06-01 18:00", "2023-06-01 23:00"),
(4,"2020-11-24 19:00", "2020-11-24 21:00"),
(4,"2020-11-25 19:00", "2020-11-25 21:00"),
(4,"2020-11-30 19:00", "2020-11-30 21:00"),
(5,"2023-05-03 19:00", "2023-05-03 21:00"),
(5,"2023-05-04 19:00", "2023-05-04 21:00"),
(6,"2022-12-25 18:00", "2022-12-25 19:00"),
(7,"2023-10-02 18:00", "2023-10-02 19:00");

INSERT INTO ProjectMaterials
(PID,MID,QTY)
VALUES
(1,3,4),
(2,2,4),
(2,2,2),
(3,4,2),
(3,5,5),
(3,11,1),
(3,12,1),
(3,18,1);

####################################################################################
## Example select statements
####################################################################################

## Example calling the stored function Project_Age
select PName, Project_Age(PAcquiredDate,PStartDate) as "Project Age (Days)" from projects;

## Example of calling stored function Total_Time_Spent
SELECT PName as "Name", Total_Time_Spent(PID) FROM Projects;

## Example of calling stored procedure Proc_Complete_Projects
CALL Proc_Complete_Projects();

# prepare an example query with a sub query
# selects all projects that use "Aida" in list of materials
SELECT DISTINCT PName as "Project Name"
FROM Projects
WHERE PID  IN 
	(SELECT PID 
	FROM ProjectMaterials
	WHERE MID IN (
		SELECT MID
		FROM Materials
		WHERE
		MType = 3
		)
	);

# query using group by and having
SELECT Count(CType) as "No. of Projects", CraftName FROM Projects
LEFT JOIN Craft_Types
ON Projects.Ctype = Craft_Types.CraftID
GROUP BY CraftName
HAVING Craft_Types.CraftName = "Crochet";

####################################################################################
## To Do - ideas for further development of project
####################################################################################
# Enforce date and time input in sessions table (not just date)
# Add trigger to update project status when project start date entered
# Add trigger to update project status when project end date entered
####################################################################################

####################################################################################
## end of file
####################################################################################