USE [msdb]
GO

/****** Object:  Job [vendor_buy_line]    Script Date: 4/25/2023 10:42:46 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 4/25/2023 10:42:46 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'vendor_buy_line', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'vendor buy line segment factor', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'domvicc', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Drop, Create & Insert table]    Script Date: 4/25/2023 10:42:47 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Drop, Create & Insert table', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.vendor_buy_line

create table dbo.vendor_buy_line (
	branch_vendor_buyline_segment varchar(60) NOT NULL PRIMARY KEY, 
	branch_id varchar(10),
	pay_to_id int,
	name nvarchar(max),
	buy_line_id nvarchar(max),
	select_code nvarchar(max),
	pay_to_total decimal(18,2),
	buy_line_total decimal(18,2),
	buy_line_factor decimal(18,4)
	) ; 

insert into dbo.vendor_buy_line

select 
	concat(sub.receive_branch,''_'',sub.pay_to_id,''_'',sub.buy_line_id,''_'',sub.select_code) as branch_vendor_buyline_segment,
	sub.receive_branch as branch_id,
	sub.pay_to_id,
	v.name,
	buy_line_id,
	select_code,
	sub.pay_to_total,
	buy_line_total, 
	sub.pay_to_total / iif(buy_line_total = 0,1,buy_line_total) as buy_line_factor
from (
		select 
			pog.pay_to_id,
			pog.receive_branch,
			p.buy_line_id,
			p.select_code,
			sum(receive_qty * price) as pay_to_total,
			 

			( 	 select 
					 sum(ext_price)	
					 from(
						select 
							sum(receive_qty * price) as ext_price
						from eclipse.purchase_order_line_generation as polg
							left join eclipse.purchase_order_generation as po on po.eclipse_id = polg.eclipse_id and po.generation_id = polg.generation_id
							left join eclipse.product as d on d.eclipse_id = polg.product_id
						where d.eclipse_id <> 1 and receive_date > dateadd(dd,-365,getdate()) and d.buy_line_id = p.buy_line_id and po.status_code = ''R'' and po.receive_branch = pog.receive_branch
						group by d.buy_line_id, po.pay_to_id,po.receive_branch
						having sum(receive_qty * price) > 0 
					 ) as sub 
			) as buy_line_total
		from eclipse.purchase_order_line_generation as polg
			left join eclipse.purchase_order_generation as pog on pog.eclipse_id = polg.eclipse_id and pog.generation_id = polg.generation_id
			left join eclipse.product as p on p.eclipse_id = polg.product_id
		where p.eclipse_id <> 1 and receive_date > dateadd(dd,-365,getdate()) and pog.status_code = ''R''
		group by pog.pay_to_id,p.buy_line_id,p.select_code,pog.receive_branch
		having sum(receive_qty * price) > 0 
 ) as sub
 left join eclipse.vendor as v on v.eclipse_id = sub.pay_to_id
 where sub.pay_to_total / iif(buy_line_total = 0,1,buy_line_total) > .0099 and sub.pay_to_id <> 41 and sub.buy_line_id <> ''37010003''

', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'dbo.vendor_buy_line', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20210330, 
		@active_end_date=99991231, 
		@active_start_time=183000, 
		@active_end_time=235959, 
		@schedule_uid=N'38ffba91-c2b6-44d8-966a-78ba60c94530'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

