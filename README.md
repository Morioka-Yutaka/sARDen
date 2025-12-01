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
<img width="767" height="176" alt="image" src="https://github.com/user-attachments/assets/af49ad5f-15c6-4156-ba91-ee336cb86317" />  
<img width="758" height="235" alt="image" src="https://github.com/user-attachments/assets/1a0beab0-c842-4124-ac21-2fa284a642a8" />  



