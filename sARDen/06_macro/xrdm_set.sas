/*** HELP START ***//*

Macro: xrdm_set  
Purpose:  
  Attach ARDM/ARM-TS-like metadata to an ARD dataset using SAS extended attributes (XATTR).  
  Supports partial updates; only non-empty parameters are written.  
  
Inputs:  
  lib=              Library where ARD dataset resides (default: WORK).  
  ard=              ARD dataset name to modify. Required.  
  result_id=        Result identifier (e.g., R001).  
  analysis_id=      Analysis identifier (e.g., A001).  
  method_id=        Method identifier (e.g., M001).  
  result_context=   Free-text description of result context.  
  table_id=         Table/TFL identifier (e.g., T14.2.1).  
  display_label=    Free-text display label for output.  
  print=            Y/N.  
                    Y -> print ExtendedAttributesDS section via PROC CONTENTS after update.  
                    N -> no print.  
  
Outputs:  
  Updates dataset-level extended attributes on &lib..&ard.  
  Optionally prints attribute listing to log/output.  
  
Dependencies / Side Effects:  
  Uses PROC DATASETS MODIFY with XATTR SET DS.  
  Does not create intermediate datasets.  
  
Notes:  
  - Free-text fields should be passed with %nrbquote(...) if they contain special characters.  
  - Existing keys are overwritten when re-specified.  
  
Example:  
  %xrdm_set(  
    lib=WORK,  
    ard=ard_tab_14_2_1,  
    result_id=R001,  
    analysis_id=A001,  
    method_id=M001,  
    result_context=%nrbquote(Drug vs Placebo on CHG),  
    table_id=%nrbquote(T14.2.1),  
    display_label=%nrbquote(Mean Difference (Drug–Placebo))  
  );

*//*** HELP END ***/

%macro xrdm_set(
lib=WORK
,ard=
,result_id=
,analysis_id=
,method_id=
,result_context=
,table_id=
,display_label=
,print=Y
);
proc datasets nolist lib=&lib;
modify &ard;
xattr set ds 

%if %length(&result_id) > 0 %then %do;
result_id ="&result_id"
%end;

%if %length(&analysis_id) > 0 %then %do;
analysis_id ="&analysis_id"
%end;

%if %length(&method_id) > 0 %then %do;
method_id ="&method_id"
%end;

%if %length(&table_id) > 0 %then %do;
table_id ="&table_id"
%end;

%if %length(&result_context) > 0 %then %do;
result_context ="&result_context"
%end;

%if %length(&display_label) > 0 %then %do;
display_label ="&display_label"
%end;

;
quit;
%if %upcase(&print) = Y %then %do;
 ods select ExtendedAttributesDS;
 proc contents data=&lib..&ard;
 run;
 ods select _all_;
%end;
%mend;
