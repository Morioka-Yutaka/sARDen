/*** HELP START ***//*

Macro: sard_stack_hierarchical_count  
Purpose:  
  Generate hierarchical ARD for count-style stacking (record/event counting).  
  Similar to sard_stack_hierarchical, but does not de-duplicate by subject id.  
  
Inputs:  
  data=                   Source event dataset (e.g., ADAE).  
  variable=               Hierarchical variables (space-separated), ordered top->bottom.  
  variable_hieral_code=   Optional ordering code variables aligned with variable= list.  
  by=                     Grouping variables (space-separated).  
  statistic=              Stats to output (space-separated). Default: n.  
  denominator_dataset=    Dataset to define denominators (optional unless p/BigN requested).  
  classdata=              Optional CLASSDATA= for PROC SUMMARY.  
  over_variables=         Y/N to include overall dummy row.  
  out=                    Output ARD dataset name.  
  
Outputs:  
  out= dataset with columns:  
    group#, group#_level, variable, variable_level, context="hierarchical",  
    stat_name, stat_label, stat, fmt_fun, plus optional variable_hieral_code columns.  
   
Notes:  
  - Counts reflect number of records/events, not number of subjects.  
  - Denominator/pct layers are computed even if statistic excludes them (harmless overhead).  
  - variable_hieral_code assumes same length as variable=.  
  
Example:  
  %sard_stack_hierarchical_count(  
    data=ADAE,  
    variable=AEBODSYS AEDECOD,  
    variable_hieral_code=AEBDSYCD F_AEPTCD,  
    by=TRTA,  
    statistic=n,  
    denominator_dataset=ADSL(rename=(TRT01A=TRTA)),  
    out=sard_stack_hierarchical_count  
  );

*//*** HELP END ***/

%macro sard_stack_hierarchical_count(
  data = ,
  variable =  ,
  variable_hieral_code = ,
  by =  ,
  statistic = n  ,
  denominator_dataset = ,
  classdata = ,
  over_variables = Y,
  out = sard_stack_hierarchical_count
);

%sard_tabulate(
  data = &denominator_dataset,
  variable = &by ,
  by = ,
  statistic = n P BigN,
  context= tabulate,
  out = toplevel
)

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

%if %length(&variable_hieral_code) ne 0 %then %do;
	%let variable_hieral_code=%kcmpres(&variable_hieral_code);
	%let variable_hieral_codenum = %sysfunc( countw( &variable_hieral_code));
  %if 1 = &variable_hieral_codenum %then %let variable_hieral_code = &variable_hieral_code;
  %if 1 < &variable_hieral_codenum %then %do;
    %do i = 1 %to &variable_hieral_codenum ;
      %let variable_hieral_code&i = %scan(&variable_hieral_code,&i,%str ( ) );
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
dummy =1;
run;
%let variable0=dummy;

%if %length(&denominator_dataset) > 0 %then %do;
  proc summary data=&denominator_dataset nway;
  %if &bynum ne  0 %then %do;
  class &by.;
  %end;
  output out=denominator(rename=(_FREQ_=BigN));
  run;
%end;

%if %upcase(&over_variables) = Y %then %do;
  %let all = 0;
%end;
%else %do;
  %let all = 1;
%end;
%do i = &all. %to &variablenum.;
proc sort data = sard_temp out=sard_temp&i;
  by  &by &&variable&i;
run;

 proc summary data= sard_temp&i; 
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
 set toplevel(in=top) sard_out2:;

if top then do;
  output;
end;

if ^top then do;
%do i = 1 %to &bynum ;
group&i=cats(upcase("&&by&i")); 
group&i._level=cats(&&by&i);
%end;

context=cats("hierarchical");
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

if variable ="dummy" then do;
  variable="hierarchical_overall";
  variable_level="Y";
end;

output;

%end;
end;

run;

%if %length(&variable_hieral_code) ne 0 %then %do;
data sard_out3;
 set sard_out3;
 if 0 then set &data(keep=&variable_hieral_code);
 if _N_ = 1 then do; 
 %do i = 1 %to &variable_hieral_codenum ;
  declare hash h&i(dataset:"&data(keep=&variable &variable_hieral_code)", multidata:"Y");
  h&i..definekey("&&variable&i");
  %do j = 1 %to &variable_hieral_codenum ;
    h&i..definedata("&&variable_hieral_code&j");
  %end;
  h&i..definedone();
 %end;
 end;
 %do i = 1 %to &variable_hieral_codenum ;
  if h&i..find() ne  0 then &&variable_hieral_code&i = 0;
 %end;
run;
%end;

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
  %if %length(&variable_hieral_code) ne 0 %then %do;
   &variable_hieral_code
  %end;
  variable_sort variable_level  statistic_sort;
run;

%if &bynum eq  0 %then %do;
proc delete data=Denominator;
run;
%end;
%do i = 1 %to &variablenum.;
%if %length(&denominator_dataset) eq 0 %then %do;
proc delete data=Denominator&i.;
run;
%end;
proc delete data=Fraction&i.;
run;
proc delete data=Numerator&i.;
run;
proc delete data=sard_temp&i.;
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
%if %upcase(&over_variables) = Y %then %do;
proc delete data=numerator0;
run;
proc delete data=fraction0;
run;
proc delete data=Sard_out0;
run;
proc delete data=Sard_temp0;
run;
%end;
%if %length(&denominator_dataset) ne 0 %then %do;
proc delete data=toplevel;
run;
%if &bynum ne  0 %then %do;
proc delete data=Denominator;
run;
%end;
%end;


%mend;
