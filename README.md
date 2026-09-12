# Digital Maturity, Remote Work & Productivity in the EU

A SAS project analyzing how enterprise digital maturity (cloud, AI, ERP adoption) relates to remote work and labor productivity across the 27 EU countries.

## Overview

As AI and cloud adoption accelerated across EU enterprises between 2023–2025, remote work also became a defining part of the labor market. This project asks:

1. Do more digitally mature countries have more remote work?
2. Does more remote work mean higher productivity?
3. Which technology (cloud, AI, or ERP) matters most for remote work?

## Data

Six datasets from Eurostat (2021–2025): Digital Intensity Index, cloud/AI/ERP adoption, remote work share, and labor productivity. Cleaned and joined into one panel of 27 EU countries using `PROC SQL`. 

## Methods

- `PROC PRINCOMP` — test whether the digital indicators form one "digital maturity" factor
- `PROC REG` / `PROC TTEST` — regression and year-over-year change analysis for each research question
- `PROC GLM` — differences across industry, sex, and age group
- `PROC LOGISTIC` — predicting "remote work leader" countries

## Key Findings

- Digital maturity behaves as one factor (PCA: 71.9% variance explained by the first component).
- Higher digital maturity is linked to more remote work — but mostly explained by region, not digitalization itself.
- Remote work is positively linked to productivity once regional differences are accounted for (an earlier negative link turned out to be an artifact of the productivity index's base year).
- Cloud computing adoption is the strongest single predictor of remote work, just ahead of AI.

## Tools

SAS. 20 AI-assisted code blocks are cited inline in the project code.

## Data Source

[Eurostat](https://ec.europa.eu/eurostat)
