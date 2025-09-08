USE [msdb]
GO

/****** Object:  Job [eda_ubap]    Script Date: 4/25/2023 10:41:41 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 4/25/2023 10:41:41 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'eda_ubap', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Running AR ledger to create Eclipse UBAP report', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'domvicc', 
		@notify_email_operator_name=N'Dom Vicchiollo', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [ubap_purchase_orders]    Script Date: 4/25/2023 10:41:42 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'ubap_purchase_orders', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.ubap
create table dbo.ubap (
	id nvarchar(255) primary key,
	order_type nvarchar(1),
	due_date date,
	invoice_date date,
	--pay_date date,
	branch_id varchar(255),
	pay_to_id int,
	[status] nvarchar(255),
	handling_code nvarchar(255),
	order_id nvarchar(255),
	gl_account int,
	gl_autopost_code nvarchar(255),
	gl_amount decimal(18,5))

insert into dbo.ubap	

select  
 	
	isnull(p.accrual_register_applied_payment_id,concat(''NoAppliedPayment'',''_'',ROW_NUMBER() over(partition by left(ap.eclipse_id,1) order by ap.eclipse_id))) as id,
	left(ap.eclipse_id,1) as order_type,
	ap.due_date,
	ap.invoice_date,
	--d.pay_date,
	ap.gl_branch_id,
	ap.pay_to_id,
	ap.status,
	ap.handling_code,
	ap.eclipse_id as order_id,
	p.gl_account,
	p.gl_autopost_code,
	p.gl_amount

from eclipse.accrual_register  as ap 
	left join eclipse.accrual_register_applied_payment_gl_posting as p on p.eclipse_id = ap.eclipse_id and p.gl_account = 33 and p.gl_autopost_code = ''UBAP''
	--left join eclipse.accrual_register_pay_date as d on d.eclipse_id = ap.eclipse_id
where left(ap.eclipse_id,1) = ''P'' /* in (''P'',''S'',''Y'') */ and ISNULL([status],''Z'') <> ''$'' and ISNULL(handling_code,''x'') <> ''HST'' and isnull(reference_number,''x'') <> ''CONSIGNMENT'' 

create index order_id
on dbo.ubap (order_id)

--and ap.eclipse_id = ''S101645821.009''', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=4
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [ubap_payable_amount]    Script Date: 4/25/2023 10:41:42 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'ubap_payable_amount', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.payable_amount
create table dbo.payable_amount (
	id nvarchar(255) primary key, 
	payable nvarchar(255),
	purchase_order nvarchar(255),
	payable_amount decimal(18,3)
	)
insert into dbo.payable_amount

	select
		--concat(y.eclipse_id,''_'',row_number() over(partition by y.eclipse_id order by y.eclipse_id)) as id,
		y.accrual_register_applied_payment_id as id,
		y.eclipse_id as payable, 
		y.transaction_ar_id purchase_order,
		p.gl_amount as payable_amount
	from eclipse.accrual_register_applied_payment as y 
		left join eclipse.accrual_register_applied_payment_gl_posting as p on p.eclipse_id = y.eclipse_id and p.accrual_register_applied_payment_id = y.accrual_register_applied_payment_id 
	where p.gl_account = 33 and p.gl_autopost_code is null and left(y.eclipse_id,1) in  (''Y'',''P'',''S'')

create index payable
on dbo.payable_amount (payable,purchase_order) ', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=4
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'eda_ubap', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20220601, 
		@active_end_date=99991231, 
		@active_start_time=230000, 
		@active_end_time=235959, 
		@schedule_uid=N'c1087073-daac-448b-a5a1-11248609ff1d'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

