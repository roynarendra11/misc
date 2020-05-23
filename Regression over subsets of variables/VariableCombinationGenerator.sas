
options symbolgen mprint;

FILENAME REFFILE '/folders/myfolders/Input_data.csv';

PROC IMPORT DATAFILE=REFFILE
	DBMS=CSV
	OUT=WORK.data;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=WORK.data(drop = QoQ) out=var_names(keep = name); RUN;

data var_names;
set var_names;
s_no = _n_;
run;


%macro combination(n);

	proc sql;
	create table Var_Comb&n. as
	select
	a1_.*
	
	%do i = 2 %to &n.;
		%put flag1;
		, a&i._.*
	%end;
	
	from var_names(rename = (name = name1 s_no = s_no1)) as a1_
	
	%do i = 2 %to &n.;
			
		%let j = %sysevalf(&i.-1);
		inner join var_names(rename = (name = name&i. s_no = s_no&i.)) as a&i._
		on a&j._.s_no&j. < a&i._.s_no&i.
			
	%end;
	;
	quit;

	proc sort data = Var_comb&n. 
		out = combinations_&n.(drop = 
		
		%do i = 1 %to &n.;
			s_no&i.
		%end;
		); by 

		%do i = 1 %to &n.;
			s_no&i. 
		%end;
	; run;

%mend;

%combination(2);

