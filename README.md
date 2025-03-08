# Customer Churn Analysis Using SQL & Power BI
**Business Challenge**: A comprehensive analysis of Telco's data (a fictitious telecommunications company) to understand the main factors causing customer churn and identify actionable insights to reduce churn, retain customers, and potentially recover some lost revenue.

## Introduction
This project analyses customer churn for a telecommunications company using **SQL** for data querying and analysis, and **Power BI** for visualisation. The goal is to find out the causes of churn, measure the financial impact of losing customers, and figure out high-risk customer segments for better customer retention.

Customer churn is a serious issue in business. If customers are leaving a business or company, their revenue and profitability are negatively affected. How do factors like age, contract type, monthly charges, payment methods, internet service, tenure, and more, affect customer retention at Telco telecoms? Let's find out.

## Dataset Description
- **Dataset:** Telco customer churn
- **Dataset Size:** 955 KB
- **Number of Customers:** 7,043
- **Number of Columns:** 21
- **Source:** Kaggle
- **Key Fields:**
  - CustomerID, Gender, SeniorCitizen
  - ContractType, PaperlessBilling, MonthlyCharges, TotalCharges, Tenure
  - StreamingTV, StreamingMovies, OnlineBackup, OnlineSecurity
  - InternetService, PaymentMethod, Churn
 
## Objectives
1. Measure overall customer churn rate.
2. Identify customer segments with the highest churn risk.
3. Understand the financial impact of churn on businesses
4. Figure out patterns in churn based on contract type, payment method, and internet services.
5. Provide insights for improved customer retention and increased revenue.

## Methodology
**1. Data Preparation & Cleaning**
- Downloaded dataset (TelcoData.csv) from Kaggle.
- Imported the TelcoData.csv dataset into SQL Server using the Import Wizard.
- Split the flat file into 5 normalised tables:
    - Customers
    - Contracts
    - Services
    - Billings
    - Churn
2. **Data Analysis using SQL**
- Joined tables to create a single customer view.
- Used CTEs, subqueries, and aggregations to calculate:
    - Overall churn rate
    - Monthly revenue and lost revenue from churn
    - Payment method, internet service, and contract type-based churn rates
    - Tenure-based churn patterns
3. **Data Visualisation using Power BI**
- Created a detailed 3-page dashboard covering:
  - **Overview:** A big picture of the company's financial performance and churn breakdown
  - **Who is Churning?**: Churn based on contract type, tenure, payment method, and internet service
  - **Why Are Customers Leaving?**: A deeper look at what's causing customers to leave.
 
## Key Insights
### ✅ High Churn Rate Is a Major Business Risk
- Overall churn rate = 26.54% (approximately 1 in 4 customers stop using the business' services)
- Lost revenue from churn = $2.86M (67% from customers on month-to-month contracts)
### ✅ Month-to-Month Contracts Are the Largest Churn Driver
- Month-to-month churn rate = 42.71%
- Lost revenue from month-to-month churn = $1.93M
### ✅ Customers Are Leaving Early
- 47.44% of customers churn within the first 12 months - early retention is a problem.
### ✅ Fiber Optic Customers Are At High-Risk of Churning
- Fiber optic churn rate = 41.89% which is higher than DSL (18.96%).
- 82.47% of churned streaming users were using fiber optic.
- Fiber optic is more expensive than DSL, indicating that cost or service quality might be an issue.
### ✅ Difficulties & Inconvenience with Payment Drives Churn
- Electronic check churn rate = 45.29% – Highest among payment methods.
- Customers using credit cards and bank transfers churn less often.
### ✅ Bundling Services Reduces Churn
- Churn rate for bundled service customers = 14.85% significantly lower than unbundled services
- Customers with both security and backup services have the lowest churn at 10.57%

## Business Impact
💡 $2.86M in lost revenue → Reducing churn among month-to-month customers could recover over $1.93M in lost revenue. They can be encouraged to get on 1 or 2-year contracts.  
💡 Fiber optic customers are valuable but at high risk - improving retention among these customer group could stabilise revenue.  
💡 Reducing payment friction (e.g. encouraging auto-pay with credit cards or bank transfers) could help reduce churn.  
💡 Lower churn among bundled security and backup services customers indicates a potential strategy for reducing churn through better packaging.

## How to Use This Project
1. **Download the dataset:** The dataset is available in the repo for reproducibility.
2. **Set Up the Database**: Create a new database in SQL Server and load the dataset using the Import Wizard into a staging table (Staging_Telco).
3. **Run the SQL scripts:** Open the SQL script from the repo and execute them to create tables, populate data, and perform analysis.
4. **Open the Power BI Dashboard:** Open the .pbix file in Power BI Desktop and have a look at the dashboards:
- **Overview**: A big picture of the company's financial performance and churn breakdown.
- **Who is Churning**: A deep dive into churn breakdown based on several factors.
- **Why Are Customers Leaving**: Root causes of customer churn at Telco.
5. **Explore Insights:** The dashboard shows key insights and trends. Adjust filters and slicers to uncover patterns.

## Future Work
- Use machine learning to predict churn risk.
- Further analysis on Fiber Optic churn patterns.
- Customer segmentation for targeted retention strategies.
- Python to more deeply analyse the dataset and uncover deeper insights.

## Credits and Acknowledgments
- **Dataset:** Telco Customer Churn Dataset
- **Tools Used:** SQL Server, Power BI
- **Author:** Victor Arum

## Status: COMPLETED
This project is a comprehensive churn analysis that demonstrates deep analytical skills and business-level insights using SQL and Power BI.

## Links
- [Project Repo](url)
