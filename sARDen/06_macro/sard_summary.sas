/*** HELP START ***//*

Macro: sard_summary  
Purpose:  
  Generate ARD-style summary statistics (long format) for continuous variables,  
  aligned to cards/ARS-like naming: group#, variable, context, stat_name, stat_label, stat, fmt_fun.  
  Can either compute statistics from raw data (data=) or post-process external stat data (statdata=).  
  
Inputs:  
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
  
Outputs:  
  out= dataset with columns:  
    group1-groupN, group1_level-groupN_level, variable, context, stat_name, stat_label, stat, fmt_fun  
  Ordering variables_sort/statistic_sort used internally to preserve requested order.  
   
Notes:  
  - When data= is used, fmt_fun is auto-derived from decimal precision (capped at 3 dp).  
  - When statdata= is used, fmt_fun is taken as-is; statdata must contain _NAME_ in "var_stat" form.  
  - stat_name "stddev" is normalized to "sd".  
  
Example:  
  %sard_summary(  
    data=ADSL,  
    by=TRT01P,  
    variable=AGE WEIGHTBL,  
    statistic=N MEDIAN MIN MAX MEAN SD,  
    out=sard_summary_mean  
  );

*//*** HELP END ***/

%macro sard_summary(
  data = ,
  statdata = ,
  statdata_value= COL1,
  by = ,
  variable = ,
  statistic =  ,
  classdata = ,
  context= summary,
  out = sard_summary
);
%if %length(&data) ne 0 and %length(&statdata) ne 0 %then %do;
  %put ERROR:You can only specify either data or statdata.;
  %abort;
%end;

%if %length(&by) ne 0 %then %do;
	%let by=%kcmpres(&by);
	%let bynum = %sysfunc( countw( &by));
  %if 1 = &bynum %then %let by1 = &by;
  %if 1 < &bynum %then %do;
    %do i = 1 %to &bynum ;
      %let by&i = %scan(&by,&i,%str ( ) );
    %end;
  %end;
%end;

%if %length(&variable) ne 0 %then %do;
	%let variable=%kcmpres(&variable);
	%let variablenum = %sysfunc( countw( &variable));
  %if 1 = &variablenum %then %let variable1 = &variable;
  %if 1 < &variablenum %then %do;
    %do i = 1 %to &variablenum ;
      %let variable&i = %scan(&variable,&i,%str ( ) );
    %end;
  %end;
%end;

%if %length(&statistic) ne 0 %then %do;
	%let statistic=%kcmpres(&statistic);
	%let statisticnum = %sysfunc( countw( &statistic ));
  %if 1 = &statisticnum %then %let statistic1 = &statistic;
  %if 1 < &statisticnum %then %do;
    %do i = 1 %to &statisticnum ;
      %let statistic&i = %scan(&statistic,&i,%str ( ) );
    %end;
  %end;
%end;

%if %length(&statdata) = 0 %then %do;
  data sard_temp;
  set &data;
  %do i = 1 %to &variablenum.;
    &&variable&i.._dp=lengthn(scan(cats(&&variable&i),2,"."));
  %end;
  run;
  proc sql noprint;
  %do i = 1 %to &variablenum.;
   select min(max( &&variable&i.._dp),3) into: &&variable&i.._dp
   from sard_temp;
  %end;
  quit;


  proc summary data=sard_temp nway
  %if %length(&classdata) ne 0 %then %do;
   classdata = &classdata. 
  %end;
  ;
  class &by. ;
  var &variable.  ;
  output out= sard_out1(drop=_TYPE_ _FREQ_)
   n=
   median=
   p25=
   p75=
   min=
   max=
   mean=
   std=
  /autoname ;
  run;
  proc sort data = sard_out1;
   by  &by;
  run;
  proc transpose data=sard_out1 out=sard_out2;
   by  &by;
  run;
%end;

data sard_out3;
length 
%do i = 1 %to &bynum ;
group&i
group&i._level
%end;
variable
context
stat_name
stat_label
$200.
stat
8.
fmt_fun $200.
;
%if %length(&statdata) eq 0 %then %do;
 set sard_out2;
%end;
%if %length(&statdata) > 0 %then %do;
 set &statdata;
%end;

varname=scan(_NAME_,1,"_");
stat_name=lowcase(scan(_NAME_,2,"_"));
select(stat_name);
 when("stddev") stat_name="sd";
 otherwise;
end;

%do i = 1 %to &bynum ;
group&i=cats(upcase("&&by&i")); 
group&i._level=cats(&&by&i);
%end;

variable=cats(upcase(varname)); 
context=cats("&context.");
select(stat_name);
  when("sd") stat_label="SD" ;
  when("p25") stat_label="Q1" ;
  when("p75") stat_label="Q3" ;
  otherwise stat_label=propcase(stat_name);
end;
stat=&statdata_value.;

%if %length(&statdata) eq 0 %then %do;
  %do i = 1 %to &variablenum ;
  if variable = "&&variable&i" then do; 
    select(stat_name);
      when("n") fmt_fun = "0";
      when("median") fmt_fun = cats(input(symget("&&variable&i.._dp"),best.) +1);
      when("mean") fmt_fun = cats(input(symget("&&variable&i.._dp"),best.) +1);
      when("sd") fmt_fun = cats(input(symget("&&variable&i.._dp"),best.) +1);
      when("p25") fmt_fun = cats(input(symget("&&variable&i.._dp"),best.) +1);
      when("p75") fmt_fun = cats(input(symget("&&variable&i.._dp"),best.) +1);
      when("min") fmt_fun = cats(input(symget("&&variable&i.._dp"),best.)) ;
      when("max") fmt_fun = cats(input(symget("&&variable&i.._dp"),best.)) ;
      otherwise fmt_fun = cats(input(symget("&&variable&i.._dp"),best.) +1);
    end;
  end;
  %end;
%end;

if upcase(stat_name) not in (%sysfunc( tranwrd( %str("%upcase(&statistic)") , %str( ) , %str(",") ) )) then delete;
variable_sort = whichc(upcase(variable), %sysfunc( tranwrd( %str("%upcase(&variable)") , %str( ) , %str(",") ) ));
statistic_sort = whichc(upcase(stat_name), %sysfunc( tranwrd( %str("%upcase(&statistic)") , %str( ) , %str(",") ) ));
run;

proc sort data = sard_out3 out=&out.(keep= group1--fmt_fun);
 by
%do i = 1 %to &bynum ;
group&i._level
%end;
  variable_sort statistic_sort;
run;

%if %length(&statdata) eq 0 %then %do;
proc delete data = sard_temp;
run;
proc delete data = sard_out1;
run;
proc delete data = sard_out2;
run;
%end;
proc delete data = sard_out3;
run;

%mend;
