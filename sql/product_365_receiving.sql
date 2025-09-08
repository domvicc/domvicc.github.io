USE [msdb]
GO

/****** Object:  Job [product_365_receiving]    Script Date: 4/25/2023 10:37:50 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 4/25/2023 10:37:50 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'product_365_receiving', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'365 day receiving cogs qty and last recevie day by Product Branch', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'PRDSGECREP1\dsgadmin', 
		@notify_email_operator_name=N'Dom Vicchiollo', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [drop,create,insert]    Script Date: 4/25/2023 10:37:50 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'drop,create,insert', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.product_365_receiving

create table dbo.product_365_receiving	 (
		
			product_branch_id varchar(50) collate SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY ,
			ship_branch varchar(10) collate SQL_Latin1_General_CP1_CS_AS,
			product_id int,
			[365_day_qty] decimal(18,2),
			ext_cogs decimal(18,2),
			last_recv_date date,
			last_purchase_order nvarchar(15)
			)
insert into dbo.product_365_receiving
					
select *

from (	
	select
		concat(ph.product_id,''*'',ph.ship_branch) as product_branch_id,
		ph.ship_branch,
		--left(ph.location_type,1) as loc_type,
		ph.product_id, 
		sum(ph.qty) as ''365_day_qty'',
		SUM((ph.qty) * isnull(cogs,r.replacement_cost)) as ext_cogs,
		isnull(max(ship_date),''2020-03-01'') as last_recv_date,
		(select max(purchase_order_id) from eclipse.product_history as h where h.ship_branch = ph.ship_branch and h.product_id = ph.product_id and h.ship_date = max(ph.ship_date)) as last_purcahse_order
from eclipse.product_history as ph
	left join dbo.branch_product_price as r on r.product_branch_id = concat(ph.product_id,''*'',ph.ship_branch)
where (((purchase_order_id is not null or transfer_order_id is not null) and ph.qty > 0)  or (sales_order_id is not null and left(location_type,1) = ''C'' and ph.qty > 0))
group by ph.ship_branch,ph.product_id--,left(ph.location_type,1)
) as s
', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'product_365_recv', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20210402, 
		@active_end_date=99991231, 
		@active_start_time=190000, 
		@active_end_time=235959, 
		@schedule_uid=N'd6457540-4f17-44e5-8a5f-c7d7c6ecd4b9'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

