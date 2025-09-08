USE [msdb]
GO

/****** Object:  Job [dsg_ledger_file]    Script Date: 4/25/2023 10:35:54 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 4/25/2023 10:35:54 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'dsg_ledger_file', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'creating tables from ledger file', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'domvicc', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [purchase_order]    Script Date: 4/25/2023 10:35:55 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'purchase_order', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DROP TABLE dbo.purchase_order

CREATE TABLE dbo.purchase_order (
	purchase_order_line_generation_id NVARCHAR(255) PRIMARY KEY,
	receive_date DATE,
	order_date DATE,
	region NVARCHAR(255),
	receive_branch VARCHAR(10),
	order_type VARCHAR(10),
	pay_to_id INT,
	ship_from_id INT,
	vendor_name NVARCHAR(255),
	ad_vendor NVARCHAR(255),
	[purchase_order_invoice] NVARCHAR(255),
	[product_stock_status] NVARCHAR(255),
	[segment] NVARCHAR(255),
	buy_line_id NVARCHAR(255),
	price_line_id NVARCHAR(255),
	line_id INT,
	product_id INT,
	[product_pescription] NVARCHAR(255),
	receive_qty INT,
	price DECIMAL(18,3),
	[ext_price] DECIMAL(18,3),
	discount_amount DECIMAL(18,3),
	freight_in_billable DECIMAL(18,3),
	freight_in_expense DECIMAL(18,3),
	[invoice_count] INT,
	[line_count] INT,
	[return_flag] INT,
	[lead_time] INT
)

INSERT INTO dbo.purchase_order

SELECT
	polg.purchase_order_line_generation_id,
	pog.receive_date,
	pog.order_date,
	b.[region],
	pog.receive_branch,
	pog.order_type,
	pog.pay_to_id,
	pog.ship_from_id,
	v.[vendor_name],
	v.[ad_vendor],
	CONCAT(pog.eclipse_id,''.'',FORMAT(invoice_number,''000'')) AS ''purchase_order_invoice'',
	sps.description AS ''product_stock_status'',
	p.select_code AS ''segment'',
	p.buy_line_id,
	p.price_line_id,
	polg.line_id,
	p.product_id,
	CAST(p.description AS NVARCHAR(50)) AS ''product_description'',
	polg.receive_qty,
	polg.price,
	(
		SELECT SUM(gl_amount)
		FROM eclipse.purchase_order_line_generation_gl_posting glp
		/* 
		66 Purchases
		95 Restocking Charges
		102 Consignment Purchases
		410 Cutting Charges
		153 Rebate Clearing
		307 Sales Allowance (Labor Credit)
		68 Handling Fee
		*/
		WHERE gl_account IN (66, 95, 102, 410, 153, 307, 68) AND glp.eclipse_id = pog.eclipse_id AND glp.purchase_order_line_generation_id = polg.purchase_order_line_generation_id
	) AS ''ext_price'',  
	
	pog.discount_amount,
	pog.freight_in_billable,
	pog.freight_in_expense,
	CASE
		WHEN ROW_NUMBER() OVER(PARTITION BY pog.eclipse_id,pog.generation_id ORDER BY polg.line_id) = 1 THEN 1 ELSE 0
	END AS ''invoice_count'',
	''1'' AS ''line_count'',
	IIF(polg.receive_qty < 0, 1, 0) AS ''return_flag'',
	DATEDIFF(DD,pog.order_date,pog.receive_date) AS ''lead_time''
FROM eclipse.purchase_order_generation pog
	LEFT JOIN eclipse.purchase_order_line_generation polg
		ON pog.eclipse_id = polg.eclipse_id AND pog.generation_id = polg.generation_id
	LEFT JOIN eclipse.product p
		ON p.eclipse_id = polg.product_id
	LEFT JOIN eclipse.system_product_status sps
		ON sps.system_product_status_id = p.product_status_id
	LEFT JOIN (
			SELECT 
				CASE 
					WHEN UPPER(SUBSTRING(name, CHARINDEX(''-AD'', name)+3, 999)) LIKE ''%PL%'' THEN ''PLUMBING''
					WHEN UPPER(SUBSTRING(name, CHARINDEX(''-AD'', name)+3, 999)) LIKE ''%EL%'' THEN ''ELECTRICAL''
					WHEN UPPER(SUBSTRING(name, CHARINDEX(''-AD'', name)+3, 999)) LIKE ''%HV%'' THEN ''HVAC''
					WHEN UPPER(SUBSTRING(name, CHARINDEX(''-AD'', name)+3, 999)) LIKE ''%PVF%'' THEN ''PVF''
					WHEN UPPER(SUBSTRING(name, CHARINDEX(''-AD'', name)+3, 999)) LIKE ''%DEC%'' THEN ''DECORATIVE''
					WHEN UPPER(SUBSTRING(name, CHARINDEX(''-AD'', name)+3, 999)) = '' '' THEN ''ELECTRICAL''
					ELSE UPPER(SUBSTRING(name, CHARINDEX(''-AD'', name), 999))
				END AS ''ad_vendor'',
				eclipse_id,
				name AS ''vendor_name'',
				name_index,
				consigned_inventory_flag
			FROM eclipse.vendor v
		) AS v
		ON pog.pay_to_id = v.eclipse_id
	LEFT JOIN (
			SELECT 
				branch_entity_id,
				eclipse_id AS ''branch'',
				CASE
					WHEN branch_id = ''NESC'' THEN ''SOUTH DAKOTA''
					WHEN branch_id = ''WIN'' THEN ''WISCONSIN''
					WHEN RIGHT(long_description,2) = ''MI'' THEN ''MICHIGAN''
					WHEN RIGHT(long_description,2) = ''MT'' THEN ''MONTANA''
					WHEN RIGHT(long_description,2) = ''ND'' THEN ''NORTH DAKOTA''
					WHEN RIGHT(long_description,2) = ''SD'' THEN ''SOUTH DAKOTA''
					WHEN RIGHT(long_description,2) = ''MN'' THEN ''MINNESOTA''
					WHEN RIGHT(long_description,2) = ''WI'' THEN ''WISCONSIN''
					WHEN RIGHT(long_description,2) = ''NE'' THEN ''NEBRASKA''
					WHEN RIGHT(long_description,2) = ''IA'' THEN ''IOWA''
				END AS ''region'',
				short_description AS ''city'',
				long_description AS ''city_state''
			FROM eclipse.branch
			WHERE is_stocking_branch > 0
		) AS b
		ON pog.receive_branch = b.[branch]
WHERE receive_date BETWEEN ''2022-01-01'' AND GETDATE()
	AND status_code = ''R''
	AND polg.purchase_order_line_generation_id IS NOT NULL
	-- AND gl_branch = ''PLY''

CREATE INDEX idx_receive_branch ON dbo.purchase_order (receive_branch)
CREATE INDEX idx_purchase_order ON dbo.purchase_order ([purchase_order_invoice])
CREATE INDEX idx_buy_line_id ON dbo.purchase_order (buy_line_id)

--CREATE INDEX idx_generation_id ON eclipse.purchase_order_generation( generation_id)
--CREATE INDEX idx_generation_id ON eclipse.purchase_order_line_generation (generation_id)
--CREATE INDEX idx_generation_id ON eclipse.purchase_order_generation_gl_posting (generation_id)', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [sales_order]    Script Date: 4/25/2023 10:35:55 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'sales_order', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.sales_order

create table dbo.sales_order (
	sales_order_line_generation_id nvarchar(255) primary key,
	ship_date date,
	order_date date,
	region nvarchar(255),
	ship_branch varchar(10),
	bill_to_id int,
	ship_to_id int,
	customer_name nvarchar(255),
	sales_order_number nvarchar(255),
	product_stock_status nvarchar(255),
	segment nvarchar(255),
	buy_line nvarchar(255),
	price_line nvarchar(255),
	order_status nvarchar(255),
	ship_via nvarchar(255),
	terms_code nvarchar(255),
	line_id int,
	customer_part_number nvarchar(255),
	price_class nvarchar(255),
	price_group nvarchar(255),
	product_id int,
	product_description nvarchar(255),
	sales_source nvarchar(255),
	ship_qty int,
	price decimal(18,3),
	price_matrix nvarchar(255),
	cogs decimal(18,3),
	cost decimal(18,3),
	EXT_price decimal(18,3),
	line_count nvarchar(25),
	freight_in_billable decimal(18,10),
	freight_in_expense decimal(18,10),
	freight_out_billable decimal(18,10),
	freight_out_expense decimal(18,10),
	return_flag int,
	is_manual_cogs_override bit,
	is_manual_cost_override bit,
	is_manual_price_override bit,
	cost_override_code nvarchar(255),
	direct_flag bit
)

insert into dbo.sales_order

select
	solg.sales_order_line_generation_id,
	sog.ship_date,
	sog.order_date,
	b.region,
	sog.ship_branch as branch, 
	sog.bill_to_id,
	sog.ship_to_id,
	c.name as customer_name,
	concat(sog.eclipse_id, ''.'',format(sog.invoice_number, ''000'')) as sales_order_number, 
	sps.description as product_stock_status,
	p.select_code as segment,
	p.buy_line_id as buy_line,
	p.price_line_id as price_line,
	ss.description as order_status,
	sog.ship_via,
	sog.terms_code,
	solg.line_id,
	solg.customer_part_number,
	solg.price_class,
	solg.price_group,
	p.product_id,
	cast(p.description as nvarchar(50)) as product_description,
	sog.sales_source,
	solg.ship_qty,
	solg.price,
	solg.price_matrix,
	solg.cogs,
	solg.cost,
	price * solg.ship_qty as EXT_price,
	''1'' as line_count,
	sog.freight_in_billable,
	sog.freight_in_expense,
	sog.freight_out_billable,
	sog.freight_out_expense,
	iif(solg.ship_qty < 0, 1, 0) as return_flag,
	solg.is_manual_cogs_override,
	solg.is_manual_cost_override,
	solg.is_manual_price_override,
	solg.cost_override_code,
	iif(direct_generation_xref >= 1,1,0) as direct_flag
from eclipse.sales_order_generation as sog
	left join eclipse.sales_order_line_generation as solg
		on solg.sales_order_id = sog.eclipse_id and solg.generation_id = sog.generation_id
	left join eclipse.product p
		on p.eclipse_id = solg.product_id
	left join eclipse.system_product_status as sps
		on sps.system_product_status_id = p.product_status_id
	left join eclipse.customer as c
		on sog.ship_to_id = c.eclipse_id
	left join eclipse.system_sales_order_status as ss
		on sog.status_code = ss.system_sales_order_status_id
	left join (
		select 
			branch_entity_id,
			branch_id,
			ship_branch_region as region,
			city,
			long_description as city_state
		from dbo.branch
	) as b 
		on ship_branch = b.branch_id COLLATE SQL_Latin1_General_CP1_CS_AS
where sog.status_code = ''I''
	and ship_branch NOT IN (''CORP'')
    and ship_date between ''2020-01-01'' and eomonth(getdate())
    and isnull(sales_source, ''x'') <> ''SR''
	and sales_order_line_generation_id is not null 
	and not exists (
		select p.product_gl_type
		from eclipse.product p
		where p.eclipse_id = solg.product_id
			and p.product_gl_type in (
				''25'',''374'',''4'',''111'',''116'',''253'',''254'',''26'',''72'',''131'',''132'',''153'',''115'',
				''398'',''95'',''338'',''238'',''61'',''196'',''158'',''198'',''107'',''199'',''60'',''391'',''308'',
				''307'',''193'',''377'',''369'',''263'',''189'',''414''
			)
	)', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [ap_payable_history]    Script Date: 4/25/2023 10:35:55 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'ap_payable_history', 
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
if exists (select * from INFORMATION_SCHEMA.TABLES where table_name = ''ap_payable_history'') drop table dbo.product_branch_calculation_eda

select   
 ap.eclipse_id as cash_distribution_id,
 b.reference_number as bank_check_number,
 ap.transaction_ar_id as payable_id,
 iif(p.invoice_date > dateadd(dd,1000,getdate()),dateadd(dd,730,getdate()),isnull(p.invoice_date,getdate())) as invoice_date,
 applied_date as paid_on_date,
 iif(p.due_date > dateadd(dd,1000,getdate()),dateadd(dd,730,getdate()),isnull(p.due_date,getdate())) as due_date,
 replace(pay_date.pay_date,''0201-02-25'',''2015-01-01'') as pay_date,
 p.price_branch,
 p.pay_to_id,
 v.name,
 vc.ad_number,
 vc.exp_inv,
 p.reference_number as vendor_invoice,
 isnull(replace(v.default_terms,''²'',''''),p.terms_code) as terms_code, 
  cast(isnull(dis.discount_amount,0) as decimal(18,2)) as discount_amount,
 cast(isnull(ded.deduction_amount,0) as decimal(18,2)) as deduction_amount,
 cast(p.invoice_amount as decimal(18,2)) as invoice_amount,

  /* Invoice amount greater than zero & applied date is less then or equal to due date*/ 
 cast(iif(isnull(ap.applied_date,b.invoice_date) <= p.due_date and invoice_amount > 0 , (p.invoice_amount - isnull(f.gl_amount,0)) * dp.discount_percent,0) as decimal(18,2)) as vendor_terms_discount_amount,
 cast(cast(isnull(dis.discount_amount,0) as decimal(18,2)) - cast(iif(applied_date <= p.due_date and invoice_amount > 0 , (p.invoice_amount - isnull(f.gl_amount,0)) * dp.discount_percent,0) as decimal(18,2)) as decimal(18,2)) as actual_discount_vs_terms,
 cast(isnull(f.gl_amount,0) as decimal(18,2)) as freight,
 iif(p.terms_code = ''VSPECIAL'',1,0) as vspecial_flag,
 /* Paid late flag = cash disb. invoice date as the "Paid On Date" of payable, comparing to due date of payable */ 
 iif(p.due_date >= isnull(ap.applied_date,b.invoice_date),0,1) as paid_late_flag,
 iif(p.reference_number like ''%DISC%'',1,0) as discount_payback_flag,
 ''1'' as vendor_invoice_count,
 /* flaging SQD directs where the Y payable is associated with a "S" sales order number on the cash disbursement */ 
 case when (  select 
     sum(case when ship_from_id = 27249 and left(transaction_ar_id,1) = ''S'' then 1 end) as sqd_flag
     from eclipse.accrual_register_applied_payment  as arap
     where arap.eclipse_id = ap.transaction_ar_id
     group by arap.eclipse_id
     ) > 0 then ''SQD Direct''
   else ''Normal''
   end as ''SQD Directs''
into dbo.ap_payable_history
from eclipse.accrual_register_applied_payment as ap
  left join eclipse.accrual_register as ar on ar.eclipse_id = ap.transaction_ar_id
  left join eclipse.payable as p on p.eclipse_id = left(ap.transaction_ar_id,10)
  left join eclipse.vendor as v on v.eclipse_id = ap.ship_from_id
  left join eclipse.accrual_register_deduction as ded on ded.eclipse_id = ap.transaction_ar_id
  left join eclipse.accrual_register_discount as dis on dis.eclipse_id = ap.transaction_ar_id
  left join eclipse.accrual_register_pay_date as pay_date on pay_date.eclipse_id = ap.transaction_ar_id
  left join eclipse_ud.vendor_class as vc on vc.eclipse_id = v.vendor_id and vc.eclipse_id not in (''3879,'',''#N/A'')
  /* cash disbursement pull to add "Paid On Data" from the payable */
  left join (
     select *
     from eclipse.accrual_register
     where cash_disbursement_id is not null and left(reference_number,4) <> ''VOID''
   ) as b on b.eclipse_id = ap.eclipse_id
  /*   Freight   */
  left join (
     select 
     eclipse_id,
     sum(gl_amount) as gl_amount
     from eclipse.payable_gl_posting as p
     where p.gl_account = 64  
     group by eclipse_id 
   ) as f on f.eclipse_id = p.eclipse_id
  /* Default Terms Percent Multiplier */ 
  left join (
     select distinct 
      t.eclipse_id,
 case when t.eclipse_id = ''V1.590D'' then ''.015''
   when t.eclipse_id = ''V315D/345D'' then ''.03''
   else isnull((tp.discount_percentage)/100,0)
   end as discount_percent
     from eclipse.terms as t 
      left join eclipse.terms_period as tp on tp.eclipse_id = t.eclipse_id
   ) as dp on dp.eclipse_id = isnull(replace(v.default_terms,''²'',''''),p.terms_code)
/* Filtering on "D" disbursements from accrual_register_applied_payment */
where left(ap.eclipse_id,1) = ''D'' and ap.transaction_ar_id is not null and b.reference_number is not null 
 


 

', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [sales_tax_analysis]    Script Date: 4/25/2023 10:35:55 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'sales_tax_analysis', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.sales_tax_analysis

create table dbo.sales_tax_analysis (
	ship_date date,
	ship_branch nvarchar(15),
	ship_via nvarchar(75),
	ship_via_tax nvarchar(75),
	bill_to_id int,
	ship_to_id int,
	sales_order nvarchar(255),
	shipping_address nvarchar(255),
	shipping_city nvarchar(255),
	shipping_state nvarchar(25),
	postal_code nvarchar(50),
	po_box_flag int,
	freight_in decimal(28,6),
	freight_out decimal(28,6),
	sales_total decimal(28,6),
	tax_total decimal(28,6),
	tax_exempt_code nvarchar(255),
	tax_exempt_id nvarchar(255),
	tax_exempt_override int,
	tax_jurisdiction nvarchar(255),
	tax_rate int,
	avalara_freight_rate nvarchar(255),
	avalara_total_tax int,
	avalara_total_amount_taxable int,
	avalara_juridiction_tax_amount nvarchar(255),
	avalara_juridiction_taxable_amount nvarchar(255),
	avalara_juridiction_type nvarchar(255),
	avalara_juridiction_name nvarchar(255),
	avalara_juridiction_tax_name nvarchar(255),
	avalara_destination_address nvarchar(255),
	avalara_source_address nvarchar(255),
	avalara_tax_committed int
)

insert into dbo.sales_tax_analysis

select 
	sog.ship_date,
	sog.ship_branch,
	sog.ship_via,
	s.tax_jurisdiction as ship_via_tax, 
	sog.bill_to_id,
	sog.ship_to_id,
	concat(sog.eclipse_id,''.'',format(sog.invoice_number,''000'')) as sales_order,
	replace(sog.shipping_address_line1,''"SHIP TO ADDRESS IS DIFFERENT EACH'',''SHIP TO ADDRESS IS DIFFERENT EACH'') as shipping_address, 
	sog.shipping_city,
	sog.shipping_state,
	sog.postal_code,
	case when upper(shipping_address_line1) like ''%PO BOX%'' then 1 
		when upper(shipping_address_line1) like ''%P.O.%'' then 1 
		when upper(shipping_address_line1) like ''%P O %'' then 1 
		else 0
		end as ''PO Box Flag'',
	isnull(sog.freight_in_billable + sog.freight_in_expense,0) as frieight_in,
	isnull(sog.freight_out_billable + sog.freight_out_expense,0) as frieght_out,
	sog.sales_total,
	sog.tax_total,
	sog.tax_exempt_code,
	sog.tax_exempt_id,
	sog.tax_exempt_override,
	sog.tax_jurisdiction,
	sog.tax_rate,
	solg.avalara_freight_rate,
	solg.avalara_total_tax,
	solg.avalara_total_amount_taxable,
	replace(solg.avalara_juridiction_tax_amount,''v'','' '') as avalara_juridiction_tax_amount,
	replace(solg.avalara_juridiction_taxable_amount,''v'','' '') as avalara_juridiction_taxable_amount,
	replace(solg.avalara_juridiction_type,''v'','' '') as avalara_juridiction_type,
	replace(solg.avalara_juridiction_name,''v'','' '') as avalara_juridiction_name,
	replace(solg.avalara_juridiction_tax_name,''v'','' '') as avalara_juridiction_tax_name,
	replace(solg.avalara_destination_address,''v'','' '') as avalara_destination_address,
	replace(solg.avalara_source_address,''v'','' '') as avalara_source_address,
	solg.avalara_tax_committed
from eclipse.sales_order_generation as sog
	left join eclipse.sales_order_log_generation as solg on solg.eclipse_id = sog.eclipse_id and solg.sales_order_log_generation_id = sog.sales_order_generation_id
	left join eclipse.ship_via as s on s.eclipse_id = sog.ship_via
where status_code = ''I'' and ship_date >= cast(concat(datepart(yyyy,getdate())-1,''-01-01'') as date)
', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [transfer_order]    Script Date: 4/25/2023 10:35:55 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'transfer_order', 
		@step_id=5, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'create table dbo.received_transfer_orders (
	transfer_order_line_generation_id nvarchar(255),
	transfer_order_number nvarchar(255),
	receive_date date,
	order_date date,
	receive_branch nvarchar(25),
	region nvarchar(255),
	segment nvarchar(255),
	product_stock_status nvarchar(255),
	buy_line_id nvarchar(255),
	price_line_id nvarchar(255),
	order_status nvarchar(255),
	ship_via nvarchar(255),
	terms_code nvarchar(255),
	line_id int,
	price_class nvarchar(255),
	receive_qty int,
	product_id int,
	product_description nvarchar(255),
	price decimal(18,3),
	ext_price decimal(18,3),
	price_matrix nvarchar(255),
	cogs decimal(18,3),
	cost decimal(18,3),
	is_manual_cogs_override bit,
	is_manual_cost_override bit,
	is_manual_price_override bit,
	cost_override_code nvarchar(255)
)

insert into dbo.received_transfer_orders

select distinct 
	tolg.transfer_order_line_generation_id,
	concat(tog.eclipse_id, ''.'',format(tog.invoice_number,''000'')) as transfer_order_number,
	tog.receive_date,
	tog.order_date,
	tog.receive_branch,
	b.region,
	p.select_code as segment,
	sps.description as product_stock_status,
	p.buy_line_id,
	p.price_line_id,
	ts.description as order_status,
	tog.ship_via,
	tog.terms_code,
	tolg.line_id,
	tolg.price_class,
	tolg.receive_qty,
	p.product_id,
	cast(p.description as nvarchar(50)) as product_description,
	 tolg.price, 
	tolg.price * tolg.receive_qty as ext_price,
	 tolg.price_matrix,
	 tolg.cogs,
	 tolg.cost,
	tolg.is_manual_cogs_override,
	tolg.is_manual_cost_override,
	tolg.is_manual_price_override,
	tolg.cost_override_code
from eclipse.transfer_order_generation as tog
left join eclipse.transfer_order_line_generation as tolg
	on tolg.eclipse_id = tog.eclipse_id
left join eclipse.product as p
	on p.eclipse_id = tolg.product_id
left join (
		select 
			branch_entity_id,
			eclipse_id as ''branch'',
			case
				when branch_id = ''NESC'' then ''SOUTH DAKOTA''
				when branch_id = ''WIN'' then ''WISCONSIN''
				when right(long_description,2) = ''MI'' then ''MICHIGAN''
				when right(long_description,2) = ''MT'' then ''MONTANA''
				when right(long_description,2) = ''ND'' then ''NORTH DAKOTA''
				when right(long_description,2) = ''SD'' then ''SOUTH DAKOTA''
				when right(long_description,2) = ''MN'' then ''MINNESOTA''
				when right(long_description,2) = ''WI'' then ''WISCONSIN''
				when right(long_description,2) = ''NE'' then ''NEBRASKA''
				when right(long_description,2) = ''IA'' then ''IOWA''
			end as ''region'',
			short_description as ''city'',
			long_description as ''city_state''
		from eclipse.branch
		where is_stocking_branch > 0
	) as b
	on tog.receive_branch = b.branch
left join eclipse.system_product_status as sps
	on sps.system_product_status_id = p.product_status_id
left join eclipse.system_transfer_order_status as ts
	on tog.status_code = ts.system_transfer_order_status_id
where tolg.transfer_order_line_generation_id is not null and status_code <> ''X''
	and receive_qty is not null and receive_date is not null




create table dbo.shipped_transfer_orders (
	transfer_order_line_generation_id nvarchar(255),
	transfer_order_number nvarchar(255),
	ship_date date,
	order_date date,
	ship_branch nvarchar(25),
	region nvarchar(255),
	segment nvarchar(255),
	product_stock_status nvarchar(255),
	buy_line_id nvarchar(255),
	price_line_id nvarchar(255),
	order_status nvarchar(255),
	ship_via nvarchar(255),
	terms_code nvarchar(255),
	line_id int,
	price_class nvarchar(255),
	ship_qty int,
	product_id int,
	product_description nvarchar(255),
	price decimal(18,3),
	ext_price decimal(18,3),
	price_matrix nvarchar(255),
	cogs decimal(18,3),
	cost decimal(18,3),
	is_manual_cogs_override bit,
	is_manual_cost_override bit,
	is_manual_price_override bit,
	cost_override_code nvarchar(255)
)

insert into dbo.shipped_transfer_orders

select distinct 
	tolg.transfer_order_line_generation_id,
	concat(tog.eclipse_id, ''.'',format(tog.invoice_number,''000'')) as transfer_order_number,
	tog.ship_date,
	tog.order_date,
	tog.ship_branch,
	b.region,
	p.select_code as segment,
	sps.description as product_stock_status,
	p.buy_line_id,
	p.price_line_id,
	ts.description as order_status,
	tog.ship_via,
	tog.terms_code,
	tolg.line_id,
	tolg.price_class,
	tolg.ship_qty,
	p.product_id,
	cast(p.description as nvarchar(50)) as product_description,
	tolg.price,
	tolg.price * tolg.ship_qty as ext_price,
	tolg.price_matrix,
	tolg.cogs,
	tolg.cost,
	tolg.is_manual_cogs_override,
	tolg.is_manual_cost_override,
	tolg.is_manual_price_override,
	tolg.cost_override_code
from eclipse.transfer_order_generation as tog
left join eclipse.transfer_order_line_generation as tolg
	on tolg.eclipse_id = tog.eclipse_id
left join eclipse.product as p
	on p.eclipse_id = tolg.product_id
left join (
		select 
			branch_entity_id,
			eclipse_id as ''branch'',
			case
				when branch_id = ''NESC'' then ''SOUTH DAKOTA''
				when branch_id = ''WIN'' then ''WISCONSIN''
				when right(long_description,2) = ''MI'' then ''MICHIGAN''
				when right(long_description,2) = ''MT'' then ''MONTANA''
				when right(long_description,2) = ''ND'' then ''NORTH DAKOTA''
				when right(long_description,2) = ''SD'' then ''SOUTH DAKOTA''
				when right(long_description,2) = ''MN'' then ''MINNESOTA''
				when right(long_description,2) = ''WI'' then ''WISCONSIN''
				when right(long_description,2) = ''NE'' then ''NEBRASKA''
				when right(long_description,2) = ''IA'' then ''IOWA''
			end as ''region'',
			short_description as ''city'',
			long_description as ''city_state''
		from eclipse.branch
		where is_stocking_branch > 0
	) as b
	on tog.ship_branch = b.branch
left join eclipse.system_product_status as sps
	on sps.system_product_status_id = p.product_status_id
left join eclipse.system_transfer_order_status as ts
	on tog.status_code = ts.system_transfer_order_status_id
where tolg.transfer_order_line_generation_id is not null and status_code <> ''X'' 
	and ship_qty is not null and ship_date is not null


drop table dbo.transfer_orders

create table dbo.transfer_orders (
	transfer_order_line_generation_id nvarchar(255),
	transfer_order_number nvarchar(255),
	ship_date date,
	receive_date date,
	order_date date,
	ship_branch nvarchar(25),
	receive_branch nvarchar(25),
	region nvarchar(255),
	segment nvarchar(255),
	product_stock_status nvarchar(255),
	buy_line_id nvarchar(255),
	price_line_id nvarchar(255),
	order_status nvarchar(255),
	ship_via nvarchar(255),
	terms_code nvarchar(255),
	line_id int,
	price_class nvarchar(255),
	ship_qty int,
	receive_qty int,
	product_id int,
	product_description nvarchar(255),
	price decimal(18,3),
	price_matrix nvarchar(255),
	cogs decimal(18,3),
	cost decimal(18,3),
	ext_price decimal(18,3),
	line_count nvarchar(25),
	is_manual_cogs_override bit,
	is_manual_cost_override bit,
	is_manual_price_override bit,
	cost_override_code nvarchar(255)
)

insert into dbo.transfer_orders(transfer_order_line_generation_id, transfer_order_number, ship_date, order_date, ship_branch, region, segment, product_stock_status, buy_line_id, price_line_id, order_status, ship_via, terms_code, line_id, price_class, ship_qty, product_id, product_description, price, ext_price, price_matrix, cogs, cost, is_manual_cogs_override, is_manual_cost_override, is_manual_price_override, cost_override_code)

select *
from dbo.shipped_transfer_orders

drop table dbo.shipped_transfer_orders

insert into dbo.transfer_orders(transfer_order_line_generation_id, transfer_order_number, receive_date, order_date, receive_branch, region, segment, product_stock_status, buy_line_id, price_line_id, order_status, ship_via, terms_code, line_id, price_class, receive_qty, product_id, product_description, price, ext_price, price_matrix, cogs, cost, is_manual_cogs_override, is_manual_cost_override, is_manual_price_override, cost_override_code)

select * 
from dbo.received_transfer_orders

drop table dbo.received_transfer_orders', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [lost_sales]    Script Date: 4/25/2023 10:35:55 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'lost_sales', 
		@step_id=6, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
drop table dbo.lost_sales
select  
	sog.ship_date,
	b.ship_branch_region,
	sog.ship_branch,
	sog.bill_to_id,
	c.name,
	sog.eclipse_id,
	sog.invoice_number,
	sog.status_code,
	sog.internal_notes,
	p.price_line_id,
	p.select_code,
	solg.product_id,
	p.description,
	solg.ship_qty,
	solg.price,
	solg.price * solg.ship_qty as ext_price
	into dbo.lost_sales
from eclipse.sales_order_generation as sog
	left join eclipse.sales_order_line_generation as solg on solg.eclipse_id = sog.eclipse_id and solg.generation_id = sog.generation_id
	left join eclipse.product as p on p.eclipse_id = solg.product_id
	left join dbo.branch as b on b.branch_id = sog.ship_branch collate SQL_Latin1_General_CP1_CS_AS
	left join eclipse.customer as c on c.eclipse_id = sog.bill_to_id
where upper(c.name) like ''%LOST SALE%''
					 
 

', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [sales_order_credit_card_payments]    Script Date: 4/25/2023 10:35:55 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'sales_order_credit_card_payments', 
		@step_id=7, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.sales_order_credit_card_payments
select 
	concat(c.eclipse_id,''.'',format(invoice_number,''000'')) as sales_order_number,
	gl_date as ship_date,
	region,
	c.ship_branch,
	customer_name,
	c.bill_to_id,
	c.ship_to_id,
	ship_via,
	product_id,
	product_description,
	c.payment_amount_credit_card as EXT_price,
	freight_in_expense,
	freight_out_expense
	into dbo.sales_order_credit_card_payments
from eclipse.sales_order_payment as c 
	left join  dbo.sales_order as so on c.eclipse_id = left(so.sales_order_line_generation_id,10) collate SQL_Latin1_General_CP1_CI_AS
where payment_amount_credit_card is not null and so.product_id = 69539 /* Filtering field for only CC payment transactions also filtering dbo.sales_order to identify the product id 69539 payment on account*/

', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [sales_order_action_code]    Script Date: 4/25/2023 10:35:55 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'sales_order_action_code', 
		@step_id=8, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'drop table dbo.sales_order_action_code

create table dbo.sales_order_action_code (
	id nvarchar(255),
	action_date date,
	action_code nvarchar(25)
)

insert into dbo.sales_order_action_code

select 
	concat(sog.sales_order_id,''_'',solg.product_id,''_'',os.status_code,''_'',ship_via,''_'',os.ship_date) as id,
	sd.action_date,
	sd.action_code
from eclipse.open_sales_order as os
left join eclipse.sales_order_generation as sog
	on sog.eclipse_id = os.sales_order_id
left join eclipse.sales_order_line_generation as solg
	on solg.eclipse_id = sog.eclipse_id
left join eclipse.sales_order_log_generation_call_detail as sd
	on sd.sales_order_log_id = sog.eclipse_id
where os.status_code <> ''B''', 
		@database_name=N'EDW_dsgsupply_com_prod', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'ledger_file', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20221111, 
		@active_end_date=99991231, 
		@active_start_time=30000, 
		@active_end_time=235959, 
		@schedule_uid=N'b23e6b64-8cfc-461d-9e54-efc6ac070c55'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


