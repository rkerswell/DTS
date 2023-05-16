USE [InfoDB]
GO

/****** Object:  StoredProcedure [dbo].[sp_ssrs_P1577_rpa]    Script Date: 16/05/2023 17:36:47 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE procedure [dbo].[sp_ssrs_P1577_rpa]

/*      
##########################################################################      
File Name : Friends and Family ED data                                                                                                                                                                                                                         



Date      : 01/10/2022
Desc      :                                                                                                                                                                                                                                                    


Author    : Richard Kerswell
PCD       : Y      

--THIS MUST BE KEPT LOGICALLY THE SAME AS SP_SSRS_P1577

--sp_ssrs_p1577_rpa '01 Sep 2022','03 Sep 2022'
##########################################################################      
--	Ver		User    Date		Change      
--	1.0		RK		01/10/2022	Created
--	2.0		RK		23/10/2022	Amended to bring in line with main SP
--	2.1		PRK		30/11/2022	Removed CDU Lounge on Claire Juke's request via the Automation Team (Richard K)
##########################################################################      
*/ 

--declare
@dtmstartdate as datetime,
@dtmenddate as datetime

as

--declare @dtmstartdate as datetime
--declare @dtmenddate as datetime

--[sp_ssrs_P1577] '01 Jan 2022', '31 Jan 2022'
--here up
--set @dtmstartdate = '01 Jan 2022'
--set @dtmenddate = '31 Jan 2022'

set @dtmenddate = DATEADD(ss,-1,dateadd(dd,1,@dtmenddate))

select	nhs_number = nerve.NHSNumber
		,pasid = nerve.HospitalNumber
		,pat_forename = patnt.forename
		,pat_surname = patnt.Surname
		,arrvl_dttm = nerve.ArrivalDateTime
		,disch_dttm = nerve.DischargeDateTime
		,Area = 'A&E'
		,[Pat Tel no]=case when patnt.HomePhone like '07%' then patnt.HomePhone else isnull(patnt.MobilePhone,patnt.HomePhone) end
		,[Died During Visit]  =case when nerve.DischargeStatusDescription in ('Dead on arrival','Died in the Emergency Care facility') then 'Y' 
									else 'N' end
		,[Died at anytime] =Case when patnt.DateOfDeath		is not null then 'Y' else null end	
		,[Patient Date of Death] =Convert(date,patnt.DateOfDeath)	
into	#FFT											
from	[cl3-data].DataWarehouse.ed.vw_EDAttendance nerve
Left	join [cl3-data].AsclepeionODS.PASData.patient patnt with (nolock) on nerve.HospitalNumber=patnt.HospitalNumber
where	nerve.IsNewAttendance = 'y'
and		nerve.DischargeDateTime between @dtmstartdate and @dtmenddate
and		nerve.ActualDischargeDestinationwardcode not in ('rk950ob','rk050ed06')
and		nerve.DischargeDestinationDescription <> 'mortuary'
and		nerve.DischargeStatusDescription not in ('Dead on arrival','Died in the Emergency Care facility')
and		nerve.DischargeDestinationGroup <> 'admitted'


union all

select	 patnt.nhs_number
		,fces.pasid
		,fces.pat_forename
		,fces.pat_surname
		,fces.admit_dttm
		,fces.disch_dttm
		,case when left(wards.ward_desc,charindex(',',wards.ward_desc+',',0)-1) = 'SAU (Surgical Assessment Unit)' then 'Surgical Assessment Unit'
					else left(wards.ward_desc,charindex(',',wards.ward_desc+',',0)-1)
					end			
		,case when patnt.pat_telno like '07%' then patnt.pat_telno else isnull(patnt.pat_mobile,patnt.pat_telno) end as [Pat Tel no]
		,Case when dismt				= '4'		then 'Y' else null end	as [Died During Visit]--3.0 --select top 1000 * from pimsmarts.dbo.cset_dismt
		,Case when patnt.pat_dod		is not null then 'Y' else null end	as [Died at anytime]--3.0
		,Convert(date,patnt.pat_dod)										as [Patient Date of Death]--3.0
from	infodb.dbo.vw_ipdc_episode_start_pfmgt fces
left join PiMSMarts.dbo.cset_wards wards on fces.fce_end_ward=wards.identifier
Left join pimsmarts.dbo.patients as patnt on patnt.pasid = fces.pasid
where	fces.last_episode_in_spell = '1'
and		fces.disch_dttm between @dtmstartdate and @dtmenddate
--and		fces.pat_age_on_admit >15
and		fces.admet = '21'
and		(fces.fce_end_ward in ('rk950mau','rk950amw','rk950ob','rk950sau','rk950amb','rk95088',
								'rk95090','rk95094','rk950cau')
or		(fces.fce_end_ward = 'rk95085' and fces.disch_dttm >='01-dec-2013'))
and     fces.dismt <>'4'  -- deceased added 12/04/2013 NS - spoke with J Glynn


union all

select	 patnt.nhs_number
		,outpat.pasid
		,outpat.pat_forename
		,outpat.pat_surname
		,outpat.arrived_dttm
		,outpat.departed_dttm
		,'REI Walk In'
		,case when patnt.pat_telno like '07%' then patnt.pat_telno else isnull(patnt.pat_mobile,patnt.pat_telno) end as [Pat Tel no]
		,null as [Died During Visit] --3.0-- I dont think deaths during an ourpatient appointment is recorded
		,Case when patnt.pat_dod is not null then 'Y' else null end	as [Died at anytime]--3.0
		,Convert(date,patnt.pat_dod)										as [Patient Date of Death]--3.0
		
from PiMSMarts.dbo.outpatients outpat 
Left join pimsmarts.dbo.patients as patnt on patnt.pasid = outpat.pasid

where clinic_code in ('OPHCAEDF','OPHNAEDF')
and visitr = 'win'
and visit = '1'
and attnd = '5'
and arrived_dttm between @dtmstartdate  and @dtmenddate
--7571


Union all
-- Ver2.0 --RL addition as per ad hoc 21922
select 
	 Isnull(MIUAT.NHSNumber,patnt.nhs_number)
	,patnt.pasid
	,isnull(MIUAT.Forename, patnt.upper_Forename)
	,isnull(MIUAT.Surname, patnt.upper_surname)
	,MIUAT.ArrivalDateTime
	,MIUAT.DepartureDateTime
	,case	when LocationName = 'The Cumberland Centre - MIU' then 'Cumberland Centre'
			else LocationName
			end
	,case when patnt.pat_telno like '07%' then patnt.pat_telno else isnull(patnt.pat_mobile,patnt.pat_telno) end as [Pat Tel no]
	,null as [Died During Visit] --3.0 -- I dont think deaths during an miu attendances are recorded
	,Case when patnt.pat_dod		is not null then 'Y' else null end	as [Died at anytime] --3.0 
	,Convert(date,patnt.pat_dod)										as [Patient Date of Death] --3.0 
from [PiMSMarts].[dbo].[MIUAttendances]	as MIUAT
left join pimsmarts.dbo.patients		as patnt on patnt.nhs_number = MIUAT.NHSNumber
--where ArrivalDateTime between '01/01/2021' and '01/07/2021'
where ArrivalDateTime between @dtmstartdate	and @dtmenddate

--Final Output with cleaning of extra field for Mobile number
--To only show 07 prefixed numbers after taking out alpha chars
select	

		--[nhs_number]
		--,[pasid]
		--,[pat_forename]
		--,[pat_surname]
		[arrvl_dttm]
		--,[disch_dttm]
		,[Area]
		--,[Pat Tel no]
		--,[Died During Visit]
		--,[Died at anytime]
		--,[Patient Date of Death]
		--,[Cleaned Mobile Number] =	case when 
		--							len(case when left(tsqltoolbox.StringUtil.ReplaceNonNumericChars(REPLACE([Pat Tel no], ' ', '')), 2) = '07'
		--								then tsqltoolbox.StringUtil.ReplaceNonNumericChars(REPLACE([Pat Tel no], ' ', ''))
		--							else NULL
		--							end) = 11 then 
		--										(case when left(tsqltoolbox.StringUtil.ReplaceNonNumericChars(REPLACE([Pat Tel no], ' ', '')), 2) = '07'
		--											then tsqltoolbox.StringUtil.ReplaceNonNumericChars(REPLACE([Pat Tel no], ' ', ''))
		--										else NULL
		--										end)
		--							else NULL
		--							end
		,[Number for Email] =case when 
									len(case when left(tsqltoolbox.StringUtil.ReplaceNonNumericChars(REPLACE([Pat Tel no], ' ', '')), 2) = '07'
										then tsqltoolbox.StringUtil.ReplaceNonNumericChars(REPLACE([Pat Tel no], ' ', ''))
									else NULL
									end) = 11 then 
												(case when left(tsqltoolbox.StringUtil.ReplaceNonNumericChars(REPLACE([Pat Tel no], ' ', '')), 2) = '07'
													then tsqltoolbox.StringUtil.ReplaceNonNumericChars(REPLACE([Pat Tel no], ' ', ''))
												else NULL
												end)
									else NULL
									end
							+ '' + '@sms.nhs.net'
from	#FFT
where case when 
									len(case when left(tsqltoolbox.StringUtil.ReplaceNonNumericChars(REPLACE([Pat Tel no], ' ', '')), 2) = '07'
										then tsqltoolbox.StringUtil.ReplaceNonNumericChars(REPLACE([Pat Tel no], ' ', ''))
									else NULL
									end) = 11 then 
												(case when left(tsqltoolbox.StringUtil.ReplaceNonNumericChars(REPLACE([Pat Tel no], ' ', '')), 2) = '07'
													then tsqltoolbox.StringUtil.ReplaceNonNumericChars(REPLACE([Pat Tel no], ' ', ''))
												else NULL
												end)
									else NULL
									end
							+ '' + '@sms.nhs.net' is not null
and		[Patient Date of Death] is null




GO
