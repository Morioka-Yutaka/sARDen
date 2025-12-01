/*** HELP START ***//*

Macro: bind_ard  
Purpose:  
  Bind multiple ARD datasets (long format) into a single ARD,  
  optionally removing duplicates and normalizing column order to ARD-friendly sequence.  
  
Inputs:  
  indata=          Space-separated list of ARD datasets to stack.  
  outdata=         Output dataset name.  
  distinct=        Y/N.  
                   Y -> remove duplicate rows across inputs (excluding dsno/record_no).  
                   N -> keep all rows.  
  drop_sortno=     Y/N.  
                   Y -> drop internal dsno and record_no from output.  
                   N -> keep them.  
  
Outputs:  
  outdata= dataset containing stacked ARD rows.  
  Column order is set to: group# / group#_level / variable / variable_level / context /  
  stat_name / stat_label / stat / fmt_fun (any other columns follow).  
   
Notes:  
  - dsno increments when CUROBS resets between input datasets.  
  - distinct=Y assumes compatible column structure across ARDs to avoid unintended row drops.  
  - Current version uses "informat &vsort;" as a placeholder; column order relies on DICTIONARY sequence.  
  
Example:  
  %bind_ard(  
    indata=Sard_summary_mean Sard_tabulate Sard_stack_hierarchical_count,  
    outdata=ard_tab_14_2_1,  
    distinct=Y,  
    drop_sortno=Y  
  );

*//*** HELP END ***/

%macro bind_ard(
indata= Sard_summary_mean
 Sard_tabulate
 Sard_stack_hierarchical_count
,outdata=bind_ard
,distinct = Y
,drop_sortno=Y);  

data Sard_union;
set
&indata.
curobs=obs
indsname=name
;
retain dsno 1;
record_no = obs;
lag_record_no=lag(record_no);
if ^missing(lag_record_no) and record_no <= lag_record_no then dsno +1;
drop lag_record_no;
run;
proc sql noprint;
 create table val_order as
 select   *
 from dictionary.COLUMNS
 where libname="WORK" and memname="SARD_UNION";

 select name into: all_list separated by " "
 from dictionary.COLUMNS
 where libname="WORK" and memname="SARD_UNION";
 select name into: sort_list separated by " "
 from dictionary.COLUMNS
 where libname="WORK" and memname="SARD_UNION" and name notin ("dsno","record_no") ;
quit;
%put &=sort_list;
%if %upcase(&distinct) = Y %then %do;
proc sort data=Sard_union;
 by &all_list;
run;
proc sort data=Sard_union nodupkey;
 by &sort_list;
run;
%end;

data val_order;
set val_order;
select(name);
%do i =1 %to 9; 
when("group&i") vsort=&i;
when("group&i._level") vsort=&i*10;
%end;
when("variable") vsort=100;
when("variable_level") vsort=200;
when("context") vsort=300;
when("stat_name") vsort=400;
when("stat_label") vsort=500;
when("stat") vsort=600;
when("fmt_fun") vsort=700;
when("dsno") vsort=800;
when("record_no") vsort=900;
otherwise vsort =10000;
end;
run;
proc sort data=val_order;
where vsort<800;
 by vsort;
run;
proc sql noprint;
 select name into: vsort
 from val_order
 order by vsort;
;
quit;


data &outdata;
informat &vsort.;
 set Sard_union;
 %if %upcase(&drop_sortno) = Y %then %do;
 drop dsno record_no ;
 %end;
run;

proc delete data=Sard_union;
run;
proc delete data=val_order;
run;

%mend;
