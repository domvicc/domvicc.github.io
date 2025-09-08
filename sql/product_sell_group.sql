USE [msdb]
GO

/****** Object:  Job [product_sell_group]    Script Date: 4/25/2023 10:43:19 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 4/25/2023 10:43:19 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'product_sell_group', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Drop, Create, Insert records for dbo.product_sell_group.....dataset used for Product Branch Calculation database in EDA - Paul Mund', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'domvicc', 
		@notify_email_operator_name=N'Dom Vicchiollo', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Drop, Create and Insert Table]    Script Date: 4/25/2023 10:43:20 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Drop, Create and Insert Table', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.product_sell_group
create table dbo.product_sell_group (

	product_id int NOT NULL PRIMARY KEY,
	description nvarchar(75),
	pdw_item_id int,
	upc nvarchar(50),
	secondary_upc nvarchar(50),
	product_status nvarchar(50),
	price_line_id nvarchar(50),
	buy_line_id nvarchar(50),
	select_code nvarchar(50),
	matrix_type nvarchar(50),
	commodity_code nvarchar(50),
	dynamic_kit_flag int,
	sell_group1 nvarchar(50),
	sell_group2 nvarchar(50),
	sell_group3 nvarchar(50),
	sell_group4 nvarchar(50),
	sell_group5 nvarchar(50),
	sell_gorup6 nvarchar(50),
	sell_group7 nvarchar(50)
	);
insert into dbo.product_sell_group
 
select   
	p.product_id,
	cast(p.description as nvarchar(75)) as description,
	p.pdw_item_id,
	p.upc,
	supc.secondary_upc,
	s.description as product_status,
	p.price_line_id,
	p.buy_line_id,
	p.select_code,
	p.matrix_type,
	p.commodity_code,
	case when exists (select k.product_id from eclipse.product_kit_component as k where k.eclipse_id = p.eclipse_id) then 1 else 0 end as dynamic_kit_flag, 
	sg.sell_group1,
	sg.sell_group2,
	sg.sell_group3,
	sg.sell_group4,
	sg.sell_group5,
	sg.sell_gorup6,
	sg.sell_group7
from eclipse.product as p 
	left join eclipse.system_product_status as s on s.system_product_status_id = p.product_status_id
	/* Secondary UPC only pulling in 1st value */ 
	left join ( 
				select *				
				from eclipse.product_secondary_upc
				where replace(right(product_secondary_upc_id,2),''_'','''') = 1  
			  ) as supc on supc.eclipse_id = p.eclipse_id
	left join (
				select 
					p.eclipse_id,
					p.[1] as sell_group1,
					p.[2] as sell_group2,
					p.[3] as sell_group3,
					p.[4] as sell_group4,
					p.[5] as sell_group5,
					p.[6] as sell_gorup6,
					p.[7] as sell_group7
				from (
						select 
							s.eclipse_id,
							s.sell_group_id,
							substring(product_branch_sell_group_id,len(product_branch_id)+2,99) as id 
						from eclipse.product_branch_sell_group as s 
						) as p	
				pivot (
				max(sell_group_id)
				for id in ([1],[2],[3],[4],[5],[6],[7] )
				) as p
			) as sg on sg.eclipse_id = p.eclipse_id
', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'product_sell_group', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20210513, 
		@active_end_date=99991231, 
		@active_start_time=200000, 
		@active_end_time=235959, 
		@schedule_uid=N'83e70eaa-af5f-4737-8201-9bfe5ecc80ce'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

