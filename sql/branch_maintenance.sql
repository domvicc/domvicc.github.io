USE [msdb]
GO

/****** Object:  Job [eda_branch_maintenance]    Script Date: 4/25/2023 10:35:12 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 4/25/2023 10:35:12 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'eda_branch_maintenance', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'branch maintenance reports', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'domvicc', 
		@notify_email_operator_name=N'Dom Vicchiollo', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [cash_box_quality]    Script Date: 4/25/2023 10:35:12 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'cash_box_quality', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.cash_box_quality
create table dbo.cash_box_quality (
	branch_id varchar(max),
	open_cash_box decimal(18,2),
	number_cleared_days int,
	total_days int,
	percent_of_days_cleared decimal(18,2)
	)
insert into dbo.cash_box_quality
select 
	branch_id,
	sum(total_amount) as open_cash_box,
	sum(cleared) as number_clear_days,
	sum(lines) as total_days,
	cast((sum(cleared)/cast(sum(lines) as float))*100 as decimal(18,2)) as percent_of_days_cleared
from (
	select 
		branch_id,
		gl_account_id,
		''Cash Box'' as ''source'',
		date,
		total_amount,
		iif(total_amount = 0,1,0) as cleared,
		cast(''1'' as int) as lines
	from eclipse.gl_account_daily_transaction_detail
	where gl_account_id = 5 and year = datepart(yyyy,getdate()) and date < dateadd(dd,-1,getdate())  
) as sub
group by branch_id', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [invoice_preview_queue]    Script Date: 4/25/2023 10:35:12 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'invoice_preview_queue', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.invoice_preview_queue
create table dbo.invoice_preview_queue (
	order_id nvarchar(max),
	ship_date date,
	ship_to_id int,
	bill_to_id int,
	price_branch varchar(max),
	ship_branch varchar(max),
	sales_order_id nvarchar(max),
	generation_id int,
	[status] nvarchar(max),
	print_status nvarchar(max),
	print_flag nvarchar(max),
	[description] nvarchar(max),
	price_total decimal(18,2),
	processed_date date,
	days_in_process_queue int,
	writer nvarchar(max),
	inside_salesperson nvarchar(max),
	outside_salesperson nvarchar(max),
	ship_via nvarchar(max),
	ipq_aging_days nvarchar(max)
	)
insert into dbo.invoice_preview_queue
select 
	CONCAT(sales_order_id,''.'',format(invoice_number,''000'')) as order_id,
	*,
	case when days_in_process_queue between 0 and 3 then ''Current''
	when days_in_process_queue between 4 and 30 then ''1-30 Days''
	when days_in_process_queue between 31 and 60 then ''30-60 Days''
	when days_in_process_queue between 61 and 90 then ''60-90 Days'' 
	when days_in_process_queue between 91 and 180 then ''90-180 Days''
	when days_in_process_queue > 180 then ''180+ Days''
	end as ipq_aging_days
from (
	select 
		q.ship_date,
		q.ship_to_id,
		q.bill_to_id,
		q.price_branch,
		q.ship_branch,
		q.sales_order_id,
		sog.invoice_number,
		q.status,
		q.print_status,
		solg.sales_order_print_status as print_flag,
		s.description,
		sog.price_total,
		isnull(sog.gl_user_date,q.ship_date) as processed_date,
		datediff(dd,isnull(sog.gl_user_date,q.ship_date),getdate()) as days_in_process_queue,
		sog.writer,
		sog.inside_salesperson,
		sog.outside_salesperson,
		sog.ship_via
	from eclipse.sales_order_print_queue as q
		left join eclipse.system_order_entry_print_status as s on s.system_order_entry_print_status_id = q.print_status
		left join eclipse.sales_order_generation as sog on sog.eclipse_id = q.sales_order_id and sog.generation_id = q.generation_id
		--left join eclipse.sales_order_print_queue as g on sog.eclipse_id = g.sales_order_id and sog.sales_order_generation_id = g.generation_id
		left join eclipse.sales_order_log_generation as solg on solg.eclipse_id = q.sales_order_id and solg.sales_order_generation_id = q.generation_id
	where q.status = ''I''  and sog.price_total is not null and q.print_status not in (''P'',''B'')
 ) as sub', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [cod_open_balance]    Script Date: 4/25/2023 10:35:12 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'cod_open_balance', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* First table to pull all AR records with an Open Balance (to narrow list of records), both negative and positive. Then pulling 2 datasets, one for SOG recods with COD terms and second for pending records in the AR cashbox */ 
create table dbo.c (
	eclipse_id nvarchar(255) collate SQL_Latin1_General_CP1_CI_AS not null PRIMARY KEY,
	invoice_date date,
	branch_id nvarchar(255),
	bill_to_id int,
	status_code nvarchar(255),
	handling_code nvarchar(255),
	sales_order_id nvarchar(255),
	cash_receipt_id nvarchar(255),
	balance_due decimal(18,2)
	)
insert into dbo.c
select *
from (
	select  
		ar.eclipse_id,
		ar.invoice_date,
		ar.gl_branch_id as branch_id,
		ar.bill_to_id,
		ar.status as status_code,
		ar.handling_code,
		ar.eclipse_id sales_order_id,
		cash_receipt_id,
		ar.balance_due
	from eclipse.accrual_register as ar
	where isnull(balance_due,0) <> 0 
) as sub 
/* Second table compiling pending cashbox ar records requiring ar to complete steps */  
create table dbo.cashbox (
	eclipse_id nvarchar(255) collate SQL_Latin1_General_CP1_CI_AS not null PRIMARY KEY
	)
insert into dbo.cashbox
select distinct
	eclipse_id
from eclipse.accrual_register_applied_payment_gl_posting as gl
where gl.gl_account = 5 and isnull(gl_autopost_code,''X'') <> ''X'' 

/* Third table compling records from ledger where terms_code on the gen = COD & has a open balance in AR File */ 
create table dbo.sog_cod (
	eclipse_id nvarchar(255) collate SQL_Latin1_General_CP1_CI_AS not null PRIMARY KEY,
	)
insert into dbo.sog_cod
select distinct
	concat(eclipse_id,''.'',format(sog.invoice_number,''000'')) as eclipse_id
from eclipse.sales_order_generation as sog 
where terms_code = ''COD'' and status_code = ''I'' and ship_date >= ''2020-03-01''
/* Total Branch 365 Day COD Sales */ 
drop table dbo.cod /* adding drop above create here because branch maintenance report is also using this value */
create table dbo.cod (
	ship_branch nvarchar(max),
	total decimal(18,2)
	)
insert into dbo.cod
select 
	ship_branch,
	sum(price_total) as total 
from eclipse.sales_order_generation as sog
where sog.status_code = ''I'' and terms_code = ''COD'' and ship_date >= dateadd(dd,-365,getdate())
group by ship_branch 
/* COD Customers with Open Balance Detail */ 
drop table dbo.open_balance_cod
create table dbo.open_balance_cod (
	invoice_date date,
	branch_id nvarchar(max), 
	bill_to_id int,
	inside_salesperson nvarchar(max),
	outside_salesperson nvarchar(max),
	customer nvarchar(max),
	status_code nvarchar(max),
	handling_code nvarchar(max),
	default_terms nvarchar(max),
	sales_order_id nvarchar(max),
	cash_receipt_id nvarchar(max),
	balance_due decimal(18,2)
	)
insert into dbo.open_balance_cod
		select 
			c.invoice_date,
			c.branch_id,
			c.bill_to_id,
			cc.inside_salesperson,
			cc.outside_salesperson,
			cc.name,
			c.status_code,
			c.handling_code,
			''COD'' as default_terms,
			sales_order_id,
			cash_receipt_id,
			balance_due
		from dbo.c 
			left join dbo.cashbox as b on b.eclipse_id = c.eclipse_id collate SQL_Latin1_General_CP1_CI_AS
			left join dbo.sog_cod as s on s.eclipse_id = c.sales_order_id collate SQL_Latin1_General_CP1_CI_AS 
			left join eclipse.customer as cc on cc.eclipse_id = c.bill_to_id
		where (b.eclipse_id is not null or s.eclipse_id is not null) 

drop table dbo.c
drop table dbo.cashbox;
drop table dbo.sog_cod; 

/* Open Balance,Total COD, Open Days,Rank */
create table dbo.cz (
	branch_id nvarchar(max),
	open_balance decimal(18,2),
	total_cod decimal(18,2),
	open_cod_days decimal(18,2),
	id int
	)
insert into dbo.cz
select 
	*,
	rank() over(order by open_cod_days) as id
from (
	select 
		sub.branch_id,
		sub.balance_due, 
		cod.total as total_cod,
		sub.open_balance/(cod.total/365) as open_cod_days
	from (
		select 
			branch_id,
			sum(balance_due) as balance_due,
			abs(sum(balance_due)) as open_balance 
		from dbo.open_balance_cod
		where branch_id <> ''CORP'' 
		group by branch_id 
	) as sub
		left join dbo.cod as cod on cod.ship_branch = sub.branch_id 
	where branch_id not in (''FAP'',''CORP'')
) as sub
/* Open COD Quality */ 
drop table dbo.open_cod_quality
create table dbo.open_cod_quality (
	branch_id nvarchar(max),
	open_balance decimal(18,2),
	total_cod decimal(18,2),
	open_cod_days decimal(18,2),
	id int,
	median decimal(18,2),
	open_cod_quality decimal(18,2)
	)
insert into dbo.open_cod_quality
select 
	*,
	iif(open_cod_days < median,1,median/open_cod_days)*100 as open_cod_quality
from (
	select 
		*,
		(
			select open_cod_days as median
			from dbo.cz
			where id =(select max(id)/2	from dbo.cz where open_cod_days > 0 ) 
		) as median
	from dbo.cz
) as sub ;

 
drop table dbo.cz;

', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [po_variance]    Script Date: 4/25/2023 10:35:12 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'po_variance', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.po_variance
create table dbo.po_variance (
	create_date date,
	ship_branch nvarchar(max),
	payable nvarchar(max),
	purchase_order nvarchar(max),
	create_user nvarchar(max),
	writer nvarchar(max),
	diff int, 
	invoice_amount decimal(18,2)
	)
insert into dbo.po_variance
select 
	p.create_date,
	p.ship_branch,
	p.payable_id,
	isnull(isnull(sales_order_id,purchase_order_id),work_order_id) as order_id,
	isnull(user_id,''ECLIPSE'') as create_user,
	isnull(writer,''ECLIPSE'') as writer,
	datediff(dd,create_date,getdate()) as diff,
	p.variance_amount
from eclipse.payable_variance_queue as p
create table dbo.q (
	ship_branch nvarchar(max),
	total_variance decimal(18,2),
	total_branch_payables decimal(18,2),
	po_variance_days decimal(18,2),
	id int
	)
insert into dbo.q
select 
	*,
	rank() over(order by po_variance_days asc) as id 
from (
	select
		*,
		total_variance / (total_branch_payables / 365) as po_variance_days
	from (
		select 
			ship_branch,
			sum(v.invoice_amount) as total_variance,
			(
				select 
					sum(abs(a.invoice_amount)) as total
				from eclipse.payable as a
				where a.entered_date >= dateadd(dd,-365,getdate()) and a.ship_branch = v.ship_branch collate SQL_Latin1_General_CP1_CI_AS
				group by ship_branch
			) as total_branch_payables
		from dbo.po_variance as v
		where create_date <= dateadd(dd,-30,getdate())
		group by ship_branch 
	) as sub
 ) as sub



drop table dbo.po_variance_quality
create table dbo.po_variance_quality (
	ship_branch nvarchar(max),
	total_variance decimal(18,2),
	total_branch_payables decimal(18,2),
	po_variance_days decimal(18,2),
	id int,
	po_variance_median decimal(18,2),
	quality decimal(18,2)
	)
insert into dbo.po_variance_quality
select 
	*,
	iif(po_variance_days < median,1,median/po_variance_days)*100 as po_variance_quality
from (
	select 
		*,	
		(
		select 
			po_variance_days as median
		from dbo.q as q
		where q.ship_branch not in (''CORP'',''FAP'',''APC'') and  q.id =
			(
				select distinct (count(*) over())/2
				from dbo.q
				where po_variance_days > 0 and ship_branch not in (''CORP'',''FAP'',''APC'')
			)
		) as median 
	from dbo.q
) as sub
drop table dbo.q', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [return_goods_queue]    Script Date: 4/25/2023 10:35:12 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'return_goods_queue', 
		@step_id=5, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.return_goods_queue
create table dbo.return_goods_queue (
	[date] date,
	branch_id varchar(max),
	tag_id nvarchar(max),
	product_id int,
	location_type nvarchar(max),
	[location] nvarchar(max),
	location_qty int,
	total_amount decimal(18,2)
	)
insert into dbo.return_goods_queue
select 
	isnull(isnull(isnull(isnull(isnull(isnull(location_last_receive_date,location_last_putaway_date),location_last_count_date),
	(select last_update_date  from eclipse.sales_order as so where so.eclipse_id = left(pil.location_tag_out,10))), 
	(select last_update_date  from eclipse.purchase_order as po where po.eclipse_id = left(pil.location_tag_out,10))),
	(select last_update_date  from eclipse.inventory_adjustment as ia where ia.eclipse_id = left(pil.location_tag_out,10))),
	(select last_update_date  from eclipse.transfer_order as t where t.eclipse_id = left(pil.location_tag_out,10))) as date,
	branch_id,
	left(pil.location_tag_out,10) as tag_id,
	pil.product_id,
	location_type,
	location,
	location_qty,
	b.avg_cost  * location_qty as total_amount
from eclipse.product_inventory_location as pil 
	left join ( 
				select 
					product_branch_id,
					max(avg_cost_per_qty) as avg_cost
				from dbo.product_branch_inventory
				group by product_branch_id
			) as b on b.product_branch_id = pil.eclipse_id

where location_type in (''F'',''O'',''R'') and location_inprocess_status is null   



 
', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [open_sales_orders]    Script Date: 4/25/2023 10:35:12 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'open_sales_orders', 
		@step_id=6, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.open_sales_orders 
create table dbo.open_sales_orders (
	order_date date,
	ship_date date,
	ship_branch nvarchar(max),
	sales_order_id nvarchar(max),
	status_code nvarchar(max),
	jm_flag int, 
	bill_to_id int,
	ship_to_id int, 
	writer nvarchar(max),
	inside_salesperson nvarchar(max),
	outside_salesperson nvarchar(max),
	sales_total decimal(18,2),
	aging_days int
	) 
insert into dbo.open_sales_orders
select 
	order_date,
	ship_date,
	ship_branch,
	sales_order_generation_id, 
	status_code,
	(select job_management_flag from eclipse.sales_order as so where so.eclipse_id = sog.eclipse_id) as jm_flag,
	bill_to_id,
	ship_to_id,
	writer,
	inside_salesperson,
	outside_salesperson,
	sales_total,
	datediff(dd,order_date,getdate()) as diff
from eclipse.sales_order_generation as sog
where (ship_date < cast(getdate() as date) and status_code = ''P'') or status_code in (''C'',''W'',''L'',''A'',''D'',''S'',''K'',''H'', ''M'')', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [sales_order_open_return_queue]    Script Date: 4/25/2023 10:35:12 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'sales_order_open_return_queue', 
		@step_id=7, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.sales_order_open_returns
create table dbo.sales_order_open_returns (
	[date] date,
	ship_branch varchar(max),
	bill_to_id int,
	ship_to_id int,
	sales_order_id nvarchar(max),
	status_code nvarchar(max),
	total_amount decimal(18,2)
	)
insert into dbo.sales_order_open_returns		

select 				
	iif(ship_date < (select last_update_date from eclipse.sales_order as so where so.eclipse_id = o.sales_order_id),ship_date,(select last_update_date from eclipse.sales_order as so where so.eclipse_id = o.sales_order_id)) as date, 
	ship_branch,
	bill_to_id,
	ship_to_id,
	sales_order_id,
	status_code,		
	total_amount
from eclipse.open_sales_order as o
where status_code not in (''B'') and total_amount > 0 
				 
	', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [ohb_no_location]    Script Date: 4/25/2023 10:35:12 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'ohb_no_location', 
		@step_id=8, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* First table running data for ohn no location */
drop table dbo.ohb_no_location 
create table dbo.ohb_no_location (
	branch_id nvarchar(max),
	product_id int, 
	description nvarchar(max),
	location nvarchar(max),
	location_status nvarchar(max),
	location_type nvarchar(max),
	location_tag nvarchar(max),
	location_qty int, 
	ext_avg_cost decimal(18,2),
	aging_date date,
	aging_days int
	)
insert into dbo.ohb_no_location
select
	pil.branch_id,
	pil.product_id,
	cast(p.description as nvarchar(75)) as description, 
	isnull(location,'' '') as location,
	isnull(location_status,'' '') as location_status,
	isnull(location_type,'' '') as location_type,
	isnull(location_tag_out,location_tag_in) as location_tag, 
	location_qty,
	abs(isnull(pbc.average_cost / pbc.branch_cost_per_qty,pbc.replacement_cost) * location_qty) as ext_avg_cost,
	isnull(isnull(isnull(pil.location_last_putaway_date,pil.location_last_receive_date),pil.location_last_count_date),pil.sql_last_modified) as aging_date,
	DATEDIFF(dd,isnull(isnull(isnull(pil.location_last_putaway_date,pil.location_last_receive_date),pil.location_last_count_date),pil.sql_last_modified),GETDATE()) as aging_days
from eclipse.product_inventory_location as pil 
		LEFT JOIN eclipse.product AS p ON p.product_id = pil.product_id	
		LEFT join dbo.product_branch_calculation as pbc on pbc.product_branch_id = pil.eclipse_id
where location_inprocess_status is null and location_qty <> 0 and location is null and pil.branch_id is not null and p.description is not null and p.buy_line_id not in ( ''MISC'',''NON-INV'') and location_type <> ''T'' 
/* Second table running quality score for OHB no loc */
--drop table dbo.ohb_no_loc
--create table dbo.ohb_no_loc  (
--	branch_id nvarchar(max),
--	ohb_total decimal(18,2),
--	inv_day decimal(18,2),
--	ohb_no_loc_days decimal(18,2),
--	id int
--	)
--insert into dbo.ohb_no_loc 
--select 
--	*,
--	RANK() over(order by ohb_no_loc_days desc) as id

--from (
--	select 
--		*,
--		ohb_total / inv_day as ohb_no_loc_days
--	from (
--		select 
--			branch_id,
--			isnull(SUM(ext_avg_cost),0) as ohb_total,
--			(select  sum(avg_cost_onhand) from dbo.product_branch_inventory as p where p.branch_id = ohb.branch_id collate SQL_Latin1_General_CP1_CI_AS)/cast(365 as float) as inv_day
--		from dbo.ohb_no_location as ohb
--		group by ohb.branch_id
--	) as sub
--) as sub

--/* OHB No Location Quality */ 
--drop table dbo.ohb_no_location_quality
--create table dbo.ohb_no_location_quality (
--	branch_id nvarchar(max),
--	ohb_no_loc_total decimal(18,2),
--	inv_days decimal(18,2),
--	ohb_no_loc_days decimal(18,2),
--	id int,
--	median decimal(18,2),
--	ohb_no_loc_quality decimal(18,2)
--	)
--insert into dbo.ohb_no_location_quality
--select 
--	*,
--	IIF(ohb_no_loc_days < median,1,median/ohb_no_loc_days)*100 as ohb_no_loc_quality
--from (
--	select 
--		*,
--		(
--		select 
--			ohb_no_loc_days as median
--		from dbo.ohb_no_loc 
--		where id = (select MAX(id)/2 from dbo.ohb_no_loc  where ohb_no_loc_days > 0)
--		) as median
--	from dbo.ohb_no_loc 
--) as sub
', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [negative_qty_locations]    Script Date: 4/25/2023 10:35:12 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'negative_qty_locations', 
		@step_id=9, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* First table running data for Negative Qty Locations */
drop table dbo.negative_qty_location
create table dbo.negative_qty_location  (
	branch_id nvarchar(max),
	product_id int, 
	description nvarchar(max),
	location nvarchar(max),
	location_status nvarchar(max),
	location_type nvarchar(max),
	location_tag nvarchar(max),
	location_qty int, 
	ext_avg_cost decimal(18,2),
	aging_date date,
	aging_days int
	)
insert into dbo.negative_qty_location 
select 
	pil.branch_id,
	pil.product_id,
	cast(p.description as nvarchar(75)) as description, 
	isnull(location,'' '') as location,
	isnull(location_status,'' '') as location_status,
	isnull(location_type,'' '') as location_type,
	isnull(location_tag_out,location_tag_in) as location_tag, 
	location_qty,
	abs(isnull(pbc.average_cost / pbc.branch_cost_per_qty,pbc.replacement_cost) * location_qty) as ext_avg_cost,
	isnull(isnull(isnull(pil.location_last_putaway_date,pil.location_last_receive_date),pil.location_last_count_date),pil.sql_last_modified) as aging_date,
	DATEDIFF(dd,isnull(isnull(isnull(pil.location_last_putaway_date,pil.location_last_receive_date),pil.location_last_count_date),pil.sql_last_modified),GETDATE()) as aging_days
from eclipse.product_inventory_location as pil 
	left join eclipse.product as p on p.eclipse_id = pil.product_id
	left join dbo.product_branch_calculation as pbc on pbc.product_branch_id = pil.eclipse_id
where location_qty < 0 and location_inprocess_status is null and p.description is not null and p.buy_line_id not in ( ''MISC'',''NON-INV'')

--/* Second table running quality score for Negative Quality Locations */
--drop table dbo.neg 
--create table dbo.neg (
--	branch_id nvarchar(max),
--	ohb_total decimal(18,2),
--	inv_day decimal(18,2),
--	neg_loc_days decimal(18,2),
--	id int
--	)
--insert into dbo.neg 
--select 
--	*,
--	RANK() over(order by neg_loc_days desc) as id

--from (
--	select 
--		*,
--		ohb_total / inv_day as neg_loc_days
--	from (
--		select 
--			n.branch_id,
--			isnull(SUM(ext_avg_cost),0) as ohb_total,
--			(select  sum(avg_cost_onhand) from dbo.product_branch_inventory as p where p.branch_id = n.branch_id collate SQL_Latin1_General_CP1_CI_AS)/cast(365 as float) as inv_day
--		from dbo.negative_qty_location as n
--		group by n.branch_id
--	) as sub
--) as sub


--/* Open COD Quality */ 
--drop table dbo.negative_location_quality
--create table dbo.negative_location_quality (
--	branch_id nvarchar(max),
--	ohb_total decimal(18,2),
--	inv_day decimal(18,2),
--	neg_loc_days decimal(18,2),
--	id int,
--	median decimal(18,2),
--	negative_location_quality decimal(18,2)
--	)
--insert into dbo.negative_location_quality

--select 
--	*,
--	iif(neg_loc_days < median,1,median/neg_loc_days)*100 as negative_location_quality
--from (
--	select 
--		*,
--		(
--			select neg_loc_days as median
--			from dbo.neg
--			where id =(select max(id)/2	from dbo.neg where ohb_total > 0 ) 
--		) as median
--	from dbo.neg
--) as sub ;', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [branch_maintenance_detail]    Script Date: 4/25/2023 10:35:13 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'branch_maintenance_detail', 
		@step_id=10, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.branch_maintenance
create table dbo.branch_maintenance (
	category nvarchar(max),
	type nvarchar(max),
	order_date date,
	ship_date date,
	ship_branch nvarchar(max),
	receive_branch nvarchar(max),
	order_id nvarchar(max),
	receipt nvarchar(max),
	status_code nvarchar(max),
	jm_flag int,
	bill_to_id int,
	ship_to_id int,
	writer nvarchar(max),
	create_user nvarchar(max),
	inside_salesperson nvarchar(max),
	outside_salesperson nvarchar(max),
	total_amount decimal(18,2),
	aging_days int,
	product_id int,
	location nvarchar(max),
	location_qty int,
	ship_qty int,
	receive_qty int,
	location_status nvarchar(max),
	location_type nvarchar(max),
	location_tag nvarchar(max),
	age int
	)
insert into dbo.branch_maintenance
select *,
	case when aging_days between 0 and 30 then 1
		 when aging_days between 31 and 60 then 2
		 when aging_days between 61 and 90 then 3
		 when aging_days > 90 then 4 
	end as age 
from (
	/* Open Sales Orders */
	select 
		''Open Order Quality'' as category, 
		''Open Sales Orders'' as type,
		order_date,
		ship_date,
		ship_branch,
		null as receive_branch, 
		sales_order_id,
		null as cash_receipt,
		status_code,
		jm_flag,
		bill_to_id,
		ship_to_id,
		writer,
		null as create_user,
		inside_salesperson,
		outside_salesperson,
		sales_total,
		aging_days,
		null as product_id,
		null as location,
		null as location_qty,
		null as ship_qty,
		null as receive_qty,
		null as location_status,
		null as location_type,
		null as location_tag
	from dbo.open_sales_orders

	union

	/* Open Sales Order Returns */ 
	select
		''Open Order Quality'' as category, 
		''Open Sales Order Returns'' as type,
		order_date,
		ship_date,
		ship_branch,
		null as recv,
		sales_order_id,
		null as cash_receipt,
		status_code,
		jm_flag,
		bill_to_id,
		ship_to_id,
		writer,
		null as create_user,
		inside_salesperson,
		outside_salesperson,
		sales_total,
		aging_days,
		null as product_id,
		null as location,
		null as location_qty,
		null as ship_qty,
		null as receive_qty,
		null as location_status,
		null as location_type,
		null as location_tag
	from dbo.open_sales_orders as so
	where exists (select * from dbo.sales_order_open_returns as r where r.sales_order_id = left(so.sales_order_id,10))

	union

	/* Open Balance COD Orders */ 
	select 
		''Branch Maintenance Quality'' as category, 
		''COD Open Balance'' as type,
		invoice_date,
		Null as ship_date,
		branch_id,
		branch_id, 
		sales_order_id,
		cash_receipt_id,
		status_code,
		null as jm_flag,
		bill_to_id,
		null as ship_to_id,
		null as writer,
		null as create_user,
		inside_salesperson,
		outside_salesperson,
		balance_due,
		datediff(dd,invoice_date,getdate()) as aging,
		null as product_id,
		null as location,
		null as location_qty,
		null as ship_qty,
		null as receive_qty,
		null as location_status,
		null as location_type,
		null as location_tag
	from dbo.open_balance_cod

	union

	/*Invoice Preview Queue */ 

	select 
		''Branch Maintenance Quality'' as category, 
		''Invoice Preview Queue'' as type,
		processed_date,
		ship_date,
		ship_branch,
		ship_branch,
		concat(sales_order_id,''.'',format(generation_id,''000'')) as sales_order_id,
		null as cash_receipt,
		description,
		null as jm_flag,
		bill_to_id,
		ship_to_id,
		writer,
		null as create_user,
		inside_salesperson,
		outside_salesperson,
		price_total,
		days_in_process_queue,
		null as product_id,
		null as location,
		null as location_qty,
		null as ship_qty,
		null as receive_qty,
		null as location_status,
		null as location_type,
		null as location_tag
	from dbo.invoice_preview_queue

	union

	/* Open Purchase Orders */
	select 
		''Open Order Quality'' as category, 
		''Open Purchase Orders'' as type,
		order_date,
		receive_date,
		receive_branch as ship_branch,
		receive_branch,
		purchase_order_id,
		null as cash_receipt,
		status_code,
		null as jm_flag,
		pay_to_id,
		pay_to_id,
		writer,
		null as create_user,
		null as inside,
		null as outside,
		abs(subtotal_amount),
		aging_days,
		null as product_id,
		null as location,
		null as location_qty,
		null as ship_qty,
		null as receive_qty,
		null as location_status,
		null as location_type,
		null as location_tag
	from dbo.open_purchase_orders
	where subtotal_amount > 0 

	union

	/* Open Purchase Order Returns */
	select 
		''Open Order Quality'' as category, 
		''Open Purchase Order Returns'' as type,
		order_date,
		receive_date,
		receive_branch as ship_branch,
		receive_branch,
		purchase_order_id,
		null as cash_receipt,
		status_code,
		null as jm_flag,
		pay_to_id,
		pay_to_id,
		writer,
		null as create_user,
		null as inside,
		null as outside,
		abs(subtotal_amount),
		aging_days,
		null as product_id,
		null as location,
		null as location_qty,
		null as ship_qty,
		null as receive_qty,
		null as location_status,
		null as location_type,
		null as location_tag
	from dbo.open_purchase_orders
	where subtotal_amount < 0 

	union

	/*Return Goods Queue */
	select 
		''Warehouse Maintenance Quality'' as category, 
		''Return Goods Queue'' as type,
		isnull(date,getdate()) as date,
		isnull(date,getdate()) as date,
		branch_id,
		branch_id,
		tag_id,
		null as cash_r,
		case when location_type = ''F'' then ''Defective''
			 when location_type = ''R'' then ''Review''
			 when location_type = ''O'' then ''Overstock'' 
		end as status_code,
		null as jm_flag,
		null as bill_to,
		null as ship_to,
		null as writer,
		null as create_user,
		null as inside_salesperson,
		null as outside_salesperson,
		abs(total_amount) as total,
		datediff(dd,date,getdate()) as aging,
		product_id,
		location,
		location_qty,
		null as ship_qty,
		null as receive_qty,
		null as location_status,
		null as location_type,
		null as location_tag
	from dbo.return_goods_queue

	union 

	/* PO Variance */ 
	select 
		''Branch Maintenance Quality'' as category,
		''PO Variance Queue'' as type,
		create_date,
		create_date,
		ship_branch,
		ship_branch,
		purchase_order,
		payable,
		null as status_code,
		null as jm_flag,
		null as bill_to,
		null as ship_to,
		writer,
		create_user,
		null as inside,
		null as outside,
		abs(invoice_amount),
		diff,
		null as prod,
		null as loc,
		null as loc_qty,
		null as ship_qty,
		null as receive_qty,
		null as location_status,
		null as location_type,
		null as location_tag
	from dbo.po_variance

	union 

	/* Xfer Shipped Not Received - Shipped */ 
	select 
		''Warehouse Maintenance Quality'' as category, 
		''Xfer Shipped Not Received - Ship'' as type, 
		processed_date,
		processed_date,
		ship_branch,
		receive_branch,
		transfer_order_id,
		null as cash_r,
		''O'' as status_code,
		null as jm,
		null as bill,
		null as ship,
		writer,
		null as createuser,
		null as inside,
		null as outside,
		abs(cost_total),
		datediff(dd,processed_date,getdate()) as aging,
		null as prod,
		null as loc,
		null as loc_qty,
		null as ship_qty,
		null as receive_qty,
		null as location_status,
		null as location_type,
		null as location_tag
	from dbo.transfers_shipped_not_received
union 
	/* Xfer Shipped Not Received - Recv */ 
	select 
		''Warehouse Maintenance Quality'' as category, 
		''Xfer Shipped Not Received - Recv'' as type, 
		processed_date,
		processed_date,
		receive_branch,
		ship_branch,
		transfer_order_id,
		null as cash_r,
		''O'' as status_code,
		null as jm,
		null as bill,
		null as ship,
		writer,
		null as createuser,
		null as inside,
		null as outside,
		abs(cost_total),
		datediff(dd,processed_date,getdate()) as aging,
		null as prod,
		null as loc,
		null as loc_qty,
		null as ship_qty,
		null as receive_qty,
		null as location_status,
		null as location_type,
		null as location_tag
	from dbo.transfers_shipped_not_received
	union 

	/* Xfer Disputes - Ship */ 
	select 
		''Warehouse Maintenance Quality'' as category, 
		''Xfer Disputes - Ship'' as type,
		ship_date,
		receive_date,
		ship_branch,
		receive_branch,
		concat(transfer_order,''.'',line_id) as transfer_order,
		null as cash_r,
		recv_status,
		null as jm,
		null as bill,
		null as ship,
		null as writer,
		null as create_user,
		null as inside,
		null as outside,
		abs(ext_ship) as total,
		datediff(dd,receive_date,getdate()) as agining,
		product_id,
		null as location, 
		null as location_qty,
		ship_qty,
		receive_qty,
		null as location_status,
		null as location_type,
		null as location_tag
	from dbo.transfer_disputes
union 
	/* Xfer Disputes - Recv */ 
	select 
		''Warehouse Maintenance Quality'' as category, 
		''Xfer Disputes - Recv'' as type,
		ship_date,
		receive_date,
		receive_branch,
		ship_branch,
		concat(transfer_order,''.'',line_id) as transfer_order,
		null as cash_r,
		recv_status,
		null as jm,
		null as bill,
		null as ship,
		null as writer,
		null as create_user,
		null as inside,
		null as outside,
		abs(ext_ship) as total,
		datediff(dd,receive_date,getdate()) as aging,
		product_id,
		null as location, 
		null as location_qty,
		ship_qty,
		receive_qty,
		null as location_status,
		null as location_type,
		null as location_tag
	from dbo.transfer_disputes
union
	/* OHB No Location */ 
	select
		''Warehouse Maintenance Quality'' as category, 
		''OHB No Location'' as type,
		aging_date,
		aging_date,
		branch_id,
		branch_id, 
		null as so_order,
		null as cash_r,
		null as recv_status,
		null as jm,
		null as bill_to,
		null as ship_to,
		null as writer,
		null as create_user,
		null as inside,
		null as outside,
		ext_avg_cost,
		aging_days,
		product_id,
		location,
		location_qty,
		null as ship_qty,
		null as recv_qty,
		location_status,
		location_type,
		location_tag
	from dbo.ohb_no_location
union
	/* Negative Qty Locations */ 
	select
		''Warehouse Maintenance Quality'' as category, 
		''Negative Qty Locations'' as type,
		aging_date,
		aging_date,
		branch_id,
		branch_id, 
		null as so_order,
		null as cash_r,
		null as recv_status,
		null as jm,
		null as bill_to,
		null as ship_to,
		null as writer,
		null as create_user,
		null as inside,
		null as outside,
		ext_avg_cost,
		aging_days,
		product_id,
		location,
		location_qty,
		null as ship_qty,
		null as recv_qty,
		location_status,
		location_type,
		location_tag
	from dbo.negative_qty_location

) as sub', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [branch_maintenance_scorecard]    Script Date: 4/25/2023 10:35:13 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'branch_maintenance_scorecard', 
		@step_id=11, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=1, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'create table dbo.bms (
	category nvarchar(max),
	[type] nvarchar(max),
	branch_id nvarchar(max),
	total_amount decimal(18,2),
	branch_total decimal(18,2),
	corp_median decimal(18,2),
	quality decimal(18,2),
	goal int
	)
insert into dbo.bms

	/* Invoice Preview Queue Quality */ 
	select 
		''Branch Maintenance Quality'' as cat,
		''Invoice Preview Queue'' as type,
		branch_id collate SQL_Latin1_General_CP1_CI_AS as branch_id,
		isnull(current_ipq,0) as total_amount,
		isnull(current_days,0) as branch_total,
		max(median) over() as corp_median,
		isnull(ipq_quality,100) as quality,
		85 as goal
	from dbo.invoice_preview_queue_quality as q 
		right join eclipse.branch as b on b.branch_id = q.ship_branch collate SQL_Latin1_General_CP1_CI_AS
union
	/* Cashbox Quality */
	select 
		''Branch Maintenance Quality'' as category,
		''Cashbox'' as type,
		b.branch_id collate SQL_Latin1_General_CP1_CI_AS,
		isnull(open_cash_box,0) as open_cash_box,
		isnull(number_cleared_days,0) as numb_days_cleared,
		isnull(total_days,0) as total_days,
		isnull(percent_of_days_cleared,100) as percent_of_cleared,
		85 as goal
	from dbo.cash_box_quality as q 
		right join eclipse.branch as b on b.branch_id = q.branch_id collate SQL_Latin1_General_CP1_CI_AS
union
	/* Open Sales Order Quality */ 
	select 
		''Open Order Quality'' as cat,
		''Open Sales Orders'' as type,
		b.branch_id collate SQL_Latin1_General_CP1_CI_AS,
		isnull(sales_total,0),
		isnull(open_order_days,0),
		max(median) over(),
		isnull(open_sales_quality,100),
		85 as goal
	from dbo.open_sales_order_quality as q 
		right join eclipse.branch as b on b.branch_id = q.ship_branch collate SQL_Latin1_General_CP1_CI_AS
union 
	/* Open Sales Order Return Quality */
	select	
		''Open Order Quality'' as cat,
		''Open Sales Order Returns'' as type,
		b.branch_id collate SQL_Latin1_General_CP1_CI_AS,
		isnull(open_returns,0),
		isnull(return_days,0),
		max(median) over(),
		isnull(open_return_quality,100),
		85 as goal
	from dbo.sales_order_return_quality as q 
		right join eclipse.branch as b on b.branch_id = q.ship_branch collate SQL_Latin1_General_CP1_CI_AS
union
	/* Open Purchase Orders */
	select 
		''Open Order Quality'' as cat,
		''Open Purchase Orders'' as type,
		b.branch_id collate SQL_Latin1_General_CP1_CI_AS,
		isnull(subtotal_amount,0),
		isnull(po_days,0),
		max(median) over(),
		isnull(open_po_quality,100),
		85 as goal
	from dbo.open_purchase_order_quality as q 
		right join eclipse.branch as b on b.branch_id = q.receive_branch collate SQL_Latin1_General_CP1_CI_AS
union
	/* Open Purchase Order Returns */
	select 
		''Open Order Quality'' as cat,
		''Open Purchase Order Returns'' as type,
		b.branch_id collate SQL_Latin1_General_CP1_CI_AS,
		isnull(subtotal_amount,0),
		isnull(po_days,0),
		max(median) over(),
		isnull(open_po_quality,100),
		85 as goal
	from dbo.open_purchase_order_return_quality as q 
		right join eclipse.branch as b on b.branch_id = q.receive_branch collate SQL_Latin1_General_CP1_CI_AS
union
	/* Return Goods Queue */
	select 
		''Warehouse Maintenance Quality'' as cat,
		''Return Goods Queue'' as type,
		b.branch_id collate SQL_Latin1_General_CP1_CI_AS,
		isnull(total_rgq,0),
		rgq_days as branch_total,
		median,
		isnull(rgq_quality,100),
		85 as goal
	from dbo.return_goods_quality as q 
		right join eclipse.branch as b on b.branch_id = q.branch_id collate SQL_Latin1_General_CP1_CI_AS
union
	/* PO Variance */ 
	select 
		''Branch Maintenance Quality'' as cat,
		''PO Variance Queue'' as type,
		b.branch_id collate SQL_Latin1_General_CP1_CI_AS,
		isnull(total_variance,0),
		isnull(po_variance_days,0),
		max(po_variance_median) over(),
		isnull(quality,100),
		85 as goal 
	from dbo.po_variance_quality as q 
		right join eclipse.branch as b on b.branch_id = q.ship_branch collate SQL_Latin1_General_CP1_CI_AS
union
	/* Xfer Shipped Not Received RECV Branch */
	select 
		''Warehouse Maintenance Quality'' as cat,
		''Xfer Shipped Not Received - Recv'' as type,
		b.branch_id collate SQL_Latin1_General_CP1_CI_AS,
		isnull(recv_total,0),
		isnull(recv_days,0),
		max(median) over(),
		isnull(transfer_shipped_not_received_quality,0),
		85 as goal
	from dbo.transfers_shipped_not_received_recv_quality as q 
		right join eclipse.branch as b on b.branch_id = q.receive_branch collate SQL_Latin1_General_CP1_CI_AS
union
	/* Xfer Shipped Not Received SHIP Branch */ 
	select 
		''Warehouse Maintenance Quality'' as cat,
		''Xfer Shipped Not Received - Ship'' as type,
		b.branch_id collate SQL_Latin1_General_CP1_CI_AS,
		isnull(ship_total,0),
		isnull(recv_days,0),
		max(median) over(),
		isnull(transfers_shipped_not_received_quality,100),
		85 as goal 
	from dbo.transfers_shipped_not_received_ship_quality as q
		right join eclipse.branch as b on b.branch_id = q.ship_branch collate SQL_Latin1_General_CP1_CI_AS
union  
	/* Xfer Dispute Recv Branch */
	select 
		''Warehouse Maintenance Quality'' as cat,
		''Xfer Disputes - Recv'' as type,
		b.branch_id collate SQL_Latin1_General_CP1_CI_AS,
		isnull(ext_recv_amount,0),
		isnull(xfer_recv_dispute_days,0),
		max(xfer_recv_dispute_median) over(),
		isnull(xfer_recv_dispute_quality,100),
		85 as goal
	from dbo.transfer_dispute_recv_quality as q
		right join eclipse.branch as b on b.branch_id = q.recv_branch collate SQL_Latin1_General_CP1_CI_AS 
union
	/* Xfer Dispute Ship Branch */ 
	select 
		''Warehouse Maintenance Quality'' as cat,
		''Xfer Disputes - Ship'' as type,
		b.branch_id collate SQL_Latin1_General_CP1_CI_AS,
		isnull(ext_ship_amount,0),
		isnull(xfer_ship_dispute_days,0),
		max(xfer_ship_dispute_median) over(),
		isnull(xfer_ship_dispute_quality,100),
		85 as goal
	from dbo.transfer_dispute_ship_quality as q
		right join eclipse.branch as b on b.branch_id = q.ship_branch collate SQL_Latin1_General_CP1_CI_AS 
union
	/* COD Open Balance */ 
	select 
		''Branch Maintenance Quality'' as cat,
		''COD Open Balance'' as type,
		b.branch_id,
		isnull(open_balance,0),
		isnull(open_cod_days,0),
		max(median) over(),
		isnull(open_cod_quality,100),
		85 as goal
	from dbo.open_cod_quality as q 
		right join eclipse.branch as b on b.branch_id = q.branch_id collate SQL_Latin1_General_CP1_CI_AS 
union
	/* OHB No Location */
	select
		''Warehouse Maintenance Quality'' as cat,
		''OHB No Location'' as type,
		l.branch_id,
		ISNULL(ohb_no_loc_total,0) as no_location_total,
		ISNULL(inv_days,0) as inv_days,
		MAX(median) over(),
		ISNULL(ohb_no_loc_quality,100),
		85 as goal
	from dbo.ohb_no_location_quality as l 
union
	/* Negative Qty Location */ 
	select
		''Warehouse Maintenance Quality'' as cat,
		''Negative Qty Locations'' as type,
		n.branch_id,
		isnull(n.ohb_total,0) as ohb_total,
		isnull(n.inv_day,0) as inv_day,
		max(n.median) over(),
		ISNULL(negative_location_quality,100),
		85 as goal
	from dbo.negative_location_quality as n 


/* Cycling through score card again to add the avg_day for each category. dv 11/15/21 */

drop table dbo.branch_maintenance_scorecard
create table dbo.branch_maintenance_scorecard (
	category nvarchar(max),
	[type] nvarchar(max),
	branch_id nvarchar(max),
	total_amount decimal(18,2),
	branch_total decimal(18,2),
	corp_median decimal(18,2),
	quality decimal(18,2),
	goal int,
	avg_day decimal(18,2)
	)
insert into dbo.branch_maintenance_scorecard

/* dbo.o from open sales order quality - 365 Day Sales - Invoice Preview Queue and Open Sales Orders */
	select 
		b.*,
		o.avg_day
	from dbo.bms as b
		left join dbo.o on o.ship_branch = b.branch_id
	where type in (''Invoice Preview Queue'',''Open Sales Orders'')

union

/* dbo.recv from open_purchase_orders and quality - 365 Receiving Total: Open Purchase Orders and PO Variance Queue */
	select 
		b.*,
		recv.avg_day
	from dbo.bms as b
		left join dbo.recv on recv.receive_branch = b.branch_id
	where type in (''Open Purchase Orders'',''PO Variance Queue'',''Open Purchase Order Returns'') 

Union

/* 365 COD Sales - Cod Open Balance */ 
	select 
		b.*
		, (select [total] from dbo.cod where cod.ship_branch = b.branch_id) as total
	from dbo.bms as b 
	where [type] = ''COD Open Balance''
	
union

-- dbo.r from open_sales_order_return quality job 
	select 
		b.*,
		[365_day_returns]/cast(365 as float) as avg_day
	from dbo.bms as b
		left join dbo.r on r.ship_branch = b.branch_id
	where [type] = ''Open Sales Order Returns''

union

-- dbo.rgq from return_goods_queue_quality job
	select 
		b.*,
		rgq.total_inv as avg_day
	from dbo.bms as b
		left join dbo.rgq on rgq.branch_id = b.branch_id
	where [type] = ''Return Goods Queue''

union

--Xfer Disputes - Ship
	select 
		b.*,
		xs.total/cast(365 as float) as avg_day
	from dbo.bms as b 
		left join dbo.xs on xs.ship_branch = b.branch_id
	where [type] = ''Xfer Disputes - Ship''

union

--XXfer Shipped Not Received - Ship
	select 
		b.*,
		xs.total/cast(365 as float) as avg_day
	from dbo.bms as b 
		left join dbo.xs on xs.ship_branch = b.branch_id
	where [type] = ''Xfer Shipped Not Received - Ship''

union

--Xfer Disputes - Recv
	select 
		b.*,
		xr.total/cast(365 as float) as avg_day
	from dbo.bms as b 
		left join dbo.xr on xr.receive_branch = b.branch_id
	where [type] = ''Xfer Disputes - Recv''

union

--Xfer Shipped Not Received - Recv
	select 
		b.*,
		xr.total/cast(365 as float) as avg_day
	from dbo.bms as b 
		left join dbo.xr on xr.receive_branch = b.branch_id
	where [type] = ''Xfer Shipped Not Received - Recv''

union

--OHB No Location
	select 
		b.*,
		xr.total/cast(365 as float) as avg_day
	from dbo.bms as b 
		left join dbo.xr on xr.receive_branch = b.branch_id
	where [type] = ''OHB No Location''

union

--Negative Qty Locations
	select 
		b.*,
		xr.total/cast(365 as float) as avg_day
	from dbo.bms as b 
		left join dbo.xr on xr.receive_branch = b.branch_id
	where [type] = ''Negative Qty Locations''






drop table dbo.bms', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'branch_maint_reports', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20211013, 
		@active_end_date=99991231, 
		@active_start_time=220000, 
		@active_end_time=235959, 
		@schedule_uid=N'4ab05030-02ef-4bd9-8497-0f7ebc562ca1'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


