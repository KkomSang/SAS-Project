* Sangeun Lee;
* Words of code (excluding comments): 2586;

* Data path appears 7 times: 6 proc import statements in Section I, and 1 ods excel statement in Section IX.;

/* Section I: Data Loading and Setup */
options nodate nonumber linesize=120 pagesize=60;
ods graphics on / width=8in height=5in imagename="plot";
title;
footnote;

* AI(Claude Sonnet 5): My csv has long text columns but only some rows have the long values. What can I use in proc import so SAS doesn't cut them off?;
proc import datafile="/export/viya/homes/sangeun.lee@st.oth-regensburg.de/Data/isoc_e_dii__custom_21976596_linear.csv"
    out=raw_dii dbms=csv replace;
    getnames=yes; guessingrows=max;

proc import datafile="/export/viya/homes/sangeun.lee@st.oth-regensburg.de/Data/isoc_cicce_use__custom_21976600_linear.csv"
    out=raw_cloud dbms=csv replace;
    getnames=yes; guessingrows=max;

proc import datafile="/export/viya/homes/sangeun.lee@st.oth-regensburg.de/Data/isoc_eb_ain2__custom_21976599_linear.csv"
    out=raw_ai dbms=csv replace;
    getnames=yes; guessingrows=max;

proc import datafile="/export/viya/homes/sangeun.lee@st.oth-regensburg.de/Data/isoc_eb_iip__custom_21976601_linear.csv"
    out=raw_erp dbms=csv replace;
    getnames=yes; guessingrows=max;

proc import datafile="/export/viya/homes/sangeun.lee@st.oth-regensburg.de/Data/lfsa_ehomp__custom_21976604_linear.csv"
    out=raw_remote dbms=csv replace;
    getnames=yes; guessingrows=max;

proc import datafile="/export/viya/homes/sangeun.lee@st.oth-regensburg.de/Data/tipsna70__custom_21976607_linear.csv"
    out=raw_prod dbms=csv replace;
    getnames=yes; guessingrows=max;

title "Section I: Raw file row counts";

proc sql;
    select "DII" as file, count(*) as obs from raw_dii
    union all select "Cloud", count(*) from raw_cloud
    union all select "AI", count(*) from raw_ai
    union all select "ERP", count(*) from raw_erp
    union all select "Remote", count(*) from raw_remote
    union all select "Productivity", count(*) from raw_prod;
quit;
title;

* AI(Claude Sonnet 5): How do I write a SAS proc format that groups the 27 EU countries into 3 regions (Northern/Western, Southern/Central, Central/Eastern), 
and puts everything else into "other"? ;
proc format;
    value $region
        "Denmark","Finland","Sweden","Netherlands","Belgium","Luxembourg","Ireland"
        = "01 Northern/Western"
        "Austria","France","Germany","Italy","Spain","Portugal","Malta","Cyprus","Greece"
        = "02 Southern/Central"
        "Czechia","Estonia","Latvia","Lithuania","Poland","Slovakia","Slovenia",
        "Hungary","Croatia","Bulgaria","Romania"
        = "03 Central/Eastern"
        other
        = "04 Non-EU27";

    value yearfmt
        2021 = "2021"
        2023 = "2023"
        2025 = "2025";
run;

%let eu27 = "Austria","Belgium","Bulgaria","Croatia","Cyprus","Czechia",
    "Denmark","Estonia","Finland","France","Germany","Greece",
    "Hungary","Ireland","Italy","Latvia","Lithuania","Luxembourg",
    "Malta","Netherlands","Poland","Portugal","Romania","Slovakia",
    "Slovenia","Spain","Sweden";


/* Section II: Data Cleaning and Panel Construction */
data dii_clean (keep=geo time_period dii);
    length geo $40;
    set raw_dii;
    if missing(obs_value) then delete;
    if indic_is = "Enterprises with at least basic level of digital intensity (DII Version 3)";
    if geo in (&eu27);
    dii = obs_value;
    label dii = "Enterprises with basic digital intensity, %";
run;

data cloud_clean (keep=geo time_period cloud);
    length geo $40;
    set raw_cloud;
    if missing(obs_value) then delete;
    if size_emp = "10 persons employed or more";
    if indic_is = "Enterprises using paid cloud computing services used over the internet";
    if unit = "Percentage of enterprises";
    if geo in (&eu27);
    cloud = obs_value;
    label cloud = "Enterprises using paid cloud computing, %";
run;

data ai_clean (keep=geo time_period ai);
    length geo $40;
    set raw_ai;
    if missing(obs_value) then delete;
    if nace_r2 = "All activities (except agriculture, forestry and fishing, "
        || "and mining and quarrying), without financial sector";
    if unit = "Percentage of enterprises";
    if geo in (&eu27);
    ai = obs_value;
    label ai = "Enterprises using at least one AI technology, %";
run;

data erp_clean (keep=geo time_period erp_biz);
    length geo $40;
    set raw_erp;
    if missing(obs_value) then delete;
    if size_emp = "10 persons employed or more";
    if indic_is = "Enterprises who have ERP software package to share information between different functional areas";
    if unit = "Percentage of enterprises";
    if geo in (&eu27);
    erp_biz = obs_value;
    label erp_biz = "Enterprises with ERP software package, %";
run;

data prod_clean (keep=geo time_period productivity);
    length geo $40;
    set raw_prod;
    if missing(obs_value) then delete;
    if na_item = "Real labour productivity per hour worked";
    if unit = "Index, 2015=100";
    if geo in (&eu27);
    productivity = obs_value;
    label productivity = "Real labour productivity per hour, Index 2015=100";
run;

data remote_clean (keep=geo time_period remote);
    length geo $40;
    set raw_remote;
    if missing(obs_value) then delete;
    if sex="Total"; if age="From 15 to 64 years";
    if frequenc="Usually"; if wstatus="Employees";
    if geo in (&eu27);
    remote = obs_value;
    label remote = "Employees (15-64) usually working from home, %";
run;

data remote_long (keep=geo time_period sex age frequenc wstatus remote_demo);
    length geo $40 sex $10 age $28 frequenc $12 wstatus $30;
    set raw_remote;
    if missing(obs_value) then delete;
    if geo in (&eu27);
    remote_demo = obs_value;
    label remote_demo = "Share working from home, percent of category"
        sex="Sex" age="Age group"
        frequenc="Working from home frequency" wstatus="Work status";
run;

proc sql;
    create table master_panel as
    select r.geo, r.time_period as year,
        r.sex, r.age, r.frequenc, r.wstatus, r.remote_demo,
        d.dii, c.cloud, a.ai, e.erp_biz, p.productivity
    from remote_long as r
    left join dii_clean as d on r.geo=d.geo and r.time_period=d.time_period
    left join cloud_clean as c on r.geo=c.geo and r.time_period=c.time_period
    left join ai_clean as a on r.geo=a.geo and r.time_period=a.time_period
    left join erp_clean as e on r.geo=e.geo and r.time_period=e.time_period
    left join prod_clean as p on r.geo=p.geo and r.time_period=p.time_period
    order by r.geo, r.time_period, r.sex, r.age, r.frequenc, r.wstatus;
quit;

data master_panel;
    set master_panel;
    y2025 = (year=2025);
    length region $25;
    region = put(geo, $region.);
run;

proc sql;
    create table panel as
    select d.geo, d.time_period as year,
        d.dii, c.cloud, a.ai, e.erp_biz, r.remote, p.productivity
    from dii_clean as d
    inner join cloud_clean as c on d.geo=c.geo and d.time_period=c.time_period
    inner join ai_clean as a on d.geo=a.geo and d.time_period=a.time_period
    inner join erp_clean as e on d.geo=e.geo and d.time_period=e.time_period
    inner join remote_clean as r on d.geo=r.geo and d.time_period=r.time_period
    inner join prod_clean as p on d.geo=p.geo and d.time_period=p.time_period
    order by d.geo, d.time_period;
quit;

data panel;
    set panel;
    y2025 = (year=2025);
    length region $25;
    region = put(geo, $region.);
run;

title "Master panel observation check";
proc sql;
    select count(*) as total_obs,
        count(distinct geo) as n_countries,
        count(distinct year) as n_years,
        count(distinct cats(sex,age,frequenc,wstatus)) as n_demo_combos
    from master_panel;
quit;
title;

title "Master panel structure";
proc print data=master_panel(obs=10) label noobs;
    var geo year sex age frequenc wstatus remote_demo dii cloud ai erp_biz productivity;
run;
proc contents data=master_panel varnum;
run;
title;

/* Section III: Descriptive Statistics and PCA */
title "Descriptive stats: full panel";
proc means data=panel n nmiss mean std min q1 median q3 max maxdec=2;
    var dii cloud ai erp_biz remote productivity;
run;
title;

* AI(Claude Sonnet 5): My data has Never, Sometimes and Usually as separate rows that add up to 100 per country, 
so averaging that column gives a meaningless number. How should I set up proc means so the three categories 
stay separate instead of being averaged together?;
title "Descriptive stats: Working from home frequency by year";
proc means data=master_panel n mean std min max maxdec=2;
    where wstatus="Employees" and sex="Total" and age="From 15 to 64 years";
    class frequenc year;
    var remote_demo;
    format year yearfmt.;
run;
title;

title "Descriptive stats: Working from home frequency by region";
proc means data=master_panel n mean std maxdec=2;
    where wstatus="Employees" and sex="Total" and age="From 15 to 64 years";
    class region frequenc;
    var remote_demo;
run;
title;

title "Country ranking by DII, 2025";
proc sort data=panel out=panel_sorted; by year descending dii; run;
proc print data=panel_sorted label noobs;
    where year=2025;
    var geo region dii cloud ai erp_biz remote productivity;
    format dii cloud ai erp_biz remote productivity 6.2;
run;
title;

/* NEW COMMAND #1 : PROC PRINCOMP */
* AI(Claude Sonnet 5): Can you write proc princomp code for 4 of my variables? I want to see if they all move together as one 'digital maturity' factor.;
title "PCA of four digital maturity indicators";
proc princomp data=panel out=panel_pca plots=pattern(ncomp=2);
    var dii cloud ai erp_biz;
run;
title;

title "PC1 and PC2 scores by country, 2025";
proc print data=panel_pca(obs=27) noobs label;
    where year=2025;
    var geo prin1 prin2;
    format prin1 prin2 7.3;
run;
title;

* AI(Claude Sonnet 5): I want to use proc rank to split my countries into quartiles by DII. Can you write the code, and also add readable labels like 'Q1 lowest' instead?;
title "DII quartile analysis";
proc rank data=panel out=panel_ranked groups=4;
    var dii; ranks dii_quartile;
run;
data panel_ranked;
    set panel_ranked;
    length dii_q_label $14;
    select(dii_quartile);
        when(0) dii_q_label="Q1 lowest";
        when(1) dii_q_label="Q2 below mid";
        when(2) dii_q_label="Q3 above mid";
        when(3) dii_q_label="Q4 highest";
        otherwise dii_q_label="n/a";
    end;
run;
proc means data=panel_ranked n mean std maxdec=2;
    class dii_q_label;
    var dii remote productivity;
run;
proc freq data=panel_ranked;
    tables dii_q_label;
run;
title;

* AI(Claude Sonnet 5): Now that I have Q1 and Q4 groups, how do I test if they're actually statistically different, not just different-looking?;
title "Q1 vs Q4 DII comparison, t-test";
proc ttest data=panel_ranked;
    class dii_q_label;
    where dii_q_label in ("Q1 lowest","Q4 highest");
    var dii remote productivity;
run;
title;

/* Section IV: Distribution and Correlation Checks */
* AI(Claude Sonnet 5): Can you write proc stdize code to standardize 6 variables to z-scores, and rename the output with a z prefix so I don't overwrite my original variables?;
title "Standardize six variables to z-scores";
proc stdize data=panel out=panel_z method=std;
    var dii cloud ai erp_biz remote productivity;
run;
data panel_z;
    set panel_z;
    rename dii=zdii cloud=zcloud ai=zai erp_biz=zerp
        remote=zremote productivity=zprod;
run;
proc sort data=panel; by geo year; run;
proc sort data=panel_z; by geo year; run;
data panel_full;
    merge panel panel_z;
    by geo year;
run;

title "Pearson correlation matrix";
proc corr data=panel pearson nosimple;
    var dii cloud ai erp_biz remote productivity;
run;
title;

* AI(Claude Sonnet 5): Can you write proc varclus code to check if my AI, cloud, and ERP variables cluster together into one group?;
title "Clustering of AI, cloud, and ERP indicators";
proc varclus data=panel maxclusters=3 short;
    var ai cloud erp_biz;
run;
title;

proc sort data=panel out=panel_by_year; by year; run;

/* NEW COMMAND #2 : PROC KDE */
* AI(Claude Sonnet 5): Can you write proc kde code to get a density curve for my remote work variable, separately for each year?;
title "KDE of remote work share by year";
proc kde data=panel_by_year;
    univar remote / plots=density;
    by year;
run;
title;

title "KDE of productivity by year";
proc kde data=panel_by_year;
    univar productivity / plots=density;
    by year;
run;
title;

title "Normality check: remote work share";
proc univariate data=panel normal;
    var remote;
    histogram remote / normal;
    qqplot remote / normal(mu=est sigma=est);
run;
title;

title "Normality check: productivity";
proc univariate data=panel normal;
    var productivity;
    histogram productivity / normal;
    qqplot productivity / normal(mu=est sigma=est);
run;
title;


/* Section V: Regression Analysis */
* AI(Claude Sonnet 5): I want to test if countries with higher DII also have higher remote work share. Can you write a simple proc reg for that?;
title "Remote work share on DII";
proc reg data=panel plots(only)=(diagnostics fitplot);
    model remote = dii y2025 / clb stb vif;
run; quit;
title;

title "DII effect on remote work, controlling for region";
proc glm data=panel plots=none;
    class region;
    model remote = dii y2025 region / solution;
run; quit;
title;

title "Productivity on remote work share";
proc reg data=panel plots(only)=(diagnostics fitplot);
    model productivity = remote y2025 / clb stb vif;
run; quit;
title;

title "Productivity on remote work, controlling for region";
proc glm data=panel plots=none;
    class region;
    model productivity = remote y2025 region / solution;
run; quit;
title;

title "Productivity on individual tech components";
proc reg data=panel plots(only)=(diagnostics fitplot);
    model productivity = remote ai cloud erp_biz y2025 / clb stb vif tol;
run; quit;
title;

title "Remote work share on AI, cloud, ERP (z-scored)";
proc reg data=panel_full plots(only)=(diagnostics fitplot);
    model zremote = zai zcloud zerp y2025 / clb stb;
run; quit;
title;

title "Remote work share on DII, 2023 only";
proc reg data=panel plots=none;
    where year=2023;
    model remote = dii / clb stb;
run; quit;
title;

title "Productivity on remote work share, 2023 only";
proc reg data=panel plots=none;
    where year=2023;
    model productivity = remote / clb stb;
run; quit;
title;

title "Remote work share on AI, cloud, ERP (z-scored), 2023 only";
proc reg data=panel_full plots=none;
    where year=2023;
    model zremote = zai zcloud zerp / clb stb;
run; quit;
title;

title "Remote work share on DII, 2025 only";
proc reg data=panel plots=none;
    where year=2025;
    model remote = dii / clb stb;
run; quit;
title;

title "Productivity on remote work share, 2025 only";
proc reg data=panel plots=none;
    where year=2025;
    model productivity = remote / clb stb;
run; quit;
title;

title "Remote work share on AI, cloud, ERP (z-scored), 2025 only";
proc reg data=panel_full plots=none;
    where year=2025;
    model zremote = zai zcloud zerp / clb stb;
run; quit;
title;

* AI(Claude Sonnet 5): I want to make a yes/no variable for whether a country is above the median remote work share, 
then find out which factors predict it with logistic regression.;
proc means data=panel median noprint;
    var remote;
    output out=remote_median median=med_remote;
run;
data panel_logit;
    set panel;
    if _n_=1 then set remote_median (keep=med_remote);
    highremote = (remote > med_remote);
run;

title "Logistic regression: predictors of remote work leader status";
proc freq data=panel_logit;
    tables highremote / nocum;
run;
proc logistic data=panel_logit;
    model highremote(event='1') = dii cloud ai erp_biz y2025
        / selection=stepwise slentry=0.10 slstay=0.15
        clparm=wald clodds=wald;
run;
title;

/* Section VI: Year-Over-Year Change */
* AI(Claude Sonnet 5): Can you write proc transpose code to reshape my panel data so each country has separate columns for 2023 and 2025?;
proc sort data=panel out=panel_long; by geo year; run;

proc transpose data=panel_long out=panel_wide_dii prefix=dii_; by geo; id year; var dii; run;
proc transpose data=panel_long out=panel_wide_cloud prefix=cloud_; by geo; id year; var cloud; run;
proc transpose data=panel_long out=panel_wide_ai prefix=ai_; by geo; id year; var ai; run;
proc transpose data=panel_long out=panel_wide_erp prefix=erp_; by geo; id year; var erp_biz; run;
proc transpose data=panel_long out=panel_wide_rem prefix=rem_; by geo; id year; var remote; run;
proc transpose data=panel_long out=panel_wide_prod prefix=prod_; by geo; id year; var productivity; run;

data panel_wide;
    merge panel_wide_dii (drop=_name_)
        panel_wide_cloud (drop=_name_)
        panel_wide_ai (drop=_name_)
        panel_wide_erp (drop=_name_)
        panel_wide_rem (drop=_name_)
        panel_wide_prod (drop=_name_);
    by geo;
    d_dii = dii_2025 - dii_2023;
    d_cloud = cloud_2025 - cloud_2023;
    d_ai = ai_2025 - ai_2023;
    d_erp = erp_2025 - erp_2023;
    d_remote = rem_2025 - rem_2023;
    d_prod = prod_2025 - prod_2023;
run;

title "Paired t-tests, 2023 vs 2025";
proc ttest data=panel_wide;
    paired dii_2025*dii_2023 cloud_2025*cloud_2023
        ai_2025*ai_2023 erp_2025*erp_2023
        rem_2025*rem_2023 prod_2025*prod_2023;
run;
title;

title "Regression on year-over-year change: remote work growth";
proc reg data=panel_wide plots=none;
    model d_remote = d_dii / clb;
run; quit;
title;

title "Regression on year-over-year change: productivity growth";
proc reg data=panel_wide plots=none;
    model d_prod = d_dii d_remote / clb;
run; quit;
title;

title "Remote work growth on tech component growth";
proc reg data=panel_wide plots=none;
    model d_remote = d_ai d_cloud d_erp / clb vif;
run; quit;
title;


/* Section VII: Heterogeneity Analysis */
* AI(Claude Sonnet 5): I want to compare AI adoption across a few specific industries like manufacturing, IT, and construction. 
Can you write proc means to compare the averages by sector, and then proc glm to test if the differences are statistically significant?;
data ai_industry;
    length geo $40 sector $80;
    set raw_ai;
    if missing(obs_value) then delete;
    if geo in (&eu27);
    if unit="Percentage of enterprises";
    if nace_r2 in ("Manufacturing",
        "Information and communication",
        "Construction",
        "Transportation and storage",
        "Accommodation and food service activities",
        "Real estate activities",
        "Wholesale trade, except of motor vehicles and motorcycles");
    sector=nace_r2; ai_sec=obs_value;
    keep geo time_period sector ai_sec;
run;

title "AI adoption by industry sector";
proc means data=ai_industry n mean std min max maxdec=2;
    class sector;
    var ai_sec;
run;
title;

title "ANOVA: AI adoption across sectors";
proc glm data=ai_industry plots=none;
    class sector;
    model ai_sec = sector / solution;
    means sector / tukey alpha=0.05;
run; quit;
title;

title "Remote work by sex and age group";
proc means data=master_panel n mean std maxdec=2;
    where frequenc="Usually" and wstatus="Employees"
        and age in ("From 15 to 24 years","From 25 to 49 years","From 50 to 64 years")
        and sex in ("Females","Males");
    class sex age;
    var remote_demo;
run;
title;

* AI(Claude Sonnet 5): I want to see if remote work differs by sex and age group, and also whether sex and age interact with each other. 
Can you write that using proc glm with an interaction term?;
title "Two-way ANOVA: sex x age interaction";
proc glm data=master_panel plots=none;
    where frequenc="Usually" and wstatus="Employees"
        and age in ("From 15 to 24 years","From 25 to 49 years","From 50 to 64 years")
        and sex in ("Females","Males");
    class sex age;
    model remote_demo = sex age sex*age / solution;
    lsmeans sex*age / pdiff adjust=tukey;
run; quit;
title;

title "Chi-square test: high remote work share by EU region";
proc freq data=panel_logit;
    tables region * highremote / chisq expected;
run;
title;


/* Section VIII: Graphical Output */
title "DII vs remote work share, country level";
proc sgplot data=panel;
    scatter x=dii y=remote / group=year datalabel=geo
        markerattrs=(symbol=circlefilled size=10);
    reg x=dii y=remote / nomarkers lineattrs=(thickness=2);
    xaxis label="Digital Intensity Index, %";
    yaxis label="Employees usually working from home, %";
    keylegend / position=topleft location=inside;
run;
title;

title "Remote work vs labour productivity";
proc sgplot data=panel;
    scatter x=remote y=productivity / group=year datalabel=geo;
    reg x=remote y=productivity / nomarkers;
    xaxis label="Employees usually working from home, %";
    yaxis label="Labour productivity, Index 2015=100";
run;
title;

* AI(Claude Sonnet 5): My bar chart shows countries but they're in random order. How do I sort the bars from highest to lowest value?;
title "Country DII ranking, 2025";
proc sgplot data=panel_sorted;
    where year=2025;
    hbar geo / response=dii categoryorder=respdesc fillattrs=(color=cx336699);
    xaxis label="DII, %";
    yaxis label="Country" fitpolicy=none;
run;
title;

* AI(Claude Sonnet 5): My box plot mixes categories that shouldn't be pooled, including a "Total" row 
and several overlapping age bands. Which rows should I filter out, and how do I split the boxes by sex?;
title "Remote work share by DII quartile";
proc sql;
    create table master_with_q as
    select m.*, p.dii_q_label
    from master_panel m
    left join panel_ranked p on m.geo=p.geo and m.year=p.year;
quit;

proc sgplot data=master_with_q;
    where frequenc="Usually" and wstatus="Employees"
        and sex in ("Females","Males")
        and age="From 15 to 64 years";
    vbox remote_demo / category=dii_q_label group=sex;
    xaxis label="DII quartile (country-year level)";
    yaxis label="Employees usually working from home, %";
run;
title;

* AI(Claude Sonnet 5): My scatter plot shows change values that can be negative or positive. 
Can I add a line at zero on both axes so it's easier to see which countries went up vs down?;
title "Year-over-year change: DII vs remote work";
proc sgplot data=panel_wide;
    scatter x=d_dii y=d_remote / datalabel=geo markerattrs=(symbol=circlefilled size=9);
    refline 0 / axis=x lineattrs=(pattern=dot);
    refline 0 / axis=y lineattrs=(pattern=dot);
    reg x=d_dii y=d_remote / nomarkers;
    xaxis label="Change in DII, pp (2025-2023)";
    yaxis label="Change in remote-work share, pp (2025-2023)";
run;
title;

title "DII vs remote work share by year";
proc sgpanel data=panel;
    panelby year / columns=3 novarname;
    scatter x=dii y=remote / datalabel=geo markerattrs=(symbol=circlefilled size=8);
    reg x=dii y=remote / nomarkers;
    colaxis label="DII, %";
    rowaxis label="Working from home share, %";
    format year yearfmt.;
run;
title;

title "AI adoption by sector and year";
proc sgpanel data=ai_industry;
    panelby sector / columns=3 novarname;
    vbox ai_sec / category=time_period;
    colaxis label="Year";
    rowaxis label="AI adoption, %";
    format time_period yearfmt.;
run;
title;

title "Remote work by age group, sex, and year";
proc sgpanel data=master_panel;
    where frequenc="Usually" and wstatus="Employees"
        and age in ("From 15 to 24 years","From 25 to 49 years","From 50 to 64 years")
        and sex in ("Females","Males");
    panelby age / columns=3 novarname;
    vbox remote_demo / category=sex group=year;
    colaxis label="Sex";
    rowaxis label="Working from home share, %";
    format year yearfmt.;
run;
title;


/* Section IX: Report Tables and Export */
* AI(Claude Sonnet 5): Can you write a proc report that groups countries by region, adds a subtotal row after 
each region and a grand total at the end, and includes a calculated column that's the difference between two other columns?;
* AI(Claude Sonnet 5): My subtotal rows are adding up percentages, which doesn't make sense. 
How do I get the region subtotal to show an average instead of a sum?;
title "Country summary table with region sub-totals, 2025";
proc report data=panel nowindows headline split="*";
    where year=2025;
    columns region geo dii cloud ai erp_biz remote productivity dig_gap;
    define region / group "EU sub-region" width=22;
    define geo / display "Country" width=16;
    define dii / analysis mean "DII*(%)" format=6.2;
    define cloud / analysis mean "Cloud*(%)" format=6.2;
    define ai / analysis mean "AI*(%)" format=6.2;
    define erp_biz / analysis mean "ERP*(%)" format=6.2;
    define remote / analysis mean "Remote*(%)" format=6.2;
    define productivity / analysis mean "Prod*(2015=100)" format=7.2;
    define dig_gap / computed "DII-Remote*(pp)" format=6.1;
    compute dig_gap;
        dig_gap = _c3_ - _c7_;
    endcomp;
    break after region / summarize ol ul;
    rbreak after / summarize dol dul;
run;
title;

title "Region x year averages";
proc tabulate data=panel format=7.2;
    class region year;
    var dii cloud ai erp_biz remote productivity;
    table region all="EU-27 average",
        (dii cloud ai erp_biz remote productivity)*(mean)*year=" ";
    format year yearfmt.;
run;
title;

proc sort data=panel out=panel_for_excel; by region geo year; run;
ods excel file="/export/viya/homes/sangeun.lee@st.oth-regensburg.de/Data/Lee_country_data.xlsx"
    options(embedded_titles='yes' sheet_interval='bygroup' sheet_label='region');
proc print data=panel_for_excel label noobs;
    by region;
    var geo year dii cloud ai erp_biz remote productivity;
    format dii cloud ai erp_biz remote productivity 6.2 year yearfmt.;
    title "EU Digital Maturity Panel by sub-region";
run;
ods excel close;
title;


/* Section X: Housekeeping */
* AI(Claude Sonnet 5): I have a bunch of temporary datasets left over from earlier steps that I don't need anymore,
like panel_wide_dii and panel_sorted. 
Can you write code to delete several of them at once?;
proc datasets library=work nolist;
    delete panel_wide_dii panel_wide_cloud panel_wide_ai
        panel_wide_erp panel_wide_rem panel_wide_prod
        remote_median panel_sorted panel_long
        panel_for_excel panel_by_year;
quit;

title "Retained work tables";
proc datasets library=work nolist;
    contents data=_all_ directory nods;
quit;
title;

ods graphics off;