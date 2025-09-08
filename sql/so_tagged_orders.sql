USE [msdb]
GO

/****** Object:  Job [tagged_orders]    Script Date: 4/25/2023 10:40:56 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 4/25/2023 10:40:56 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'tagged_orders', 
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
/****** Object:  Step [run job]    Script Date: 4/25/2023 10:40:56 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'run job', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.tagged_orders
create table dbo.tagged_orders (
	sales_order_line_generation_id nvarchar(255) collate SQL_Latin1_General_CP1_CI_AS,
	eclipse_id nvarchar(255) collate SQL_Latin1_General_CP1_CI_AS,
	generation_id int,
	line_id int,
	ship_qty int,
	cogs decimal(18,3),	
	ext_cogs decimal(18,3),
	location_tag nvarchar(255),
	broken_tag_flag int,
	po_status_code varchar(10),
	receive_qty int,
	po_cogs decimal(18,3),
	ext_po_cogs decimal(18,3),
	cogs_variance_flag int,
	variance_total decimal(18,3)
	)
insert into dbo.tagged_orders
select  
	*,
	case when cogs <> po_cogs then 1 else 0 end as cogs_variance_flag,
	case when cogs <> po_cogs then (cogs - po_cogs) * receive_qty end as variance_total
from (
select distinct  
	sub.*,
	isnull(pog.status_code,tog.status_code) as po_status_code,

	isnull(isnull(polg.receive_qty,tolg.receive_qty),tolg.ship_qty) as receive_qty,

	case when tog.status_code = ''S'' then tolg.cogs
		 when tog.status_code = ''R'' then tolg.price
		 else polg.price 
		 end as po_cogs,
	(
		case when tog.status_code = ''S'' then tolg.cogs
		 when tog.status_code = ''R'' then tolg.price
		 else polg.price 
		 end 
		 *
		isnull(isnull(polg.receive_qty,tolg.receive_qty),tolg.ship_qty) 
	) as ext_po_cogs
from (
	select    
		solgl.sales_order_line_generation_id, 
		solgl.eclipse_id,
		solgl.generation_id,
		solgl.line_id,
		solg.ship_qty,
		solg.cogs,
		solg.cogs*solg.ship_qty as ext_cogs,
		location_tag,
		case when exists (
				select eclipse_id
			from eclipse.sales_order_log_comment as c 
			where left(comment,17) = ''** Broken Tag **'' and c.eclipse_id = solgl.eclipse_id)
			 then 1 
			 else 0
			 end as broken_tag_flag 
	from eclipse.sales_order_line_generation_location as solgl	
		left join eclipse.sales_order_line_generation as solg on solg.eclipse_id = solgl.eclipse_id and solg.sales_order_line_generation_id = solgl.sales_order_line_generation_id
	where location_tag is not null and LEFT(location_tag,1) in (''P'',''T'')   
) as sub
	left join eclipse.purchase_order_line_generation as polg on polg.eclipse_id = LEFT(sub.location_tag,10)  and CONCAT(polg.eclipse_id,''.'',polg.line_id) = sub.location_tag  
	left join eclipse.purchase_order_generation as pog on pog.eclipse_id = polg.eclipse_id and pog.generation_id = polg.generation_id
	left join eclipse.transfer_order_line_generation as tolg on tolg.eclipse_id = LEFT(sub.location_tag,10)  and CONCAT(tolg.eclipse_id,''.'',tolg.line_id) = sub.location_tag  
	left join eclipse.transfer_order_generation as tog on tog.eclipse_id = tolg.eclipse_id and tog.generation_id = tolg.generation_id and tog.status_code = ''R'' 
) as sub
where po_status_code is not null 
 
create index sales_order_line_generation_id on dbo.tagged_orders(sales_order_line_generation_id)
create index idx_location_tag on dbo.tagged_orders (location_tag)', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=4
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'tagged_orders', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20220615, 
		@active_end_date=99991231, 
		@active_start_time=180000, 
		@active_end_time=235959, 
		@schedule_uid=N'657959b2-7905-424d-a83b-13e4897992f9'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

