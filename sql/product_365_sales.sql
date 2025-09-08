USE [msdb]
GO

/****** Object:  Job [product_365_sales]    Script Date: 4/25/2023 10:37:29 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 4/25/2023 10:37:29 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'product_365_sales', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'PSUB file for Product 365 day sales and cogs', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'PRDSGECREP1\dsgadmin', 
		@notify_email_operator_name=N'Dom Vicchiollo', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Drop,Create,Insert Table]    Script Date: 4/25/2023 10:37:30 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Drop,Create,Insert Table', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.product_365_sales
create table dbo.product_365_sales (
		
			product_branch_id varchar(50) collate SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY ,
			ship_branch varchar(10) collate SQL_Latin1_General_CP1_CS_AS,
			product_id int,
			[30_day_qty] int,
			[30_day_cogs] decimal(18,2), 
			[90_day_qty] int,
			[90_day_cogs] decimal(18,2),
			[365_day_sales] decimal(18,2),
			ext_cogs decimal(18,2),
			last_sales_date date
			)
insert into dbo.product_365_sales

select 
	s.*,
	(	select
			isnull(max(ship_date),''2020-03-01'') 
		from eclipse.product_history as ph 
		where ph.ship_branch = s.ship_branch and ph.product_id = s.product_id and sales_order_id is not null and ph.qty < 0 and ph.price <> 0 and charindex(''~~'',eclipse_id) = 0 and left(location_type,1) in (''S'',''T'',''W'',''C'',''L'',''V'')
	) as last_sale_date
from (	
		select 
			product_branch_id,
			ship_branch,
			product_id,
			sum([30_day_qty]) as [30_day_qty],
			sum([30_day_cogs]) as [30_day_cogs],
			sum([90_day_qty]) as [90_day_qty],
			sum([90_day_cogs]) as [90_day_cogs],
			sum([365_day_sales]) as [365_day_sales],
			sum([ext_cogs]) as [ext_cogs]
		from (
			select 
					concat(ph.product_id,''*'',ph.ship_branch) as product_branch_id,
					ph.ship_branch,
					ph.product_id, 
					ph.ship_date,
					IIF(ship_date >= dateadd(day,-30,getdate()),-1*ph.qty,0) as ''30_day_qty'',
					IIF(ship_date >= dateadd(day,-30,getdate()),(-1*ph.qty) * isnull(cogs,r.replacement_cost),0) as ''30_day_cogs'',
					IIF(ship_date >= dateadd(day,-90,getdate()),-1*ph.qty,0) as ''90_day_qty'',
					IIF(ship_date >= dateadd(day,-90,getdate()),(-1*ph.qty) * isnull(cogs,r.replacement_cost),0) as ''90_day_cogs'',
					/* 9/9/22 per JWiz requesting to add in return qtys to the 365 sales number in order to get close to the Financials stock sales number for Inventory Turns metric */
					/*9/16/22 per JWiz request to move metric back to not include return qtys*/
					/*4/7/23 per JWiz removing return qtys from 365 sales only, not qtys, to impact turns calcluation using 365 sales but not effect excess number using qty */ 
					iif(ph.qty < 0,-1*ph.qty,0) as ''365_day_sales'',
					/* 4/27/23 - per JWiz 365 cogs should now include returns for turns calculation */ 
					(-1*ph.qty) * isnull(cogs,r.replacement_cost) as ext_cogs
			from eclipse.product_history as ph
				left join dbo.branch_product_price as r on r.product_branch_id = CONCAT(ph.product_id,''*'',ph.ship_branch)
			where sales_order_id is not null 
				/* 9/9/22 per JWiz requesting to add in return qtys to the 365 sales number in order to get close to the Financials stock sales number for Inventory Turns metric */
				/*9/16/22 per JWiz request to move metric back to not include return qtys*/
				/*4/7/23 per JWiz removing return qtys from 365 sales only, not qtys, to impact turns calcluation using 365 sales but not effect excess number using qty */ 
				--and ph.qty < 0 /* Per John Wiz because of impact to Excess Inventory on 365 day calculation. ***THIS WILL NOT MATCH Inventory Inquiry because that screen includes returns into 365 sales calculation */	
				and ph.price <> 0  
				and ship_date >= dateadd(day,-365,getdate()) 
				and charindex(''~~'',eclipse_id) = 0 
				and left(location_type,1) in (''S'',''T'',''W'',''C'',''L'',''V'')
			--group by ph.ship_branch,ph.product_id,ship_date
		) as sub
		group by product_branch_id, ship_branch,product_id
) as s

', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'prod_365_sales', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20210331, 
		@active_end_date=99991231, 
		@active_start_time=193000, 
		@active_end_time=235959, 
		@schedule_uid=N'e67a30df-7270-40e6-8206-bff212c3016d'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

