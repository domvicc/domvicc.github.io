USE [msdb]
GO

/****** Object:  Job [dsg_inventory_audit]    Script Date: 4/25/2023 10:36:23 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 4/25/2023 10:36:24 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'dsg_inventory_audit', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Change branch filter onces on first file, twice on [branch] file', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'domvicc', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [drop create tables]    Script Date: 4/25/2023 10:36:24 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'drop create tables', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.dsg_inventory_audit_journal
create table dbo.dsg_inventory_audit_journal (
	eom date,
	gl_date date,
	journal_id nvarchar(255),
	journal_type nvarchar(255),
	header_notation nvarchar(255),
	rebate_po nvarchar(255),
	gl_amount decimal(18,3),
	id nvarchar(255) primary key not null
	)
create index idx_journal on dbo.dsg_inventory_audit_journal (journal_id)

drop table dbo.dsg_inventory_audit_spa_analyis
create table dbo.dsg_inventory_audit_spa_analyis (
	eclipse_id nvarchar(255) primary key not null,
	type nvarchar(255),
	ship_date date,
	ship_branch varchar(255), 
	purchase_order_id nvarchar(255),
	journal_id nvarchar(255),
	sales_order_id nvarchar(255) ,
	invoice_number int,
	line_id int,
	product_id int,
	po_qty int,
	rebate_cost decimal(18,3),
	avg_cost decimal(18,3),
	rep_cost decimal(18,3),
	ext_rebate_cost decimal(18,3),
	ext_avg_cost decimal(18,3),
	ext_rep_cost decimal(18,3),
	rebate_amount decimal(18,3),
	journal_amount decimal(18,3),
	[G/L] decimal(18,3),
	perpetual decimal(18,3),
	inv_vs_gl decimal(18,3),
	so_claim_count int, 
	po_claim_count int,
	rebate_avg_vs_gl decimal(18,3),
	rebate_rep_vs_gl decimal(18,3),
	rebate_other decimal(18,3),
	rest decimal(18,3),
	rep_vs_avg decimal(18,3),
	rejected_amount decimal(18,3),
	gl_amount decimal(18,3),
	vendor_proposed_rebate_amount decimal(18,3),
	avg_vs_gl decimal(18,3),
	procure_flag_variance int 
	)


drop table dbo.dsg_inventory_audit_branch
/* CHANGE BRANCH ID HERE */
create table dbo.dsg_inventory_audit_branch (

	category nvarchar(255),
	[type] nvarchar(255),
	order_invoice_id nvarchar(255) primary key not null,
	product_branch_id nvarchar(255),
	ship_date date,
	price_date date,
	ship_branch varchar(255),
	order_id nvarchar(255),
	line_id int,
	product_id int,
	qty int,
	return_flag int,
	review_flag int,
	credit_rebill_flag int,
	manual_override_flag int, 
	merge_product_flag int,
	in_out nvarchar(255),
	so_returns nvarchar(255),
	po_review_status nvarchar(255),
	kits int, 
	rebate_type nvarchar(255),
	procurement nvarchar(255),
	dts_flag int, 
	gl_amount decimal(18,3),
	avg_cost decimal(18,3),
	rep_cost decimal(18,3),
	ext_avg_cost decimal(18,3),
	ext_rep_cost decimal(18,3),
	avg_vs_gl decimal(18,3),
	location_tag nvarchar(255),
	ext_po_cogs decimal(18,3),
	avg_cost_adj_flag int,
	header_comment nvarchar(max),
	rebate_category nvarchar(255),
	purchase_order_id nvarchar(255),
	journal_id nvarchar(255),
	journal_amount decimal(18,3),
	zero_dollar_adj_flag int,
	total_variance decimal(18,3)
	)', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [dsg_audit_branch]    Script Date: 4/25/2023 10:36:24 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'dsg_audit_branch', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'use msdb
if
	(select count(distinct ship_branch) from dbo.dsg_inventory_audit_branch) =
	(
	select  
		count(distinct branch_id) 
		--min(branch_id) as branch_id 
	from edw_dsgsupply_com_prod.eclipse.branch as b 
	where is_stocking_branch = 1 and right(long_description,2) not in (''IA'',''NE'') and branch_id not in (''NDBI'',''NDMI'',''ROG'',''MANK'')
	and not exists (select ship_branch from edw_dsgsupply_com_prod.dbo.dsg_inventory_audit_branch as i where i.ship_branch = b.branch_id collate SQL_Latin1_General_CP1_CS_AS) 
	 )

exec sp_stop_job N''dsg_inventory_audit''  
else


drop table edw_dsgsupply_com_prod.dbo.dsg_audit_branch
create table edw_dsgsupply_com_prod.dbo.dsg_audit_branch (
	audit_branch_id varchar(255) collate SQL_Latin1_General_CP1_CS_AS
	)

insert into edw_dsgsupply_com_prod.dbo.dsg_audit_branch

select  
	min(branch_id) as branch_id 
from edw_dsgsupply_com_prod.eclipse.branch as b 
where is_stocking_branch = 1 and right(long_description,2) not in (''IA'',''NE'') and branch_id not in (''NDBI'',''NDMI'',''ROG'',''MANK'')
and not exists (select ship_branch from edw_dsgsupply_com_prod.dbo.dsg_inventory_audit_branch as i where i.ship_branch = b.branch_id collate SQL_Latin1_General_CP1_CS_AS)

', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [dsg_inventory_audit_journal]    Script Date: 4/25/2023 10:36:24 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'dsg_inventory_audit_journal', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
insert into dbo.dsg_inventory_audit_journal

	select 
		EOMONTH(gl_date) as eom,
		gl_date,
		journal_id,
		journal_type,
		header_notation,
		iif(journal_type in (''SPJ Rebate'',''SPA Rebate''),rebate_po,null) as rebate_po,
		sum(gl_amount) as gl_amount,
		id
	from (
			select 
				right(header_notation,10) as rebate_po,
				j.*,
				g.gl_amount,
				case when g.gl_account = 153 then ''Rebate Exchange 153''
						when left(header_notation,21) = ''Rebate Offset for P/O'' then isnull((select max(''SPJ Rebate'') from dbo.spj_po as r where right(j.header_notation,10) = left(purchase_order_id,10) collate SQL_Latin1_General_CP1_CI_AS ),''SPA Rebate'')
						when upper(header_notation) like ''%EX%'' then ''Manual Rebate Exchange''
						when header_notation like ''%Inventory Adjustment%'' then ''Inventory Adjustments''
						else ''Manual Entry'' end as journal_type,
				concat(g.eclipse_id,''.'',format(j.invoice_number,''000''),''_'',(select * from dbo.dsg_audit_branch)) as id 
			--	sum(gl_amount) as rebate_amount,
			
				--*
			from eclipse.journal_generation_gl_posting as g 
				left join eclipse.journal_generation as j on j.eclipse_id = g.eclipse_id and j.generation_id = g.generation_id
			where gl_account in (15) and exists (select audit_branch_id from dbo.dsg_audit_branch as b where b.audit_branch_id = g.gl_branch) /* and left(header_notation,6) = ''Rebate'' */ and gl_date  between dateadd(dd,1,eomonth(dateadd(mm,-2,getdate()))) and eomonth(dateadd(mm,-1,getdate()))
	) as sub
	group by EOMONTH(gl_date), gl_date, journal_id, journal_type, header_notation, iif(journal_type in (''SPJ Rebate'',''SPA Rebate''),rebate_po,null),id

alter index idx_journal on dbo.dsg_inventory_audit_journal rebuild --(journal_id)



', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [dsg_inventory_audit_rebate_journal]    Script Date: 4/25/2023 10:36:24 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'dsg_inventory_audit_rebate_journal', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.dsg_inventory_audit_rebate_journal
create table dbo.dsg_inventory_audit_rebate_journal (
	id nvarchar(255) primary key not null,
	gl_date date, 
	purchase_order_id nvarchar(255) not null, 
	journal_id nvarchar(255),
	gl_branch varchar(255), 
	gl_account int,
	journal_amount decimal(18,2),
	[type] nvarchar(255)
	)


insert into dbo.dsg_inventory_audit_rebate_journal

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
		where header_notation like ''%P0%'' and gl_amount <> 0  and g.gl_branch = (select * from dbo.dsg_audit_branch) and gl_date <= eomonth(dateadd(mm,-1,getdate()))

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
		where g.gl_branch = (select * from dbo.dsg_audit_branch) 
) as sub

create index idx_journal on dbo.dsg_inventory_audit_rebate_journal (journal_id)
create index idx_purchase_order on dbo.dsg_inventory_audit_rebate_journal (purchase_order_id)', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [dsg_inventory_audit_inventory_adjustment]    Script Date: 4/25/2023 10:36:24 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'dsg_inventory_audit_inventory_adjustment', 
		@step_id=5, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.dsg_inventory_audit_inventory_adjustment
create table dbo.dsg_inventory_audit_inventory_adjustment (
	purchase_order_line_generation_id nvarchar(255) primary key not null, 
	product_branch_id nvarchar(255), 
	receive_date date,
	receive_branch varchar(255),
	purchase_order_id nvarchar(255),
	line_id int,
	product_id int,
	qty int,
	return_flag int,
	review_flag int,
	override_flag int,
	gl_amount decimal(18,3)
	)
insert into dbo.dsg_inventory_audit_inventory_adjustment

select 
	gl.inventory_adjustment_line_id,
	CONCAT(ial.product_id,''*'',gl.gl_branch) as product_branch_id, 
	ia.adjustment_date,
	gl.gl_branch,
	gl.eclipse_id,
	ial.line_id,
	ial.product_id,
	ial.adjustment_qty as qty,
	0 as return_flag,
	0 as review_flag,
	iif(ial.manual_price_override_date is not null,1,0) as override_date,
	gl.gl_amount
from eclipse.inventory_adjustment_line_gl_posting as gl
	left join eclipse.inventory_adjustment_line as ial on ial.eclipse_id = gl.eclipse_id and ial.inventory_adjustment_line_id = gl.inventory_adjustment_line_id
	left join eclipse.inventory_adjustment as ia on ia.eclipse_id = gl.eclipse_id
where gl_branch = (select * from dbo.dsg_audit_branch) and gl_account = 15 and ia.adjustment_date between dateadd(dd,1,eomonth(dateadd(mm,-2,getdate()))) and eomonth(dateadd(mm,-1,getdate()))

create index idx_product_branch_id on dbo.dsg_inventory_audit_inventory_adjustment (product_branch_id)

', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [dsg_inventory_audit_purchase_order]    Script Date: 4/25/2023 10:36:24 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'dsg_inventory_audit_purchase_order', 
		@step_id=6, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.dsg_inventory_audit_purchase_order
create table dbo.dsg_inventory_audit_purchase_order (
	purchase_order_line_generation_id nvarchar(255) primary key not null, 
	product_branch_id nvarchar(255), 
	receive_date date,
	receive_branch varchar(255),
	purchase_order_id nvarchar(255),
	line_id int,
	product_id int,
	qty int,
	return_flag int,
	review_flag int,
	credit_rebill_flag int,
	is_manual_cogs_override int, 
	gl_amount decimal(18,3)
	)

insert into dbo.dsg_inventory_audit_purchase_order

select 
	polg.purchase_order_line_generation_id,
	concat(product_id,''*'',receive_branch) as product_branch_id, 
	pog.receive_date,
	pog.receive_branch,
	concat(pog.eclipse_id,''.'',format(pog.invoice_number,''000'')) as purchase_order_id,
	polg.line_id,
	polg.product_id,
	polg.receive_qty as qty, 
	case when polg.receive_qty >= 0 then 0 else 1 end as return_flag,
	case when exists (select product_branch_id from dbo.product_branch_inventory as i where location_type = ''Review'' and left(location_tag_out,1) = ''P'' and location_tag_out = CONCAT(pog.eclipse_id,''.'',polg.line_id) collate SQL_Latin1_General_CP1_CS_AS) then 1 else 0 end as review_flag,
	case when isnull(pog.order_type,''norm'') in (''CRD'',''CRC'',''ORIG'') then 1 else 0 end as credit_rebill_flag,
	polg.is_manual_price_override,
	gl.gl_amount


from eclipse.purchase_order_generation as pog
	 left join eclipse.purchase_order_line_generation as polg on polg.eclipse_id = pog.eclipse_id and pog.generation_id = polg.generation_id 
	 left join eclipse.purchase_order_line_generation_gl_posting as gl on gl.eclipse_id = pog.eclipse_id and gl.purchase_order_line_generation_id = polg.purchase_order_line_generation_id and gl.gl_account = 15
	 left join dbo.dsg_audit_branch as b on b.audit_branch_id = pog.gl_branch
where b.audit_branch_id is not null and status_code = ''R'' and gl.gl_amount is not null and receive_date between dateadd(dd,1,eomonth(dateadd(mm,-2,getdate()))) and eomonth(dateadd(mm,-1,getdate()))

create index idx_product_branch_id on dbo.dsg_inventory_audit_purchase_order (product_branch_id)
 


', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [dsg_inventory_audit_transfer_order]    Script Date: 4/25/2023 10:36:24 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'dsg_inventory_audit_transfer_order', 
		@step_id=7, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.dsg_inventory_audit_transfer_order
create table dbo.dsg_inventory_audit_transfer_order (
	transfer_order_line_generation_id nvarchar(255) primary key not null, 
	product_branch_id nvarchar(255), 
	ship_date date,
	branch_id varchar(255),
	transfer_order_id nvarchar(255),
	line_id int,
	product_id int,
	is_manual_cogs_override int, 
	qty int,
	gl_amount decimal(18,3)
	)

insert into dbo.dsg_inventory_audit_transfer_order

select  *
from ( 
	select 
		tolg.transfer_order_line_generation_id,
		concat(product_id,''*'',isnull(receive_branch,ship_branch)) as product_branch_id, 
		isnull(tog.receive_date,tog.ship_date) as ship_date, 
		isnull(tog.receive_branch,tog.ship_branch) as branch_id,
		concat(tog.eclipse_id,''.'',format(tog.invoice_number,''000'')) as transfer_order_id,
		tolg.line_id,
		tolg.product_id,
		tolg.is_manual_cogs_override,
		
		case when ship_branch is not null then -1 *	isnull(tolg.receive_qty,tolg.ship_qty) else isnull(tolg.receive_qty,tolg.ship_qty) end as qty,

		case when ship_branch is not null then -1 * (select gl_amount from eclipse.transfer_order_line_generation_gl_posting as gl where gl.eclipse_id = tog.eclipse_id and tolg.line_id = gl.line_id and gl.gl_branch = tog.ship_branch and gl.gl_account = 15 and gl.generation_id = tolg.generation_id)
			 when ship_branch is null then (select gl_amount from eclipse.transfer_order_line_generation_gl_posting as gl where gl.eclipse_id = tog.eclipse_id and tolg.line_id = gl.line_id and gl_amount is not null and gl.gl_account = 15 and generation_id = 1)  
			 else 0 
			 end as gl_amount

	from eclipse.transfer_order_generation as tog
		 left join eclipse.transfer_order_line_generation as tolg on tolg.eclipse_id = tog.eclipse_id and tog.generation_id = tolg.generation_id 

	where status_code in (''R'',''S'') and tog.gl_branch = (select * from dbo.dsg_audit_branch) and isnull(tog.receive_date,tog.ship_date) between dateadd(dd,1,eomonth(dateadd(mm,-2,getdate()))) and eomonth(dateadd(mm,-1,getdate()))
) as sub
where gl_amount is not null  
 
 
create index idx_product_branch_id on dbo.dsg_inventory_audit_transfer_order (product_branch_id)
 


', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [dsg_inventory_audit_sales_order]    Script Date: 4/25/2023 10:36:24 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'dsg_inventory_audit_sales_order', 
		@step_id=8, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
drop table dbo.dsg_inventory_audit_sales_order
create table dbo.dsg_inventory_audit_sales_order (
	sales_order_line_generation_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS primary key not null,
	product_branch_id nvarchar(255), 
	ship_date date,
	price_date date,
	price_time time,
	ship_branch varchar(255),
	sales_order_id nvarchar(255),
	line_id int,
	product_id int,
	qty int, 
	return_flag int,
	credit_rebill_flag int,
	is_manual_cogs_override int,
	gl_amount decimal(18,3),
	cogs_matrix_override_flag int,
	cost_override_code nvarchar(255)
	)

insert into dbo.dsg_inventory_audit_sales_order

select 
	solg.sales_order_line_generation_id,
	concat(product_id,''*'',ship_branch) as product_branch_id, 
	sog.ship_date,
	sog.gl_user_date as price_date,
	sog.gl_user_time as price_time,
	sog.ship_branch,
	concat(sog.eclipse_id,''.'',format(sog.invoice_number,''000'')) as sales_order_id,
	solg.line_id,
	solg.product_id,
	solg.ship_qty as qty,
	case when solg.ship_qty >= 0 then 0 else 1 end as return_flag,
	case when isnull(sog.order_type,''norm'') in (''CRD'',''CRC'',''ORIG'',''CRSG'') then 1 else 0 end as credit_rebill_flag,
	solg.is_manual_cogs_override,
	gl.gl_amount,
	case when cogs_basis is not null then 1 
		 when cogs_class is not null then 1 
		 when cogs_formula is not null then 1 
		 when cogs_multiplier is not null then 1 
		 else 0 end as cogs_matrix_override_flag,
	cost_override_code
	

from eclipse.sales_order_generation as sog
	 left join eclipse.sales_order_line_generation as solg on solg.eclipse_id = sog.eclipse_id and sog.generation_id = solg.generation_id 
	 left join eclipse.sales_order_line_generation_gl_posting as gl on gl.eclipse_id = sog.eclipse_id and gl.sales_order_line_generation_id = solg.sales_order_line_generation_id and gl.gl_account = 15
	 left join dbo.dsg_audit_branch as b on b.audit_branch_id = sog.ship_branch
	 --left join (
		--		select 
		--			max(sales_order_log_comment_id) as sales_order_log_comment_id,
		--			sales_order_id,
		--			generation_id,
		--			max(date) as date,
		--			max(time) as time
		--		from dbo.so_process_date
		--		group by sales_order_id, generation_id
		--		) as p on p.sales_order_id = sog.eclipse_id and p.generation_id = sog.generation_id
where b.audit_branch_id is not null and status_code = ''I'' and direct_generation_xref is null and gl.gl_amount is not null  and sog.ship_date  between dateadd(dd,1,eomonth(dateadd(mm,-2,getdate()))) and eomonth(dateadd(mm,-1,getdate()))


create index idx_product_branch_id on dbo.dsg_inventory_audit_sales_order(product_branch_id)
create index idx_sales_order_id on dbo.dsg_inventory_audit_sales_order(sales_order_id)




', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [dsg_inventory_audit]    Script Date: 4/25/2023 10:36:24 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'dsg_inventory_audit', 
		@step_id=9, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.dsg_inventory_audit 
create table dbo.dsg_inventory_audit (

	[type] nvarchar(255),
	order_invoice_id nvarchar(255) primary key not null,
	product_branch_id nvarchar(255) collate SQL_Latin1_General_CP1_CI_AS,
	ship_date date,
	price_date date, 
	price_time time,
	ship_branch varchar(255),
	order_id nvarchar(255),
	line_id int,
	product_id int, 
	qty int,
	return_flag int,
	review_flag int,
	credit_rebill_flag int,
	manual_override_flag int,
	kits nvarchar(255),
	rebate_type nvarchar(255),
	gl_amount decimal(18,3),
	cogs_matrix_override_flag int,
	cost_override_code nvarchar(255),
	in_out nvarchar(255),
	so_returns nvarchar(255),
	po_review_status nvarchar(255),
	
	
	)

insert into dbo.dsg_inventory_audit 


select   *

from (

		select 
			sub.*,
			case when gl_amount > 0 then ''In'' else ''Out'' end as in_out,
			case when return_flag = ''1'' and type = ''Sales Order'' then ''SO Returns'' else '''' end as so_returns,
			case when review_flag = ''1'' then ''Review'' else '''' end as po_review_status
			--f.kit_flag as kits,

			--r.rebate_type
			--case when exists (select eclipse_id from eclipse.sales_order_line_kit as k where k.eclipse_id = order_id collate SQL_Latin1_General_CP1_CI_AS) then ''Kit'' else '''' end as kits,

			--case when exists (select sales_order_line_generation_id from dbo.spa_po as p where sub.order_invoice_id = p.sales_order_line_generation_id) then ''SPA''
			--	 when exists (select rebate_purchase_order_id from dbo.spa_po as p where left(sub.order_invoice_id,10) = p.rebate_purchase_order_id) then ''SPA''
			--	 when exists (select sales_order_line_generation_id from dbo.rebates as r where r.sales_order_line_generation_id = sub.order_invoice_id) then ''SPJ''
			--	 when exists (select rebate_purchase_order_id from dbo.rebates as r where LEFT(rebate_purchase_order_id,10) = left(sub.order_invoice_id,10)) then ''SPJ''
			--	 end as rebate_type
			--case when exists ( 
			--				select 
			--					sales_order_line_generation_id
			--				from dbo.cogs_validation as c 
			--				where exists (select * from dbo.spj_po as p where p.sales_order_id = left(c.id,10)) and is_manual_cogs_override = 1 and tagged_order is null and c.sales_order_line_generation_id = sub.order_invoice_id collate SQL_Latin1_General_CP1_CI_AS
			--				) then ''SPJ''
			--	 when exists (select eclipse_id from eclipse.vendor_rebate_detail as d where d.sales_order_id = LEFT(order_id,10) collate SQL_Latin1_General_CP1_CI_AS and sub.line_id = d.sales_order_line_id) then ''SPA''
			--		else '''' end as rebate
		
		from (
			select 
				''Sales Order'' as type,
				case when k.eclipse_id is not null then concat(sales_order_line_kit_id,''_'',row_number() over(partition by k.sales_order_line_id order by s.line_id)) collate SQL_Latin1_General_CP1_CS_AS else s.sales_order_line_generation_id end  as order_invoice_id,
				case when k.eclipse_id is not null then concat(cast(component_product_id as int),''*'',ship_branch)   else product_branch_id end as product_branch_id,
				ship_date,
				price_date,
				price_time,
				ship_branch,
				s.sales_order_id as order_id,
				s.line_id,
				case when k.eclipse_id is not null then component_product_id else product_id end as product_id,
				case when k.eclipse_id is not null then (k.component_qty * -1)*qty else qty * -1 end as qty, 
				return_flag,
				''0'' as review_flag,
				credit_rebill_flag,
				is_manual_cogs_override,
				case when k.eclipse_id is not null then 1 else 0 end as kits, 
				isnull(r.rebate_type,spa.rebate_type) as rebate_type, 
				--r.rebate_type,
				case when k.eclipse_id is not null then 
						case when row_number() over(partition by s.sales_order_line_generation_id order by product_id) = 1 then gl_amount else null end 
					 else gl_amount
					 end as gl_amount,
				cogs_matrix_override_flag,
				cost_override_code


			from dbo.dsg_inventory_audit_sales_order as s 
				left join eclipse.sales_order_line_kit as k on k.eclipse_id = left(s.sales_order_id,10) collate SQL_Latin1_General_CP1_CS_AS and left(s.sales_order_line_generation_id,14) =  k.sales_order_line_id collate SQL_Latin1_General_CP1_CS_AS
				left join dbo.spa_po as spa on spa.sales_order_line_generation_id = s.sales_order_line_generation_id collate SQL_Latin1_General_CP1_CS_AS and spa.rebate_part_number = case when k.eclipse_id is not null then component_product_id else product_id end
				left join dbo.rebates as r on r.sales_order_line_generation_id = s.sales_order_line_generation_id collate SQL_Latin1_General_CP1_CS_AS and r.rebate_type = ''SPJ'' 

			union

			select 
				''Transfer Order'' as type,
				transfer_order_line_generation_id,
				product_branch_id,
				ship_date,
				null as price_date,
				cast(''23:00:00'' as time) as price_time, 
				branch_id,
				transfer_order_id,
				line_id,
				product_id,
				case when gl_amount > 0 then qty * -1 else qty end as qty,
				''0'' as return_flag,
				''0'' as review_flag,
				''0'' as c_r_flag,
				is_manual_cogs_override as override_flag,
				''0'' as kits,
				NULL as rebate_type,
				gl_amount,
				''0'' as cogs_matrix_override_flag,
				''0'' as cost_override_code
			from dbo.dsg_inventory_audit_transfer_order
			where ship_date <= EOMONTH(dateadd(mm,-1,GETDATE()))  and gl_amount is not null 

			union

			select 
				''Purchase Order'' as type,
				purchase_order_line_generation_id,
				product_branch_id,
				receive_date,
				null as price_date,
				cast(''23:00:00'' as time) as price_time,
				receive_branch,
				purchase_order_id,
				line_id,
				product_id,
				qty,
				return_flag,
				review_flag,
				credit_rebill_flag,
				is_manual_cogs_override,
				''0'' as kits,
				NULL as rebate_type,
				gl_amount,
				''0'' as cogs_matrix_override_flag,
				''0'' as cost_override_code
				
			from dbo.dsg_inventory_audit_purchase_order
			where receive_date <= EOMONTH(dateadd(mm,-1,GETDATE()))  


			union

			select 
				''Inventory Adjustment'' as type,
				purchase_order_line_generation_id,
				product_branch_id,
				receive_date,
				null as price_date,
				cast(''23:00:00'' as time) as price_time,
				receive_branch,
				purchase_order_id,
				line_id,
				product_id,
				qty,
				return_flag,
				review_flag,
				''0'' as c_r_flag,
				override_flag,
				''0'' as kits,
				NULL as rebate_type,
				gl_amount,
				''0'' as cogs_matrix_override_flag,
				''0'' as cost_override_code
			from dbo.dsg_inventory_audit_inventory_adjustment 
			where receive_date <= EOMONTH(dateadd(mm,-1,GETDATE())) 


		) as sub
			--left join (
			--		select
			--			sales_order_line_generation_id, 
			--			max(rebate_type) as rebate_type
			--		from dbo.rebates as r
			--		group by sales_order_line_generation_id
			--		) as r
			--		on r.sales_order_line_generation_id = sub.order_invoice_id
			--left join (
			--		select * 
			--		from (
			--			select *,
			--			case when exists (select eclipse_id from eclipse.product_kit_component as k where k.eclipse_id = pb.product_id) then 1 
			--				 when exists (select component_product_id from eclipse.product_kit_component as k where k.component_product_id = pb.product_id) then 1
			--				 else 0 
			--				 end as kit_flag
			--			--case when exists (select product_branch_id from dbo.product_branch_inventory as i where i.product_branch_id = pb.product_branch_id and location_type = ''Review'' and left(location_tag_out,1) = ''P'') then 1 
			--			--	 else 0
			--			--	 end as review_flag
			--			from dbo.product_branch as pb
			--			where branch_id = (select audit_branch_id from audit_branch) collate SQL_Latin1_General_CP1_CI_AS
			--		) as sub 
			--	) as f on f.product_branch_id = sub.product_branch_id collate SQL_Latin1_General_CP1_CI_AS 
) as sub
 
create index idx_order_id on dbo.dsg_inventory_audit (order_id)
create index idx_ship_date on dbo.dsg_inventory_audit (ship_date)
create index idx_product_branch_id on dbo.dsg_inventory_audit (product_branch_id)
create index idx_ship_branch on dbo.dsg_inventory_audit (ship_branch) 
create index idx_product_id on dbo.dsg_inventory_audit(product_id)', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [dsg_audit_rep_cost]    Script Date: 4/25/2023 10:36:24 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'dsg_audit_rep_cost', 
		@step_id=10, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.dsg_audit_rep_cost 
create table dbo.dsg_audit_rep_cost (
	id nvarchar(255), 
	price_date date,
	price_time time,
	ship_branch varchar(255) collate SQL_Latin1_General_CP1_CS_AS,
	product_id int,
	product_branch_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS,
	eclipse_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS
	)
insert into dbo.dsg_audit_rep_cost

	select distinct  
		concat(isnull(price_date,ship_date),''_'',product_branch_id) as id,
		isnull(price_date,ship_date) as price_date,
		price_time,
		ship_branch,
		product_id,
		product_branch_id,
		concat(product_id,''~'') as eclipse_id
	from dbo.dsg_inventory_audit 
	 
create index idx_id on dbo.dsg_audit_rep_cost (id)
create index idx_price_date on dbo.dsg_audit_rep_cost (price_date)
create index idx_price_time on dbo.dsg_audit_rep_cost (price_time)
create index idx_product_branch_id on dbo.dsg_audit_rep_cost (product_branch_id) 
create index idx_eclipse_id on dbo.dsg_audit_rep_cost (eclipse_id) 
--create index idx_product_id on dbo.dsg_audit_rep_cost (product_id)
--create index idx_ship_branch on dbo.dsg_audit_rep_cost (ship_branch) 
', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [dsg_audit_rep_cost_territory]    Script Date: 4/25/2023 10:36:24 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'dsg_audit_rep_cost_territory', 
		@step_id=11, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.dsg_audit_rep_cost_territory
create table dbo.dsg_audit_rep_cost_territory (
	id nvarchar(255) NOT NULL PRIMARY KEY,
	price_date date,
	product_branch_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS,
	branch_id varchar(255) collate SQL_Latin1_General_CP1_CS_AS,
	product_id int,
	replacement_cost decimal(18,4)
	)
insert into dbo.dsg_audit_rep_cost_territory

select 
		id,
		price_date,
		product_branch_id,
		branch_id,
		product_id,
	 
				/* 2. Territory Price Sheet ID */
				(
				select
					basis6_amount
				from (
						select 
						ROW_NUMBER() over(partition by p.product_id, b.branch_id  order by effective_date desc) as id,
						p.*
						from eclipse.product_price as p
							left join eclipse.branch_matrix_hierarchy_branch_list as b on b.matrix_hierarchy_branch_id = p.price_sheet_id
						where p.price_sheet_id is not null and p.basis6_amount is not null and p.eclipse_id = concat(sub.eclipse_id,matrix_hierarchy_branch_id) and b.branch_id = sub.branch_id /*collate SQL_Latin1_General_CP1_CI_AS*/ and p.effective_date <= sub.price_date
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
						left join eclipse.branch_matrix_hierarchy_branch_list as b on b.matrix_hierarchy_branch_id = p.price_sheet_id
					where p.price_sheet_id is not null and p.per_qty is not null and p.eclipse_id = concat(sub.eclipse_id,matrix_hierarchy_branch_id) and b.branch_id = sub.branch_id and p.effective_date <= sub.price_date
					) as sub 
				where sub.id = 1 
				)
			as rep_cost
from (
	select 
		id,
		max(price_date) as price_date,
		max(product_branch_id) as product_branch_id,
		max(ship_branch) as branch_id,
		max(product_id) as product_id,
		max(eclipse_id) as eclipse_id
	from dbo.dsg_audit_rep_cost
	group by id
) as sub


 
create index idx_price_date on dbo.dsg_audit_rep_cost_territory(price_date)
create index idx_product_branch_id on dbo.dsg_audit_rep_cost_territory(product_branch_id) 
create index idx_product_id on dbo.dsg_audit_rep_cost_territory(product_id) 
create index idx_branch_id on dbo.dsg_audit_rep_cost_territory(branch_id) 


', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [dsg_audit_rep_cost_tilde]    Script Date: 4/25/2023 10:36:24 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'dsg_audit_rep_cost_tilde', 
		@step_id=12, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.dsg_audit_rep_cost_tilde
create table dbo.dsg_audit_rep_cost_tilde (
	id nvarchar(255) NOT NULL PRIMARY KEY,
	price_date date,
	product_branch_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS,
	branch_id varchar(255) collate SQL_Latin1_General_CP1_CS_AS,
	product_id int,  
	replacement_cost decimal(18,4)
	)
insert into dbo.dsg_audit_rep_cost_tilde 

select 
		id,
		price_date,
		product_branch_id,
		branch_id,
		product_id,
				/* Default Tilde Sheet */ 
				(
				select
					basis6_amount
				from (
						select 
						ROW_NUMBER() over(partition by product_id, price_sheet_id order by effective_date desc) as id,
						*
						from eclipse.product_price as p
						where p.price_sheet_id is null and p.basis6_amount is not null and p.eclipse_id = sub.eclipse_id and p.effective_date <= sub.price_date
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
					where p.price_sheet_id is null and p.per_qty is not null and p.eclipse_id = sub.eclipse_id  and p.effective_date <= sub.price_date
					) as sub 
				where sub.id = 1 
				)
	 as ''rep_cost''
from (
	select 
		id,
		max(price_date) as price_date,
		max(product_branch_id) as product_branch_id,
		max(ship_branch) as branch_id,
		max(product_id) as product_id,
		max(eclipse_id) as eclipse_id
	from dbo.dsg_audit_rep_cost
	group by id
) as sub


create index idx_price_date on dbo.dsg_audit_rep_cost_tilde(price_date)
create index idx_product_branch_id on dbo.dsg_audit_rep_cost_tilde(product_branch_id) 
create index idx_product_id on dbo.dsg_audit_rep_cost_tilde(product_id)', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [dsg_audit_rep_cost_branch]    Script Date: 4/25/2023 10:36:24 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'dsg_audit_rep_cost_branch', 
		@step_id=13, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.dsg_audit_rep_cost_branch
create table dbo.dsg_audit_rep_cost_branch (
	id nvarchar(255) NOT NULL PRIMARY KEY,
	price_date date,
	product_branch_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS,
	branch_id varchar(255) collate SQL_Latin1_General_CP1_CS_AS,
	replacement_cost decimal(18,4)
	)
insert into dbo.dsg_audit_rep_cost_branch

select 
		id,
		price_date,
		product_branch_id,
		branch_id,
				/* 1. Branch Price Sheet ID */
				(
				select
					basis6_amount
				from (
						select 
						ROW_NUMBER() over(partition by product_id, price_sheet_id order by effective_date desc) as id,
						*
						from eclipse.product_price as p
						where p.basis6_amount is not null and p.eclipse_id = sub.eclipse_id /*concat(sub.eclipse_id,branch_id) collate SQL_Latin1_General_CP1_CI_AS */ and p.effective_date <= sub.price_date
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
					where  p.basis6_amount is not null and p.eclipse_id = sub.eclipse_id /*concat(sub.eclipse_id,branch_id)   collate SQL_Latin1_General_CP1_CI_AS */ and p.effective_date <= sub.price_date
					) as sub 
				where sub.id = 1 
				) as rep_cost
from (
	select 
		id,
		max(price_date) as price_date,
		max(product_branch_id) as product_branch_id,
		max(ship_branch) as branch_id,
		max(product_id) as product_id,
		max(eclipse_id) as eclipse_id
	from dbo.dsg_audit_rep_cost
	group by id
) as sub

create index idx_price_date on dbo.dsg_audit_rep_cost_branch(price_date)
create index idx_product_branch_id on dbo.dsg_audit_rep_cost_branch(product_branch_id)', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [dsg_audit_rep_cost_snet]    Script Date: 4/25/2023 10:36:24 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'dsg_audit_rep_cost_snet', 
		@step_id=14, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.dsg_audit_rep_cost_snet
create table dbo.dsg_audit_rep_cost_snet (
	id nvarchar(255) NOT NULL PRIMARY KEY,
	price_date date,
	product_branch_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS,
	branch_id varchar(255) collate SQL_Latin1_General_CP1_CS_AS,
	product_id int,
	replacement_cost decimal(18,4)
	)
insert into dbo.dsg_audit_rep_cost_snet

select 
		id,
		price_date,
		product_branch_id,
		branch_id,
		product_id,

				/* SNET Sheet for all branches */ 
				(
				select
					basis6_amount
				from (
						select 
						ROW_NUMBER() over(partition by product_id, price_sheet_id order by effective_date desc) as id,
						*
						from eclipse.product_price as p
						where p.basis6_amount is not null and p.eclipse_id = sub.eclipse_id and p.effective_date <= sub.price_date
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
					where p.per_qty is not null and p.eclipse_id = sub.eclipse_id and p.effective_date <= sub.price_date
					) as sub 
				where sub.id = 1 
				)
	 as ''rep_cost''
from (
	select 
		id,
		max(price_date) as price_date,
		max(product_branch_id) as product_branch_id,
		max(ship_branch) as branch_id,
		max(product_id) as product_id,
		max(concat(eclipse_id,''SNET'')) as eclipse_id
	from dbo.dsg_audit_rep_cost
	group by id
) as sub

create index idx_price_date on dbo.dsg_audit_rep_cost_snet(price_date)
create index idx_product_branch_id on dbo.dsg_audit_rep_cost_snet(product_branch_id) 

', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [dsg_inventory_audit_br_cost]    Script Date: 4/25/2023 10:36:24 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'dsg_inventory_audit_br_cost', 
		@step_id=15, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.dsg_inventory_audit_br_cost
create table dbo.dsg_inventory_audit_br_cost (
	eclipse_id nvarchar(255) primary key not null,
	log_counter int,
	product_branch_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS, 
	[user_id] nvarchar(10),
	[date] date,
	[time] time,
	comment_type nvarchar(255),
	comment nvarchar(255)
	)
insert into dbo.dsg_inventory_audit_br_cost

select    
	eclipse_id,
	log_counter,
	concat(product_id,''*'',branch_id) as product_branch_id,
	user_id,
	date,
	time,
	comment_type,
	comment
from eclipse.product_location_activity_log as l
where comment_type = ''BR.COST'' and exists (select audit_branch_id from dbo.dsg_audit_branch as b where b.audit_branch_id = left(eclipse_id,len(b.audit_branch_id)) collate SQL_Latin1_General_CP1_CI_AS) 

create index idx_product_branch_id on dbo.dsg_inventory_audit_br_cost (product_branch_id) 
create index idx_date on dbo.dsg_inventory_audit_br_cost ([date])
create index idx_time on dbo.dsg_inventory_audit_br_cost ([time])
 

', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [dsg_inventory_audit_branch_cost]    Script Date: 4/25/2023 10:36:24 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'dsg_inventory_audit_branch_cost', 
		@step_id=16, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.dsg_inventory_audit_branch_cost
create table dbo.dsg_inventory_audit_branch_cost (
	id nvarchar(255) primary key not null, 
	price_date date,
	ship_branch varchar(255) collate SQL_Latin1_General_CP1_CS_AS,
	product_id int,
	product_branch_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS,
	eclipse_id nvarchar(255) collate SQL_Latin1_General_CP1_CS_AS,
	avg_cost decimal(18,3)
	)

insert into dbo.dsg_inventory_audit_branch_cost

	select 
		concat(sub.id,''_'',sub.price_time) as id,
		sub.price_date,
		sub.ship_branch,
		sub.product_id,
		sub.product_branch_id,
		sub.eclipse_id,
		sub.avg_cost / isnull(sub.qty,pbc.branch_cost_per_qty) as avg_cost
	from (
		select *,
				(
					select avg_cost
					from (
					select 
					row_number() over(partition by product_branch_id order by log_counter desc) as id, 
					[avg] as avg_cost
					from (
					select 
						*,
						cast(substring(substring(comment,charindex(''Now :'',comment)+5,99),1,charindex('' - UM'',substring(comment,charindex(''Now :'',comment)+5,99))) as decimal(18,3)) as [avg]
					from dbo.dsg_inventory_audit_br_cost as i
					where i.comment like ''%Avg Cost%'' and i.product_branch_id = r.product_branch_id and (i.[date] < r.price_date or (i.[date] = r.price_date and i.[time] <= r.price_time))
					) as sub
					) as sub 
					where id = 1 			
				) as avg_cost,   
		
				(
					select qty
					from (
					select 
					row_number() over(partition by product_branch_id order by log_counter asc) as id, 
					 qty  
					from (
					select 
						*,
						cast(reverse(substring(reverse(comment),1,charindex('' : ytQ'',reverse(comment)))) as int) as qty
					from dbo.dsg_inventory_audit_br_cost as i
					where i.comment like ''%Avg Cost%''  and i.product_branch_id = r.product_branch_id and i.[date] > r.price_date
					) as sub
					) as sub 
					where id = 1 			
				) as qty
		from dbo.dsg_audit_rep_cost as r
	) as sub
			left join dbo.product_branch_calculation as pbc on pbc.product_branch_id = sub.product_branch_id

create index idx_price_date on dbo.dsg_inventory_audit_branch_cost (price_date)
create index idx_ship_branch on dbo.dsg_inventory_audit_branch_cost (ship_branch)
create index idx_product_id on dbo.dsg_inventory_audit_branch_cost (product_id)
create index idx_product_branch_id on dbo.dsg_inventory_audit_branch_cost (product_branch_id)



', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [dsg_inventory_audit_spa]    Script Date: 4/25/2023 10:36:24 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'dsg_inventory_audit_spa', 
		@step_id=17, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.dsg_inventory_audit_spa
create table dbo.dsg_inventory_audit_spa (
	eclipse_id nvarchar(255) primary key not null,
	ship_date date,
	ship_branch varchar(255), 
	purchase_order_id nvarchar(255) ,
	sales_order_id nvarchar(255) ,
	line_id int,
	invoice_number int,
	product_branch_id nvarchar(255), 
	product_id int,
	po_qty int,
	cost decimal(18,3),
	rebate_cost decimal(18,3),
	rebate_amount decimal(18,3), 
	--isnull(sum(rebate_amount),sum(vendor_proposed_rebate_amount)) as rebate_amount,
	vendor_cost decimal(18,3),
	vendor_rebate_cost decimal(18,3),
	vendor_proposed_rebate_amount decimal(18,3),
	accepted_flag int,
	so_claim_count int,
	po_claim_count int,
	dts_flag int,
	avg_cost decimal(18,3)
--	qty int
	)

insert into dbo.dsg_inventory_audit_spa
 
select 
	
	eclipse_id,
	ship_date,
	ship_branch,
	purchase_order_id,
	sales_order_id,
	sales_order_line_id,
	sales_order_invoice_number,
	product_branch_id, 
	product_id,
	po_qty,
	cost,
	rebate_cost,
	rebate_amount, 
	--isnull(sum(rebate_amount),sum(vendor_proposed_rebate_amount)) as rebate_amount,
	vendor_cost,
	vendor_rebate_cost,
	vendor_proposed_rebate_amount,
	accepted_flag as accepted_flag,
	so_claim_count,
	po_claim_count,
	dts_flag,
	avg_cost --/ isnull(qty,(select branch_cost_per_qty from dbo.product_branch_calculation as pbc where pbc.product_branch_id = sub.product_branch_id)) as avg_cost
	--isnull(qty,(select branch_cost_per_qty from dbo.product_branch_calculation as pbc where pbc.product_branch_id = sub.product_branch_id)) as qty,

from (
	select  
		*,	
		(	
		select 
			avg_cost
		from (
			select 
				*,
				row_number() over(partition by product_branch_id order by price_date asc) as pid
			from dbo.dsg_inventory_audit_branch_cost as c 
			where c.product_branch_id = sub.product_branch_id and sub.ship_date <= c.price_date
		) as sub
		where sub.pid = 1 
		) as avg_cost

	from (	
			select 	 
				min(eclipse_id) as eclipse_id,
				ship_branch,
				ship_date,
				purchase_order_id,
				sales_order_id,
				sales_order_line_id,
				sales_order_invoice_number,
				concat(product_id,''*'',ship_branch) as product_branch_id, 
				product_id,
				sum(po_qty) as po_qty,
				isnull(max(cost),max(vendor_cost)) as cost,
					max(rebate_cost) as rebate_cost,
				sum(rebate_amount) as rebate_amount, 
				max(vendor_cost) as vendor_cost,
				max(vendor_rebate_cost) as vendor_rebate_cost,
				sum(vendor_proposed_rebate_amount) as vendor_proposed_rebate_amount,
				accepted_flag as accepted_flag,
				count(*) over(partition by sales_order_id, sales_order_line_id, sales_order_invoice_number) as so_claim_count,
				row_number() over(partition by product_id, sales_order_id, sales_order_line_id, sales_order_invoice_number order by purchase_order_id ) as po_claim_count,
				case when exists (select eclipse_id from eclipse.sales_order_generation as sog where sog.eclipse_id = r.sales_order_id and sog.sales_source = ''DTS'') then 1 else 0 end as dts_flag
			from eclipse.vendor_rebate_detail as r 
					left join dbo.dsg_audit_branch as b on b.audit_branch_id = r.ship_branch
			where b.audit_branch_id is not null and ship_date between dateadd(dd,1,eomonth(dateadd(mm,-2,getdate()))) and eomonth(dateadd(mm,-1,getdate()))
			group by purchase_order_id, sales_order_id, sales_order_line_id, sales_order_invoice_number, product_id, accepted_flag, ship_date, ship_branch 
	) as sub
) as sub


create index idx_product_branch_id on dbo.dsg_inventory_audit_spa (product_branch_id)
create index idx_sales_order_id on dbo.dsg_inventory_audit_spa (sales_order_id) 
create index idx_ship_branch on dbo.dsg_inventory_audit_spa (ship_branch) 


', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [dsg_inventory_audit_avg_cost]    Script Date: 4/25/2023 10:36:25 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'dsg_inventory_audit_avg_cost', 
		@step_id=18, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.dsg_inventory_audit_avg_cost
create table dbo.dsg_inventory_audit_avg_cost (

	[type] nvarchar(255),
	order_invoice_id nvarchar(255) primary key not null,
	product_branch_id nvarchar(255),
	ship_date date,
	price_date date,
	ship_branch varchar(255),
	order_id nvarchar(255),
	line_id int,
	product_id int, 
	qty int,
	return_flag int,
	review_flag int,
	credit_rebill_flag int,
	manual_override_flag int,
	merge_product_flag int,
	in_out nvarchar(255),
	so_returns nvarchar(255),
	po_review_status nvarchar(255),
	kits nvarchar(255),
	rebate_type nvarchar(255),
	procurement nvarchar(255),
	dts_flag int, 
	cogs_matrix_override_flag int,
	cost_override_code nvarchar(255),
	gl_amount decimal(18,3),
	avg_cost decimal(18,3),
	rep_cost decimal(18,3),
	ext_avg_cost decimal(18,3),
	ext_rep_cost decimal(18,3)
	--avg_vs_gl decimal(18,3)
	--rebate_difference decimal(18,3)
	)

insert into dbo.dsg_inventory_audit_avg_cost

select 
	[type],
	order_invoice_id,
	product_branch_id,
	ship_date,
	price_date,
	ship_branch,
	order_id,
	line_id,
	product_id,
	qty,
	return_flag,
	review_flag,
	credit_rebill_flag,
	manual_override_flag,
	case when exists (select merge_product_id from eclipse.product as p where p.merge_product_id = sub.product_id) then 1 else 0 end as merge_product_flag,
	in_out,
	so_returns,
	po_review_status,
	kits,
	rebate_type as rebate_type, 
	procurement,
	case when exists (select eclipse_id from eclipse.sales_order_generation as sog where sog.eclipse_id = left(order_id,10) collate SQL_Latin1_General_CP1_CI_AS and sog.sales_source = ''DTS'') then 1 else 0 end as dts_flag,
	cogs_matrix_override_flag,
	cost_override_code,
	gl_amount,
	avg_cost, 
	replacement_cost, 
	ext_avg_cost,
	ext_rep_cost

--	case when [type] in (''Purchase Order'',''Transfer Order'') and in_out = ''In'' then 0 else ext_avg_cost - gl_amount end  as avg_vs_gl
--	case when replace(rebate_type,'''',NULL) is not null then (ext_rep_cost - gl_amount) - (ext_avg_cost - gl_amount) else 0 end as rebate_difference
from (
	
	select 
		i.*,
		(select top 1 location_tag from eclipse.sales_order_line_generation_location as l where l.location_type = ''T'' and left(order_invoice_id,10) = l.eclipse_id collate SQL_Latin1_General_CP1_CS_AS and left(order_invoice_id,16) = sales_order_line_generation_id collate SQL_Latin1_General_CP1_CS_AS) as procurement,
		case when replacement_cost = 0 then avg_cost else isnull(avg_cost,replacement_cost) end as avg_cost,
		replacement_cost,
		case when qty is null then gl_amount else abs(qty) * isnull(avg_cost,replacement_cost) end as ext_avg_cost,
		case when qty is null then gl_amount else abs(qty) * replacement_cost end as ext_rep_cost	
	 from dbo.dsg_inventory_audit as i 
		left join (
					select 
						sub.*,
						isnull(isnull(isnull(b.replacement_cost,ter.replacement_cost),s.replacement_cost),til.replacement_cost) as replacement_cost	
					from dbo.dsg_inventory_audit_branch_cost as sub 
						left join dbo.dsg_audit_rep_cost_territory as ter on ter.id = reverse(substring(reverse(sub.id),charindex(''_'',reverse(sub.id))+1,99)) and ter.replacement_cost is not null 
						left join dbo.dsg_audit_rep_cost_tilde as til on til.id = reverse(substring(reverse(sub.id),charindex(''_'',reverse(sub.id))+1,99)) and til.replacement_cost is not null 
						left join dbo.dsg_audit_rep_cost_branch as b on b.id = reverse(substring(reverse(sub.id),charindex(''_'',reverse(sub.id))+1,99)) and b.replacement_cost is not null 
						left join dbo.dsg_audit_rep_cost_snet as s on s.id = reverse(substring(reverse(sub.id),charindex(''_'',reverse(sub.id))+1,99)) and s.replacement_cost is not null 
				) as a on a.id = concat(isnull(i.price_date,i.ship_date),''_'',i.product_branch_id,''_'',i.price_time) 
) as sub


', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [dsg_inventory_audit_spa_analysis]    Script Date: 4/25/2023 10:36:25 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'dsg_inventory_audit_spa_analysis', 
		@step_id=19, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'--drop table dbo.dsg_inventory_audit_spa_analyis
--create table dbo.dsg_inventory_audit_spa_analyis (
--	eclipse_id nvarchar(255) primary key not null,
--	type nvarchar(255),
--	ship_date date,
--	ship_branch varchar(255), 
--	purchase_order_id nvarchar(255),
--	journal_id nvarchar(255),
--	sales_order_id nvarchar(255) ,
--	invoice_number int,
--	line_id int,
--	product_id int,
--	po_qty int,
--	rebate_cost decimal(18,3),
--	avg_cost decimal(18,3),
--	rep_cost decimal(18,3),
--	ext_rebate_cost decimal(18,3),
--	ext_avg_cost decimal(18,3),
--	ext_rep_cost decimal(18,3),
--	rebate_amount decimal(18,3),
--	journal_amount decimal(18,3),
--	[G/L] decimal(18,3),
--	perpetual decimal(18,3),
--	inv_vs_gl decimal(18,3),
--	so_claim_count int, 
--	po_claim_count int,
--	rebate_avg_vs_gl decimal(18,3),
--	rebate_rep_vs_gl decimal(18,3),
--	rebate_other decimal(18,3),
--	rest decimal(18,3),
--	rep_vs_avg decimal(18,3),
--	rejected_amount decimal(18,3),
--	gl_amount decimal(18,3),
--	vendor_proposed_rebate_amount decimal(18,3),
--	avg_vs_gl decimal(18,3),
--	procure_flag_variance int 
--	)
insert into dbo.dsg_inventory_audit_spa_analyis

	select  distinct 
		eclipse_id,
		type,
		ship_date,
		ship_branch, 
		purchase_order_id,
		journal_id,
		sales_order_id,
		invoice_number,
		line_id,
		product_id,
		po_qty,
		rebate_cost,
		avg_cost,
		rep_cost,
		rebate_cost * po_qty as ext_rebate_cost,
		ext_avg_cost,
		ext_rep_cost,
		rebate_amount as rebate_amount,
		case when journal_id is not null then  rebate_amount else 0 end as journal_amount,
		((rebate_cost * po_qty) * -1) + case when journal_id is not null then isnull(vendor_proposed_rebate_amount,rebate_amount) else 0 end as [G/L],
		(ext_avg_cost * -1) + case when journal_id is not null then isnull(vendor_proposed_rebate_amount,rebate_amount) else 0 end  as Perpetual,
		(ext_avg_cost * -1) + case when journal_id is not null then isnull(vendor_proposed_rebate_amount,rebate_amount) else 0 end  - (((rebate_cost * po_qty) * -1) + case when journal_id is not null then isnull(vendor_proposed_rebate_amount,rebate_amount) else 0 end) as [Perpetual vs G/L],
		so_claim_count,
		po_claim_count,
		rebate_avg_vs_gl,
		rebate_rep_vs_gl,
		rebate_other,
		rebate_other as rest,
		rep_vs_avg,
		rejected_amount,
		gl_amount,
		vendor_proposed_rebate_amount,
		(avg_cost - rebate_cost) * po_qty as avg_vs_gl,
		procure_flag_variance
	from (

		select 

	 
			case when vendor_proposed_rebate_amount is not null and accepted_flag = 0 then ''SPA Vendor Rejected''
				 when so_claim_count > 1 and journal_id is null and (vendor_proposed_rebate_amount is null or (vendor_proposed_rebate_amount is not null and accepted_flag = 1)) then ''SPA Missing Journal & Duplicate Entry''
				 when journal_id is null and (vendor_proposed_rebate_amount is null or (vendor_proposed_rebate_amount is not null and accepted_flag = 1)) then ''SPA Missing Journal''
				 when so_claim_count > 1 and  (vendor_proposed_rebate_amount is null or (vendor_proposed_rebate_amount is not null and accepted_flag = 1)) then ''SPA SO Duplicate Entry''
				 when so_claim_count = 1 and (vendor_proposed_rebate_amount is null or (vendor_proposed_rebate_amount is not null and accepted_flag = 1)) and journal_id is not null and dts_flag = 1 then ''SPA DTS Rebate Claim''
				 when so_claim_count = 1 and (vendor_proposed_rebate_amount is null or (vendor_proposed_rebate_amount is not null and accepted_flag = 1)) and journal_id is not null then ''SPA Avg vs GL''

			else '''' end as type, 

			*,
		 
			ext_avg_cost - gl_amount ''rebate_avg_vs_gl'',
		
			case when avg_cost = isnull(vendor_cost,cost) then 0
				when avg_cost <> isnull(vendor_cost,cost) and rep_cost < isnull(vendor_cost,cost) then rebate_amount
				when rep_cost = isnull(vendor_cost,cost) then rebate_amount 
				else 0 
				end as ''rebate_rep_vs_gl'',
	
			case when avg_cost = isnull(vendor_cost,cost) then 0
				when rep_cost = isnull(vendor_cost,cost) then 0
				when avg_cost <> isnull(vendor_cost,cost) and rep_cost < isnull(vendor_cost,cost) then 0 
				else rebate_amount
				end as ''rebate_other'',

			case when avg_cost = isnull(vendor_cost,cost) then 0
				when vendor_proposed_rebate_amount is not null and accepted_flag = 0 then 0 
				when so_claim_count > 1 and  (vendor_proposed_rebate_amount is null or (vendor_proposed_rebate_amount is not null and accepted_flag = 1)) then 0 
				when journal_id is null and (vendor_proposed_rebate_amount is null or (vendor_proposed_rebate_amount is not null and accepted_flag = 1)) then 0 
				when rep_cost = isnull(vendor_cost,cost) then cast(((ext_rep_cost - gl_amount) - (ext_avg_cost - gl_amount)) as decimal(18,3))
				else cast(((ext_rep_cost - gl_amount) - (ext_avg_cost - gl_amount) )  as decimal(18,3))
				end as ''rep_vs_avg'',

			case when vendor_proposed_rebate_amount is not null and accepted_flag = 0 then ext_avg_cost - gl_amount
				else 0
				end as ''rejected_amount''
		from (
			select distinct 
			--	solg.sales_order_line_generation_id,
				s.[eclipse_id],
				s.[ship_date],
				s.ship_branch,
				s.[purchase_order_id],
				s.sales_order_id,
				s.line_id,
				s.[invoice_number],
				[product_branch_id],
				s.[product_id],
				[po_qty],
				s.[cost],
				[rebate_cost],
				[rebate_amount],
				[vendor_cost],
				[vendor_rebate_cost],
				[vendor_proposed_rebate_amount],
				[accepted_flag],
				[so_claim_count],
				[po_claim_count],
				isnull(isnull(po_cogs,avg_cost),s.cost) as avg_cost,
				isnull(isnull(po_cogs,avg_cost),s.cost) * po_qty as ext_avg_cost,
				s.cost as rep_cost,
				s.cost * po_qty as ext_rep_cost,
				rebate_cost * po_qty as gl_amount,
				journal_id,
				journal_amount,
				t.location_tag,
				t.po_cogs,
				iif(t.po_cogs > s.cost,1,0) as procure_flag_variance,
				dts_flag
			from dbo.dsg_inventory_audit_spa as s 
					--left join dbo.dsg_audit_branch as b on b.audit_branch_id = s.ship_branch collate SQL_Latin1_General_CP1_CI_AS
				--	left join eclipse.sales_order_generation as sog on sog.eclipse_id = s.sales_order_id collate SQL_Latin1_General_CP1_CI_AS and s.invoice_number = sog.invoice_number
				--	left join eclipse.sales_order_line_generation as solg on solg.eclipse_id = sog.eclipse_id and solg.generation_id = sog.generation_id and solg.line_id = s.line_id
					
					
					/* attempting to remove sales order tables to improve querry time.... did not see duplicates on WIN, PLO */
					left join (
										select 
										--t.sales_order_line_generation_id,
										t.eclipse_id,
										t.line_id,
										 
										max(location_tag) as location_tag, 
										sum(receive_qty) as receive_qty, 
										sum(ext_po_cogs)/sum(receive_qty) as po_cogs,
										sum(receive_qty) * (sum(ext_po_cogs)/sum(receive_qty)) as ext_po_cogs
									from dbo.tagged_orders as t
							 
									where po_status_code = ''R''  
									group by t.eclipse_id,t.line_id --t.sales_order_line_generation_id,
							) as t on t.eclipse_id  = s.sales_order_id and t.line_id = s.line_id
						--) as t on t.sales_order_id = s.sales_order_id and t.line_id = s.line_id and t.invoice_number = s.invoice_number
							--on t.sales_order_line_generation_id = solg.sales_order_line_generation_id collate SQL_Latin1_General_CP1_CS_AS
					left join dbo.dsg_inventory_audit_rebate_journal as j on left(j.id,10) = s.purchase_order_id and j.gl_account = 15 
				where exists (select audit_branch_id from dbo.dsg_audit_branch as b where b.audit_branch_id = s.ship_branch collate SQL_Latin1_General_CP1_CI_AS)
		) as sub
	 ) as sub 


 
 
 
', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [dsg_inventory_audit_BRANCH]    Script Date: 4/25/2023 10:36:25 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'dsg_inventory_audit_BRANCH', 
		@step_id=20, 
		@cmdexec_success_code=0, 
		@on_success_action=4, 
		@on_success_step_id=2, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'insert into dbo.dsg_inventory_audit_branch
select 

	   [category]
      ,[type]
      ,[order_invoice_id]
      ,[product_branch_id]
      ,[ship_date]
      ,[price_date]
      ,[ship_branch]
      ,[order_id] 
      ,[line_id]
      ,[product_id]
      ,[qty]
      ,[return_flag]
      ,[review_flag]
      ,[credit_rebill_flag]
      ,[manual_override_flag]
      ,[merge_product_flag]
      ,[in_out]
      ,[so_returns]
      ,[po_review_status]
      ,[kits]
      ,[rebate_type]
      ,[procurement]
      ,[dts_flag]
      ,[gl_amount]
      ,[avg_cost]
      ,[rep_cost]
      ,[ext_avg_cost]
      ,[ext_rep_cost]
      ,[avg_vs_gl]
      ,[location_tag]
	  ,[ext_po_cogs]
      ,[avg_cost_adj_flag]
      ,[header_comment]
      ,[rebate_category]
      ,[purchase_order_id]
      ,[journal_id]
      ,[journal_amount]
      ,[zero_dollar_adj_flag]
      ,[total_variance]
	
from (
		select 
			case when product_id = 2961 and (type <> ''Purchase Order'' or (type = ''Transfer Order'' and in_out = ''In'' and location_tag is not null)) then ''UoM Variance''
				 when rebate_type = ''SPA'' then isnull(replace(rebate_category,''Rep vs Avg Cost'',''SPA Avg vs GL''),''SPA Missing Journal'')
				 when rebate_type = ''SPJ'' then ''SPJ Avg vs GL''
				 when type = ''Sales Order'' and return_flag = 1 and location_tag is not null and ((gl_amount*-1) - (po_cogs * ship_qty)) <> 0 then ''Sales Return to Vendor Variance'' 
				 when type = ''Sales Order'' and return_flag = 1 and dts_flag = 0 and avg_cost <> 0 and credit_rebill_flag = 0 then 
				    case  when location_tag is not null then ''Sales Returns''
					   when manual_override_flag = 1 and (type = ''Sales Order'' or (type in (''Purchase Order'',''Transfer Order'') and in_out = ''Out''))  then ''Sales Returns''
					   else ''Sales Returns''
					   end 
				 when type = ''Sales Order'' and rebate_type is null and return_flag = 1 and so_returns = ''SO Returns''  and dts_flag = 0 and avg_cost <> 0 then ''Sales Returns'' 
				 when type = ''Sales Order'' and cogs_variance_flag = 1 then
					case when broken_tag_flag = 1 then ''Procurement Broken Tag'' else ''Procurement Cogs Variance'' end
				 --when (((ext_po_cogs*-1) - total_po) / (iif(gl_amount=0,1,gl_amount) / iif(qty = 0,1,qty)) * avg_cost) - ((ext_po_cogs*-1) - total_po) <> 0 then ''Procurement Broken Tag''
				 when type = ''Sales Order''  and avg_cost_adj_flag =  0 and rebate_type is null and return_flag = 0 and manual_override_flag = 1 and dts_flag = 0 then ''Sales Order Manual Override'' 
				 
				 when type = ''Sales Order''  and avg_cost_adj_flag = 0 and rebate_type is null and return_flag = 0 and manual_override_flag = 0 and dts_flag = 0 and procurement is null and gl_amount <> ext_avg_cost and credit_rebill_flag = 0 and avg_cost <> 0 then ''Misc Sales Order Variance''
				 when type = ''Sales Order''  and avg_cost_adj_flag = 1 and rebate_type is null and return_flag = 0 and manual_override_flag = 0 and dts_flag = 0 and procurement is null and gl_amount <> ext_avg_cost and credit_rebill_flag = 0 and avg_cost <> 0 then ''Avg Cost Adjustments''
				 when type = ''Purchase Order''and manual_override_flag = 1 and credit_rebill_flag = 0  and in_out = ''Out'' and location_tag is null then ''Purchase Order Manual Overrides'' 
				 when type = ''Transfer Order'' and (ext_avg_cost - gl_amount > 1 or ext_avg_cost - gl_amount < -1) and in_out = ''Out'' and qty < 0 and order_invoice_id <> ''T100123863_175_1''  and location_tag is null and avg_cost <> 0 and avg_cost_adj_flag = 0 then ''Misc Transfer Order Variance''
				 when type = ''Inventory Adjustment'' and gl_amount = 0 and sum(gl_amount) over(partition by order_id,sub.product_id) <> 0 and zero_dollar_adj_flag = 1 then ''Zero Dollar Inventory Adjustment''				
				 when type = ''Inventory Adjustment'' and ((ext_avg_cost - gl_amount < -1 or ext_avg_cost - gl_amount > 1) or manual_override_flag = 1 ) and zero_dollar_adj_flag = 1 then ''Inventory Adjustment Overrides''
				 when type = ''Sales Order'' and rebate_type is null and cogs_matrix_override_flag = 1 and credit_rebill_flag = 0 then ''Cogs Matrix Override''
				 when type = ''Sales Order'' and rebate_type is null and cost_override_code is not null and avg_cost_adj_flag = 0 then ''Non SPJ Override'' 
				 when type = ''Sales Order''  and avg_cost_adj_flag = 1 and rebate_type is null and return_flag = 0 and manual_override_flag = 1 and dts_flag = 0 and procurement is null and gl_amount <> ext_avg_cost and credit_rebill_flag = 0 and avg_cost <> 0 then ''Sales Order Manual Override''
			else null end as ''category'',
			sub.*,
				
			 case
				/* Excluding Misc Return Products with $0 GL on sales order */ 
				when product_id = 69536 and gl_amount = 0 then 0 
				/* UoM Variance  */
				when product_id = 2961 then 
					case when location_tag is not null then ((gl_amount*-1) - (po_cogs * ship_qty)) 
						 else avg_vs_gl 
						 end  
				/* SPA Rebates */
				when rebate_type = ''SPA'' then 
					case when location_tag is not null then ((gl_amount*-1) - (po_cogs * ship_qty))  
						 else isnull(avg_vs_gl,0) 
						 end
				/* SPJ Rebates */
				when rebate_type = ''SPJ'' then 
					case when location_tag is not null then ((gl_amount*-1) - (po_cogs * ship_qty))  
						 else isnull(avg_vs_gl,0)
						 end
				/*Sales Return to Vendor Variance */
				when type = ''Sales Order'' and return_flag = 1 and location_tag is not null and ((gl_amount*-1) - (po_cogs * ship_qty))  <> 0 then ((gl_amount*-1) - (po_cogs * ship_qty)) 
				/*SO Return*/
				when type = ''Sales Order'' and return_flag = 1 and dts_flag = 0 and avg_cost <> 0 and credit_rebill_flag = 0 and avg_cost_adj_flag = 0 then 
					 case when location_tag is not null then ((gl_amount*-1) - (po_cogs * ship_qty))  
						  when manual_override_flag = 1 and (type = ''Sales Order'' or (type in (''Purchase Order'',''Transfer Order'') and in_out = ''Out''))  then isnull(avg_vs_gl,0)
						  else isnull(avg_vs_gl,0) 
						  end 
				when type = ''Sales Order'' and rebate_type is null and return_flag = 1 and so_returns = ''SO Returns''  and dts_flag = 0 and avg_cost <> 0 then
					 case when location_tag is not null then ((gl_amount*-1) - (po_cogs * ship_qty))  
						  else isnull(avg_vs_gl,0) 
						  end 
				/* Procurement Variance */
				when type = ''Sales Order'' and cogs_variance_flag = 1 then 
					 case when gl_amount = 0 then ext_po_cogs - gl_amount 
						  when ship_qty > receive_qty and qty + receive_qty < 0 then ((ship_qty - receive_qty) * avg_cost) - ((gl_amount / ship_qty) * (ship_qty - receive_qty)) + (variance_total *-1)
						  else variance_total * -1
						  end
					-- ((qty + receive_qty) * avg_cost) - ((ship_qty - receive_qty) * (gl_amount / qty)) + (((gl_amount / ship_qty) - po_cogs) * ship_qty)   
				--when type = ''Sales Order'' and (procurement is not null or location_tag is not null) then  
				--	 case when gl_amount = 0 then ext_po_cogs - gl_amount 
				--		  else (((ext_po_cogs*-1) - total_po) / (iif(gl_amount=0,1,gl_amount) / iif(qty = 0,1,qty)) * avg_cost) - ((ext_po_cogs*-1) - total_po)
				--		  end
			
				/*Sales Order Manual Override */
				when type = ''Sales Order''  and rebate_type is null and return_flag = 0 and manual_override_flag = 1 and dts_flag = 0  then 
					 case when location_tag is not null then ((gl_amount*-1) - (po_cogs * ship_qty))  
						  else isnull(avg_vs_gl,0)
						  end
				/*Avg Cost Adjustment*/
				when type = ''Sales Order''  and avg_cost_adj_flag = 1 and rebate_type is null and return_flag = 0 and manual_override_flag = 0 and dts_flag = 0 and procurement is null and gl_amount <> ext_avg_cost and credit_rebill_flag = 0 and avg_cost <> 0 then
					case when location_tag is not null then ((gl_amount*-1) - (po_cogs * ship_qty))  
						  else isnull(avg_vs_gl,0)
						  end
				/*Purhcase Order Manual Override*/
				when type = ''Purchase Order'' and manual_override_flag = 1 and credit_rebill_flag = 0  and in_out = ''Out'' and location_tag is null then avg_vs_gl
				/*Transfer Order Manual Adjustment*/
				when type = ''Transfer Order'' and (ext_avg_cost - gl_amount > 1 or ext_avg_cost - gl_amount < -1) and in_out = ''Out'' and qty < 0 and order_invoice_id <> ''T100123863_175_1''  and location_tag is null and avg_cost <> 0 and avg_cost_adj_flag = 0 then avg_vs_gl
				/*Zero Dollar Inventory Adjustments */
				when type = ''Inventory Adjustment'' and gl_amount = 0 and sum(gl_amount) over(partition by order_id,sub.product_id) <> 0 and zero_dollar_adj_flag = 1 then sum(gl_amount) over(partition by order_id,sub.product_id)
				/*Inventory Adjustment Manual Override*/
				when type = ''Inventory Adjustment'' and ((ext_avg_cost - gl_amount < -1 or ext_avg_cost - gl_amount > 1) or manual_override_flag = 1 ) and zero_dollar_adj_flag = 1  then avg_vs_gl
				/* Cogs Matrix Override */
				when type = ''Sales Order'' and rebate_type is null and cogs_matrix_override_flag = 1 and credit_rebill_flag = 0 then 
					case when location_tag is not null then ((gl_amount*-1) - (po_cogs * ship_qty))  
						  else isnull(avg_vs_gl,0)
						  end
				/* Cost Override Code - Non SPJ Job Type */
				when type = ''Sales Order'' and rebate_type is null and cost_override_code is not null and credit_rebill_flag = 0 and avg_cost_adj_flag = 0  then 
					case when location_tag is not null then ((gl_amount*-1) - (po_cogs * ship_qty))  
						  else isnull(avg_vs_gl,0)
						  end
				/*Misc Sales Order Override*/
				when type = ''Sales Order''  and avg_cost_adj_flag = 0 and rebate_type is null and return_flag = 0 and manual_override_flag = 0 and dts_flag = 0 and procurement is null and gl_amount <> ext_avg_cost and credit_rebill_flag = 0 and avg_cost <> 0 then 
					case when location_tag is not null then ((gl_amount*-1) - (po_cogs * ship_qty))  
						  else isnull(avg_vs_gl,0)
						  end
				else 0 end as total_variance
		from (
				select 
					l.*,
					case when l.gl_amount <= 0 then ((l.avg_cost * -1) * abs(l.qty)) - l.gl_amount
						 else l.ext_avg_cost - l.gl_amount
						 end as avg_vs_gl,


					isnull(t.location_tag,t2.sales_order_line_generation_id) as location_tag,
						(
						select 
							sum(cogs) as cogs 
						from (
							select distinct
								sales_order_line_generation_id,
								location_tag,
								receive_qty as qty,
								ext_po_cogs as cogs 
							from dbo.tagged_orders as t 
							where t.sales_order_line_generation_id = l.order_invoice_id 
						) as sub
						 ) as ext_po_cogs,
					case when exists (
									  select product_branch_id
									  from dbo.dsg_inventory_audit_br_cost as b
									  where comment_type = ''BR.COST'' 
										  and (left(comment,len(user_id)) = user_id or left(comment,14) = ''Per Qty Change'')
										  and comment like ''%Avg Cost%''
										  and user_id <> ''ECLIPSE''
										  and b.product_branch_id = l.product_branch_id collate SQL_Latin1_General_CP1_CS_AS 
									  )
					then 1 else 0
					end as avg_cost_adj_flag,
				    ia.header_comment,
					a.type as rebate_category,
					a.purchase_order_id,
					a.journal_id,
					a.journal_amount, 
					case when l.type = ''Inventory Adjustment''  and l.gl_amount = 0 and exists
							(
								select 
									product_id
								from (				
										select   	
											row_number() over(partition by ship_date, product_id order by ship_date asc) as id,
											ship_date as ship_date,
											product_id,
											gl_amount as adj_check
										from dbo.dsg_inventory_audit_avg_cost as c
										where ((c.type = ''Sales Order'' and c.qty < 0) or (c.type = ''Transfer Order'' and c.qty > 0) or (c.type = ''Purchase Order'' and c.qty > 0)) and l.product_id = c.product_id and c.ship_date >= l.ship_date
									 ) as sub
								where id = 1 
								)
								then 1 else 0 end as zero_dollar_adj_flag,

					 sum(l.gl_amount) over(partition by left(l.order_invoice_id,10), l.line_id,l.product_id) as total_po,
					 tag.ship_qty,
					 tag.receive_qty,
					 tag.po_cogs,
					 tag.cogs_variance_flag,
					 tag.broken_tag_flag,
					 tag.variance_total

				from dbo.dsg_inventory_audit_avg_cost as l
							left join eclipse.inventory_adjustment as ia on ia.eclipse_id = l.order_id collate SQL_Latin1_General_CP1_CI_AS
							left join (
										select 
											location_tag,
											sum(ext_po_cogs) as ext_po_cogs
										from dbo.tagged_orders
										group by location_tag
										) as t on t.location_tag = CONCAT(left(order_invoice_id,10),''.'',l.line_id)
							left join (
										select 
											sales_order_line_generation_id,
											max(location_tag) as location_tag,
											sum(ext_po_cogs) as ext_po_cogs
										from dbo.tagged_orders
										group by sales_order_line_generation_id
										) as t2 on t2.sales_order_line_generation_id = l.order_invoice_id

							left join (
										select 
											sales_order_line_generation_id,
											max(ship_qty) as ship_qty,
											sum(ext_cogs) as ext_cogs,
											sum(receive_qty) as receive_qty,
											sum(ext_po_cogs) / sum(receive_qty) as po_cogs, 
											sum(ext_po_cogs) as ext_po_cogs,
											max(cogs_variance_flag) as cogs_variance_flag,
											max(broken_tag_flag) as broken_tag_flag,
											sum(variance_total) as variance_total
										from dbo.tagged_orders as t 
										group by sales_order_line_generation_id
										) as tag on tag.sales_order_line_generation_id = l.order_invoice_id

							left join (
										select *
										from (
											select 
												ROW_NUMBER() over(partition by sales_order_id, invoice_number,line_id order by ship_date)as id,
												count(*) over(partition by sales_order_id, line_id) as id2,
												*
											from dbo.dsg_inventory_audit_spa_analyis
										) as sub
										where id = 1 		
										) as a on a.sales_order_id = left(l.order_invoice_id,10) and a.line_id = l.line_id and l.qty * -1 = a.po_qty  and l.order_id = concat(a.sales_order_id,''.'',format(a.invoice_number,''000''))

				where l.product_id <> 69233 
						and kits = 0 
						and l.order_invoice_id not in (
							''S101120729_158_2'' /* ALX massive avg costing & uom issue which was fixed correctly by JY */
							,''S100218257_150_1'' /* ABE massive avg costing & uom issue which was fixed correctly by JY */
							,''S100204792_158_1''  /* ALX massive avg costing & uom issue which was fixed correctly by MITCHY */
							)
						and case when l.ship_branch = ''FARW'' and l.product_id = 55124 then 1 else 0 end = 0  /* massive variances on example where Eclipse did not update activity log for multiple PO''s */
			) as sub
	) as sub
 where avg_vs_gl not between -1 and 1

 

', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


