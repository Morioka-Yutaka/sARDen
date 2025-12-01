/*** HELP START ***//*

Macro: sard_tabulate  
Purpose:  
  Generate ARD-style tabulations (long format) for categorical variables,  
  producing n, BigN (denominator), and p (proportion), compatible with cards tabulate ARD.  
  
Inputs:  
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
  
Outputs:  
  out= dataset with columns:  
    group1-groupN, group1_level-groupN_level (if by provided),  
    variable, variable_level, context, stat_name, stat_label, stat, fmt_fun  
  fmt_fun:  
    n/BigN -> "0", p -> "xx.x" (intended display template).  
   
Notes:  
  - If by= is empty, denominators are scalar and applied to all levels.  
  - variable_level stored as formatted value (vvalue).  
  - Assumes variable/bystats exist and are non-missing for numerator records.  
  
Example:  
  %sard_tabulate(  
    data=ADSL,  
    by=TRT01P,  
    variable=SEX,  
    statistic=n P BigN,  
    out=sard_tabulate  
  );

*//*** HELP END ***/

%macro sard_tabulate(
  data = ,
  variable =  ,
  by =  ,
  statistic = n P BigN,
  denominator_dataset = ,
  classdata = ,
  context= tabulate,
  out = sard_tabulate
);

%let bynum = 0;
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

data sard_temp ;
set &data;
run;

%if %length(&denominator_dataset) > 0 %then %do;
  proc summary data=&denominator_dataset nway;
  %if &bynum ne  0 %then %do;
  class &by.;
  %end;
  output out=denominator(rename=(_FREQ_=BigN));
  run;
%end;

%do i = 1 %to &variablenum.;
 proc summary data=sard_temp 
  %if %length(&classdata) ne 0 %then %do;
   classdata = &classdata. 
  %end;
  ;
  class &by. &&variable&i.;
  ways &bynum %eval(&bynum + 1);
  output out= sard_out&i;
run;

 %let qkey  = %sysfunc( tranwrd( %str("&by") , %str( ) , %str(",") ) );

%if %length(&denominator_dataset) = 0 %then %do;
  data denominator&i;
   set sard_out&i;
  %if &bynum ne  0 %then %do;
   if cmiss(of &by. ) = 0 and missing(&&variable&i);
  %end;
  %else %do;
   if missing(&&variable&i);
  %end;
   rename _FREQ_ = BigN;
  run;
%end;

data numerator&i;
 set sard_out&i;
 if cmiss(of &by. &&variable&i. ) = 0;
 variable_level=strip(vvalue(&&variable&i. ));
 rename _FREQ_ = n;
run;

data fraction&i. ;
set numerator&i.;
 %if &bynum ne  0 %then %do;
  %if %length(&denominator_dataset) =0 %then %do;
  if 0 then set denominator&i.;
  %end;
   %if %length(&denominator_dataset) >0 %then %do;
  if 0 then set denominator;
  %end;
  if _N_ = 1 then do;
   %if %length(&denominator_dataset) =0 %then %do;
   declare hash h1(dataset:"denominator&i.");
   %end;
   %if %length(&denominator_dataset) >0 %then %do;
   declare hash h1(dataset:"denominator");
   %end;
   h1.definekey(&qkey);
   h1.definedata("BigN");
   h1.definedone();
  end;
  if h1.find() ne 0 then call missing(of BigN);
%end;
 %if &bynum eq  0 %then %do;
   %if %length(&denominator_dataset) =0 %then %do;
     if _N_ = 1 then set denominator&i.(keep=BigN);
   %end;
   %if %length(&denominator_dataset) >0 %then %do;
     if _N_ = 1 then set denominator(keep=BigN);
   %end;
%end;

if 0 < BigN then do;
  per = divide(n , BigN);
end;
variable =cats("&&variable&i.") ;
run;
%end;

data sard_out2;
set fraction:;
run;

data sard_out3;
length 
%do i = 1 %to &bynum ;
group&i
group&i._level
%end;
variable
variable_level
context
stat_name
stat_label
$200.
stat
8.
fmt_fun $200.
;
 set sard_out2:;


%do i = 1 %to &bynum ;
group&i=cats(upcase("&&by&i")); 
group&i._level=cats(&&by&i);
%end;

context=cats("&context.");
%put _local_;
%do i = 1 %to &statisticnum ;
stat_name = "&&statistic&i.";
select(upcase(stat_name));
  when("N") do;
    stat_name ="n";
    stat_label="n";
    stat =n;
    fmt_fun = "0";
  end;
  when("BIGN") do;
    stat_name ="N";
    stat_label="N";
    stat =BigN;
    fmt_fun = "0";
  end;
  when("P") do;
     stat_name ="p";
     stat_label="%";
     stat = per;
     fmt_fun ="xx.x";
  end;
  otherwise put "WARNING:" stat_name=;
end;
variable_sort = whichc(upcase(variable), %sysfunc( tranwrd( %str("%upcase(&variable)") , %str( ) , %str(",") ) ));
statistic_sort = whichc(upcase(stat_name), %sysfunc( tranwrd( %str("%upcase(&statistic)") , %str( ) , %str(",") ) ));
output;

%end;
run;

proc sort data = sard_out3 out=&out
 %if &bynum ne  0 %then %do;
 (keep= group1--fmt_fun );
 %end;
 %if &bynum eq  0 %then %do;
 (keep= variable--fmt_fun );
 %end;
 by
 %if &bynum ne  0 %then %do;
  %do i = 1 %to &bynum ;
  group&i._level
  %end;
 %end;
variable_level
  variable_sort statistic_sort;
run;

%if %length(&denominator_dataset) > 0 %then %do;
proc delete data=Denominator;
run;
%end;

%do i = 1 %to &variablenum.;
proc delete data=Denominator&i.;
run;
proc delete data=Fraction&i.;
run;
proc delete data=Numerator&i.;
run;
%end;
proc delete data=Sard_out1;
run;
proc delete data=Sard_out2;
run;
proc delete data=Sard_out3;
run;

proc delete data=Sard_temp;
run;



%mend;
