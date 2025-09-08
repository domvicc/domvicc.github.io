USE [msdb]
GO

/****** Object:  Job [so_process_date]    Script Date: 4/25/2023 10:40:43 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 4/25/2023 10:40:43 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'so_process_date', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=3, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Running Query to capture Process order date from Change log', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'melhedt', 
		@notify_email_operator_name=N'Melissa Hedtke', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [so_process_date]    Script Date: 4/25/2023 10:40:43 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'so_process_date', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.so_process_date 

create table dbo.so_process_date(
	sales_order_log_comment_id Nvarchar(255) primary Key NOT NULL,
	sales_order_id Nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS,
	generation_id int,
	[date] date,
	[time] time
)

insert into dbo.so_process_date

Select 
	sales_order_log_comment_id,
	sales_order_id,
	generation_id,
	[date],
	[time] 
from eclipse.sales_order_log_comment
Where left(comment,17) = ''Processed Order #''


Create index idx_sale_order_id on dbo.so_process_date (sales_order_id)
Create index idx_generation_id on dbo.so_process_date (generation_id)
Create index idx_date on dbo.so_process_date (date)
Create index idx_time on dbo.so_process_date (time)', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'so_process_date', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20221005, 
		@active_end_date=99991231, 
		@active_start_time=30000, 
		@active_end_time=235959, 
		@schedule_uid=N'2ab3b9ba-a00d-4cb5-90c0-ff3648a31c88'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

