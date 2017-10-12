/**************************************Stability**************************************************************/

/*****************************************PSI*****************************************************************/

%macro dataset(data, year1, prev_year_cut_off);

	proc sort data = &data. out = stability_&year1.;
		by CIF_ID descending Rating_date;
		where rating_date < &prev_year_cut_off.;
	run;

	proc sort data = stability_&year1. nodupkey;
		by CIF_ID;
	run; 

	%mend;

%dataset(tmp4.Corporate_v2_20130729, 2011, "31Dec2011"d)
%dataset(tmp4.Corporate_v2_20130729, 2012, "31Dec2012"d)
%dataset(tmp4.Corporate_v2_20130729, 2013, "31Dec2013"d)
%dataset(tmp4.Corporate_v2_20130729, 2014, "31Dec2014"d)



%macro stability(data, year1, segment, rg);

	proc sort data = &data. out = stability;
		by CIF_ID descending rating_date;
	run;

	proc sort data = stability;
		by CIF_ID;
	run;

	data stability_&year1. (keep = 	CIF_ID counterparty_name rating_date_&year1. MG__Local_RG_&year1. 
									PA__Local_RG_&year1. Final_Local_RG_&year1.);
		set stability_&year1.;
		rename 	MG__Local_RG = MG__Local_RG_&year1.
				PA__Local_RG = PA__Local_RG_&year1.
				Final_Local_RG = Final_Local_RG_&year1.
				rating_date = rating_date_&year1.;
		label	MG__Local_RG = MG__Local_RG_&year1.
				PA__Local_RG = PA__Local_RG_&year1.
				Final_Local_RG = Final_Local_RG_&year1.
				rating_date = rating_date_&year1.;
	run;

	data stability_&segment.;
		merge stability (in=a) stability_&year1. (in=b);
		by CIF_ID;
		if a=b;
	run;

	data stability_&segment.;
		set stability_&segment.;
		if &rg._&year1. ne &rg. then ind = 1;
		diff_between_dates = (rating_date - rating_date_&year1.)/365;
	run;

	data stability_&segment;
		set stability_&segment.;
		where 0.5 < diff_between_dates < 1.5;
	run;

	proc sql;
		create table rg_&segment. as
		select &rg., count(&rg.) as Count
		from stability_&segment.
		group by &rg.;

	proc sql;
		create table rg_&segment. as
		select &rg., Count, sum(Count) as Total
		from rg_&segment.;

	proc sql;
		create table rg_&year1._&segment. as
		select &rg._&year1., count(&rg._&year1.) as Count_&year1.
		from stability_&segment.
		group by &rg._&year1.;

	proc sql;
		create table rg_&year1._&segment. as
		select &rg._&year1., Count_&year1., sum(Count_&year1.) as Total_&year1.
		from rg_&year1._&segment.;


/******************************Population Stability Index************************************************/


	data  PSI_&segment.;
     	merge rg_&segment. (in =a) rg_&year1._&segment. (in=b rename=(&rg._&year1. = &rg.));
     	by &rg.;
     	if a=b;
	run;

	data PSI_&segment.;
		set PSI_&segment.;
		Percentage_&year1. = Count_&year1. / Total_&year1.;
		Percentage = Count/ Total;
		Change = (Percentage - Percentage_&year1.);  
		ProportionChange = (Percentage/Percentage_&year1.);
		LnProportionChange = Log(ProportionChange);
		StabilityIndex = Change * LnProportionChange;
	run;

	proc sql;	
		select sum(StabilityIndex) as PSI
		from PSI_&segment.;
	quit;


/*********************************Transition matrix*****************************************************/


	proc freq data=stability_&segment. noprint;
		tables &rg._&year1.*&rg. / out=stability_trans_&segment. nopercent nocol;
	run;

	proc sort data =stability_trans_&segment.;
		by &rg._&year1. &rg.;
	run;

	proc transpose data = stability_trans_&segment. out = stability_trans_&segment.(drop = _NAME_ _LABEL_);
		by &rg._&year1.;
		ID &rg.;
		var count; 
	run;


/**************************************CHI Square Test**************************************************/

	data rg_combination;
    	 merge rg_&segment. (in =a) rg_&year1._&segment. (in=b rename=(&rg._&year1. = &rg.));
    	 by &rg.;
	run;


	%macro missing_var (var);

		data  rg_combination;
			set  rg_combination;
			if &var = . then &var = 0;
			if Total = . then Total = Total_&year1.;
			else if Total_&year1. = . then Total_&year1. = Total;
		run;

	%mend;

	%missing_var(count_&year1.);
	%missing_var(Total_&year1.);
	%missing_var(count);
	%missing_var(Total);
	%missing_var(Percentage_&year1.);
	%missing_var(Percentage);	

	data rg_combination;
		set rg_combination;
		chi_statistic = (count - count_&year1.)**2 / (count+count_&year1.);
	run;

	proc sql;
		create table chi_test as
		select &rg., count, count_&year1., chi_statistic, sum(chi_statistic) as Sum_chi_statistic, count (&rg.) - 1 as dof
		from rg_combination;


	data chi_test;
		set chi_test;
		p_value= 1-probchi(sum_chi_statistic,dof);
	run;


		%mend;

%stability (tmp4.Corporate_v2_20130729, 2011, SA, Final_Local_RG);

