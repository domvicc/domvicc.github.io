USE [msdb]
GO

/****** Object:  Job [eda_inventory_database]    Script Date: 4/25/2023 10:34:13 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 4/25/2023 10:34:13 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'eda_inventory_database', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Combining product_branch_id from the product_branch_calculation and product_inventory_location files.


Job also running product_inventory,  product_branch_calculation and product_branch_inventory jobs', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'PRDSGECREP1\dsgadmin', 
		@notify_email_operator_name=N'Dom Vicchiollo', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [product_branch]    Script Date: 4/25/2023 10:34:14 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'product_branch', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=1, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.product_branch
create table dbo.product_branch (
		product_branch_id varchar(255) collate SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,
		product_id int,
		branch_id varchar(255) collate SQL_Latin1_General_CP1_CS_AS,
		create_date datetime
		)
insert into dbo.product_branch
select 
	pb.*
from (
	select * from (
		select 
			eclipse_id as product_branch_id,
			cast(replace(substring(eclipse_id,0,charindex(''*'',eclipse_id)),''.'','''') as int) as product_id,
			substring(eclipse_id,charindex(''*'',eclipse_id)+1,99) as branch_id,
			getdate() as create_date
		from eclipse.product_inventory as pie
		where len(eclipse_id) < 50 /* Adding this filter to prevent job from failing due to bad data on product id */ 
	union
		select 
			eclipse_id as product_branch_id,
			cast(replace(substring(eclipse_id,0,charindex(''*'',eclipse_id)),''.'','''') as int) as product_id,
			substring(eclipse_id,charindex(''*'',eclipse_id)+1,99) as branch_id,
			getdate() as create_date
		from eclipse.product_branch_calculation
	 ) as sub 
) as pb
	
create index idx_product_id on dbo.product_branch (product_id)
create index idx_branch_id on dbo.product_branch (branch_id)', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [branch_product]    Script Date: 4/25/2023 10:34:14 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'branch_product', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=1, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.branch_product
create table dbo.branch_product (

		product_branch_id varchar(255) collate SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,
		lead_time_days int,
		lead_time_override_flag int,
		user_control_min_qty int,
		user_control_max_qty int,
		manual_safety_stock int,
		safety_factor float,
		lead_factor float, 
		branch_stock_status varchar(255),
		user_control_min_max_expire_date date,
		safety_stock_expiration_date date,
		ss_expire_date date,
		forecast_parameter_seasonal_flag int,
		buy_package_qty int,
		is_divisable nvarchar(99)	
	)

insert into dbo.branch_product

select distinct

		pt.product_branch_id,

		/* Checking lead time overrides at 1. Branch Level 2. Territory Level 3. All Level */
		case when isnull(pb.lead_time_days,0) > 0 then pb.lead_time_days
			 when isnull(bp.lead_time_days,0) > 0 then bp.lead_time_days
			 when isnull(ter.lead_time_days,0) > 0 then ter.lead_time_days
			 else null
			 end as lead_time_days,

		case when isnull(pb.lead_time_days,0) > 0 then 1
			 when isnull(bp.lead_time_days,0) > 0 then 1
			 when isnull(ter.lead_time_days,0) > 0 then 1
			 else 0
			 end as lead_time_override_flag,

		pb.user_control_min_qty,
		pb.user_control_max_qty,
		pb.user_control_service_stock_qty as manual_safety_stock,
		pb.safety_factor,
		pb.lead_factor,
		/* Branch Product Stock Flag Order of Operations: the system checks for the stock flag in the following order: 1. Branch Level Override  2. Territory Override  3. All Branch Override  4. Default (Auto)  */                                                                  
		case -- Branch Level Stock Flag in case where branch flag is not null
			when pb.product_stock_flag is not null then
			case when pb.product_stock_flag = ''Y'' then ''Yes''
					when pb.product_stock_flag = ''y'' then ''Yes'' 
					when pb.product_stock_flag = ''0'' then ''No''
					when pb.product_stock_flag = ''-'' then ''Auto''
					when pb.product_stock_flag = ''1'' then ''Yes'' 
					when pb.product_stock_flag = ''D'' then ''Discontinued''
					when pb.product_stock_flag = ''2'' then ''Auto''
					when pb.product_stock_flag = ''NO'' then ''No'' 
					when pb.product_stock_flag = ''N'' then ''No'' 
					end
			-- Territory Level Stock Flag in case where branch stock flag is null and terriroty flag is not
			when pb.product_stock_flag is null and ter.product_stock_flag is not null then  
					case when ter.product_stock_flag = ''Y'' then ''Yes''
					when ter.product_stock_flag = ''y'' then ''Yes'' 
					when ter.product_stock_flag = ''0'' then ''No''
					when ter.product_stock_flag = ''-'' then ''Auto''
					when ter.product_stock_flag = ''1'' then ''Yes'' 
					when ter.product_stock_flag = ''D'' then ''Discontinued''
					when ter.product_stock_flag = ''2'' then ''Auto''
					when ter.product_stock_flag = ''NO'' then ''No'' 
					when ter.product_stock_flag = ''N'' then ''No'' 
					end
			-- ALL level Stock Flag in case when branch and territory are null (auto) 
			when pb.product_stock_flag is null and ter.product_stock_flag is null and bp.product_stock_flag is not null then
					case when bp.product_stock_flag = ''Y'' then ''Yes''
					when bp.product_stock_flag = ''y'' then ''Yes'' 
					when bp.product_stock_flag = ''0'' then ''No''
					when bp.product_stock_flag = ''-'' then ''Auto''
					when bp.product_stock_flag = ''1'' then ''Yes'' 
					when bp.product_stock_flag = ''D'' then ''Discontinued''
					when bp.product_stock_flag = ''2'' then ''No''
					when bp.product_stock_flag = ''NO'' then ''No'' 
					when bp.product_stock_flag = ''N'' then ''No'' 
					end
			else ''Auto''
		end as branch_stock_status,

		case when pb.user_control_min_max_expire_date < dateadd(dd,-365,getdate()) then dateadd(dd,-365,getdate()) 
			 when pb.user_control_min_max_expire_date > dateadd(dd,1500,getdate()) then dateadd(dd,1500,getdate())
			 else isnull(pb.user_control_min_max_expire_date,bp.user_control_min_max_expire_date)
		end as user_control_min_max_expire_date, 

		case when  pb.user_control_service_stock_expire_date  < dateadd(dd,-365,getdate()) then dateadd(dd,-365,getdate()) 
			 when  pb.user_control_service_stock_expire_date  > dateadd(dd,1500,getdate()) then dateadd(dd,1500,getdate())
			 else pb.user_control_service_stock_expire_date
		end as safety_stock_expiration_date,

		pb.user_control_service_stock_expire_date as ss_expire_date,
		isnull(pb.forecast_parameter_seasonal_flag,bp.forecast_parameter_seasonal_flag) as forecast_parameter_seasonal_flag,

		isnull(pb.buy_package_qty,bp.buy_package_qty) as buy_package_qty,
		isnull(pb.is_buy_package_divisible,bp.is_buy_package_divisible) as is_divisable

		 
from dbo.product_branch as pt
	left join eclipse.product_branch as pb on pb.branch_id = pt.branch_id and pb.eclipse_id = pt.product_id
	left join eclipse.product_branch as bp on bp.eclipse_id = pt.product_id and bp.branch_id = ''ALL'' 
	/* adding territory level product_branch items for all pb columns */
	left join (
				select *
				from (
						select 
							concat(product_id,''*'',t.territory_branch_id) as pbi,
							/* added in rank by using the pb.product_branch_id ex 11565_7 to sub string int after ''_'' and rank by accroding value to pull only branches with the first priorty by rank dv 4/24/23 */ 
							rank() over(partition by pb.product_id order by cast(stuff(product_branch_id,1,charindex(''_'',product_branch_id),'''') as int)) as rnk,
							pb.*
						from eclipse.product_branch as pb
							left join eclipse.territory_branch_list as t on t.territory_id = pb.branch_id
						where
						branch_id in
							(select distinct
								eclipse_id
								from eclipse.territory_branch_list
								)
					) as sub
				where sub.rnk = 1 
			  ) as ter on ter.pbi = pt.product_branch_id
	
 
', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [buy_line_branch]    Script Date: 4/25/2023 10:34:14 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'buy_line_branch', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=1, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.buy_line_branch
create table dbo.buy_line_branch (
		
		buy_line_branch varchar(255) collate SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,
		branch_id varchar(255) collate SQL_Latin1_General_CP1_CS_AS,
		warehouse_branch varchar(255) collate SQL_Latin1_General_CP1_CS_AS,
		buy_branch varchar(255) collate SQL_Latin1_General_CP1_CS_AS,
		demand_branch varchar(255) collate SQL_Latin1_General_CP1_CS_AS,
		buy_line_id varchar(255) collate SQL_Latin1_General_CP1_CS_AS,
		procure_group_id nvarchar(255),
		child_branch_type varchar(255),
		target_type nvarchar(255),
		target_amount nvarchar(255),
		buyline_lead_time int,
		lead_time_override_flag int, 
		override_lead_time_expire_date date,
		default_lead_factor int,
		default_lead_time_days int,
		avg_lead_time int, 
		buyer varchar(255),
		buyer_default varchar(255),
		forecast_parameter_trend_percentage float,
		child_branch_flag int,
		seasonal_flag int,
		combine_on_central_purchase_order int,
		line_buy_cycle_days int,
		last_line_buy_date date,
		days_into_cycle int,
		branch_target_hits int,
		network_target_hits int,
		suggest_on_all_flag int
		)

insert into dbo.buy_line_branch

		select distinct 
		*
		from (
			select  
					concat(bl.eclipse_id,''*'',br.branch_id) as buy_line_branch,
					br.branch_id,
					c.warehouse_branch,
					c.buy_branch,
					c.demand_branch,
					bl.eclipse_id as buy_line_id, 
					bl.procure_group_id,

					case when c.child_branch_flag = 0 then ''Parent''
					 	 when c.child_branch_flag = 1 then ''Parent-Child''
						 when c.child_branch_flag = 2 then ''Child - Warehouse''
						 when c.child_branch_flag = 3 then ''Child - Purchase'' 
						 when c.child_branch_flag = 4 then ''Grand-Child'' 
						 when c.child_branch_flag = 5 then ''Grand-Parent''
					end as child_branch_type,
					 
					isnull(isnull(blb.target_type,t.target_type),b.target_type) as target_type,
					isnull(isnull(blb.target_amount_level1,t.target_amount_level1),b.target_amount_level1) as target_amount,

					/* If transfer branch, then c.lead_time (7), else cycles through branch, territory , then "ALL" level */
					case when c.lead_time > 0  then c.lead_time
						 when blb.override_lead_time_days is not null and isnull(blb.override_lead_time_expire_date,cast(getdate() as date)) >= cast(getdate() as date) then blb.override_lead_time_days
						 when t.override_lead_time_days is not null and ISNULL(t.override_lead_time_expire_date,cast(getdate() as date)) >= CAST(getdate() as date) then t.override_lead_time_days
						 when b.override_lead_time_days is not null and isnull(b.override_lead_time_expire_date,cast(getdate() as date))>=cast(getdate() as date) then b.override_lead_time_days
					 	 else null
						end as ''buyline_lead_time'', 

					case when c.child_branch_flag in (0,5) and isnull(isnull(blb.override_lead_time_days,t.override_lead_time_days),b.override_lead_time_days) > 0 then 1 else 0 end as lead_time_override_flag,

					isnull(isnull(blb.override_lead_time_expire_date,t.override_lead_time_expire_date),b.override_lead_time_expire_date) as ''override_lead_time_expire_date'',
					isnull(isnull(blb.default_lead_factor,t.default_lead_factor),b.default_lead_factor) as ''default_lead_factor'',
					isnull(isnull(blb.default_lead_time_days,t.default_lead_time_days),b.default_lead_time_days) as ''default_lead_time_days'',
					a.avg_lead_time,
					
					/* Per JW request 6/23/2021- only reporting on actual field entries for buyer.....seperating into two fields because In Stock Report needs a rollup view of Buyers */
					case when blb.buyer is null then isnull(t.buyer,b.buyer)
						 when charindex(''_'',blb.buyer) = 0 then blb.buyer 
						 when charindex(''_'',blb.buyer) > 0 then isnull((select distinct buyer from eclipse.buy_line_branch as b where b.buy_line_id = blb.buy_line_id and b.branch_id = substring(blb.buyer,0,charindex(''_'',blb.buyer))),b.buyer)
						 else blb.buyer
						 end as ''buyer'',

					isnull(isnull(blb.buyer,t.buyer),b.buyer) as buyer_default, 
					isnull(isnull(blb.forecast_parameter_trend_percentage,t.forecast_parameter_trend_percentage),b.forecast_parameter_trend_percentage) as ''forecast_parameter_trend_percentage'',
					isnull(c.child_branch_flag,0) as ''child_branch_flag'',
					isnull(isnull(blb.forecast_parameter_seasonal_flag,t.forecast_parameter_seasonal_flag),b.forecast_parameter_seasonal_flag) as ''seasonal_flag'',
					bl.combine_on_central_purchase_order,
					isnull(isnull(blb.line_buy_cycle_days,t.line_buy_cycle_days),b.line_buy_cycle_days) as ''line_buy_cycle_days'',
					isnull(blbc.last_line_buy_date,p.last_line_buy_date) as last_line_buy_date,
					datediff(dd,isnull(isnull(blb.line_buy_cycle_days,t.line_buy_cycle_days),b.line_buy_cycle_days),getdate()) as ''days_into_cycle'',
					case when blbc.branch_id = ''WIN'' then 2 else 4 end as branch_target_hits,
					''6'' as network_target_hits,
					max(cast(isnull(isnull(blb.suggest_on_all_flag,t.suggest_on_all_flag),b.suggest_on_all_flag) as int)) over(partition by br.branch_id) as suggest_on_all_flag
				from eclipse.branch as br
						inner join eclipse.buy_line as bl on bl.eclipse_id = bl.eclipse_id
						/* Buy line branch - branch w/ records ***Added territory logic 4/10/22) - Found after MICH conversion, buyer group started using territories */
						left join eclipse.buy_line_branch as blb on blb.branch_id = br.branch_id and blb.buy_line_id = bl.buy_line_id
						
						/*  Buy Line Branch Maintenance Branch Territory Branch ID  */
						left join (
									select *
									from (
										select
											t.territory_branch_id,
											b.*,
											m.matrix_hierarchy,
											row_number() over(partition by t.territory_branch_id order by matrix_hierarchy) as id /* tagging row id in order of matrix terriorty hierarchy to specify only id = 1 */ 
										from eclipse.buy_line_branch as b
											left join eclipse.territory_branch_list as t on t.eclipse_id = b.branch_id
											/* added matrix_hierarchy to evaluate territory order, and tag row_id = 1 as parent territory */
											left join eclipse.branch_matrix_hierarchy_branch_list as m on m.branch_id = t.territory_branch_id and t.territory_id = m.matrix_hierarchy_branch_id
										where t.territory_branch_list_id is not null   
									) as sub
									where id = 1 
								) as t on t.territory_branch_id = br.branch_id and t.buy_line_id = bl.buy_line_id
					
					
						 left join (
									select *
									from eclipse.buy_line_branch_calc
									where left(eclipse_id,9) not in (''KOHFCTS *'',''KOHFIXT *'',''ZURNIND *'') and left(eclipse_id,8) not in (''UPONOR *'')
								  ) as blbc on blbc.buy_line_id = blb.buy_line_id and blbc.branch_id = br.branch_id				
						/*  Buy Line Branch Maintenance Branch = ALL  */
						left join eclipse.buy_line_branch as b on b.buy_line_id = bl.buy_line_id and b.branch_id = ''ALL''  
						/* Procure Groups &  Child Branch Flag & Default Lead Time = 7  */
						left join (
									select distinct 
											sub.buy_line_id,
											sub.branch_id,
											sub.warehouse_branch,
											sub.buy_branch,
											sub.procure_group_id,
											sub.demand_branch,
												/* Grand Child */
											case when sub.child_branch_flag = 2 and pb.branch_id is not null then 4 
												 when sub.child_branch_flag = 0 and gp.buy_branch is not null then 5 
												 else sub.child_branch_flag 
												 end as child_branch_flag,
											sub.lead_time,
											sub.additional_lead_time,
											sub.branch_target_hits,
											sub.network_target_hits,
											sub.sql_last_modified,
											pb.branch_id as pb_br,
											pb.warehouse_branch as pb_w,
											pb.buy_branch as pb_b,
											gp.buy_branch as gp_branch
										from (
											select distinct 
												bl.eclipse_id as buy_line_id,
												pb.branch_id,
												pb.warehouse_branch,
												pb.buy_branch, 
												pb.procure_group_id,
												/* Demand Branch */
												case when pb.branch_id = pb.warehouse_branch and pb.branch_id = pb.buy_branch then pb.branch_id 
															
														when pb.branch_id = pb.warehouse_branch and pb.branch_id <> pb.buy_branch then pb.branch_id
														/* Grand Parent */
														when bp.buy_branch is not null and bp.buy_branch = pb.branch_id then pb.buy_branch	
														when pb.buy_branch <> pb.branch_id and pb.buy_branch <> pb.warehouse_branch and pb.branch_id <> pb.warehouse_branch then pb.warehouse_branch
														when pb.branch_id <> pb.buy_branch then pb.buy_branch
														end as demand_branch, 
												/*Child & Parent/Child Branch Flag */ 
												case when pb.branch_id = pb.warehouse_branch and pb.branch_id = pb.buy_branch then 0
													when bp.buy_branch is not null and bp.buy_branch = pb.branch_id and bp.branch_id <> pb.branch_id then 1
													when pb.branch_id = pb.warehouse_branch and pb.branch_id <> pb.buy_branch then 3
											--		when c.branch_id is not null then 4 
													when pb.buy_branch <> pb.branch_id and pb.buy_branch <> pb.warehouse_branch and pb.branch_id <> pb.warehouse_branch then 2
													when pb.branch_id <> pb.buy_branch then 2
													end as child_branch_flag,	
												/* Default Transfer Lead Time */
											
												case when pb.branch_id = pb.warehouse_branch and pb.branch_id = pb.buy_branch then 0 
													when bp.buy_branch is not null and bp.buy_branch = pb.branch_id  then t.cycle_days
													when pb.branch_id = pb.warehouse_branch and pb.branch_id <> pb.buy_branch then 0
													when pb.buy_branch <> pb.branch_id and pb.buy_branch <> pb.warehouse_branch and pb.branch_id <> pb.warehouse_branch then t.cycle_days
													when pb.branch_id <> pb.buy_branch then t.cycle_days
													end as lead_time,

												t.additional_lead_time,
												
												case when pb.branch_id = ''WIN'' then 2 else 4 end as branch_target_hits,
												--case when pb.branch_id = ''WIN'' then 4 else 6 end as network_target_hits,
												''6'' as network_target_hits,
												pb.sql_last_modified
											from eclipse.buy_line as bl									
												left join eclipse.procure_group_branch as pb on pb.eclipse_id = bl.procure_group_id
												left join eclipse.procure_group_branch as bp on bp.eclipse_id = bl.procure_group_id and bp.buy_branch = pb.branch_id and bp.branch_id <> pb.branch_id 
												/* Auto Suggest Transfer Lead Time  */
												left join (
														select 
															substring(replace(sat.eclipse_id,''AUTO.XFER.DFLT~'',''''),1,charindex(''.'',replace(sat.eclipse_id,''AUTO.XFER.DFLT~'',''''))-1) as from_branch,
															substring(replace(sat.eclipse_id,''AUTO.XFER.DFLT~'',''''),charindex(''.'',replace(sat.eclipse_id,''AUTO.XFER.DFLT~'',''''))+1,99) as to_branch,
															replace(cycle_days,''²'','''') as cycle_days,
															replace(additional_lead_time,''²'','''') as additional_lead_time,
															replace(ship_via,''²'','''') as ship_via
														from eclipse_ud.suggested_auto_transfer as sat
														where left(eclipse_id,9) = ''AUTO.XFER'' 
														) as t on t.to_branch = pb.branch_id and t.from_branch = pb.buy_branch

											) as sub
									/* Grand Child */
									left join (
												select * from (
												select pb.*,
														case when pb.branch_id = pb.warehouse_branch and pb.branch_id = pb.buy_branch then 0
															when bp.buy_branch is not null and bp.buy_branch = pb.branch_id and bp.branch_id <> pb.branch_id then 1
															when pb.branch_id = pb.warehouse_branch and pb.branch_id <> pb.buy_branch then 3
										 					when pb.buy_branch <> pb.branch_id and pb.buy_branch <> pb.warehouse_branch and pb.branch_id <> pb.warehouse_branch then 2
															when pb.branch_id <> pb.buy_branch then 2
															end as child_branch_flag
												from eclipse.buy_line as bl									
													left join eclipse.procure_group_branch as pb on pb.eclipse_id = bl.procure_group_id
													left join eclipse.procure_group_branch as bp on bp.eclipse_id = bl.procure_group_id and bp.buy_branch = pb.branch_id and bp.branch_id <> pb.branch_id 
													) as sub
												where sub.child_branch_flag = 1
											) as pb on pb.procure_group_id = sub.procure_group_id and pb.branch_id = sub.demand_branch and sub.buy_branch = pb.branch_id
									/* Grand Parent */
									left join (
												select * from (
												select pb.*,
														case when pb.branch_id = pb.warehouse_branch and pb.branch_id = pb.buy_branch then 0
															when bp.buy_branch is not null and bp.buy_branch = pb.branch_id and bp.branch_id <> pb.branch_id then 1
															when pb.branch_id = pb.warehouse_branch and pb.branch_id <> pb.buy_branch then 3
										 					when pb.buy_branch <> pb.branch_id and pb.buy_branch <> pb.warehouse_branch and pb.branch_id <> pb.warehouse_branch then 2
															when pb.branch_id <> pb.buy_branch then 2
															end as child_branch_flag
												from eclipse.buy_line as bl									
													left join eclipse.procure_group_branch as pb on pb.eclipse_id = bl.procure_group_id
													left join eclipse.procure_group_branch as bp on bp.eclipse_id = bl.procure_group_id and bp.buy_branch = pb.branch_id and bp.branch_id <> pb.branch_id 
													) as sub
												where sub.child_branch_flag = 1
													) as gp on gp.procure_group_id = sub.procure_group_id and gp.buy_branch = sub.buy_branch
								) as c on c.branch_id = br.branch_id and c.buy_line_id = bl.buy_line_id
							/* Last Buy Date from Parent Branch */
							--left join eclipse.buy_line_branch_calc as p on p.buy_line_id = bl.buy_line_id and p.branch_id = c.buy_branch
							left join (
										select *
										from eclipse.buy_line_branch_calc
										where left(eclipse_id,9) not in (''KOHFCTS *'',''KOHFIXT *'',''ZURNIND *'') and left(eclipse_id,8) not in (''UPONOR *'') 
									) as p on p.buy_line_id = bl.buy_line_id and p.branch_id = c.buy_branch
							/* Average Buy Line Lead Time */
							left join (
										select 
											buy_line_id,
											avg(lead_time) as avg_lead_time
										from (
											select distinct
												receive_branch,
												pay_to_id,
												v.eclipse_id as buy_line_id, 
												order_date,
												receive_date,
												datediff(dd,order_date,receive_date) as lead_time
											from eclipse.purchase_order_generation as pog
												left join eclipse.buy_line_branch_vendor as v on v.vendor_id = pog.ship_from_id and replace(v.branch_id,''ALL'',pog.receive_branch) = pog.receive_branch
											where status_code = ''R'' and receive_date > dateadd(dd,-90,getdate())
										) as sub
										where buy_line_id is not null  
										group by buy_line_id
									) as a on a.buy_line_id = bl.buy_line_id collate SQL_Latin1_General_CP1_CS_AS
						) as sub


', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [branch_demand]    Script Date: 4/25/2023 10:34:14 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'branch_demand', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=1, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.branch_demand 
create table dbo.branch_demand (
		product_branch_id varchar(255) collate SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,
		product_demand_branch_id varchar(255) collate SQL_Latin1_General_CP1_CS_AS,
		buy_line_id varchar(255),
		branch_stock_status varchar(50),
		product_status_id int,
		product_stock_status varchar(50),
		branch_id varchar(10) collate SQL_Latin1_General_CP1_CS_AS,
		warehouse_branch varchar(10),
		buy_branch varchar(10),
		demand_branch varchar(10) ,
		child_branch_flag int,
		child_branch_type varchar(50),
		product_id int,
		eoq int,
		max_eoq int,
		low_sale_qty int,
		demand_per_day float,
		network_demand float,
		demand_period_days int,
		raw_hits int,
		network_raw_hits int,
		hits int,
		network_hits int,
		purchase_qty int,
		branch_target_hits int,
		network_target_hits int,
		combine_on_central_purchase_order int,
		safe_stock_date_flag int,
		min_max_date_flag int,
		parent_hits_flag int,
		lead_time int,
		lead_time_override_flag int,
		lead_time_override_type varchar(50), 
		manual_safety_stock int,
		user_control_min_qty int,
		user_control_max_qty int,
		safety_factor float,
		seasonal_flag int,
		safety_stock_expire_date date,
		user_control_min_max_expire_date date,
		line_buy_cycle_days int,
		days_into_cycle int,
		last_buy_date date,
		avg_lead_time int,
		is_divisable nvarchar(255)
		)
insert into dbo.branch_demand			
	select distinct 
		op.product_branch_id, 
		concat(pbc.product_id,''*'',isnull(b.demand_branch,substring(product_branch_id,charindex(''*'',product_branch_id)+1,99))) as product_demand_branch_id,
		p.buy_line_id,
		op.branch_stock_status,
		p.product_status_id,
		p.product_stock_status,
		isnull(b.branch_id,substring(product_branch_id,charindex(''*'',product_branch_id)+1,99)) as branch_id,
		b.warehouse_branch,
		b.buy_branch,
		b.demand_branch as demand_branch, 
		b.child_branch_flag,
		b.child_branch_type,
		isnull(pbc.product_id,cast(replace(SUBSTRING(op.product_branch_id,1,CHARINDEX(''*'',op.product_branch_id)-1),''.'','''') as int)) as product_id,
		pbc.eoq,
		(pbc.demand_per_day / cast(isnull(p.purchase_qty,1) as float)) * 183 as max_eoq,
		pbc.low_sale_qty,
		cast(
			case when pbc.demand_per_day / cast(isnull(p.purchase_qty,1) as float)  < 0 then 0
					when pbc.demand_per_day / cast(isnull(p.purchase_qty,1) as float)  is null then 0 
					else pbc.demand_per_day / cast(isnull(p.purchase_qty,1) as float) 
					end
			as decimal(18,4)) as demand_per_day ,

			sum(demand_per_day) over(partition by demand_branch,pbc.product_id) as network_demand,
		
			pbc.demand_period_days,
			pbc.raw_hits as raw_hits,
			sum(pbc.raw_hits) over(partition by demand_branch, pbc.product_id) as network_raw_hits,
			pbc.hits,
			sum(pbc.hits) over(partition by demand_branch,pbc.product_id) as network_hits,
			p.purchase_qty,
			b.branch_target_hits,
			b.network_target_hits,
			b.combine_on_central_purchase_order,
			case when op.manual_safety_stock > 0 and isnull(op.ss_expire_date,cast(getdate() as date)) >= cast(getdate() as date) then 1 else 0 end as safe_stock_date_flag,
			case when (op.user_control_min_qty > 0 or op.user_control_max_qty > 0) and isnull(op.user_control_min_max_expire_date,cast(getdate() as date)) >= cast(getdate() as date) then 1 else 0 end as min_max_date_flag,
			case when branch_stock_status = ''Yes'' then 1
				 when raw_hits >= b.branch_target_hits then 1
				 when hits >= b.network_target_hits then 1 
				 when sum(pbc.hits) over(partition by demand_branch,pbc.product_id) >= b.network_target_hits then 1 
				 when sum(pbc.hits) over(partition by demand_branch,pbc.product_id) >= b.network_target_hits then 1 
				 else 0 end as parent_hits_flag,

			/* Lead Time - Lead Times at product level take precedence over those at buy line Order of operations:  1. Product-Branch Override	2. Buyline Override 3. Product-Branch Default 4. Buyline Default  5. System Default of 14 days 	*/
			case when op.lead_time_days > 0 then op.lead_time_days
				 when b.buyline_lead_time > 0 then b.buyline_lead_time
				 when pbc.lead_time_days > 0 then pbc.lead_time_days
				 when b.default_lead_time_days > 0 then b.default_lead_time_days
				 else 14
				 end as lead_time,

			case when op.lead_time_override_flag = 1 then 1
				 when b.lead_time_override_flag = 1 then 1
				 when pbc.lead_time_days > 0 then 0
				 when b.default_lead_time_days > 0 then 0
				 else 0
				 end as lead_time_override_flag,

			case when op.lead_time_override_flag > 0 then ''Product Override''
				 when b.lead_time_override_flag > 0 then ''Buy Line Override''
				 when pbc.lead_time_days > 0 then ''Calculated Lead Time''
				 when b.lead_time_override_flag = 0 then ''Xfer Lead Time''
				 when b.default_lead_time_days > 0 then ''Default Lead Time''
				 else null
				 end as lead_time_override_type, 


			isnull(op.manual_safety_stock / cast(isnull(p.purchase_qty,1) as float),0) as manual_safety_stock,
			op.user_control_min_qty,
			op.user_control_max_qty,
			op.safety_factor,
			op.forecast_parameter_seasonal_flag as seasonal_flag,
			op.ss_expire_date,
			op.user_control_min_max_expire_date,
			b.line_buy_cycle_days,
			b.days_into_cycle,
			b.last_line_buy_date,
			b.avg_lead_time,
			case when isnull(op.is_divisable,0) = ''1'' then ''Yes'' 
				 when isnull(op.is_divisable,0) = ''Y'' then ''Yes''
				 else ''No'' end as is_divisable
	from dbo.branch_product as op
		
		left join eclipse.product_branch_calculation as pbc on op.product_branch_id = pbc.eclipse_id
		left join ( 
			select
				p.eclipse_id,
				p.buy_line_id,
				p.price_line_id,
				p.eclipse_id as product_id,
				p.product_status_id,
				cast(p.description as nvarchar(50)) as description,
				p.catalog_number,
				p.upc,
				--product_gl_type,
				--product_status_id,
				s.description as product_stock_status,
				cast(p.keywords as nvarchar(50)) as keywords,
				p.select_code,
				--matrix_type,
				--index_type,
				--unit_weight,
				--pdw_item_id,
				commodity_code,
				p.branch_cost_per_qty,
				p.branch_cost_per_um,
				p.user_defined_id1,
				p.user_defined_id2,
				uom.uom_qty as purchase_qty
				--p.user_defined_id10
			from eclipse.product as p
				left join eclipse.system_product_status as s on s.system_product_status_id = p.product_status_id
				left join eclipse.product_uom as uom on uom.product_uom_id = concat(p.eclipse_id,''_'',p.default_purchase_uom_position)
		) as p on p.eclipse_id = cast(replace(SUBSTRING(op.product_branch_id,1,CHARINDEX(''*'',op.product_branch_id)-1),''.'','''') as int)
		left join dbo.buy_line_branch as b on b.branch_id = substring(product_branch_id,charindex(''*'',product_branch_id)+1,99) and b.buy_line_id = p.buy_line_id
	--where b.branch_id is  null 


', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [branch_territory_demand]    Script Date: 4/25/2023 10:34:14 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'branch_territory_demand', 
		@step_id=5, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=1, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.branch_territory_demand 
create table dbo.branch_territory_demand (

		product_branch_id varchar(255) collate SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,
		buy_line_id varchar(255),
		branch_stock_status varchar(50),
		product_stock_status varchar(50),
		branch_id varchar(10),
		warehouse_branch varchar(10),
		buy_branch varchar(10),
		demand_branch varchar(10) ,
		child_branch_flag int,
		child_branch_type varchar(50),
		product_id int,
		eoq int,
		branch_eoq int,
		max_eoq int,
		low_sale_qty int,
		demand_per_day float,
		branch_demand float,
		network_demand float,
		demand_period_days int,
		raw_hits int,
		network_raw_hits int,
		hits int,
		network_hits int,
		branch_target_hits int,
		network_target_hits int,
		combine_on_central_purchase_order int,
		safe_stock_date_flag int,
		min_max_date_flag int,
		parent_hits_flag int,
		lead_time int,
		lead_time_override_flag int,
		lead_time_override_type varchar(50), 
		manual_safety_stock int,
		safety_stock_expire_date date,
		user_control_min_qty int,
		user_control_max_qty int,
		user_control_min_max_expire_date date,
		safety_factor float,
		seasonal_flag int,
		purchase_qty int,
		hrsc float,
		sfty_days float,
		order_point_days int,
		order_point float,
		pil int,
		sql_order_point int,
		line_buy_cycle_days int,
		days_into_cycle int,
		last_buy_date date,
		avg_lead_time int,
		is_divisable nvarchar(255)

		)

insert into dbo.branch_territory_demand				
				
select  
	--case when branch_stock_status = ''Auto'' and raw_hits < branch_target_hits and network_raw_hits >= network_target_hits then demand_per_day 
	
	--else 0 end as test, 
	product_branch_id,
	buy_line_id,
	branch_stock_status,
	product_stock_status,
	branch_id,
	warehouse_branch,
	buy_branch,
	demand_branch,
	child_branch_flag,
	child_branch_type,
	product_id,
	eoq,
	branch_eoq,
	max_eoq,
	low_sale_qty,
	case when branch_stock_status = ''Yes'' then demand_per_day
		 when raw_hits < branch_target_hits and (min_max_date_flag = 1 or safe_stock_date_flag = 1) then demand_per_day
		 when raw_hits < branch_target_hits then 0
		 when raw_hits >= branch_target_hits then demand_per_day
		 when min_max_date_flag = 1 or safe_stock_date_flag = 1 then demand_per_day
		 else 0
		 end as demand_per_day,
	sum(branch_demand) over(partition by product_demand_branch_id) as branch_demand,
	network_demand,
	demand_period_days,
	raw_hits,
	network_raw_hits,
	hits,
	network_hits,
	branch_target_hits,
	network_target_hits,
	combine_on_central_purchase_order,
	safe_stock_date_flag,
	min_max_date_flag,
	parent_hits_flag,
	lead_time,
	lead_time_override_flag,
	lead_time_override_type, 
	manual_safety_stock,
	safety_stock_expire_date,
	user_control_min_qty,
	user_control_max_qty,
	user_control_min_max_expire_date,
	safety_factor,
	seasonal_flag,
	purchase_qty,
	hrsc,
	sfty_days,
	(cast(round(round(sfty_days,1,1),0) as int) + lead_time) as order_point_days, 
	order_point,
	pil,
	sql_order_point,
	line_buy_cycle_days,
	days_into_cycle,
	last_buy_date,
	avg_lead_time,
	is_divisable

from (


select *,

isnull(
		case when branch_stock_status not in (''Yes'',''Auto'') then 0 
			-- when b.child_branch_flag = 4 then 0 
			/*    Parent  & Child-Purchase & Grand Parent  
							0 = Parent Branch			
							1 = Parent - Child			
							2 = Child - Warehouse		
							3 = Child - Purchase		
							4 = Grand Child				
							5 = Grand Parent 			
												  	  */		
													  
				when child_branch_flag in (0,5) then 
								 
					case 	when branch_stock_status = ''Yes'' then demand_per_day
							when raw_hits >= branch_target_hits then demand_per_day
							when raw_hits < branch_target_hits and network_raw_hits >= network_target_hits then demand_per_day
							else 0 
							end
				
				when child_branch_flag in (1,2,3,4) then 
								 
					case 	when branch_stock_status not in (''Yes'',''Auto'') then 0 
							when branch_stock_status = ''Auto'' then 
									case when raw_hits < branch_target_hits and network_raw_hits >= network_target_hits then demand_per_day 
										 else 0 end
							when branch_stock_status = ''Yes'' then 0 --case when order_point > pil then demand_per_day else 0 end 
							--when raw_hits >= branch_target_hits and order_point > pil then demand_per_day
							when raw_hits >= branch_target_hits then 0
							when raw_hits < branch_target_hits and network_raw_hits >= network_target_hits then demand_per_day
							else 0 
							end
			 
				--when child_branch_flag in (2,3,4) then 
				--	case when /*(select branch_stock_status from dbo.branch_product as b where b.product_branch_id = sub.product_branch_id) */ branch_stock_status not in (''Yes'',''Auto'') then 0 
				--		 when raw_hits < branch_target_hits and network_raw_hits >= network_target_hits and order_point > pil then demand_per_day
				--		 when raw_hits >= branch_target_hits then 0
				--		 when order_point > pil then demand_per_day
				--		 else 0
				--		 end

				--when child_branch_flag = 2  then  
								
				--			case when branch_stock_status = ''Yes'' then 0 
				--				 /* If child branch has min or max within expire date, then exclude demand from parent branch */
				--				 when (isnull(user_control_min_qty,0) > 0 or isnull(user_control_max_qty,0) > 0) and min_max_date_flag = 1 then 0
				--				 /* If child branch has min only within expire date, add demand to parent */ 
				--				 when (isnull(user_control_min_qty,0) > 0 and isnull(user_control_max_qty,0) = 0) and min_max_date_flag = 1 then demand_per_day 
				--				 /* Branch raw hits < Target and Network hits >= target then add demand to parent */
				--				 when raw_hits < branch_target_hits and sum(raw_hits) over(partition by demand_branch, product_id) >= network_target_hits then demand_per_day 
				--				 /* Branch raw hits < Target and Network hits < target then add demand to parent */
				--				 when raw_hits < branch_target_hits and sum(raw_hits) over(partition by demand_branch, product_id) < network_target_hits then 0
				--				 when raw_hits < branch_target_hits then	
				--						cast(
				--						case when demand_per_day   < 0 then 0
				--								when demand_per_day   is null then 0 
				--								when raw_hits >= branch_target_hits then demand_per_day  
				--								else demand_per_day  
				--								end
				--						as decimal(18,4))
				--						else 0
				--				end			
							end
					,0)
				as branch_demand

 

from (
	/* Order Point */ select sub.*,
			ceiling(
			--cast(
				--round(round(round(
				case-- when op.branch_stock_status in (''No'',''Discontinued'') then 0 
					 when branch_stock_status = ''No'' and ((user_control_min_qty > 0 or user_control_max_qty > 0) and min_max_date_flag = 1) then user_control_min_qty	
					 when product_status_id = 4 and ((user_control_min_qty > 0 or user_control_max_qty > 0) and min_max_date_flag = 1) then user_control_min_qty	
					 when branch_stock_status = ''No'' and safe_stock_date_flag = 1 then manual_safety_stock 	
					 when product_status_id = 4 and safe_stock_date_flag = 1 then manual_safety_stock 
					 when branch_stock_status in (''No'',''Discontinued'') and ((isnull(user_control_min_qty,0) > 0 or isnull(user_control_max_qty,0) > 0) and min_max_date_flag = 1) then isnull(user_control_min_qty,0)
					 when  branch_stock_status in (''No'',''Discontinued'') then 0 

					 --when user_control_min_qty > 0 and isnull(user_control_max_qty,0) = 0 and min_max_date_flag = 1 then user_control_min_qty

					/* Purchasing Branches: Child branch Flags 0,1,3 */  
					 when isnull(child_branch_flag,1) in (0,5) then 
						case when (min_max_date_flag = 1 or safe_stock_date_flag = 1) then
							   case when isnull(user_control_min_qty,0) > 0 and isnull(user_control_max_qty,0) > 0 then isnull(user_control_min_qty,0)
									when isnull(user_control_min_qty,0) > 0 and isnull(user_control_min_qty,0) >= order_point then user_control_min_qty 
									when isnull(manual_safety_stock,0) >= order_point and isnull(manual_safety_stock,0) >= isnull(user_control_min_qty,0) then manual_safety_stock
									else order_point
									end	
						    when branch_stock_status = ''Yes'' then 
								case 
									when isnull(user_control_min_qty,0) > 0 and isnull(user_control_max_qty,0) > 0 and min_max_date_flag = 1 then isnull(user_control_min_qty,0)
									when (isnull(user_control_min_qty,0) > isnull(order_point,0) and min_max_date_flag = 1) then isnull(user_control_min_qty,0)
									else order_point
									end
							 when branch_stock_status = ''Auto'' then	
								case when isnull(user_control_min_qty,0) > 0 and isnull(user_control_max_qty,0) > 0 and min_max_date_flag = 1 then isnull(user_control_min_qty,0)
									 when isnull(user_control_min_qty,0) >= order_point and min_max_date_flag = 1 then isnull(user_control_min_qty,0)
									 when (isnull(user_control_min_qty,0) > 0 and min_max_date_flag = 1) and order_point >= isnull(user_control_min_qty,0) then order_point
									 when (isnull(user_control_min_qty,0) > 0 and min_max_date_flag = 1) and order_point <= isnull(user_control_min_qty,0) then isnull(user_control_min_qty,0) 
									 when parent_hits_flag = 1 then order_point
									 else 0
									 end
							 when product_status_id not in (1,2) then 0 
							 when branch_stock_status in (''No'',''Discontinued'') and ((isnull(user_control_min_qty,0) > 0 or isnull(user_control_max_qty,0) > 0) and min_max_date_flag = 1) then isnull(user_control_min_qty,0)
							 when  branch_stock_status in (''No'',''Discontinued'') then 0 
							 else 0
						 end
						 					 /* Transfering Branches Child Branch Flag 2,4  */ 
					 when isnull(child_branch_flag,1) in (1,2,3,4) then
						case when (min_max_date_flag = 1 or safe_stock_date_flag = 1) then
								case when isnull(user_control_max_qty,0) > order_point and isnull(user_control_max_qty,0) > isnull(manual_safety_stock,0) and isnull(user_control_max_qty,0) > isnull(user_control_min_qty,0) and min_max_date_flag = 1  then isnull(user_control_max_qty,0)
									 when isnull(user_control_min_qty,0) >= order_point then isnull(user_control_min_qty,0)
									 when isnull(manual_safety_stock,0) >= order_point and isnull(manual_safety_stock,0) >= isnull(user_control_min_qty,0) then isnull(manual_safety_stock,0)
									 else order_point
									 end
						     when branch_stock_status = ''Yes'' then 
								case when (isnull(user_control_max_qty,0) > order_point and min_max_date_flag = 1) then isnull(user_control_max_qty,0)
									 when isnull(user_control_max_qty,0) is null and isnull(user_control_min_qty,0) >= order_point and min_max_date_flag = 1 then isnull(user_control_min_qty,0) 
									 when (isnull(user_control_min_qty,0) > order_point and min_max_date_flag = 1) then isnull(user_control_min_qty,0)
									 when safe_stock_date_flag = 1 and isnull(manual_safety_stock,0) > order_point then isnull(manual_safety_stock,0) 
									 when safe_stock_date_flag = 1 and isnull(manual_safety_stock,0) < order_point then order_point
									 else order_point
									 end
							 when branch_stock_status = ''Auto'' then	
								case when ((isnull(user_control_max_qty,0) is null or isnull(user_control_max_qty,0) < isnull(user_control_min_qty,0)) and isnull(user_control_min_qty,0) >= order_point and min_max_date_flag = 1) then isnull(user_control_min_qty,0)
									 when isnull(user_control_max_qty,0) > order_point and isnull(user_control_min_qty,0) > 0 and  min_max_date_flag = 1 then isnull(user_control_max_qty,0)
									 when ((isnull(user_control_min_qty,0) > 0 or isnull(user_control_max_qty,0) > 0) and min_max_date_flag = 1) and order_point > isnull(user_control_min_qty,0) then order_point 
									 when (isnull(user_control_min_qty,0) > order_point and min_max_date_flag = 1) then isnull(user_control_min_qty,0)
									 when safe_stock_date_flag = 1 and isnull(manual_safety_stock,0) >= order_point then isnull(manual_safety_stock,0) 
									 when safe_stock_date_flag = 1 and isnull(manual_safety_stock,0) < order_point then order_point
									 when raw_hits >= branch_target_hits then order_point
									 else 0
								end



							 else 0
						 end
					else 0
				end  ) as sql_order_point 
						 
from ( 

select sub.*,
	ceiling(isnull(((lead_time + cast(round(round(sfty_days,1,1),0) as int)) * demand_per_day) + manual_safety_stock ,0)) as order_point,  
	o.pil
from (

	/*Safety Days */ select *,

					case when lead_time < 1 then 0 
						when lead_time between 1 and 15 then (lead_time+7)* hrsc							 
						when lead_time between 16 and 60 then  ((lead_time/cast(2 as decimal(18,3)))+15) * hrsc
						when lead_time > 60 then  ((lead_time/cast(4 as decimal(18,3)))+30) * hrsc
						end
						as sfty_days
from (
	  	 /* HRSC */ select *,

						case when hits < 4 then 1.6 * isnull(safety_factor,1)
							 when hits >= 4 then (round((4/cast(hits as float)),3) +.6) * isnull(safety_factor,1)   
						end
						as hrsc,
							
			/*Branch EOQ Calculation for Parent & Child Branches */ 
 			case when branch_stock_status in (''No'',''Discontinued'') then 0 
				/* Parent Branches Stock Flag Yes & Auto */  
				 when isnull(child_branch_flag,0) = 0 then 
			
					case when branch_stock_status = ''Yes'' then 
						 case when user_control_min_qty >= eoq and min_max_date_flag = 1 then user_control_min_qty
							  when user_control_min_qty >= max_eoq and min_max_date_flag = 1 then eoq 
							 
							  when low_sale_qty > eoq then low_sale_qty
							  --when eoq > cast(round(round(round(round(network_demand * 183,3),2),1),0) as int) then cast(round(round(round(round(network_demand * 183,3),2),1),0) as int) 
							  when eoq < cast(round(round(round(round(network_demand * 183,3),2),1),0) as int) and eoq > max_eoq then eoq
							  
							  when eoq > max_eoq and eoq > 0 then max_eoq 
							  else eoq 
							  end 
					  
						 when branch_stock_status = ''Auto'' then	
							case when user_control_min_qty >= eoq and min_max_date_flag = 1 then user_control_min_qty
								-- when eoq > cast(round(round(round(round(network_demand * 183,3),2),1),0) as int) then cast(round(round(round(round(network_demand * 183,3),2),1),0) as int) 
								 when eoq < cast(round(round(round(round(network_demand * 183,3),2),1),0) as int) and eoq > max_eoq then eoq
								 when eoq > max_eoq and eoq > 0 then max_eoq 
								 when raw_hits >= branch_target_hits then iif(low_sale_qty > eoq, low_sale_qty,eoq) 
								 when network_hits >= network_target_hits then iif(low_sale_qty > eoq, low_sale_qty,eoq) 
								 else 0
							end
						 else 0
					 end
				 /* Child Branches Stock Flag Yes & Auto */ 
				 when isnull(child_branch_flag,0) in (1,2) then
					case when branch_stock_status = ''Yes'' then 
						 case when user_control_max_qty >= eoq and min_max_date_flag = 1then user_control_max_qty
							  when low_sale_qty > eoq then low_sale_qty
							  when user_control_min_qty >= max_eoq and min_max_date_flag = 1 then eoq
							  when eoq > max_eoq and eoq > 0 then max_eoq 
							  else eoq 
							  end
						 when branch_stock_status = ''Auto'' then	
							case when user_control_max_qty >= eoq and min_max_date_flag = 1 then user_control_max_qty
								 when eoq > max_eoq and eoq > 0 then max_eoq 
								 when raw_hits >= branch_target_hits then iif(low_sale_qty > eoq, low_sale_qty,eoq) 
								 when network_hits >= network_target_hits then iif(low_sale_qty > eoq, low_sale_qty,eoq) 
								 else 0
							end
						 else 0
					 end
				else 0
			end 
			as branch_eoq
from dbo.branch_demand as bd
	
) as sub
) as sub 
	left join dbo.product_open_inventory as o on o.product_branch_id = concat(sub.product_id,''*'',sub.branch_id)  
) as sub
) as sub
 


--where child_branch_flag = 0 and raw_hits < 4 and network_raw_hits >= 6 and network_demand > 0 

--where product_id = 45467 and demand_branch = ''BIS'' 
--where product_branch_id = ''28201*SXF'' 

/* 10026 RCH Parent-Child - including demand on PLYW (warehouse) branch (not PLY) */
/* 44577 SXF Grand Parent - including Parent Child demand in SXF Branch */
/* 11444*LAC - Child Warehouse -  including demand of child branches in LAC branch, as well as LACW & LACP  */
/* 18478 Buy Branch BIS - BIS displaying actual branch demand BISW is displaying */



 ) as sub 

 --where demand_branch in (''FAR'') and product_id = 230

--where branch_stock_status = ''No'' and (min_max_date_flag = 1 or safe_stock_date_flag = 1)


', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [order_line_plenty]    Script Date: 4/25/2023 10:34:14 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'order_line_plenty', 
		@step_id=6, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=1, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.order_line_plenty
create table dbo.order_line_plenty (

	product_branch_id varchar(255) collate SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,
	branch_id varchar(50),
	product_id int,
	order_point int,
	line_point int,
	plenty_date date
	)

insert into dbo.order_line_plenty 

select distinct 
	product_branch_id,
	sub.branch_id,
	sub.product_id,
	sql_order_point as order_point,
	ceiling( case when child_branch_flag in (0,5) then ceiling(((lead_time + line_buy_cycle_days + cast(round(round(line_point_safety_days,1,1),0) as int)) * sub.demand_per_day) + manual_safety_stock)  
		 		  when child_branch_flag in (1,2,3,4) then 
				
					case when user_control_min_qty > 0 and user_control_max_qty = 0 then line_buy_cycle_days * demand_per_day
						 else ceiling(((order_point_days + line_buy_cycle_days) * demand_per_day) + eoq + manual_safety_stock)
					end
					end)
				as line_point,
		case when child_branch_flag in (0,5) then cast(dateadd(dd,(line_buy_cycle_days + lead_time - iif(days_into_cycle > line_buy_cycle_days,0,days_into_cycle)),getdate()) as date)
		 else cast(dateadd(dd,plenty_lead + xfer_buy_cycle + lead_time - iif(days_into_cycle > line_buy_cycle_days,0,days_into_cycle),getdate()) as date)
		 end
		 as plenty_date
		
	--child_branch_type,
	--demand_branch,
	--buy_line_id,
	--product_stock_status,
	--branch_stock_status,
	--lead_time as lead_time_days,
	--round(sfty_days,0) as lead_time_safe_days,
	--order_point_days,
	--sub.demand_per_day,
	--manual_safety_stock,
	--isnull(safety_factor,1) as safety_factor,
	--hrsc,
	--pil,
	--eoq,
	--line_point_safety_days,
	--raw_order_point,
	----eda_order_point,
	--sub.demand_per_day,
	--lead_time,
	--order_point_days as transfer_point_days, 
	--line_buy_cycle_days,
	--lead_time + line_buy_cycle_days + cast(round(round(line_point_safety_days,1,1),0) as int) as line_point_days,
	--cast(round(round(line_point_safety_days,1,1),0) as int) as line_point_safety_days,
	--demand_per_day,
	--manual_safety_stock,
	--network_demand,
	--sub.demand_period_days,
	--sub.raw_hits,
	--sub.hits,
	--network_raw_hits,
	--lead_time,
	--lead_time_override_flag,
	--lead_time_override_type,
	--[90_day_avg_lead_time],
	--line_buy_cycle_days,
	--days_into_cycle,
	--last_buy_date,
	--user_control_min_qty,
	--user_control_max_qty,
	--user_control_min_max_expire_date,
	--manual_safety_stock,
	--safety_stock_expire_date

from (

select 
--isnull(sql_order_point,0) - isnull(eda_order_point,0) as diff,

*
from (

select 
	--product_branch_id,
	--buy_line_id,
	--child_branch_type,
	--branch_id,
	--product_id,
	--eda_order_point,
		ceiling(
			--cast(
				--round(round(round(
				case-- when op.branch_stock_status in (''No'',''Discontinued'') then 0 
					 when branch_stock_status = ''No'' and ((user_control_min_qty > 0 or user_control_max_qty > 0) and min_max_date_flag = 1) then user_control_min_qty	
					 when product_stock_status = ''Discontinued'' and ((user_control_min_qty > 0 or user_control_max_qty > 0) and min_max_date_flag = 1) then user_control_min_qty	
					 when branch_stock_status = ''No'' and safe_stock_date_flag = 1 then manual_safety_stock 	
					 when product_stock_status = ''Discontinued'' and safe_stock_date_flag = 1 then manual_safety_stock 
					 when branch_stock_status in (''No'',''Discontinued'') and ((isnull(user_control_min_qty,0) > 0 or isnull(user_control_max_qty,0) > 0) and min_max_date_flag = 1) then isnull(user_control_min_qty,0)
					 when  branch_stock_status in (''No'',''Discontinued'') then 0 

					 --when user_control_min_qty > 0 and isnull(user_control_max_qty,0) = 0 and min_max_date_flag = 1 then user_control_min_qty

					/* Purchasing Branches: Child branch Flags 0,1,3 */  
					 when isnull(child_branch_flag,1) in (0,1,3,5) then 
						case when (min_max_date_flag = 1 or safe_stock_date_flag = 1) then
							   case when isnull(user_control_min_qty,0) > 0 and isnull(user_control_max_qty,0) > 0 then isnull(user_control_min_qty,0)
									when isnull(user_control_min_qty,0) > 0 and isnull(user_control_min_qty,0) >= raw_order_point then user_control_min_qty 
									when raw_order_point = 0 and isnull(manual_safety_stock,0) >= isnull(user_control_min_qty,0) then manual_safety_stock
									else order_point
									end	
						    when branch_stock_status = ''Yes'' then 
								case 
									when isnull(user_control_min_qty,0) > 0 and isnull(user_control_max_qty,0) > 0 and min_max_date_flag = 1 then isnull(user_control_min_qty,0)
									when (isnull(user_control_min_qty,0) > isnull(raw_order_point,0) and min_max_date_flag = 1) then isnull(user_control_min_qty,0)
									else order_point
									end
							 when branch_stock_status = ''Auto'' then	
								case when isnull(user_control_min_qty,0) > 0 and isnull(user_control_max_qty,0) > 0 and min_max_date_flag = 1 then isnull(user_control_min_qty,0)
									 when isnull(user_control_min_qty,0) >= raw_order_point and min_max_date_flag = 1 then isnull(user_control_min_qty,0)
									 when (isnull(user_control_min_qty,0) > 0 and min_max_date_flag = 1) and raw_order_point >= isnull(user_control_min_qty,0) then order_point
									 when (isnull(user_control_min_qty,0) > 0 and min_max_date_flag = 1) and raw_order_point <= isnull(user_control_min_qty,0) then isnull(user_control_min_qty,0) 
									 when parent_hits_flag = 1 then order_point
									 else 0
									 end
							 when product_stock_status not in (''Stock'',''NonStock'') then 0 
							 when branch_stock_status in (''No'',''Discontinued'') and ((isnull(user_control_min_qty,0) > 0 or isnull(user_control_max_qty,0) > 0) and min_max_date_flag = 1) then isnull(user_control_min_qty,0)
							 when  branch_stock_status in (''No'',''Discontinued'') then 0 
							 else 0
						 end
					 /* Transfering Branches Child Branch Flag 2,4  */ 
					 when isnull(child_branch_flag,1) in (2,4) then
						case when (min_max_date_flag = 1 or safe_stock_date_flag = 1) then
								case when isnull(user_control_min_qty,0) > 0 and isnull(user_control_max_qty,0) = 0 then isnull(user_control_min_qty,0)
									 when isnull(user_control_max_qty,0) > raw_order_point and isnull(user_control_max_qty,0) > isnull(manual_safety_stock,0) and isnull(user_control_max_qty,0) > isnull(user_control_min_qty,0) and min_max_date_flag = 1  then isnull(user_control_max_qty,0)
									 when isnull(user_control_min_qty,0) >= raw_order_point then isnull(user_control_min_qty,0)
									 when isnull(manual_safety_stock,0) >= raw_order_point and isnull(manual_safety_stock,0) >= isnull(user_control_min_qty,0) then order_point
									 else order_point
									 end
						     when branch_stock_status = ''Yes'' then 
								case when (isnull(user_control_max_qty,0) > raw_order_point and min_max_date_flag = 1) then isnull(user_control_max_qty,0)
									 when isnull(user_control_max_qty,0) is null and isnull(user_control_min_qty,0) >= raw_order_point and min_max_date_flag = 1 then isnull(user_control_min_qty,0) 
									 when (isnull(user_control_min_qty,0) > raw_order_point and min_max_date_flag = 1) then isnull(user_control_min_qty,0)
									 when safe_stock_date_flag = 1 and isnull(manual_safety_stock,0) / cast(isnull(purchase_qty,1) as float) > raw_order_point then isnull(manual_safety_stock,0) 
									 when safe_stock_date_flag = 1 and isnull(manual_safety_stock,0) / cast(isnull(purchase_qty,1) as float) < raw_order_point then order_point
									 else order_point
									 end
							 when branch_stock_status = ''Auto'' then	
								case when ((isnull(user_control_max_qty,0) is null or isnull(user_control_max_qty,0) < isnull(user_control_min_qty,0)) and isnull(user_control_min_qty,0) >= order_point and min_max_date_flag = 1) then isnull(user_control_min_qty,0)
									 when isnull(user_control_max_qty,0) > order_point and isnull(user_control_min_qty,0) > 0 and  min_max_date_flag = 1 then isnull(user_control_max_qty,0)
									 when ((isnull(user_control_min_qty,0) > 0 or isnull(user_control_max_qty,0) > 0) and min_max_date_flag = 1) and order_point > isnull(user_control_min_qty,0) then order_point 
									 when (isnull(user_control_min_qty,0) > order_point and min_max_date_flag = 1) then isnull(user_control_min_qty,0)
									 when safe_stock_date_flag = 1 and isnull(manual_safety_stock,0) / cast(isnull(purchase_qty,1) as float) >= order_point then isnull(manual_safety_stock,0) 
									 when safe_stock_date_flag = 1 and isnull(manual_safety_stock,0) / cast(isnull(purchase_qty,1) as float) < order_point then order_point
									 when raw_hits >= branch_target_hits then order_point
									 else 0
								end



							 else 0
						 end
					else 0
				end   
				) as sql_order_point,*,
			--	,lead_time + line_buy_cycle_days + round(sfty_days,0) as line_point_safety_days

		 
				case when lead_time + line_buy_cycle_days <= 15 then (lead_time + line_buy_cycle_days + 7) * cast(hrsc as float)
					 when lead_time + line_buy_cycle_days > 15 and lead_time + line_buy_cycle_days < 60 then (((lead_time + line_buy_cycle_days)/2) + 15) * cast(hrsc as float)
					 when lead_time + line_buy_cycle_days >= 60 then (((lead_time + line_buy_cycle_days)/4) + 30) * cast(hrsc as float) 
					 end
				 
					 as line_point_safety_days

				
from (
select
	ceiling(isnull(((lead_time + cast(round(round(sfty_days,1,1),0) as int)) * demand_per_day) + isnull(manual_safety_stock / cast(isnull(purchase_qty,1) as float),0),0)) as order_point,
	ceiling(isnull(((lead_time + cast(round(round(sfty_days,1,1),0) as int)) * demand_per_day),0)) as raw_order_point,
	isnull(((lead_time + cast(round(round(sfty_days,1,1),0) as int)) * demand_per_day) + isnull(manual_safety_stock / cast(isnull(purchase_qty,1) as float),0),0) as origin_op,

--	((4/cast(hits as float)) +.6) * isnull(safety_factor,1) as hrsc, 

	*
from (
 
			select 
			op.demand_branch,
			op.product_branch_id as product_branch_id,
			op.child_branch_type,
			op.safety_factor,
			op.[branch_stock_status],
			op.[user_control_min_qty],
			op.[user_control_max_qty],
			op.manual_safety_stock,
			op.[raw_hits],
			op.[hits], 
			op.buy_line_id,
			op.product_id,
			op.product_stock_Status,
			--replace(eda.order_point,'','','''') as eda_order_point  ,
			op.branch_id
			,op.[hrsc]
			,op.[lead_time]
			,op.lead_time_override_flag
			,op.lead_time_override_type
			,iif(op.child_branch_flag in (0,5),op.line_buy_cycle_days,999) as line_buy_cycle_days
			,iif(op.child_branch_flag in (0,5),datediff(dd,op.last_buy_date,getdate()),datediff(dd,t.last_buy_date,getdate())) as days_into_cycle
			,iif(op.child_branch_flag in (0,5),op.line_buy_cycle_days,t.line_buy_cycle_days) as xfer_buy_cycle
			,iif(op.child_branch_flag in (0,5),op.lead_time,t.lead_time) as plenty_lead
			,op.last_buy_date
			,op.avg_lead_time as ''90_day_avg_lead_time''
			,op.[sfty_days]
			,op.[order_point_days]
			,op.[demand_period_days]
			,op.[child_branch_flag]
			,op.[branch_target_hits]
			,op.[network_demand]
			,op.[network_hits]
			,op.[network_raw_hits]
			,op.[network_target_hits]
			,op.[safe_stock_date_flag]
			,op.[min_max_date_flag]
			,op.[parent_hits_flag]
			,op.[purchase_qty]
			,op.[seasonal_flag]
			,op.[user_control_min_max_expire_date]	 
			,op.[safety_stock_expire_date]
			,op.pil
			,op.eoq
			,case when op.child_branch_flag in (1,2,3,4) then op.demand_per_day
				 else op.branch_demand
				 end as demand_per_day
			,t.lead_time as lt
			,t.line_buy_cycle_days as lbcd

			from dbo.branch_territory_demand as op
				left join dbo.branch_territory_demand as t on t.product_id = op.product_id and t.branch_id = op.demand_branch
				--left join dbo.eda_order_point as eda on eda.product_branch_id = op.product_branch_id collate SQL_Latin1_General_CP1_CS_AS
			where (op.order_point > 0 or op.min_max_date_flag = 1 or op.safe_stock_date_flag = 1 or op.parent_hits_flag = 1 or op.branch_stock_status = ''Yes'' or op.manual_safety_stock > 0 or op.branch_demand > 0 )  
 
) as sub
) as sub
) as sub
) as sub

 order by product_id

 ', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [product_branch_calculation]    Script Date: 4/25/2023 10:34:14 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'product_branch_calculation', 
		@step_id=7, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=1, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.product_branch_calculation

create table dbo.product_branch_calculation (

		product_branch_id varchar(255) collate SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,
		branch_id nvarchar(20) collate SQL_Latin1_General_CP1_CS_AS,
		branch_stock_status varchar(50),
		buy_line_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS,
		price_line_id nvarchar(255),
		stocking_branch nvarchar(6) collate SQL_Latin1_General_CP1_CS_AS,
		buyer nvarchar(255),
	--	vendor_name nvarchar(75),
		product_id int,
		description nvarchar(255),
		alternate_description nvarchar(255), 
		catalog_number nvarchar(255),
		upc nvarchar(255),
		product_stock_status nvarchar(255),
		keywords nvarchar(255),
		select_code nvarchar(255),
		commodity_code nvarchar(255),
		branch_cost_per_qty int,
		branch_cost_per_um nvarchar(50),
		user_defined_id1 nvarchar(255),
		user_defined_id2 nvarchar(255), 
		rank_number1 varchar(5),
		hits int, 
		raw_hits int,
		raw_demand decimal(18,2),
		lead_time_days int,
		demand_per_day decimal(18,2),
		eoq int,
		average_cost decimal(18,2),
		replacement_cost decimal(18,2),
		low_sale_qty int,
		number_of_days_with_zero_onhand int,
		user_control_min_qty int,
		user_control_max_qty int,
		user_control_min_max_expire_date date,
		manual_safety_stock int,
		safety_stock_expiration_date date,
		forecast_parameter_trend_percentage decimal(18,4),
		classify_section nvarchar(255),
		classify_group nvarchar(255),
		classify_category nvarchar(255),
		classify_vendor_group nvarchar(255),
		service_stock int,
		ss_expire_date date,
		buy_package_qty int,
		region varchar(25),
		last_receive_date date,
		last_sale_date date,
		first_recv_date date,
		doh int,
		cycle_days int,
		target_type nvarchar(255),
		target_amount nvarchar(255),
		is_divisable nvarchar(255),
		suggest_on_all_flag int,
		procure_group_id nvarchar(255),
		cut_product_type nvarchar(255)
		)

insert into dbo.product_branch_calculation

select distinct
	pb.product_branch_id, 
	pb.branch_id, 
	pb.branch_stock_status,
	pb.buy_line_id,
	p.price_line_id,
	pb.buy_branch as stocking_branch,
	blb.buyer as buyer,
	pb.product_id,
	p.description,
	p.alternate_description, 
	p.catalog_number,
	p.upc,
	--product_gl_type,
	--product_status_id,
	pb.product_stock_status,
	cast(p.keywords as nvarchar(75)) as keywords,
	p.select_code,
	--matrix_type,
	--index_type,
	--unit_weight,
	--pdw_item_id,
	p.commodity_code,
	p.branch_cost_per_qty,
	p.branch_cost_per_um,
	p.user_defined_id1,
	p.user_defined_id2,
	--pb.user_defined_id10
	pbc.rank_number1,
	pb.hits,
	pb.raw_hits,
	pbc.raw_demand,
	pb.lead_time as lead_time_days,
	pb.demand_per_day,
	pb.branch_eoq as eoq,
	pbc.average_cost,
	rep.replacement_cost as replacement_cost,
	pb.low_sale_qty,
	pbc.number_of_days_with_zero_onhand,
	pb.user_control_min_qty,
	pb.user_control_max_qty,
	pb.user_control_min_max_expire_date, 
	pb.manual_safety_stock,
	pb.safety_stock_expire_date,
	blb.forecast_parameter_trend_percentage, 
	pc.section as classify_section,
	pc.[group] as classify_group,
	pc.category as classify_category,
	pc.vendor_group as classify_vendor_group,
	pb.manual_safety_stock as service_stock,
	pb.safety_stock_expire_date as ss_expire_date,
	(select buy_package_qty from dbo.branch_product as bp where bp.product_branch_id = pb.product_branch_id) as buy_package_qty,
	ter.ship_branch_region,
	isnull(pbi.last_receive_date,''2015-01-01'') as last_receive_date,
	isnull(pbi.last_sale_date,''2015-01-01'') as last_sale_date,
	isnull(pbi.first_recv_date,''2015-01-01'') as first_recv_date,
	pbi.doh,
	blb.line_buy_cycle_days,
	blb.target_type,
	blb.target_amount,
	pb.is_divisable,
	blb.suggest_on_all_flag,
	blb.procure_group_id,
	p.cut_product_type
from dbo.branch_territory_demand as pb
	left join dbo.branch_product_price as rep on rep.product_branch_id = pb.product_branch_id
	--left join dbo.product_replacement_cost as rep on rep.product_id = pb.product_id
	left join dbo.buy_line_branch as blb on blb.buy_line_branch = concat(pb.buy_line_id,''*'',pb.branch_id) collate SQL_Latin1_General_CP1_CI_AS
	left join eclipse.product_branch_calculation as pbc on pbc.eclipse_id = pb.product_branch_id
	left join dbo.product_branch_inventory  as pbi  on pb.product_branch_id = pbi.product_branch_id and substring(pbi.prod_branch_loc,charindex(''_'',pbi.prod_branch_loc)+1,99) = 1 and pbi.loc_type = ''S'' 
	---Product File Attributes
	left join ( 
				select 
					p.eclipse_id,
					p.buy_line_id,
					p.price_line_id,
					product_id,
					cast(p.description as nvarchar(50)) as description,
					cast(alternate_description as nvarchar(50)) as alternate_description, 
					p.catalog_number,
					p.upc,
					product_gl_type,
					product_status_id,
					s.description as product_stock_status,
					cast(p.keywords as nvarchar(50)) as keywords,
					p.select_code,
					matrix_type,
					index_type,
					unit_weight,
					pdw_item_id,
					commodity_code,
					p.branch_cost_per_qty,
					p.branch_cost_per_um,
					p.user_defined_id1,
					p.user_defined_id2,
					p.user_defined_id10,
					p.cut_product_type
				from eclipse.product as p
					left join eclipse.system_product_status as s on s.system_product_status_id = p.product_status_id
			) as p on p.eclipse_id = pb.product_id
	-- Product Classify
	left join eclipse_ud.product_classify as pc on pc.eclipse_id = p.product_id and ISNUMERIC(pc.eclipse_id) = 1 and pc.eclipse_id <> ''#N/A''
	left join (
				select 
					branch_id,
					ship_branch_region
				from dbo.branch 
			) as ter on ter.branch_id = pb.branch_id collate SQL_Latin1_General_CP1_CI_AS
', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [product_branch_inventory]    Script Date: 4/25/2023 10:34:15 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'product_branch_inventory', 
		@step_id=8, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=1, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.product_branch_inventory 
create table dbo.product_branch_inventory (

			prod_branch_loc varchar(255) collate SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,
			product_branch_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS,
			branch_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS,
			product_id int, 
			buy_line_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS,
			price_line_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS,
			buyer nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS,
			description nvarchar(255),
			catalog_number nvarchar(255),
			select_code nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS,
			commodity_code nvarchar(50),
			PIL int,
			front_screen_stock_status nvarchar(255),
			branch_stock_status nvarchar(255),
			loc_type nvarchar(255),
			location_type nvarchar(50),
			available_inventory int,
			in_stock nvarchar(255),
			purchase_order_qty int,
			on_po  nvarchar(255),
			transfer_order_qty int,
			on_xfer  nvarchar(255),
			rank_number1  nvarchar(10),
			hits int,
			raw_hits int,
			lead_time_days int,
			demand_per_day decimal(18,2),
			eoq int,
			average_cost decimal(18,2),
			replacement_cost decimal(18,2),
			avg_cost_per_qty decimal(18,2),
			branch_cost_per_um  nvarchar(255),
			avg_cost_onhand decimal(18,2),
			avg_cost decimal(18,2),
			rep_cost decimal(18,2),
			low_sale_qty int,
			user_control_min_qty int,
			user_control_max_qty int,
			user_control_min_max_expire_date date,
			manual_safety_stock int,
			safety_stock_expiration_date date,
			forecast_parameter_trend_percentage decimal(18,2),
			number_of_days_with_zero_onhand int,
			classify_section  nvarchar(50),
			classify_group  nvarchar(50),
			classify_category  nvarchar(50),
			classify_vendor_group  nvarchar(50),
			upc nvarchar(75),
			user_defined_id1  nvarchar(50),
			user_defined_id2  nvarchar(50),
			location_lot_id nvarchar(255),
			excess_inventory  nvarchar(50),
			excess_qty  int,
			excess_value decimal(18,2),
			doh  decimal(18,2),
			[365_sales_qty] int,
			[365_cogs] int,
			[30_day_qty] int,
			[30_day_cogs] decimal(18,2),
			[90_day_qty] int,
			[90_day_cogs] decimal(18,2),
			committed_qty int,
			last_receive_date date,
			last_sale_date date,
			first_recv_date date,
			receive_date_aging nvarchar(50),
			new_stock_products nvarchar(50),
			[location] nvarchar(50),
			location_status nvarchar(255),
			location_tag_in nvarchar(255),
			location_tag_out nvarchar(255),
			location_inprocess_status nvarchar(255),
			product_count int,
			last_purchase_order nvarchar(255),
			total_ohb int,
			location_last_count_date date,
			);

insert into dbo.product_branch_inventory

select distinct
	* 
from (
	select 
		

		concat(p.product_branch_id,''*'',isnull(ohb.loc_type,''N/A'')
		,''_'',row_number() over(partition by concat(p.product_branch_id,''*'',isnull(ohb.loc_type,''N/A'')) order by concat(p.product_branch_id,''*'',isnull(ohb.loc_type,''N/A'')))
		) as prod_branch_loc, 
		p.product_branch_id,
		p.branch_id,
		p.product_id,
		p.buy_line_id,
		p.price_line_id,
		p.buyer,
		cast(p.description as nvarchar(75)) as description,
		cast(p.catalog_number as nvarchar(75)) as catalog_number,
		p.select_code,
		p.commodity_code,
		pil.PIL, 
		p.product_stock_status as front_screen_stock_status,
		p.branch_stock_status,
		isnull(ohb.loc_type,''N/A'') as loc_type,
		isnull(ohb.location_type,''N/A'') as location_type,
		isnull(ohb.on_hand_balance,0) as available_inventory, 

		/* In-Stock Reporting - Per JWIZ 1/15/21 in stock includes: stock_status(Yes,Auto), rank(A,B,C) */ 
		/* 4/19/22 per JWIZ adding filter to exclude items with demand_per_day = 0 */ 
		case 
			when p.product_stock_status <> ''Stock'' then ''Other''
			when isnull(ohb.location_type,''N/A'') <> ''Stock'' then ''Other'' 
			when demand_per_day = 0 then ''Other'' 
			when isnull(ohb.total,0) > 0 and p.branch_stock_status in (''Yes'',''Auto'') and isnull(p.rank_number1,''X'') in (''A'',''B'',''C'') then ''In Stock''
			when isnull(ohb.total,0) <= 0 and p.branch_stock_status in (''Yes'',''Auto'') and isnull(p.rank_number1,''X'') in (''A'',''B'',''C'') and ((iif(low_sale_qty > eoq, low_sale_qty,eoq) > 0) or (p.branch_stock_status is null and iif(low_sale_qty > eoq, low_sale_qty,eoq) > 0)) then ''Stock Out''
		else ''Other'' end as in_stock,

		iif(ohb.parent_loc_flag = 1,pil.purchase_order_qty,0) as purchase_order_qty,
		iif(pil.purchase_order_qty > 0, ''On PO'', ''No'') as on_po,
		iif(ohb.parent_loc_flag = 1,pil.transfer_order_qty,0) as transfer_order_qty, 
		iif(pil.transfer_order_qty > 0, ''On Xfer'',''No'') as on_xfer, 
		p.rank_number1,
		iif( ohb.parent_loc_flag = 1,p.hits,0) as hits,
		p.raw_hits,
		isnull(p.lead_time_days,14) as lead_time_days,
		iif(ohb.parent_loc_flag = 1,p.demand_per_day,0) as demand_per_day,
		iif(ohb.parent_loc_flag = 1,p.eoq,0) as eoq,
		p.average_cost,
		rep_cost.replacement_cost as replacement_cost,
		iif(isnull((p.average_cost/p.branch_cost_per_qty),rep_cost.replacement_cost)=0,rep_cost.replacement_cost,isnull((p.average_cost/p.branch_cost_per_qty),rep_cost.replacement_cost)) as avg_cost_per_qty,
		p.branch_cost_per_um,
		isnull(iif(isnull((p.average_cost/p.branch_cost_per_qty),rep_cost.replacement_cost)=0,rep_cost.replacement_cost,isnull((p.average_cost/p.branch_cost_per_qty),rep_cost.replacement_cost)) * ohb.on_hand_balance,0) as avg_cost_onhand,
		(p.average_cost/p.branch_cost_per_qty) * ohb.on_hand_balance as avg_cost,
		rep_cost.replacement_cost * ohb.on_hand_balance as rep_cost,
		p.low_sale_qty,
		p.user_control_min_qty,
		p.user_control_max_qty,
		p.user_control_min_max_expire_date, 
		p.manual_safety_stock,
		p.safety_stock_expiration_date, 
		p.forecast_parameter_trend_percentage,
		p.number_of_days_with_zero_onhand,
		p.classify_section,
		p.classify_group,
		p.classify_category,
		p.classify_vendor_group,
		p.upc,
		p.user_defined_id1,
		p.user_defined_id2,
		ohb.location_lot_id,

		/* EXCESS INVENTORY */
		/* Per JWiz 3/23/2021: excess value = ([Current On Hand Qty] - [365 Day Qty] > 0) & Last Receive Date > 180 Days
		 **Important: PerJWiz....365 Day Sales Qty only to include Sales Qty and NOT Return Qty (as calculated in Inventory Inquiry Screen) */
		iif(
			p.buy_line_id not in (''NON-INV'',''RENTAL'')
			and isnull(ohb.total,0) > 0 
			and isnull(ohb.total,0) - isnull(cogs.[365_day_sales],0) > 0 
			and datediff(day,isnull(lr.last_recv_date,''2015-01-01''),getdate()) > 180
			,''Excess Inventory''
			,'''') as excess_inventory,
		/* EXCESS INVENTORY - QTY */ 
		iif(
			p.buy_line_id not in (''NON-INV'',''RENTAL'')
			and ohb.parent_loc_flag = 1 
			and isnull(ohb.total,0) > 0 
			and isnull(ohb.total,0) - isnull(cogs.[365_day_sales],0) > 0 
			and datediff(day,isnull(lr.last_recv_date,''2015-01-01''),getdate()) > 180
			,isnull(ohb.total,0) - iif(isnull(cogs.[365_day_sales],0) < 0,0,isnull(cogs.[365_day_sales],0))
			,0) as excess_qty,
		/* EXCESS INVENTORY - EXCESS VALUE */ 
		iif(
			p.buy_line_id not in (''NON-INV'',''RENTAL'')
			and ohb.parent_loc_flag = 1 
			and isnull(ohb.total,0) > 0 
			and isnull(ohb.total,0) - isnull(cogs.[365_day_sales],0) > 0 
			and datediff(day,isnull(lr.last_recv_date,''2015-01-01''),getdate()) > 180
			,isnull(ohb.total,0) - iif(isnull(cogs.[365_day_sales],0)< 0,0,isnull(cogs.[365_day_sales],0))
			,0)
			*
		   (iif(
			isnull((p.average_cost/p.branch_cost_per_qty),rep_cost.replacement_cost)=0
			,rep_cost.replacement_cost
			,isnull((p.average_cost/p.branch_cost_per_qty),rep_cost.replacement_cost))
			) as excess_value,

		  /* DOH */ 
		  cast(iif( 
			ohb.parent_loc_flag = 1 
			and isnull(ohb.total,0)  > 0 
			and cogs.ext_cogs > 0 
			and p.average_cost > 0
			,365/(cogs.ext_cogs / replace(isnull( isnull((p.average_cost/p.branch_cost_per_qty)
			,rep_cost.replacement_cost) * isnull(ohb.total,0),0),0,1))
			,0) as decimal(18,2)) as DOH,

		 case when ohb.parent_loc_flag = 1 then isnull(cogs.[365_day_sales],0)
			  when ohb.product_inventory_location_id is null and exists (select product_branch_id from dbo.product_365_sales as s where s.product_branch_id = p.product_branch_id) then isnull(cogs.[365_day_sales],0)
			  else 0 end as ''365_sales_qty'',
		 case when ohb.parent_loc_flag = 1 then isnull(cogs.ext_cogs,0)
			  when ohb.product_inventory_location_id is null and exists (select product_branch_id from dbo.product_365_sales as s where s.product_branch_id = p.product_branch_id) then isnull(cogs.ext_cogs,0)
			  else 0 end as ''365_cogs'',

		 case when ohb.parent_loc_flag = 1 then isnull(cogs.[30_day_qty],0)
			  when ohb.product_inventory_location_id is null and exists (select product_branch_id from dbo.product_365_sales as s where s.product_branch_id = p.product_branch_id) then isnull(cogs.[30_day_qty],0)
			  else 0 end as ''30_day_qty'',
		 case when ohb.parent_loc_flag = 1 then isnull(cogs.[30_day_cogs],0)
			  when ohb.product_inventory_location_id is null and exists (select product_branch_id from dbo.product_365_sales as s where s.product_branch_id = p.product_branch_id) then isnull(cogs.[30_day_cogs],0)
			  else 0 end as ''30_day_cogs'',

		 case when ohb.parent_loc_flag = 1 then isnull(cogs.[90_day_qty],0)
			  when ohb.product_inventory_location_id is null and exists (select product_branch_id from dbo.product_365_sales as s where s.product_branch_id = p.product_branch_id) then isnull(cogs.[90_day_qty],0)
			  else 0 end as ''90_day_qty'',
		 case when ohb.parent_loc_flag = 1 then isnull(cogs.[90_day_cogs],0)
			  when ohb.product_inventory_location_id is null and exists (select product_branch_id from dbo.product_365_sales as s where s.product_branch_id = p.product_branch_id) then isnull(cogs.[90_day_cogs],0)
			  else 0 end as ''90_day_cogs'',

		iif( ohb.parent_loc_flag = 1,pil.[committed],0) as committed_qty,
		isnull(lr.last_recv_date,''2015-01-01'') as last_receive_date,
		isnull(cogs.last_sales_date,''2015-01-01'') as last_sale_date,
		isnull(np.first_recv_date,''2015-01-01'') as first_recv_date,

		--Receive Aging Date
		case when datediff(dd,isnull(lr.last_recv_date,''2015-01-01''),getdate()) <= 30 then ''1-30 Days'' 
		when datediff(dd,isnull(lr.last_recv_date,''2015-01-01''),getdate()) > 30 and datediff(dd,isnull(lr.last_recv_date,''2015-01-01''),getdate()) <= 60  then ''30-60 Days''
		when datediff(dd,isnull(lr.last_recv_date,''2015-01-01''),getdate()) > 60 and datediff(dd,isnull(lr.last_recv_date,''2015-01-01''),getdate()) <= 90 then ''60-90 Days''
		when datediff(dd,isnull(lr.last_recv_date,''2015-01-01''),getdate()) > 90 and datediff(dd,isnull(lr.last_recv_date,''2015-01-01''),getdate()) <= 180 then ''90-180 Days''
		when datediff(dd,isnull(lr.last_recv_date,''2015-01-01''),getdate()) > 180 and datediff(dd,isnull(lr.last_recv_date,''2015-01-01''),getdate()) <= 360 then ''180-360 Days''
		when datediff(dd,isnull(lr.last_recv_date,''2015-01-01''),getdate()) > 360 and datediff(dd,isnull(lr.last_recv_date,''2015-01-01''),getdate()) <= 720 then ''360-720 Days'' 
		when datediff(dd,isnull(lr.last_recv_date,''2015-01-01''),getdate()) > 720 then ''720+ Days''
		end as receive_date_aging,

		-- New Stock Product 
		 case when p.branch_stock_status in (''Yes'',''Auto'') and iif(user_control_min_qty > 0 and user_control_min_max_expire_date > getdate(),1,0) = 1 and np.first_recv_date > dateadd(dd,-30,getdate()) and ohb.loc_type = ''S'' and p.product_stock_status = ''Stock'' and ohb.on_hand_balance > 0 and pil.pil > 0  then ''New Stocked Product''
			  when p.branch_stock_status in (''Yes'',''Auto'') and iif(low_sale_qty > eoq, low_sale_qty,eoq) > 0 and ohb.loc_type = ''S'' and np.first_recv_date > dateadd(dd,-30,getdate()) and p.product_stock_status = ''Stock'' and ohb.on_hand_balance > 0 and pil.pil > 0 then ''New Stocked Product''
		else '''' end as new_stock_products,
		ohb.location,
		ohb.location_status,
		ohb.location_tag_in,
		ohb.location_tag_out,
		ohb.location_inprocess_status,
		isnull(ohb.parent_loc_flag,0) as product_count,
		lr.last_purchase_order,
		ohb.total as total_ohb,
		ohb.location_last_count_date

from dbo.product_branch_calculation as p
--	left join dbo.product_365_sales as ls on ls.product_branch_id = p.product_branch_id
	left join dbo.product_365_receiving as lr on lr.product_branch_id = p.product_branch_id
	left join dbo.branch_product_price as rep_cost on rep_cost.product_branch_id = p.product_branch_id
--	left join dbo.product_replacement_cost as rep_cost on rep_cost.product_id = p.product_id
	left join dbo.product_365_sales as cogs on cogs.product_branch_id = p.product_branch_id
	left join dbo.product_open_inventory as pil on pil.product_branch_id = p.product_branch_id
	left join dbo.product_new_inventory as np on np.product_branch_id = p.product_branch_id
	left join (
				select
					pil.product_inventory_location_id,
					concat(pil.product_inventory_id,''*'',location_type) as product_branch_loc,
					pil.product_inventory_id,
					pil.product_id,
					pil.branch_id ,
					case when left(location_type,1) = ''*'' then ''Review''
					when location_inprocess_status is not null then ''In-Process''
					when left(location_type,1) = ''C'' then ''Customer Consignment''
					when left(location_type,1) = ''S'' and len(location_type) > 1 then ''Vendor Consignment''
					when left(location_type,1) = ''F'' then ''Defective''
					when left(location_type,1) = ''L'' then ''Display'' 
					when left(location_type,1) = ''O'' then ''Over Stock''
					when left(location_type,1) = ''P'' then ''Invalid''
					when left(location_type,1) = ''R'' then ''Review''
					when left(location_type,1) = ''S'' then ''Stock'' 
					when left(location_type,1) = ''T'' then ''Tagged''
					when left(location_type,1) = ''W'' then ''Direct Through Stock'' 
					when left(location_type,1) = ''Z'' then ''Invalid''  
					when left(location_type,1) = ''D'' then ''Invalid''
					end as location_type, 
					location_type as loc_type,
					pil.location_lot_id,
					pil.location_qty as on_hand_balance,
					
					isnull((select sum(l.location_qty) from eclipse.product_inventory_location as l where left(l.location_type,1) in (''S'',''C'') and isnull(l.location_inprocess_status,''x'') <> ''I'' and l.product_inventory_id = pil.product_inventory_id),0) as total,	  
					location_status,
					location,
					location_tag_in,
					location_tag_out,
					location_tag,
					location_inprocess_status,
						(
							select id
							from (
							select
							product_inventory_location_id,
 							row_number() over(partition by product_inventory_id order by location_qty desc) as id 
							from eclipse.product_inventory_location
							where location_type = ''S'' and isnull(location_inprocess_status,''X'') <> ''I''
							) as sub 
							where id = 1 and sub.product_inventory_location_id = pil.product_inventory_location_id 
						 ) as parent_loc_flag,
					location_last_count_date
				from eclipse.product_inventory_location as pil  
			 
				) as ohb on ohb.product_inventory_id = p.product_branch_id

where p.product_id not in (1,2,3,120047,120048,69233,69226,69539,69537) and p.price_line_id <> ''MISC'' 
) as sub 
where  


	(
		sub.last_receive_date <> ''2015-01-01'' 
		or sub.last_sale_date <> ''2015-01-01'' 
		or sub.pil <> 0 
		or isnull(available_inventory,0) <> 0 
		or hits > 0 or isnull(sub.committed_qty,0) > 0 
		or iif(low_sale_qty > eoq,low_sale_qty,eoq) > 0 
		or exists (select product_branch_id from dbo.product_365_sales as s where s.product_branch_id = sub.product_branch_id)
	)

 
create index idx_product_branch_id on dbo.product_branch_inventory (product_branch_id)
create index idx_product_id on dbo.product_branch_inventory (product_id)
', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [product_branch_calculation_eda]    Script Date: 4/25/2023 10:34:15 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'product_branch_calculation_eda', 
		@step_id=9, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
 if exists (select * from INFORMATION_SCHEMA.TABLES where table_name = ''product_branch_calculation_eda'') drop table dbo.product_branch_calculation_eda
 select *
 into dbo.product_branch_calculation_eda
 from (
  select distinct 
  pbc.[product_branch_id]
  ,pbc.[branch_id]
  ,pbc.[product_id]
  ,pbc.[buy_line_id]
  ,pbc.[price_line_id]
  ,pbc.[buyer]
  ,pbc.[description]
  ,pbc.[alternate_description]
  ,pbc.[catalog_number]
  ,pbc.[select_code]
  ,pbc.[commodity_code]
  ,pbi.[PIL]
  ,pbc.product_stock_status as front_screen_stock_status
  ,pbc.[branch_stock_status]
  ,pbc.[rank_number1]
  ,pbc.[hits]
  ,pbc.[raw_hits]
  ,pbc.[lead_time_days]
  ,pbc.[demand_per_day]
  ,pbc.[eoq]
  ,pbc.[average_cost]
  ,pbc.[replacement_cost]
  ,pbi.[avg_cost_per_qty]
  ,pbc.[branch_cost_per_um]
  ,pbc.[low_sale_qty]
  ,pbc.[user_control_min_qty]
  ,pbc.[user_control_max_qty]
  ,pbc.[user_control_min_max_expire_date]
  ,pbc.[manual_safety_stock]
  ,pbc.[safety_stock_expiration_date]
  ,pbc.[forecast_parameter_trend_percentage]
  ,pbc.[number_of_days_with_zero_onhand]
  ,pbc.[classify_section]
  ,pbc.[classify_group]
  ,pbc.[classify_category]
  ,pbc.[classify_vendor_group]
  ,pbc.[upc]
  ,supc.secondary_upc
  ,pbc.[user_defined_id1]
  ,pbc.[user_defined_id2]
  ,pbi.[excess_inventory],
  pbc.[cut_product_type],
  p.doh, 
  pbc.product_stock_status,
  pbc.branch_cost_per_qty,
  isnull(pbc.raw_demand,0) as raw_demand,
  pbc.stocking_branch,
  isnull(pbi.last_receive_date,''2015-01-01'') as last_receive_date,
  isnull(pbi.last_sale_date,''2015-01-01'') as last_sale_date,
  isnull(pbi.first_recv_date,''2015-01-01'') as first_recv_date,
  r.ship_branch_region as region, 
  service_stock,
  ss_expire_date,
  buy_package_qty,
  o.order_point,
  o.line_point,
  o.plenty_date,
  pbc.cycle_days,
  pbc.target_type,
  pbc.target_amount,
  pbc.is_divisable,
  pbc.procure_group_id,
  pbc.suggest_on_all_flag
 from dbo.product_branch_calculation as pbc
   left join dbo.product_branch_inventory  as pbi  on pbc.product_branch_id = pbi.product_branch_id
   left join dbo.order_line_plenty as o on o.product_branch_id = pbc.product_branch_id
   left join (
      select *
      from dbo.product_branch_inventory 
      where location_type = ''Stock''
  ) as p on p.product_branch_id = pbi.product_branch_id 
  left join (
     select  
      b.branch_entity_id,
      b.branch_id,
      b.long_description,
      case 
     when b.branch_id = ''NESC'' then ''South Dakota''
     when b.branch_id = ''WIN'' then ''Wisconsin''
     when c.state = ''WI'' then ''Wisconsin''
     when c.state = ''MN'' then ''Minnesota''
     when c.state = ''SD'' then ''South Dakota''
     when c.state = ''ND'' then ''North Dakota''
     when c.state = ''MT'' then ''Montana'' 
     when c.state = ''MI'' then ''Michigan''
     when c.state = ''NE'' then ''Nebraska''
     when c.state = ''IA'' then ''Iowa''
     end as ship_branch_region,
      c.address_line1,
      c.city,
      c.state,
      left(c.postal_code,5) as postal_code 
     from eclipse.branch as b 
      left join eclipse.customer as c on c.eclipse_id = b.branch_entity_id
   ) as r on r.branch_id = pbc.branch_id
  /* secondary upc only pulling in first value */
  left join (
    select secondary_upc, eclipse_id    
    from eclipse.product_secondary_upc as u
    where replace(right(product_secondary_upc_id,2),''_'','''') = 1  
   ) as supc on supc.eclipse_id = pbc.product_id
 ) as sub

', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [product_branch_inventory_eda]    Script Date: 4/25/2023 10:34:15 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'product_branch_inventory_eda', 
		@step_id=10, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'	
	if exists (select * from INFORMATION_SCHEMA.TABLES WHERE table_name = ''product_branch_inventory_eda'') drop table dbo.product_branch_inventory_eda
  
  select *
	into dbo.product_branch_inventory_eda
  from (
 SELECT  
  p.prod_branch_loc,
    [product_branch_id]
    ,[branch_id]
    ,[product_id]
    ,cast([description] as nvarchar(75)) as description
    ,[loc_type]
    ,[location_type]
    ,[available_inventory]
    ,[purchase_order_qty]
    ,[transfer_order_qty]
     ,p.avg_cost_onhand
     ,[committed_qty]
     ,[committed_qty] * [avg_cost_per_qty] as committed_value
    ,[excess_inventory]
    ,[excess_qty]
    ,[excess_value]
 ,iif(product_count = 1 and excess_qty > 0 and committed_qty > 0 and (excess_qty - committed_qty) < 0,0,
  iif(excess_qty = 0,0,excess_qty - committed_qty)) * avg_cost_per_qty as excess_less_committed
    ,[last_receive_date]
    ,[last_sale_date]
    ,[first_recv_date]
    ,[receive_date_aging]
    ,[new_stock_products]
    ,[in_stock],
   p.purchase_order_qty * p.avg_cost_per_qty as po_total,
   p.transfer_order_qty * p.avg_cost_per_qty as to_total,
   cast([available_inventory]/iif([demand_per_day]<=0,1,[demand_per_day]) as bigint) as days_of_inventory_on_hand
   ,p.[365_sales_qty]
   ,p.[365_cogs]
   ,p.[30_day_qty]
   ,p.[30_day_cogs]
   ,p.[90_day_qty]
   ,p.[90_day_cogs]
   ,p.hits
   ,p.doh
   ,p.lead_time_days
   ,p.demand_per_day
   ,p.user_control_min_qty
   ,p.user_control_max_qty
   ,p.location
   ,p.location_status
   ,p.location_tag_in
   ,p.location_tag_out
   ,p.location_inprocess_status
   ,p.location_lot_id
   ,p.product_count
   ,p.last_purchase_order,
   case when p.loc_type in (''C'',''W'') then ''BAD RECORD'' else c.name end as ''name'',
   case when p.loc_type in (''C'',''W'') then ''BAD RECORD'' else c.name_index end as name_index,
   avg_cost,
   rep_cost,
   location_last_count_date

   FROM [EDW_dsgsupply_com_prod].[dbo].[product_branch_inventory] as p 
  /* Adding Customer/Vendor Name for Consignment and DTS  2021-07-29 DV  */
  left join (
     select 
      prod_branch_loc, 
      case when left(loc_type,1) = ''C'' then c.name 
        when left(loc_type,1) = ''W'' then c.name 
        when left(loc_type,1) = ''S'' then v.name 
      end as ''name'',
      case when left(loc_type,1) = ''C'' then c.name_index
        when left(loc_type,1) = ''W'' then c.name_index
        when left(loc_type,1) = ''S'' then v.name_index
      end as name_index
     from dbo.product_branch_inventory as p
      left join eclipse.customer as c on c.eclipse_id = replace(replace(replace(loc_type,''C'',''''),''S'',''''),''W'','''') collate SQL_Latin1_General_CP1_CI_AS
      left join eclipse.vendor as v on v.eclipse_id = replace(replace(replace(loc_type,''C'',''''),''S'',''''),''W'','''') collate SQL_Latin1_General_CP1_CI_AS 
     where len(loc_type) > 1 and loc_type <> ''N/A''
    ) as c on c.prod_branch_loc = p.prod_branch_loc
 ) as sub 
 
', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'product_branch_inventory', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20210402, 
		@active_end_date=99991231, 
		@active_start_time=60000, 
		@active_end_time=180000, 
		@schedule_uid=N'c967cf38-abd1-46ca-a64b-677e2f9f9aef'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


