USE [msdb]
GO

/****** Object:  Job [price_matrix]    Script Date: 4/25/2023 10:41:10 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 4/25/2023 10:41:10 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'price_matrix', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'domvicc', 
		@notify_email_operator_name=N'Dom Vicchiollo', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [product_price]    Script Date: 4/25/2023 10:41:10 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'product_price', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.product_price 
create table dbo.product_price ( 
	
	product_price_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,
	price_sheet_id nvarchar(255),
	product_id int,
	per_uom nvarchar(255),
	per_qty int,
	basis int,
	global_basis_name nvarchar(255),
	price decimal(38,9)
	)
insert into dbo.product_price

select 

	replace(concat(product_price_id,''~'',basis) collate SQL_Latin1_General_CP1_CS_AS,''~~'',''~'') as product_price_id,
	price_sheet_id,
	product_id, 
	per_uom,
	per_qty,
	basis,
	b.global_basis_name,
	product_price as price
from (
		select *
		from (
			select 
				eclipse_id as product_price_id,
				product_id,
				per_uom,
				per_qty,
				price_sheet_id,
				effective_date,
				basis1_basis_id,
				basis1_amount as ''1'',
				basis2_basis_id,
				basis2_amount as ''2'',
				basis3_basis_id,
				basis3_amount as ''3'',
				basis4_basis_id,
				basis4_amount as ''4'',
				basis5_basis_id,
				basis5_amount as ''5'',
				basis6_basis_id,
				basis6_amount as ''6'',
				basis7_basis_id,
				basis7_amount as ''7'',
				basis8_basis_id,
				basis8_amount as ''8'',
				basis9_basis_id,
				basis9_amount as ''9'',
				row_number() over(partition by product_id order by effective_Date desc) as id 
			from eclipse.product_price as pp
		) as sub 
		where sub.id = 1 
) as p
	unpivot (
		product_price for basis in ([1],[2],[3],[4],[5],[6],[7],[8],[9])
	) as p
	left join eclipse.system_price_global_basis as b on b.system_price_global_basis_id = p.basis
order by product_id ', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'price_matrix', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20211006, 
		@active_end_date=99991231, 
		@active_start_time=10000, 
		@active_end_time=235959, 
		@schedule_uid=N'72f2d3ad-dc73-4944-b279-fe7984f3c90e'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

