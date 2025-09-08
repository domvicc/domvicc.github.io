USE [msdb]
GO

/****** Object:  Job [rebates]    Script Date: 4/25/2023 10:38:19 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 4/25/2023 10:38:20 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'rebates', 
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
/****** Object:  Step [spj_rebate_sales_purchase_order]    Script Date: 4/25/2023 10:38:20 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'spj_rebate_sales_purchase_order', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.spj_po
create table dbo.spj_po (
	id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,
	purchase_order_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS,
	line_id int,
	sales_order_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS
	)

insert into dbo.spj_po
select 
	purchase_order_line_comment_id as id,
	purchase_order_id,
	line_id,
	RIGHT(comment,10) as sales_order_id
from eclipse.purchase_order_line_comment 
where left(comment,6) = ''Rebate''  

create index idx_purchase_order_id on dbo.spj_po (purchase_order_id)
create index idx_sales_order_id on dbo.spj_po (sales_order_id)', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [spa_rebates]    Script Date: 4/25/2023 10:38:20 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'spa_rebates', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
drop table dbo.spa_po
create table dbo.spa_po (
	sales_order_line_generation_rebate_id nvarchar(255) primary key not null,
	sales_order_line_generation_id nvarchar(255),
	sales_order_id nvarchar(255),
	rebate_purchase_order_id nvarchar(255),
	rebate_part_number int,
	rebate_type varchar(255)
	)

insert into dbo.spa_po

	select 
		sales_order_line_generation_rebate_id,
		sales_order_line_generation_id,
		eclipse_id,
		rebate_purchase_order_number,
		rebate_part_number,
		''SPA'' as rebate_type
	from eclipse.sales_order_line_generation_rebate

create index idx_rebate_purchase_order_number on dbo.spa_po (rebate_purchase_order_id)

 
', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [rebates]    Script Date: 4/25/2023 10:38:20 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'rebates', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.rebates
create table dbo.rebates (
	id nvarchar(255) primary key not null, 
	sales_order_line_generation_id nvarchar(255),
	sales_order_id nvarchar(255),
	rebate_purchase_order_id nvarchar(255),
	rebate_type varchar(255)
	)
insert into dbo.rebates  

				select distinct 
					CONCAT(sales_order_line_generation_id,''_'',CONCAT(s.po,''.'',line_id),''_'',''SPJ'') as id,
					sales_order_line_generation_id,
					s.sales_order_id,
					s.po as rebate_purchase_order,
					''SPJ'' as rebate_type
					
				from (
					select
						ROW_NUMBER() over(partition by sales_order_id order by CONCAT(purchase_order_id,''.'',line_id)) as id,
						sales_order_id,
						purchase_order_id as po
					from dbo.spj_po
				) as s
						left join eclipse.sales_order_line_generation as solg on solg.eclipse_id = s.sales_order_id collate SQL_Latin1_General_CP1_CI_AS
				
				where cost_override_code in (''0'',''ALT VENDOR'',''DO NOT USE'',''JOBQUOTE REB'',''REBATE PEND'',''SPJ NON-SQ-D'',''SPJ SQ-D Q2C'',''VOLUME REB'')---solg.is_manual_cogs_override = 1 and cost_override_code is not null 
					--and 
					-- exists (
					--		select sales_order_line_generation_id 
					--		from eclipse.sales_order_line_generation_location as l 
					--		where solg.eclipse_id = l.eclipse_id and l.sales_order_line_generation_id = solg.sales_order_line_generation_id and location_type <> ''T'' 
					--		)
	 
	 
insert into dbo.rebates
 
select 
	concat(id,''_'',row_number() over(partition by id order by id)) as id,
	sales_order_line_generation_id,
	sales_order_id,
	rebate_purchase_order,
	rebate_type
	from (
	select 
		CONCAT(s.sales_order_line_generation_id,''_'',s.rebate_purchase_order_id,''_'',''SPA'') as id ,
		s.sales_order_line_generation_id,
		s.sales_order_id,
		s.rebate_purchase_order_id as rebate_purchase_order,
		''SPA'' as rebate_type
					
	from (
		select 
		ROW_NUMBER() over(partition by sales_order_line_generation_rebate_id order by rebate_purchase_order_id) as id,
		*
		from dbo.spa_po as s
 			) as s
					--left join eclipse.sales_order_line_generation as solg on solg.eclipse_id = p.sales_order_id collate SQL_Latin1_General_CP1_CI_AS
				
			where exists (select sales_order_line_generation_id from eclipse.sales_order_line_generation_rebate as solg where solg.eclipse_id = s.sales_order_id collate SQL_Latin1_General_CP1_CI_AS and solg.sales_order_line_generation_id = s.sales_order_line_generation_id collate SQL_Latin1_General_CP1_CI_AS)
	) as sub
 

create index idx_rebate_purchase_order on dbo.rebates (rebate_purchase_order_id)
create index idx_sales_order on dbo.rebates(sales_order_id)
', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [rebate_journal]    Script Date: 4/25/2023 10:38:20 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'rebate_journal', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.rebate_journal
create table dbo.rebate_journal (
	id nvarchar(255) primary key not null,
	gl_date date, 
	purchase_order_id nvarchar(255) not null, 
	journal_id nvarchar(255),
	gl_branch varchar(255), 
	gl_account int,
	journal_amount decimal(18,2),
	[type] nvarchar(255)
	)


insert into dbo.rebate_journal

select 
	concat(sub.purchase_order,''_'',ROW_NUMBER() over(partition by sub.purchase_order order by sub.journal)) as id,

	*,
	case when gl_account = 15 then ''Inventory''
		 when gl_account = 208 then ''Direct Inventory''
		 when gl_account = 153 then ''Rebate Exchange''
		 when gl_account = 72 then ''Transfer Exchange'' 
		 else null 
		 end as [type]
from (
		select 
			j.gl_date,
			concat(RIGHT(header_notation,10),''.001'') as purchase_order,
			concat(j.eclipse_id,''.001'') as journal,
			g.gl_branch,
			gl_account,
			g.gl_amount
				
		from eclipse.journal_generation as j 
			left join eclipse.journal_generation_gl_posting as g on g.eclipse_id = j.eclipse_id and g.gl_account in (15,208,153,72) 
		where header_notation like ''%P0%'' and gl_amount <> 0 and gl_date <= eomonth(dateadd(mm,-1,getdate()))

		union  

		select 
			j.gl_date,
			sub.*,
			g.gl_branch,
			g.gl_account,
			g.gl_amount
		from (
			select 
				concat(eclipse_id,''.001'') as purchase_order,
				concat(LEFT(comment,10),''.001'') as journal
			from eclipse.purchase_order_log_comment
			where left(comment,2) = ''J1''
		) as sub
			left join eclipse.journal_generation_gl_posting as g on g.eclipse_id = left(journal,10) and gl_account in (15,208,153,72) 
			left join eclipse.journal_generation as j on g.eclipse_id = j.eclipse_id 
) as sub

create index idx_journal on dbo.rebate_journal (journal_id)
create index idx_purchase_order on dbo.rebate_journal (purchase_order_id)', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [spa_timing_variance]    Script Date: 4/25/2023 10:38:20 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'spa_timing_variance', 
		@step_id=5, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'if exists (select * from INFORMATION_SCHEMA.TABLES where table_name = ''spa_timing_variance'') drop table dbo.spa_timing_variance; 
with so as (
	select 
	concat(sales_order_id,''.'',format(invoice_number,''000'')) as so,
	*
	from dbo.dsg_inventory_audit_spa_analyis
) 
select 
	*
	into dbo.spa_timing_variance
from so 
where not exists (
			select *
			from dbo.sales_order as s 
			where ship_date <= eomonth(dateadd(mm,-1,getdate())) and so.so = s.sales_order_number and s.line_id = so.line_id 
			     )', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [spj_timing_variance]    Script Date: 4/25/2023 10:38:20 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'spj_timing_variance', 
		@step_id=6, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
if exists (select * from INFORMATION_SCHEMA.TABLES where table_name = ''spj_timing_variance'') drop table dbo.spj_timing_variance;

with spj as (
	select 
		eclipse_id,
		ship_branch,
		rebate_purchase_order_id, 
		sum(invoiced_amount) as invoiced_amount,
		sum(open_amount) as open_amount
	from (
		select distinct
			sog.ship_date,
			sog.ship_branch,
			sog.eclipse_id,
			r.rebate_purchase_order_id,
			sog.invoice_number,
			sog.status_code,
			iif(status_code = ''I'',sog.cogs_total,0) as invoiced_amount,
			iif(status_code <>''I'',sog.cogs_total,0) as open_amount,
			sog.cogs_total
		from dbo.rebates as r 
			left join eclipse.sales_order_generation as sog on sog.eclipse_id = r.sales_order_id collate SQL_Latin1_General_CP1_CI_AS
		where rebate_type = ''SPJ'' and sog.status_code not in (''B'',''X'') 
	) as sub
	group by  eclipse_id, rebate_purchase_order_id, ship_branch
	having sum(open_amount) > 0 
) 
 
select 
	s.eclipse_id,
	ship_branch,
	invoiced_amount,
	open_amount,
	invoiced_amount  / (invoiced_amount + open_amount) as percent_complete,
	sum(journal_amount) as journal_amount,
	sum(journal_amount) - ((invoiced_amount  / (invoiced_amount + open_amount)) * sum(journal_amount)) as variance
	into dbo.spj_timing_variance
from spj as s 
	left join  dbo.rebate_journal as r on left(r.id,10) = left(s.rebate_purchase_order_id,10) and r.gl_account = 15 
group by s.eclipse_id,invoiced_amount,open_amount,ship_branch

	
 
', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'rebate_job', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20220728, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'e3ce93de-fb16-4fd9-9e15-665f05513fcd'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

