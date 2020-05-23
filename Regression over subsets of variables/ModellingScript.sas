
options symbolgen mprint;

%let dep = QoQ;

FILENAME REFFILE '/folders/myfolders/Input_data.csv';

PROC IMPORT DATAFILE=REFFILE
	DBMS=CSV
	OUT=WORK.data;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=WORK.data(drop = QoQ) out=var_names(keep = name) noprint; RUN;

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
	
	data combinations_&n.;
	set combinations_&n.;
	str = (name1
		%do i = 2 %to &n.;
			||name&i.
		%end;
	);
	run;
	
%mend;


/* Creating template for storing model parameters */

%macro summDat(n);
	data summary;
	
	format dependent $32. 
	
	%do i = 1 %to &n.;
	indep&i. $72.
	%end;
	
	intercept_est best32.
	
	%do i = 1 %to &n.;
	estimate&i. best32.
	%end;
	
	%do i = 0 %to &n.;
	tval&i. best32.
	%end;
	
	%do i = 0 %to &n.; 
	probt&i. $32.
	%end;
	
	%do i = 1 %to &n.;
	vif&i. best32.
	%end;
	
	rmse best32.
	Rsq	best32.
	adjRsq best32.
	;
	stop;
	run;

%mend;

	
	

%macro reg(var);
	

	%let r = %sysfunc(countw(&var., ' '));
	
	
	ods output FitStatistics = fitstat ParameterEstimates = parstat;
	ods trace on;
	proc reg data= data;
		model &dep. = &var. / vif stb adjrsq rsquare rmse;
	run;
	ods trace off;
	
	
	proc sql noprint;
		select 
		estimate
		,tvalue
		,probt
		,varianceInflation
		into :estimates separated by ' ' 
		, :tvals separated by ' '
		, :probs separated by ' '
		, :vifs separated by ' '
		from parstat;
	quit;
	
	%put &estimates. and &tvals. and &probs. and &vifs.;
	
	
	proc sql noprint;
		select 
		cvalue1
		,cvalue2
		into :rmse separated by ' ' 
		, :rsq separated by ' '
		from fitstat;
	quit;
	
	%put &rmse. and &rsq.;


	data dat;
		
		dependent = put("&dep.",$32.);

		intercept_est = input(scan("&estimates.",1,' '),best32.);
		
		%do i = 1 %to &r.;
		
			%let j = %sysevalf(&i.+1);
			indep&i. = put(scan("&var.", &i.),$72.);
			estimate&i. = input(scan("&estimates.",&j.,' '),best32.);
			vif&i. = input(scan("&vifs.",&j.,' '),best32.);
		
		%end;
		
		
		%do i = 1 %to &r.+1;
		
			%let h = %sysevalf(&i.-1);
			tval&h. = input(scan("&tvals.",&i.,' '),best32.);
			probt&h. = put(scan("&probs.",&i.,' '),$32.);
		
		%end;
		
		
		rmse = input(scan("&rmse.",1,' '),best32.);
		
		Rsq = input(scan("&rsq.",1,' '),best32.);
		AdjRsq = input(scan("&rsq.",2,' '),best32.);
		
			
	run;

	data summary;
		set summary dat;
	run;
	
%mend;

%macro iter(nloop);

	%summDat(&nloop.);

	%do a = 2 %to &nloop.;
		%combination(&a.);
	
	
		data _NULL_;
			if 0 then set combinations_&a. nobs=n;
			call symputx('totalobs',n);
			stop;
		run;
	
		%put no. of observations = &totalobs;
	
		%do x = 1 %to &totalobs;
		
			data _null_;
			set combinations_&a.;
			if _n_ = &x. then call symput("comb", str);
			run;
		
		%reg(&comb.);
		
		%end;
	%end;

	%put &comb.;

%mend;


/*
If you wish to create a maximum combination of 4 put it in %iter call. It will automatically create
the final summary dataset with all combination of variables i.e. 2, 3, and 4 */

%iter(2);


/*-----------------------------------------------------------------------------  
Manual Data and reg step run
-----------------------------------------------------------------------------*/

%summDat(4); /* Create summary dataset of maximum variable combination  */

/* Combination of variables till the max combination */
%combination(2);
%combination(3);
%combination(4);

/* Run regression for a combination and append result in summary dataset */

%macro manualRun(db);

	data _null_;
	set &db.;
	if 0 then set combinations_&a. nobs=n;
	call symputx('count',n);
	stop;
	run;
	
	%put no. of observations = &count;
	
	%do x = 1 %to &count;
		
			data _null_;
			set &db.;
			if _n_ = &x. then call symput("comb", str);
			run;
		%reg(&comb.);
		%end;

%mend;

%manualRun(combination_2);

