
--create proc [usp_detect_volume_outlier] as 

	declare @q1 float
	declare @q2 float
	declare @q3 float
	declare @q4 float
	declare @iq float
	declare @r_min float
	declare @r_max float

	-- Step #1. clean up the staging table
	if object_id('stg.outlier_discovery') is not null
		drop table stg.outlier_discovery;


	-- Step #2. build the staging table with dates (business days only) and volume 
	select 
			[date] ,
			[volume]
	into stg.outlier_discovery
		from whatever_your_table_contain_volume_data

	-- Step #3. add quartile
	alter table stg.outlier_discovery add quartile int;
	alter table stg.outlier_discovery add outlier int;
	update stg.outlier_discovery set outlier=0;

	with cte as (
	select  NTILE(4) OVER(ORDER BY [volume] ASC) as quartile, [date]
	from stg.outlier_discovery
	)

	update o
		set o.quartile = cte.quartile
	from stg.outlier_discovery o
	inner join cte on o.[date] = cte.[date];


	-- step #4. calculate the outlier boundary
	-- this is not the perfect calculation as the range has been further expanded
	-- probably no need to bring it back to the regular outlier detection algorithm as this works for now
	select @q1 = avg(volume) from stg.outlier_discovery where quartile = 1;
	select @q2 = avg(volume) from stg.outlier_discovery where quartile = 2;
	select @q3 = avg(volume) from stg.outlier_discovery where quartile = 3;
	select @q4 = avg(volume) from stg.outlier_discovery where quartile = 4;
	select @iq = @q4-@q2;
	select @r_min = @q1 - 1.5*@iq;
	select @r_max = @q3 + 1.5*@iq;

	--print @q1;
	--print @q2;
	--print @q3;
	--print @q4;
	--print @iq;
	--print @q1-1.5*@iq;
	--print @q3+1.5*@iq;


	-- step #5. set the outlier flag
	update stg.outlier_discovery
	set outlier = 1
	where volume < @r_min or volume > @r_max;

