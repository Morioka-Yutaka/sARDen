# sARDen
sARDen is a SAS toolkit for producing CDISC ARS–aligned Analysis Results Data (ARD). Inspired by the R pharmaverse cards schema, it respectfully mirrors ARD conventions for cross-language workflows.  
Macros cover summaries, tabulations, and hierarchical stacking, outputting long-format ARDs plus ARDM-like metadata via XATTR for traceability.  

<img width="360" height="360" alt="sARDen_small" src="https://github.com/user-attachments/assets/eb930364-b5eb-40f0-9a98-62f3362b8c03" />

## Test Data
We use ADSL and ADAE created as test data with the “sas_faker” package (https://github.com/Morioka-Yutaka/sas_faker),   
but you can freely substitute typical ADSL/ADAE datasets instead, so feel free to adapt that part as you like.
~~~sas
%loadPackage(sas_faker)
%sas_faker(
n_groups=3, 
n_per_group=50,
output_lib=WORK,
seed =123456,
create_dm = N,
create_ae = N,
create_sv =  N,
create_vs = N,
create_adsl = Y,
create_adae = Y,
create_advs = N
);
~~~~
[ADSL]  
<img width="767" height="176" alt="image" src="https://github.com/user-attachments/assets/af49ad5f-15c6-4156-ba91-ee336cb86317" />  
[ADAE]  
<img width="758" height="235" alt="image" src="https://github.com/user-attachments/assets/1a0beab0-c842-4124-ac21-2fa284a642a8" />  

## `%sard_summary()` macro <a name="sardsummary-macro-4"></a> ######
### Purpose:  
  Generate ARD-style summary statistics (long format) for continuous variables,  
  aligned to cards/ARS-like naming: group#, variable, context, stat_name, stat_label, stat, fmt_fun.  
  Can either compute statistics from raw data (data=) or post-process external stat data (statdata=).  
  
### Parameters:  
~~~text
  data=                 Source dataset for raw summaries (mutually exclusive with statdata=).  
  statdata=             Pre-computed statistics dataset (mutually exclusive with data=).  
  statdata_value=       Numeric value column in statdata to map into stat (default: COL1).  
  by=                   Grouping variables (space-separated). Must be non-empty for this version.  
  variable=             Analysis variables to summarize (space-separated). Required when data= is used.  
  statistic=            Statistics to keep (space-separated).  
                         Expected tokens (case-insensitive): N MEDIAN MEAN SD MIN MAX P25 P75 etc.  
  classdata=            Optional CLASSDATA= dataset for PROC SUMMARY to force level display.  
  context=              Context label stored in output (default: summary).  
  out=                  Output ARD dataset name.  
~~~
### Outputs:  
~~~text
  out= dataset with columns:  
    group1-groupN, group1_level-groupN_level, variable, context, stat_name, stat_label, stat, fmt_fun  
  Ordering variables_sort/statistic_sort used internally to preserve requested order.  
~~~

### Notes:  
  - When data= is used, fmt_fun is auto-derived from decimal precision (capped at 3 dp).  
  - When statdata= is used, fmt_fun is taken as-is; statdata must contain _NAME_ in "var_stat" form.  
  - stat_name "stddev" is normalized to "sd".  
  
### Example:  
~~~sas
  %sard_summary(  
    data=ADSL,  
    by=TRT01P,  
    variable=AGE WEIGHTBL,  
    statistic=N MEDIAN MIN MAX MEAN SD,  
    out=sard_summary_mean  
  );
~~~
<img width="1366" height="510" alt="image" src="https://github.com/user-attachments/assets/c7a4b6ca-0d36-4f98-930c-fdf0c6f2d09d" />  

~~~sas
proc sort data=ADSL out=_ADSL;
   by TRT01P;
run;
proc surveymeans data=_ADSL geomean  gmstderr ;
   by TRT01P;
  var WEIGHTBL HEIGHTBL;
  ods output GeometricMeans=geomean_1;
run;
proc sort data=geomean_1;
  by  TRT01P VarName;
run;
proc transpose data=geomean_1 out=geomean_2(rename=(_NAME_=__NAME_)) prefix=value;
  by TRT01P VarName;
run;
data geomean_3;
set geomean_2;
_NAME_=catx("_",varname,__NAME_);
fmt_fun ="2";
run;
%sard_summary(
  statdata = geomean_3,
  statdata_value = value1,
  by =TRT01P,
  variable = WEIGHTBL HEIGHTBL,
  statistic = GeoMean GMStdErr,
  out = sard_summary_geomean
)
~~~
<img width="1286" height="376" alt="image" src="https://github.com/user-attachments/assets/c6eefb3d-00a3-4248-900b-04a2e43a8e16" />

  
---
## `%sard_tabulate()` macro <a name="sardtabulate-macro-5"></a> ######
### Purpose:  
  Generate ARD-style tabulations (long format) for categorical variables,  
  producing n, BigN (denominator), and p (proportion), compatible with cards tabulate ARD.  
  
### Parameters:  
~~~text
  data=                   Source dataset.  
  variable=               Categorical variables to tabulate (space-separated). Required.  
  by=                     Optional grouping variables (space-separated).  
  statistic=              Stats to output (space-separated). Default: n P BigN.  
                           n    = count within variable level  
                           BigN = denominator for the by-group  
                           p    = n/BigN  
  denominator_dataset=    Optional dataset to define denominators explicitly.  
                           If blank, denominators are derived from data=.  
  classdata=              Optional CLASSDATA= for PROC SUMMARY to force level display.  
  context=                Context label stored in output (default: tabulate).  
  out=                    Output ARD dataset name.  
~~~

### Outputs:  
  out= dataset with columns:  
    group1-groupN, group1_level-groupN_level (if by provided),  
    variable, variable_level, context, stat_name, stat_label, stat, fmt_fun  
  fmt_fun:  
    n/BigN -> "0", p -> "xx.x" (intended display template).  
   
### Notes:  
  - If by= is empty, denominators are scalar and applied to all levels.  
  - variable_level stored as formatted value (vvalue).  
  - Assumes variable/bystats exist and are non-missing for numerator records.  
  
### Example:  
~~~sas
  %sard_tabulate(  
    data=ADSL,  
    by=TRT01P,  
    variable=SEX,  
    statistic=n P BigN,  
    out=sard_tabulate  
  );
~~~

<img width="1248" height="508" alt="image" src="https://github.com/user-attachments/assets/f1e5fd8c-4782-41df-b1a9-cfd266e3f803" />

  
---


