
-- ========================================================================
-- 📌 1. SETUP: Use the Appropriate Database for the Analysis
-- ========================================================================
USE TelcoChurnDB;

-- The dataset was imported via the 'Import Flat File' wizard and saved as Staging_Telco.

-- =========================================================================
-- 📌 2. DATA PREVIEW: View the First Few Rows of the Staging_Telco Dataset
-- =========================================================================
SELECT TOP 5 *
FROM Staging_Telco;

-- =========================================================================
-- 📌 3. TABLE NORMALISATION: Create Normalised Tables from Staging_Telco
-- =========================================================================
CREATE TABLE Customers (
	CustomerID NVARCHAR(20) PRIMARY KEY,
	Gender NVARCHAR(10),
	SeniorCitizen BIT,
	Partner BIT,
	Dependents BIT
);

CREATE TABLE Contracts (
	ContractID INT IDENTITY(1,1) PRIMARY KEY,
	CustomerID NVARCHAR(20),
	ContractType NVARCHAR(50),
	Tenure INT,
	PaperlessBilling NVARCHAR(10),
	FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID) ON DELETE CASCADE
);

CREATE TABLE Services (
	ServicesID INT IDENTITY(1,1) PRIMARY KEY,
	CustomerID NVARCHAR(20),
	PhoneService NVARCHAR(5),
	MultipleLines NVARCHAR(30),
	InternetService NVARCHAR(20),
	OnlineSecurity NVARCHAR(30),
	OnlineBackup NVARCHAR(30),
	DeviceProtection NVARCHAR(30),
	TechSupport NVARCHAR(30),
	StreamingTV NVARCHAR(30),
	StreamingMovies NVARCHAR(30),
	FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID) ON DELETE CASCADE
);

CREATE TABLE Billings (
	BillingID INT IDENTITY(1,1) PRIMARY KEY,
	CustomerID NVARCHAR(20),
	PaymentMethod NVARCHAR(30),
	MonthlyCharges DECIMAL(10,2),
	TotalCharges DECIMAL(10,2),
	FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID) ON DELETE CASCADE
);

CREATE TABLE Churn (
	ChurnID INT IDENTITY(1,1) PRIMARY KEY,
	CustomerID NVARCHAR(20),
	Churn NVARCHAR(10),
	FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID) ON DELETE CASCADE
);

-- =========================================================================
-- 📌 4. DATA INSERTION: Populate Normalised Tables
-- =========================================================================
INSERT INTO Customers (CustomerID, Gender, SeniorCitizen, Partner, Dependents)
SELECT CustomerID, Gender, 
       TRY_CAST(SeniorCitizen AS BIT),
       CASE WHEN Partner = 'Yes' THEN 1 ELSE 0 END,
       CASE WHEN Dependents = 'Yes' THEN 1 ELSE 0 END
FROM Staging_Telco;

INSERT INTO Contracts (CustomerID, ContractType, Tenure, PaperlessBilling)
SELECT CustomerID, Contract, Tenure, PaperlessBilling
FROM Staging_Telco;

INSERT INTO Services (CustomerID, PhoneService, MultipleLines, InternetService, 
                      OnlineSecurity, OnlineBackup, DeviceProtection, TechSupport, 
                      StreamingTV, StreamingMovies)
SELECT CustomerID, PhoneService, MultipleLines, InternetService, 
       OnlineSecurity, OnlineBackup, DeviceProtection, TechSupport, 
       StreamingTV, StreamingMovies
FROM Staging_Telco;

INSERT INTO Billings (CustomerID, PaymentMethod, MonthlyCharges, TotalCharges)
SELECT CustomerID, PaymentMethod,
       TRY_CAST(MonthlyCharges AS DECIMAL(10,2)),
       CASE 
           WHEN LTRIM(RTRIM(TotalCharges)) = '' THEN NULL 
           ELSE TRY_CAST(TotalCharges AS DECIMAL(10,2)) 
       END
FROM Staging_Telco;

INSERT INTO Churn (CustomerID, Churn)
SELECT CustomerID, Churn
FROM Staging_Telco;

-- =========================================================================
-- 📌 5. NORMALISATION VALIDATION: Checking for Normalisation
-- =========================================================================
SELECT COUNT(*) AS NumberOfCustomers FROM Customers;
SELECT COUNT(*) AS NumberOfContracts FROM Contracts;
SELECT COUNT(*) AS NumberOfServices FROM Services;
SELECT COUNT(*) AS NumberOfBillings FROM Billings;
SELECT COUNT(*) AS NumberOfChurn FROM Churn;

-- Join normalised tables and check results
SELECT c.CustomerID, c.ContractType, b.TotalCharges
FROM Contracts AS c
JOIN Billings AS b
ON c.CustomerID = b.CustomerID
ORDER BY b.TotalCharges DESC;

-- =========================================================================
-- 📌 6. DATA VALIDATION: Checking for Data Issues
-- =========================================================================
DROP PROCEDURE IF EXISTS dbo.CheckNullValues;
GO

-- Create a stored procedure to check for null values
CREATE PROCEDURE CheckNullValues (@TableName NVARCHAR(100))
AS
BEGIN
    DECLARE @sql NVARCHAR(MAX) = '';

    -- Generate dynamic SQL to check NULL and blank values
    SELECT @sql = @sql + 
        'SELECT ''' + COLUMN_NAME + ''' AS ColumnName, 
                COUNT(*) AS NumberOfNullValues 
        FROM ' + QUOTENAME(@TableName) + ' 
        WHERE ' + COLUMN_NAME + ' IS NULL 
        OR (' + COLUMN_NAME + ' IS NOT NULL AND LTRIM(RTRIM(CAST(' + COLUMN_NAME + ' AS NVARCHAR))) = '''') UNION ALL '
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = @TableName;
    
    -- Remove last "UNION ALL"
    SET @sql = LEFT(@sql, LEN(@sql) - 10);

    EXEC sp_executesql @sql;
END;
GO

-- Apply the stored procedure to all tables
EXEC CheckNullValues 'Customers';
EXEC CheckNullValues 'Contracts';
EXEC CheckNullValues 'Services';
EXEC CheckNullValues 'Billings';
EXEC CheckNullValues 'Churn';

-- Understand why there are missing values TotalCharges
SELECT 
	s.CustomerID, 
	s.TotalCharges, 
	s.MonthlyCharges, 
	s.Tenure, 
	c.ContractType
FROM Staging_Telco s
LEFT JOIN Contracts c ON s.CustomerID = c.CustomerID
WHERE LTRIM(RTRIM(s.TotalCharges)) = '' 
   OR TRY_CAST(s.TotalCharges AS DECIMAL(10,2)) IS NULL;
 
-- The 11 customers with 0 Tenure could mean that they're new customers who haven't been billed yet.
-- So, since they haven't been billed, they haven't made any payments, which is likely why their TotalCharges is NULL.

-- They have valid MonthlyCharges, indicating they are active customers, just not billed yet.

-- Their contract type as 'Two year' and 'One year' means they may have just signed up and billing starts later.

-- If we convert these NULL values to 0.00 (billed but amount was zero or haven't been billed so system defaulted to 0.00), it could mislead our analysis.
-- In reality, these customers haven't been billed at all, so NULL better represents that more accurately. It ensured data integrity.

-- =========================================================================
-- 📌 7. EXPLORATORY DATA ANALYSIS (EDA)
-- =========================================================================
-- UNDERSTANDING CUSTOMERS & CONTRACTS
-- ✅ How many customers do we have?
SELECT COUNT(*) AS TotalCustomers FROM Customers;

-- ✅ Distribution by Contract Type
SELECT 
	ContractType, 
	COUNT(*) AS NumberOfCustomers
FROM Contracts
GROUP BY ContractType;

-- ✅ Average Monthly Charges per Contract Type
SELECT 
	c.ContractType, 
	FORMAT(
		AVG(b.MonthlyCharges), 'N2'
	) AS AverageMonthlyCharges
FROM Contracts c
JOIN Billings b 
	ON c.CustomerID = b.CustomerID
GROUP BY c.ContractType;

-- UNDERSTANDING RVENUE & BILLING
-- ✅ Total Revenue from all billed customers
SELECT 
	SUM(TotalCharges) AS TotalRevenue 
FROM Billings 
WHERE TotalCharges IS NOT NULL;

-- ✅ Average revenue per customer
SELECT 
	AVG(TotalCharges) AS AvgRevenue 
FROM Billings 
WHERE TotalCharges IS NOT NULL;

-- ✅ Which Payment Method is most popular?
SELECT 
	PaymentMethod, 
	COUNT(*) AS NumberOfCustomers
FROM Billings 
GROUP BY PaymentMethod
ORDER BY NumberOfCustomers DESC;

-- =========================================================================
-- 📌 8. CHURN ANALYSIS
-- =========================================================================
-- The goal is to find out the key factors driving churn and key patterns.

-- ✅ What is the overall churn rate?
SELECT 
    FORMAT(
        (COUNT(CASE WHEN Churn = 'Yes' THEN 1 END) * 100.0) / COUNT(*),
        'N2'
    ) AS ChurnRate
FROM Churn;

-- ✅ Churn Rate by Contract Type
SELECT 
	c.ContractType, 
	COUNT(ch.CustomerID) AS TotalCustomers, 
    FORMAT(
		COUNT(CASE WHEN ch.Churn = 'Yes' THEN 1 END) * 100.0 / COUNT(*), 'N2'
	) AS ChurnRate
FROM Contracts c
JOIN Churn ch 
	ON c.CustomerID = ch.CustomerID
GROUP BY c.ContractType;

-- ✅ Churn Rate by Monthly Charges
WITH SpendingCTE AS (
    SELECT 
        b.CustomerID,
        MonthlyCharges,
        Churn,
        CASE 
            WHEN MonthlyCharges < 30 THEN 'Low Spend (<$30)'
            WHEN MonthlyCharges BETWEEN 30 AND 70 THEN 'Medium Spend ($30-$70)'
            ELSE 'High Spend (>$70)' 
        END AS SpendingCategory
    FROM Billings b
    JOIN Churn ch 
		ON b.CustomerID = ch.CustomerID
)
SELECT 
	SpendingCategory, 
    COUNT(*) AS TotalCustomers, 
    FORMAT(
		COUNT(CASE WHEN Churn = 'Yes' THEN 1 END) * 100.0 / COUNT(*), 'N2'
	) AS ChurnRate
FROM SpendingCTE
GROUP BY SpendingCategory;

-- ✅ What internet services impact churn the most?
SELECT 
    s.InternetService, 
    COUNT(CASE WHEN ch.Churn = 'Yes' THEN 1 END) AS ChurnedUsers,
    FORMAT(
		COUNT(CASE WHEN ch.Churn = 'Yes' THEN 1 END) * 100.0 / COUNT(*), 'N2'
	) AS ChurnRate
FROM Services s
JOIN Churn ch 
	ON s.CustomerID = ch.CustomerID
GROUP BY s.InternetService
ORDER BY ChurnRate DESC;

-- ✅ Churn Rate based on Gender
SELECT 
	Gender, 
    COUNT(*) AS TotalCustomers, 
    COUNT(CASE WHEN Churn = 'Yes' THEN 1 END) AS ChurnedCustomers,
    FORMAT(
		COUNT(CASE WHEN Churn = 'Yes' THEN 1 END) * 100.0 / COUNT(*), 'N2'
	) AS ChurnRate
FROM Customers c
JOIN Churn ch 
	ON c.CustomerID = ch.CustomerID
GROUP BY Gender;

-- ✅ Churn Rate by Payment Method
SELECT 
	b.PaymentMethod, 
    COUNT(*) AS TotalCustomers, 
    COUNT(CASE WHEN ch.Churn = 'Yes' THEN 1 END) AS ChurnedCustomers,
    FORMAT(
		COUNT(CASE WHEN ch.Churn = 'Yes' THEN 1 END) * 100.0 / COUNT(*), 'N2'
	) AS ChurnRate
FROM Billings b
JOIN Churn ch 
	ON b.CustomerID = ch.CustomerID
GROUP BY b.PaymentMethod
ORDER BY ChurnRate DESC;

-- ✅ Senior Citizens and Churn
SELECT 
	SeniorCitizen, 
    COUNT(*) AS TotalCustomers, 
    COUNT(CASE WHEN Churn = 'Yes' THEN 1 END) AS ChurnedCustomers,
    FORMAT(
		COUNT(CASE WHEN Churn = 'Yes' THEN 1 END) * 100.0 / COUNT(*), 'N2'
	) AS ChurnRate
FROM Customers c
JOIN Churn ch 
	ON c.CustomerID = ch.CustomerID
GROUP BY SeniorCitizen;

-- ✅ Churn Rate for Customers Without Internet Services
SELECT 
	s.InternetService, 
    COUNT(*) AS TotalCustomers, 
    COUNT(CASE WHEN ch.Churn = 'Yes' THEN 1 END) AS ChurnedCustomers,
    FORMAT(
		COUNT(CASE WHEN ch.Churn = 'Yes' THEN 1 END) * 100.0 / COUNT(*), 'N2
	') AS ChurnRate
FROM Services s
JOIN Churn ch 
	ON s.CustomerID = ch.CustomerID
GROUP BY s.InternetService;

-- ✅ Do Senior Citizens Using Electronic Checks Churn at a Higher Rate?
SELECT
    COUNT(*) AS TotalSeniorCustomers, 
    COUNT(CASE WHEN ch.Churn = 'Yes' THEN 1 END) AS SeniorChurnedCustomers,
    FORMAT(COUNT(CASE WHEN ch.Churn = 'Yes' THEN 1 END) * 100.0 / COUNT(*), 'N2') AS ChurnRate
FROM Customers c
JOIN Billings b 
	ON c.CustomerID = b.CustomerID
JOIN Churn ch 
	ON c.CustomerID = ch.CustomerID
WHERE c.SeniorCitizen = 1 AND b.PaymentMethod = 'Electronic check';

-- =========================================================================
-- 📌 9. ADVANCED BUSINESS INSIGHTS
-- =========================================================================

-- ✅ Why did churned customers leave?
SELECT 
	c.ContractType, 
	b.MonthlyCharges, 
	s.InternetService, 
    COUNT(ch.CustomerID) AS ChurnedCustomers
FROM Churn ch
JOIN Billings b 
	ON ch.CustomerID = b.CustomerID
JOIN Contracts c 
	ON ch.CustomerID = c.CustomerID
JOIN Services s 
	ON ch.CustomerID = s.CustomerID
WHERE ch.Churn = 'Yes'
GROUP BY c.ContractType, b.MonthlyCharges, s.InternetService
ORDER BY ChurnedCustomers DESC;

-- ✅ Customer Lifetime Value (CLV)
-- Customer Lifetime Value (CLV) is an important metric in business. Instead of focusing only on churn, let's quantify lost revenue.
-- If churned customers had a high CLV, the business should invest more on trying to retain customers.
SELECT 
	c.CustomerID, 
	c.ContractType,
    SUM(b.TotalCharges) OVER (PARTITION BY c.CustomerID) AS LifetimeValue
FROM Billings b
JOIN Contracts c 
	ON b.CustomerID = c.CustomerID
ORDER BY LifetimeValue DESC;
-- This identifies the high-value customers, so that the business can focus more on retaining valuable customers.

-- ✅ Revenue Lost from Churned Customers
WITH LostRevenueCTE AS (
    SELECT 
		c.ContractType, 
		b.TotalCharges,
        SUM(b.TotalCharges) OVER (PARTITION BY c.ContractType) AS TotalLostRevenue
    FROM Billings b
    JOIN Churn ch 
		ON b.CustomerID = ch.CustomerID
    JOIN Contracts c 
		ON b.CustomerID = c.CustomerID
    WHERE ch.Churn = 'Yes'
)
SELECT DISTINCT 
	ContractType, 
	FORMAT(TotalLostRevenue, 'N2') AS LostRevenue
FROM LostRevenueCTE
ORDER BY LostRevenue DESC;

-- ✅ Lost Revenue from Month-to-Month Contract Users
SELECT 
    c.ContractType, 
    SUM(b.TotalCharges) AS LostRevenue,
    COUNT(CASE WHEN ch.Churn = 'Yes' THEN 1 END) AS ChurnedCustomers
FROM Contracts c
JOIN Billings b 
	ON c.CustomerID = b.CustomerID
JOIN Churn ch 
	ON c.CustomerID = ch.CustomerID
WHERE ch.Churn = 'Yes'
GROUP BY c.ContractType
ORDER BY LostRevenue DESC;

-- ✅ Churn Trends Over Tenure
WITH ChurnByTenure AS (
    SELECT 
		c.Tenure, 
        COUNT(*) AS TotalCustomers,
        COUNT(CASE WHEN ch.Churn = 'Yes' THEN 1 END) AS ChurnedCustomers
    FROM Contracts c
    JOIN Churn ch 
		ON c.CustomerID = ch.CustomerID
    GROUP BY c.Tenure
)
SELECT 
	Tenure, 
	TotalCustomers, 
	ChurnedCustomers,
    FORMAT(AVG(ChurnedCustomers * 100.0 / NULLIF(TotalCustomers, 0)) 
    OVER (ORDER BY Tenure ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 'N2') AS MovingAvgChurnRate
FROM ChurnByTenure;
-- This will show whether customers churn early or stay longer before leaving

-- ✅ Tenure Distribution in Months
SELECT 
    CASE 
        WHEN Tenure BETWEEN 0 AND 12 THEN '0-12 Months'
        WHEN Tenure BETWEEN 13 AND 24 THEN '13-24 Months'
        WHEN Tenure BETWEEN 25 AND 36 THEN '25-36 Months'
        WHEN Tenure BETWEEN 37 AND 48 THEN '37-48 Months'
        ELSE '49+ Months'
    END AS TenureGroup,
    COUNT(*) AS TotalCustomers
FROM Contracts
GROUP BY 
    CASE 
        WHEN Tenure BETWEEN 0 AND 12 THEN '0-12 Months'
        WHEN Tenure BETWEEN 13 AND 24 THEN '13-24 Months'
        WHEN Tenure BETWEEN 25 AND 36 THEN '25-36 Months'
        WHEN Tenure BETWEEN 37 AND 48 THEN '37-48 Months'
        ELSE '49+ Months'
    END
ORDER BY TenureGroup;

-- ✅ Monthly Revenue Growth Over Time
SELECT 
	Tenure, 
    FORMAT(AVG(TotalCharges), 'N2') AS AvgRevenue
FROM Contracts c
JOIN Billings b 
	ON c.CustomerID = b.CustomerID
GROUP BY Tenure
ORDER BY Tenure;
-- Businesses can use this insight to forecast revenue

-- ✅ Effect of Paperless Billing on Churn
SELECT 
	PaperlessBilling, 
    COUNT(*) AS TotalCustomers, 
    COUNT(CASE WHEN Churn = 'Yes' THEN 1 END) AS ChurnedCustomers,
    FORMAT(
		COUNT(CASE WHEN Churn = 'Yes' THEN 1 END) * 100.0 / COUNT(*), 'N2'
	) AS ChurnRate
FROM Contracts c
JOIN Churn ch 
	ON c.CustomerID = ch.CustomerID
GROUP BY PaperlessBilling;

-- ✅ Customer Loyalty Score
SELECT 
	c.CustomerID,
    c.ContractType,
    b.MonthlyCharges,
    c.Tenure,
    CASE 
           WHEN c.Tenure > 24 AND b.MonthlyCharges > 50 THEN 'Loyal Customer'
           WHEN c.Tenure <= 24 AND b.MonthlyCharges <= 50 THEN 'Low Engagement'
           WHEN ch.Churn = 'Yes' THEN 'Churned'
           ELSE 'Moderate Engagement'
       END AS LoyaltyStatus
FROM Contracts c
JOIN Billings b 
	ON c.CustomerID = b.CustomerID
JOIN Churn ch 
	ON c.CustomerID = ch.CustomerID;

-- ✅ What Percentage of New Customers (Tenure < 12 Months) Use Electronic Checks?
SELECT 
    COUNT(*) AS NewCustomers, 
    COUNT(CASE WHEN b.PaymentMethod = 'Electronic check' THEN 1 END) AS ElectronicCheckUsers,
    FORMAT(
		COUNT(CASE WHEN b.PaymentMethod = 'Electronic check' THEN 1 END) * 100.0 / COUNT(*), 'N2'
	) AS Percentage
FROM Contracts c
JOIN Billings b 
	ON c.CustomerID = b.CustomerID
WHERE c.Tenure < 12;

-- =========================================================================
-- 📌 10. CUSTOMER SEGMENTATION & RETENTION INSIGHTS
-- =========================================================================

-- ✅ Identifying Bundled vs. Unbundled Service Customers
SELECT 
    CASE 
        WHEN (StreamingTV = 'Yes' OR StreamingMovies = 'Yes') AND TechSupport = 'Yes' THEN 'Bundled Services'
        ELSE 'Unbundled Services'
    END AS ServiceType,
    COUNT(*) AS TotalCustomers,
    FORMAT(
		COUNT(CASE WHEN ch.Churn = 'Yes' THEN 1 END) * 100.0 / COUNT(*), 'N2'
	) AS ChurnRate
FROM Services s
JOIN Churn ch 
	ON s.CustomerID = ch.CustomerID
GROUP BY 
    CASE 
        WHEN (StreamingTV = 'Yes' OR StreamingMovies = 'Yes') AND TechSupport = 'Yes' THEN 'Bundled Services'
        ELSE 'Unbundled Services'
    END
ORDER BY ChurnRate DESC;

-- ✅ Segmenting High/Medium/Low Churn Risk Customers
-- Classify high, medium, and low churn risk customers based on monthly charges and contract type
SELECT 
	ChurnRisk, 
	COUNT(*) AS NumberOfCustomers
FROM (
    SELECT 
		c.CustomerID, 
		c.ContractType, 
		b.MonthlyCharges, 
		ch.Churn,
           CASE 
               WHEN ch.Churn = 'Yes' THEN 'Churned'
               WHEN c.ContractType = 'Month-to-Month' AND b.MonthlyCharges > 70 THEN 'Very High Risk'
               WHEN c.ContractType = 'Month-to-Month' AND b.MonthlyCharges BETWEEN 30 AND 70 THEN 'High Risk'
               WHEN c.ContractType = 'One Year' AND b.MonthlyCharges > 70 THEN 'Medium Risk'
               WHEN c.ContractType = 'Two Year' OR b.MonthlyCharges < 30 THEN 'Low Risk'
               ELSE 'Low Risk'
           END AS ChurnRisk
    FROM Billings b
    JOIN Contracts c 
		ON b.CustomerID = c.CustomerID
    JOIN Churn ch 
		ON c.CustomerID = ch.CustomerID
) RiskTable
GROUP BY ChurnRisk
ORDER BY NumberOfCustomers DESC;
-- Since our analysis says those who spend more are more likely to churn, we can figure the high-risk customers and focus on retaining them.
-- Also, in streaming and telecom companies, customers charged more are more likely to churn.

-- ✅ Customer Segmentation Based on Services
-- How many customers use streaming services (TV or Movies)?
SELECT 
    COUNT(*) AS StreamingUsers
FROM Services
WHERE StreamingTV = 'Yes' OR StreamingMovies = 'Yes';

-- ✅ Which Services are Most Used by Churned Customers?
SELECT 
	s.InternetService, 
	COUNT(*) AS ChurnedUsers
FROM Services s
JOIN Churn ch 
	ON s.CustomerID = ch.CustomerID
WHERE ch.Churn = 'Yes'
GROUP BY s.InternetService
ORDER BY ChurnedUsers DESC;

-- ✅ Does Churn Increase for Customers Who Have No Streaming Services?
SELECT 
    CASE 
        WHEN (StreamingTV = 'Yes' OR StreamingMovies = 'Yes') THEN 'Streaming Users'
        ELSE 'No Streaming Services'
    END AS StreamingCategory,
    COUNT(*) AS TotalCustomers,
    COUNT(CASE WHEN ch.Churn = 'Yes' THEN 1 END) AS ChurnedCustomers,
    FORMAT(COUNT(CASE WHEN ch.Churn = 'Yes' THEN 1 END) * 100.0 / COUNT(*), 'N2') AS ChurnRate
FROM Services s
JOIN Churn ch 
	ON s.CustomerID = ch.CustomerID
GROUP BY 
    CASE 
        WHEN (StreamingTV = 'Yes' OR StreamingMovies = 'Yes') THEN 'Streaming Users'
        ELSE 'No Streaming Services'
    END;
-- Streaming users churn more (30.32%) which is surprising because usually, bundling reduces churn.
-- Perhaps, streaming users are paying higher monthly charges, which we've seen increases churn risk.
-- Let's check if churned streaming users were Fiber Optic users - perhaps expensive internet plans are the issue.

-- ✅ Are Churned Streaming Users Mostly Fiber Optic Users?
SELECT 
    s.InternetService,
    COUNT(*) AS TotalChurnedStreamingUsers,
    FORMAT(COUNT(*) * 100.0 / (SELECT COUNT(*) 
                               FROM Services s
                               JOIN Churn ch 
								ON s.CustomerID = ch.CustomerID
                               WHERE ch.Churn = 'Yes'
                               AND (s.StreamingTV = 'Yes' OR s.StreamingMovies = 'Yes')), 'N2') AS Percentage
FROM Services s
JOIN Churn ch 
	ON s.CustomerID = ch.CustomerID
WHERE ch.Churn = 'Yes'
AND (s.StreamingTV = 'Yes' OR s.StreamingMovies = 'Yes')
GROUP BY s.InternetService
ORDER BY Percentage DESC;
-- Fiber Optic users make up 82.47% of churned customers who are streaming users. This indicates these users may be leaving because of high costs.
-- They may be switching to cheaper alternatives or downgrading services.

-- ✅ Compare Churned Fiber Optic Users vs. Non-Churned Fiber Optic Users
SELECT
    ch.Churn,
    FORMAT(AVG(b.MonthlyCharges), 'N2') AS AvgMonthlyCharge
FROM Billings b
JOIN Services s 
	ON b.CustomerID = s.CustomerID
JOIN Churn ch 
	ON b.CustomerID = ch.CustomerID
WHERE s.InternetService = 'Fiber optic'
GROUP BY ch.Churn;
-- At first glance, it appears high cost is not the main reason Fiber Optic users are leaving because non-churned users actually pay more.
-- But what if churned users started with lower plans but churned before upgrading? Also, non-hired Fiber Optic users may be on longer contracts.

-- ✅ Check Tenure of Churned vs. Non-Churned Fiber Optic Users
SELECT 
    ch.Churn,
    FORMAT(AVG(c.Tenure), 'N2') AS AvgTenure
FROM Contracts c
JOIN Services s 
	ON c.CustomerID = s.CustomerID
JOIN Churn ch 
	ON c.CustomerID = ch.CustomerID
WHERE s.InternetService = 'Fiber optic'
GROUP BY ch.Churn;
-- Fiber Optic customers leave early. This suggests unsatisfaction early on, perhaps due to pricing or performance.
-- Customers who make it past 2-3 years are much more likely to stay.

-- ✅ Compare Contract Types of Churned vs. Non-Churned Fiber Optic Users
SELECT 
    c.ContractType,
    ch.Churn,
    COUNT(*) AS NumberOfCustomers
FROM Contracts c
JOIN Services s 
	ON c.CustomerID = s.CustomerID
JOIN Churn ch 
	ON c.CustomerID = ch.CustomerID
WHERE s.InternetService = 'Fiber optic'
GROUP BY c.ContractType, ch.Churn
ORDER BY c.ContractType, ch.Churn;
-- Month to month churn rate of 54.61% is the real problem!
-- Customers on month-to-month contracts are massively at risk - can leave anything.
-- Long term contracts lock in customers and protect against churn

-- =========================================================================
-- 📌 11. BUSINESS RECOMMENDATIONS
-- =========================================================================

-- ✅ Reduce Churn Among Month-to-Month Customers
-- 42.71% churn rate for Month-to-Month contract customers.
-- Highest lost revenue comes from Month-to-Month churners ($1.92M lost)
SELECT 
    c.ContractType, 
    COUNT(*) AS TotalCustomers, 
    FORMAT(
        COUNT(CASE WHEN ch.Churn = 'Yes' THEN 1 END) * 100.0 / COUNT(*), 'N2'
    ) AS ChurnRate
FROM Contracts c
JOIN Churn ch ON c.CustomerID = ch.CustomerID
GROUP BY c.ContractType;
-- 📌 ACTIONABLE STRATEGY
-- Provide discounted long-term contracts for Month-to-Month customers
-- Offer loyalty reewards or exclusive perks for Month-to-Month customers who renew.

-- ✅ Improve Customer Retention in First 12 Months
-- 2,186 customers have tenure <= 12 months, with the highest churn rate of 47.44%.
-- Customers in their first year are the most likely to churn, indicating poor early retention.
WITH TenureChurn AS (
    SELECT 
        CASE 
            WHEN c.Tenure BETWEEN 0 AND 12 THEN '0-12 Months'
            WHEN c.Tenure BETWEEN 13 AND 24 THEN '13-24 Months'
            ELSE '25+ Months'
        END AS TenureGroup,
        COUNT(c.CustomerID) AS TotalCustomers,
        COUNT(CASE WHEN ch.Churn = 'Yes' THEN 1 END) AS ChurnedCustomers
    FROM Contracts c
    JOIN Churn ch 
        ON c.CustomerID = ch.CustomerID
    GROUP BY 
        CASE 
            WHEN c.Tenure BETWEEN 0 AND 12 THEN '0-12 Months'
            WHEN c.Tenure BETWEEN 13 AND 24 THEN '13-24 Months'
            ELSE '25+ Months'
        END
)
SELECT 
    TenureGroup,
    TotalCustomers,
    ChurnedCustomers,
    FORMAT(ChurnedCustomers * 100.0 / NULLIF(TotalCustomers, 0), 'N2') + '%' AS ChurnRate
FROM TenureChurn
ORDER BY CAST(ChurnedCustomers * 100.0 / NULLIF(TotalCustomers, 0) AS FLOAT) DESC;
-- 📌 ACTIONABLE STRATEGY
-- Strengthen customer onboarding programs for new customers (first 0-12 months).
-- Offer personalized discounts or incentives for new users to renew contracts.
-- Reach out to new customers in their first few months to rate their experience of the service and express their pain points, if any.

-- ✅ Address Churn Among Fiber Optic Users
-- 41.89% of Fiber Optic customers churn (highest among internet service types).
-- 82.47% of churned streaming users had Fiber Optic.
SELECT 
    s.InternetService, 
    COUNT(CASE WHEN ch.Churn = 'Yes' THEN 1 END) AS ChurnedUsers,
    FORMAT(
        COUNT(CASE WHEN ch.Churn = 'Yes' THEN 1 END) * 100.0 / COUNT(*), 'N2'
    ) AS ChurnRate
FROM Services s
JOIN Churn ch ON s.CustomerID = ch.CustomerID
GROUP BY s.InternetService
ORDER BY ChurnRate DESC;

SELECT 
    s.InternetService,
    COUNT(*) AS TotalChurnedStreamingUsers,
    FORMAT(COUNT(*) * 100.0 / (SELECT COUNT(*) 
                               FROM Services s
                               JOIN Churn ch 
								ON s.CustomerID = ch.CustomerID
                               WHERE ch.Churn = 'Yes'
                               AND (s.StreamingTV = 'Yes' OR s.StreamingMovies = 'Yes')), 'N2') AS Percentage
FROM Services s
JOIN Churn ch 
	ON s.CustomerID = ch.CustomerID
WHERE ch.Churn = 'Yes'
AND (s.StreamingTV = 'Yes' OR s.StreamingMovies = 'Yes')
GROUP BY s.InternetService
ORDER BY Percentage DESC;
-- 📌 ACTIONABLE STRATEGY
-- Survey Fiber Optic customers to identify pricing or quality concerns.
-- Introduce tiered Fiber Optic plans (low-cost, mid-tier, premium).
-- Offer price-matching discounts for Fiber Optic users considering cancellation.

-- ✅ Reduce Churn for Customers Paying via Electronic Check
-- 45.29% churn rate for Electronic Check users (highest among payment methods).
-- Customers using Bank Transfer and Credit Card churn much less (~15-19%).
SELECT 
    b.PaymentMethod, 
    COUNT(*) AS TotalCustomers, 
    FORMAT(
        COUNT(CASE WHEN ch.Churn = 'Yes' THEN 1 END) * 100.0 / COUNT(*), 'N2'
    ) AS ChurnRate
FROM Billings b
JOIN Churn ch ON b.CustomerID = ch.CustomerID
GROUP BY b.PaymentMethod
ORDER BY ChurnRate DESC;
-- 📌 ACTIONABLE STRATEGY
-- Incentivize auto-pay or credit card usage (e.g., 5% discount for switching).
-- Educate customers on faster and more secure payment methods.

-- ✅ Target Senior Electronic Check Users with Auto-Pay Incentives
-- Senior Citizens using Electronic Checks have a high churn rate (~60%).
-- They may be uncomfortable with digital payments or unaware of auto-pay benefits.
-- Switching them to Bank Transfers or Credit Cards could reduce churn.
WITH SeniorElectronicCheck AS (
    SELECT 
        c.CustomerID, 
        c.SeniorCitizen, 
        b.PaymentMethod, 
        ch.Churn
    FROM Customers c
    JOIN Billings b 
        ON c.CustomerID = b.CustomerID
    JOIN Churn ch 
        ON c.CustomerID = ch.CustomerID
    WHERE c.SeniorCitizen = 1 
    AND b.PaymentMethod = 'Electronic check'
)
SELECT 
    COUNT(*) AS TotalSeniorElectronicCheckUsers,
    COUNT(CASE WHEN Churn = 'Yes' THEN 1 END) AS ChurnedSeniorElectronicCheckUsers,
    FORMAT(COUNT(CASE WHEN Churn = 'Yes' THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0), 'N2') + '%' AS ChurnRate
FROM SeniorElectronicCheck;
-- 📌 ACTIONABLE STRATEGY
-- Offer discounts ($5/month) or one-time bill credit for switching to Bank Transfer or Credit Card auto-pay.
-- Add a dedicated "Senior Assistance" team to help set up secure auto-pay.
-- Offer phone support, in-person help, or step-by-step online guides for auto-pay setup.
-- Provide personalized customer outreach to explain benefits and security of auto-pay.

-- ✅ Identify & Upsell Long-Tenure, Low-Spend Customers
-- 1653 customers are low-spend (<$30) but have long tenures (>24 months).
-- These customers are loyal but not spending much.
SELECT c.CustomerID, c.Tenure, b.MonthlyCharges
FROM Contracts c
JOIN Billings b ON c.CustomerID = b.CustomerID
WHERE c.Tenure > 24 
AND b.MonthlyCharges < 30
ORDER BY c.Tenure DESC;
-- 📌 ACTIONABLE STRATEGY
-- Offer discounted premium service bundles (e.g., faster internet, streaming).
-- Target with personalized promotions based on past usage trends.

-- ✅ Improve Streaming Service Retention
-- 30.32% churn rate for Streaming Users vs. 22.80% for non-streamers.
-- Most churned streaming users were Fiber Optic customers.
SELECT 
    CASE 
        WHEN (StreamingTV = 'Yes' OR StreamingMovies = 'Yes') THEN 'Streaming Users'
        ELSE 'No Streaming Services'
    END AS StreamingCategory,
    COUNT(*) AS TotalCustomers,
    COUNT(CASE WHEN ch.Churn = 'Yes' THEN 1 END) AS ChurnedCustomers,
    FORMAT(COUNT(CASE WHEN ch.Churn = 'Yes' THEN 1 END) * 100.0 / COUNT(*), 'N2') AS ChurnRate
FROM Services s
JOIN Churn ch ON s.CustomerID = ch.CustomerID
GROUP BY 
    CASE 
        WHEN (StreamingTV = 'Yes' OR StreamingMovies = 'Yes') THEN 'Streaming Users'
        ELSE 'No Streaming Services'
    END;
-- 📌 ACTIONABLE STRATEGY
-- Offer streaming bundles with longer contracts (e.g., free HBO for annual plans).
-- Analyse whether competitors (Netflix, Hulu) are offering better streaming packages.

-- ✅ Retargeting Lost Revenue from Churned Customers
-- $1.92M in lost revenue from churned Month-to-Month customers.
-- $674K lost from One-Year contract churners.
WITH LostRevenueCTE AS (
    SELECT 
        c.ContractType, 
        b.TotalCharges,
        SUM(b.TotalCharges) OVER (PARTITION BY c.ContractType) AS TotalLostRevenue
    FROM Billings b
    JOIN Churn ch 
        ON b.CustomerID = ch.CustomerID
    JOIN Contracts c 
        ON b.CustomerID = c.CustomerID
    WHERE ch.Churn = 'Yes'
)
SELECT DISTINCT 
    ContractType, 
    FORMAT(TotalLostRevenue, 'N2') AS LostRevenue
FROM LostRevenueCTE
ORDER BY LostRevenue DESC;
-- 📌 ACTIONABLE STRATEGY
-- Retarget churned customers with exclusive "Come Back" promotions.
-- Offer one-month free service for rejoining with an annual plan.