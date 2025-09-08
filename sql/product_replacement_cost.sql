USE [msdb]
GO

/****** Object:  Job [product_replacement_cost]    Script Date: 4/25/2023 10:38:44 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 4/25/2023 10:38:44 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'product_replacement_cost', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Job running product replacement cost for the Product Database in EDA', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'domvicc', 
		@notify_email_operator_name=N'Dom Vicchiollo', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [product_branch_price_branch]    Script Date: 4/25/2023 10:38:44 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'product_branch_price_branch', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
drop table dbo.branch_product_price_branch

create table dbo.branch_product_price_branch (
	product_branch_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,
	replacement_cost decimal(18,4)
	)
insert into dbo.branch_product_price_branch

select 
	product_branch_id,
				/* 1. Branch Price Sheet ID */
				(
				select
					basis6_amount
				from (
						select 
						ROW_NUMBER() over(partition by product_id, price_sheet_id order by effective_date desc) as id,
						*
						from eclipse.product_price as p
						where p.price_sheet_id is not null and p.basis6_amount is not null and p.eclipse_id = concat(sub.eclipse_id,branch_id)
					) as sub
					where sub.id = 1 
				) 
				/		
				(
				select 
					per_qty
				from (
					select 
					ROW_NUMBER() over(partition by product_id, price_sheet_id order by effective_date desc) as id,
					p.*
					from eclipse.product_price as p	 
					where p.price_sheet_id is not null and p.basis6_amount is not null and p.eclipse_id = concat(sub.eclipse_id,branch_id)
					) as sub 
				where sub.id = 1 
				) as rep_cost
from (
	select 
		pb.product_branch_id,
		branch_id,
		product_id,
		concat(pb.product_id,''~'') as eclipse_id
	from dbo.product_branch as pb
) as sub

', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [product_branch_price_territory]    Script Date: 4/25/2023 10:38:44 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'product_branch_price_territory', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.branch_product_price_territory
create table dbo.branch_product_price_territory (
	product_branch_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,
--	average_cost decimal(18,4),
	replacement_cost decimal(18,4)
	)
insert into dbo.branch_product_price_territory

select 
	product_branch_id,
	 
				/* 2. Territory Price Sheet ID */
				(
				select
					basis6_amount
				from (
						select 
						ROW_NUMBER() over(partition by p.product_id, b.branch_id  order by effective_date desc) as id,
						p.*
						from eclipse.product_price as p
							left join eclipse.branch_matrix_hierarchy_branch_list as b on b.matrix_hierarchy_branch_id = p.price_sheet_id and b.branch_id <> b.matrix_hierarchy_branch_id
						where p.price_sheet_id is not null and p.basis6_amount is not null and p.eclipse_id = concat(sub.eclipse_id,matrix_hierarchy_branch_id) and b.branch_id = sub.branch_id 
					) as sub
				 where sub.id = 1 
				 ) 
				 /
				(
				select 
					per_qty
				from (
					select 
					ROW_NUMBER() over(partition by p.product_id, b.branch_id order by effective_date desc) as id,
					p.*
					from eclipse.product_price as p
						left join eclipse.branch_matrix_hierarchy_branch_list as b on b.matrix_hierarchy_branch_id = p.price_sheet_id and b.branch_id <> b.matrix_hierarchy_branch_id
					where p.price_sheet_id is not null and p.per_qty is not null and p.eclipse_id = concat(sub.eclipse_id,matrix_hierarchy_branch_id) and b.branch_id = sub.branch_id
					) as sub 
				where sub.id = 1 
				)
			as rep_cost
from (
	select 
		pb.product_branch_id,
		branch_id,
		product_id,
		concat(pb.product_id,''~'') as eclipse_id
	from dbo.product_branch as pb
) as sub


', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [product_branch_price_tilde]    Script Date: 4/25/2023 10:38:44 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'product_branch_price_tilde', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.branch_product_price_tilde 
create table dbo.branch_product_price_tilde (
	product_branch_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,
	replacement_cost decimal(18,4)
	)
insert into dbo.branch_product_price_tilde 

select 
	product_branch_id,

				/* Default Tilde Sheet */ 
				(
				select
					basis6_amount
				from (
						select 
						ROW_NUMBER() over(partition by product_id, price_sheet_id order by effective_date desc) as id,
						*
						from eclipse.product_price as p
						where p.price_sheet_id is null and p.basis6_amount is not null and p.eclipse_id = sub.eclipse_id
					) as sub
					where sub.id = 1 
				) 
				/		
				(
				select 
					per_qty
				from (
					select 
					ROW_NUMBER() over(partition by product_id, price_sheet_id order by effective_date desc) as id,
					p.*
					from eclipse.product_price as p	 
					where p.price_sheet_id is null and p.per_qty is not null and p.eclipse_id = sub.eclipse_id  
					) as sub 
				where sub.id = 1 
				)
	 as ''rep_cost''
from (
	select 
		pb.product_branch_id,
		branch_id,
		product_id,
		concat(pb.product_id,''~'') as eclipse_id
	from dbo.product_branch as pb
) as sub


 ', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [product_branch_price_snet]    Script Date: 4/25/2023 10:38:44 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'product_branch_price_snet', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.branch_product_price_snet
create table dbo.branch_product_price_snet (
	product_branch_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,
	replacement_cost decimal(18,4)
	)
insert into dbo.branch_product_price_snet

select 
	product_branch_id,

				/* SNET Sheet for all branches */ 
				(
				select
					basis6_amount
				from (
						select 
						ROW_NUMBER() over(partition by product_id, price_sheet_id order by effective_date desc) as id,
						*
						from eclipse.product_price as p
						where p.basis6_amount is not null and p.eclipse_id = concat(sub.eclipse_id,''SNET'')
					) as sub
					where sub.id = 1 
				) 
				/		
				(
				select 
					per_qty
				from (
					select 
					ROW_NUMBER() over(partition by product_id, price_sheet_id order by effective_date desc) as id,
					p.*
					from eclipse.product_price as p	 
					where p.per_qty is not null and p.eclipse_id = concat(sub.eclipse_id,''SNET'')
					) as sub 
				where sub.id = 1 
				)
	 as ''rep_cost''
from (
	select 
		pb.product_branch_id,
		branch_id,
		product_id,
		concat(pb.product_id,''~'') as eclipse_id
	from dbo.product_branch as pb
) as sub


 ', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [product_branch_price]    Script Date: 4/25/2023 10:38:44 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'product_branch_price', 
		@step_id=5, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.branch_product_price

create table dbo.branch_product_price (
	product_branch_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,
	replacement_cost decimal(18,4)
	)
insert into dbo.branch_product_price

select
	pb.product_branch_id,
	/* adding logic to skip branch level rep cost for DWVFIT buyline....issue with price sheets and cached records not clearing in eclipse 7/26/22 */ 
	case when exists (select buy_line_id from eclipse.product as p where p.eclipse_id = pb.product_id and buy_line_id = ''DWVFIT'') then
			case when exists (select branch_id from eclipse.branch_matrix_hierarchy_branch_list as h where h.branch_id = pb.branch_id and h.matrix_hierarchy_branch_id = ''MICH'') then  isnull(isnull(ISNULL(b.replacement_cost,t.replacement_cost),s.replacement_cost),d.replacement_cost) 
				else isnull(isnull(t.replacement_cost,s.replacement_cost),d.replacement_cost)
				end
		 when exists (select buy_line_id from eclipse.product as p where p.eclipse_id = pb.product_id and buy_line_id = ''DURODYNE'') then
			case when exists (select branch_id from eclipse.branch_matrix_hierarchy_branch_list as h where h.branch_id = pb.branch_id and h.matrix_hierarchy_branch_id = ''MICH'') then isnull(isnull(ISNULL(b.replacement_cost,t.replacement_cost),s.replacement_cost),d.replacement_cost)  
				else isnull(isnull(b.replacement_cost,s.replacement_cost),d.replacement_cost)
				end
		 when exists (select buy_line_id from eclipse.product as p where p.eclipse_id = pb.product_id and buy_line_id = ''UPONOR'') then
			case when exists (select branch_id from eclipse.branch_matrix_hierarchy_branch_list as h where h.branch_id = pb.branch_id and h.matrix_hierarchy_branch_id = ''MICH'') then isnull(isnull(ISNULL(b.replacement_cost,t.replacement_cost),s.replacement_cost),d.replacement_cost) 
				else isnull(isnull(t.replacement_cost,s.replacement_cost),d.replacement_cost)
				end
		 when exists (select buy_line_id from eclipse.product as p where p.eclipse_id = pb.product_id and buy_line_id = ''PVCPRPIP'') then
			case when exists (select branch_id from eclipse.branch_matrix_hierarchy_branch_list as h where h.branch_id = pb.branch_id and h.matrix_hierarchy_branch_id = ''MICH'') then isnull(isnull(ISNULL(b.replacement_cost,t.replacement_cost),s.replacement_cost),d.replacement_cost) 
				else isnull(s.replacement_cost,d.replacement_cost)
				end 
		 when pb.product_branch_id = ''251614*SHE'' then isnull(isnull(t.replacement_cost,s.replacement_cost),d.replacement_cost)
		 else isnull(isnull(ISNULL(b.replacement_cost,t.replacement_cost),s.replacement_cost),d.replacement_cost) 
		 end as rep_cost
from dbo.product_branch as pb
	left join dbo.branch_product_price_branch as b on b.product_branch_id = pb.product_branch_id
	left join dbo.branch_product_price_territory as t on t.product_branch_id = pb.product_branch_id 
	left join dbo.branch_product_price_tilde as d on d.product_branch_id = pb.product_branch_id
	left join dbo.branch_product_price_snet as s on s.product_branch_id = pb.product_branch_id
 
 
', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'prod_replace_cost', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20210331, 
		@active_end_date=99991231, 
		@active_start_time=213000, 
		@active_end_time=235959, 
		@schedule_uid=N'4e8ddb8d-3423-4258-8bb5-454e4371dc55'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

