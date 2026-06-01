# Macroeconomic Data Warehouse in SQLite

This project designs a SQLite star-schema data warehouse for analysing macroeconomic indicators across countries and years.

## Business Problem

Economic indicators are often stored in separate files with different structures. A dimensional warehouse makes it easier to integrate GDP growth, purchasing power parity expenditure, and productivity data for repeatable reporting and analysis.

## What This Project Demonstrates

- SQLite database design
- Star-schema modelling with fact and dimension tables
- Country, time, measure, and activity dimensions
- Fact tables for GDP growth, PPP expenditure, and productivity
- Foreign key relationships and analytical query readiness

## Key Findings

- A star-schema structure makes multi-country economic indicators easier to query, compare, and extend.
- Separating dimensions such as country, time, measure, and economic activity reduces duplication and improves analytical consistency.
- SQLite provides a lightweight way to demonstrate warehouse design without requiring enterprise database infrastructure.

## Business Recommendation

Use dimensional modelling when recurring economic or performance reporting requires consistent definitions, repeatable joins, and a structure that can support dashboards or downstream analytics.

## Tools Used

- SQL
- SQLite
- Dimensional modelling
- Data warehousing concepts

## Repository Structure

```text
.
├── macroeconomic_data_warehouse.sql
└── README.md
```

## How To Use

Open the SQL script in SQLite DB Browser, SQLite CLI, or another SQL environment that supports SQLite syntax. The script defines the warehouse structure and transformation logic for the macroeconomic analysis workflow.
